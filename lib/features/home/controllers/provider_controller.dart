import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/models.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/services/location_service.dart';

class ProviderController extends ChangeNotifier {
  final _api      = ApiService.instance;
  final _realtime = RealtimeService.instance;
  final _location = LocationService();

  ProviderModel?          _provider;
  List<InterventionModel> _myInterventions  = [];
  InterventionModel?      _pendingDispatch;
  List<ProviderAssistant> _assistants       = [];
  bool                    _isAvailable = true;
  bool                    _isLoading   = false;
  bool                    _initialized = false;
  String?                 _actionError;

  // ── Timeout dispatch ──────────────────────────────────────────────────────
  // Pour chaque intervention en attente, on garde un timer de 30s.
  // Si le prestataire ne répond pas, on appelle /decline côté API
  // (le serveur repassera au prestataire suivant dans la liste).
  final Map<String, Timer> _dispatchTimers = {};

  StreamSubscription<Position>?      _locationSub;
  StreamSubscription?                _wsSub;
  StreamSubscription<RemoteMessage>? _fcmSub;
  Timer?                             _pollTimer;

  ProviderModel?          get provider          => _provider;
  List<InterventionModel> get myInterventions   => _myInterventions;
  InterventionModel?      get pendingDispatch   => _pendingDispatch;
  List<ProviderAssistant> get assistants        => List.unmodifiable(_assistants);
  bool                    get canAddAssistant   =>
      _assistants.where((a) => a.isActive).length < 3;
  bool                    get isAvailable       => _isAvailable;
  bool                    get isLoading         => _isLoading;
  String?                 get actionError       => _actionError;

  List<InterventionModel> get pendingRequests =>
      _myInterventions
          .where((i) => i.isPending && i.dispatchedProviderId == _provider?.id)
          .toList();

  InterventionModel? get activeIntervention =>
      _myInterventions.where((i) => i.isAccepted || i.isInProgress).firstOrNull;

  double get todayEarnings {
    final today = DateTime.now();
    return _myInterventions
        .where((i) => i.isCompleted && i.completedAt != null
            && i.completedAt!.day   == today.day
            && i.completedAt!.month == today.month
            && i.completedAt!.year  == today.year)
        .fold(0.0, (sum, i) => sum + i.totalPrice * 0.85);
  }

  double get totalEarnings => _myInterventions
      .where((i) => i.isCompleted)
      .fold(0.0, (sum, i) => sum + i.totalPrice * 0.85);

  int get completedCount => _myInterventions.where((i) => i.isCompleted).length;

  // ── Initialisation (idempotente) ──────────────────────────────────────────

  void initialize(ProviderModel provider) {
    _provider    = provider;
    _isAvailable = provider.isAvailable;

    if (_initialized) {
      notifyListeners();
      return;
    }
    _initialized = true;
    _bootstrapDispatch();
    loadAssistants();
    _startLocationUpdates();
    _subscribeWebSocket();
    _subscribeFcm();
    _startPolling();
  }

  Future<void> _bootstrapDispatch() async {
    await _loadInterventions();
    final pending = pendingRequests;
    if (pending.isNotEmpty) {
      final first = pending.first;
      _triggerDispatchAlert(first);
      notifyListeners();
    }
  }

  // ── Polling de secours (4s) ───────────────────────────────────────────────

  void _startPolling() {
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollForUpdates(),
    );
  }

  Future<void> _pollForUpdates() async {
    final previousPendingIds = pendingRequests.map((r) => r.id).toSet();
    await _loadInterventions();
    final newPendingIds = pendingRequests.map((r) => r.id).toSet();

    final freshlyArrived = newPendingIds.difference(previousPendingIds);
    for (final id in freshlyArrived) {
      final match = _myInterventions.where((i) => i.id == id);
      if (match.isNotEmpty) {
        debugPrint('[ProviderController] Nouvelle demande détectée par sondage: $id');
        _triggerDispatchAlert(match.first);
      }
    }
  }

  // ── FCM foreground ────────────────────────────────────────────────────────

  void _subscribeFcm() {
    _fcmSub = FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      final type = data['type'] as String?;

      // Accepter 'dispatch_alert' ET 'new_order' (deux noms possibles selon
      // la version du serveur) ainsi que les notifications sans data.type
      // mais avec un intervention_id — pour couvrir FCM V1 legacy.
      if (type != 'dispatch_alert' && type != 'new_order') return;

      final interventionId = data['intervention_id'] as String?;
      if (interventionId == null) return;

      final clientName     = data['client_name']     as String?;
      final serviceType    = data['service_type']    as String?;
      final address        = data['address']         as String?;
      final estimatedPrice = data['estimated_price'] as String?;

      debugPrint('[ProviderController] FCM dispatch reçu: $interventionId');

      // Construire un InterventionModel minimal pour le timer de timeout
      // en attendant le rechargement complet.
      ProviderAlertService.instance.newOrder(
        dispatchId    : interventionId,
        clientName    : clientName,
        serviceType   : serviceType,
        address       : address,
        estimatedPrice: estimatedPrice,
      );

      // Démarrer le timer de 30s pour ce dispatch
      _startDispatchTimer(interventionId);

      // Rafraîchir pour faire apparaître la demande immédiatement.
      _loadInterventions();
    });
  }

  // ── Alerte + timer de timeout 30s ────────────────────────────────────────

  void _triggerDispatchAlert(InterventionModel intervention) {
    ProviderAlertService.instance.newOrder(
      dispatchId    : intervention.id,
      clientName    : intervention.clientName,
      serviceType   : intervention.serviceTypeName,
      address       : intervention.address,
      estimatedPrice: intervention.estimatedPrice?.toString(),
    );
    _startDispatchTimer(intervention.id);
  }

  /// Lance un timer de 30s pour le dispatch [interventionId].
  /// Si le prestataire n'accepte/refuse pas dans ce délai, on decline
  /// automatiquement (le serveur passera au prestataire suivant).
  void _startDispatchTimer(String interventionId) {
    // Annuler un éventuel timer précédent pour la même intervention.
    _dispatchTimers[interventionId]?.cancel();

    _dispatchTimers[interventionId] = Timer(
      const Duration(seconds: 30),
      () => _autoDeclineOnTimeout(interventionId),
    );
  }

  Future<void> _autoDeclineOnTimeout(String interventionId) async {
    debugPrint('[ProviderController] Timeout 30s — auto-decline $interventionId');
    _dispatchTimers.remove(interventionId);

    // Vérifier que l'intervention est toujours en attente (pas déjà traitée).
    final stillPending = pendingRequests.any((r) => r.id == interventionId);
    if (!stillPending) return;

    try {
      await _api.declineDispatchedIntervention(interventionId);
      // Supprimer localement pour ne pas laisser la demande affichée.
      _myInterventions.removeWhere((i) => i.id == interventionId);
      if (_pendingDispatch?.id == interventionId) _pendingDispatch = null;
      ProviderAlertService.instance.stop();
      notifyListeners();
      debugPrint('[ProviderController] Auto-decline OK pour $interventionId');
    } catch (e) {
      debugPrint('[ProviderController] Erreur auto-decline: $e');
      FirebaseCrashlytics.instance.log(
          '[ProviderController] auto-decline ERREUR $interventionId: $e');
    }
  }

  void _cancelDispatchTimer(String interventionId) {
    _dispatchTimers[interventionId]?.cancel();
    _dispatchTimers.remove(interventionId);
  }

  // ── Chargement des interventions ──────────────────────────────────────────

  Future<void> _loadInterventions() async {
    try {
      final data = await _api.getProviderInterventions();
      _myInterventions = data
          .map((e) => InterventionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[ProviderController] Erreur chargement : $e');
    }
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────

  void _subscribeWebSocket() {
    if (_provider == null) return;
    _wsSub = _realtime.subscribeToDispatch(_provider!.id).listen((data) {
      final updated = InterventionModel.fromJson(data);

      if (updated.dispatchedProviderId == _provider!.id && updated.isPending) {
        _pendingDispatch = updated;
        _triggerDispatchAlert(updated);
        notifyListeners();
        return;
      }

      final idx = _myInterventions.indexWhere((i) => i.id == updated.id);
      if (idx >= 0) {
        _myInterventions[idx] = updated;
      } else {
        _myInterventions.insert(0, updated);
      }

      if (_pendingDispatch?.id == updated.id && !updated.isPending) {
        _pendingDispatch = null;
        _cancelDispatchTimer(updated.id);
        ProviderAlertService.instance.stop();
      }
      notifyListeners();
    });
  }

  // ── GPS continu ───────────────────────────────────────────────────────────

  void _startLocationUpdates() {
    _sendImmediatePosition();
    _locationSub = _location.positionStream().listen(
      (pos) async {
        if (_provider == null) return;
        try {
          await _api.updateGlobalLocation(pos.latitude, pos.longitude);
          final active = activeIntervention;
          if (active != null) {
            await _api.updateProviderLocation(active.id, pos.latitude, pos.longitude);
          }
        } catch (e) {
          debugPrint('[ProviderController] Erreur mise à jour position : $e');
        }
      },
      onError: (e) => debugPrint('[ProviderController] Erreur flux position : $e'),
    );
  }

  Future<void> _sendImmediatePosition() async {
    try {
      final pos = await _location.getCurrentPosition();
      if (pos == null || _provider == null) return;
      await _api.updateGlobalLocation(pos.latitude, pos.longitude);
      final active = activeIntervention;
      if (active != null) {
        await _api.updateProviderLocation(active.id, pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint('[ProviderController] Erreur position immédiate : $e');
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> toggleAvailability() async {
    if (!_isAvailable && activeIntervention != null) return;
    _isAvailable = !_isAvailable;
    notifyListeners();
    try {
      await _api.updateAvailability(_isAvailable);
    } catch (_) {
      _isAvailable = !_isAvailable;
      notifyListeners();
    }
  }

  Future<bool> acceptIntervention(String id, {int? assignedAssistantId}) async {
    _isLoading   = true;
    _actionError = null;
    // Annuler le timer de timeout — le prestataire a répondu.
    _cancelDispatchTimer(id);
    ProviderAlertService.instance.stop();
    notifyListeners();
    try {
      final data    = await _api
          .acceptIntervention(id, assignedAssistantId: assignedAssistantId)
          .timeout(const Duration(seconds: 30));
      final updated = InterventionModel.fromJson(data);
      _upsert(updated);
      _pendingDispatch = null;
      _isAvailable     = false;
      _isLoading       = false;
      notifyListeners();
      _sendImmediatePosition();
      return true;
    } catch (e) {
      debugPrint('[ProviderController] acceptIntervention error: $e');
      FirebaseCrashlytics.instance.log('[ProviderController] acceptIntervention error: $e');
      _actionError = 'Impossible d\'accepter cette demande. Réessayez.';
      _isLoading   = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> startIntervention(String id) async {
    _actionError = null;
    try {
      final data = await _api.startIntervention(id).timeout(const Duration(seconds: 30));
      _upsert(InterventionModel.fromJson(data));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ProviderController] startIntervention error: $e');
      FirebaseCrashlytics.instance.log('[ProviderController] startIntervention error: $e');
      _actionError = 'Impossible de démarrer l\'intervention. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeIntervention(String id, {required double finalAmount}) async {
    _actionError = null;
    try {
      final data = await _api
          .completeIntervention(id, finalAmount: finalAmount)
          .timeout(const Duration(seconds: 30));
      _upsert(InterventionModel.fromJson(data));
      _isAvailable = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ProviderController] completeIntervention error: $e');
      FirebaseCrashlytics.instance.log('[ProviderController] completeIntervention error: $e');
      _actionError = 'Impossible de terminer l\'intervention. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> declineIntervention(String id) async {
    _actionError = null;
    // Annuler le timer — le prestataire a répondu (refus explicite).
    _cancelDispatchTimer(id);
    try {
      ProviderAlertService.instance.stop();
      await _api.declineDispatchedIntervention(id).timeout(const Duration(seconds: 30));
      _myInterventions.removeWhere((i) => i.id == id);
      _pendingDispatch = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ProviderController] declineIntervention error: $e');
      FirebaseCrashlytics.instance.log('[ProviderController] declineIntervention error: $e');
      _actionError = 'Impossible de refuser cette demande. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  // ── Équipe ────────────────────────────────────────────────────────────────

  Future<void> loadAssistants() async {
    try {
      final list = await _api.getAssistants();
      _assistants
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (e) {
      debugPrint('[ProviderController] loadAssistants: $e');
    }
  }

  Future<String?> addAssistant({
    required String name,
    String? phone,
    String? photoBase64,
  }) async {
    try {
      final created = await _api.createAssistant(
          name: name, phone: phone, photoBase64: photoBase64);
      _assistants.add(created);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[ProviderController] addAssistant: $e');
      return 'Impossible d\'ajouter cet assistant. Réessayez.';
    }
  }

  Future<String?> updateAssistant(int id, {
    String? name,
    String? phone,
    String? photoBase64,
  }) async {
    try {
      final updated = await _api.updateAssistant(id,
          name: name, phone: phone, photoBase64: photoBase64);
      final idx = _assistants.indexWhere((a) => a.id == id);
      if (idx >= 0) _assistants[idx] = updated;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[ProviderController] updateAssistant: $e');
      return 'Impossible de modifier cet assistant. Réessayez.';
    }
  }

  Future<bool> removeAssistant(int id) async {
    try {
      await _api.deleteAssistant(id);
      _assistants.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ProviderController] removeAssistant: $e');
      return false;
    }
  }

  Future<bool> assignAssistant(String interventionId, int? assistantId) async {
    _actionError = null;
    try {
      final data = await _api
          .assignAssistant(interventionId, assistantId)
          .timeout(const Duration(seconds: 30));
      _upsert(InterventionModel.fromJson(data));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ProviderController] assignAssistant: $e');
      _actionError = 'Impossible de réaffecter cette commande. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  void _upsert(InterventionModel updated) {
    final idx = _myInterventions.indexWhere((i) => i.id == updated.id);
    if (idx >= 0) _myInterventions[idx] = updated;
    else _myInterventions.insert(0, updated);
  }

  @override
  void dispose() {
    for (final t in _dispatchTimers.values) {
      t.cancel();
    }
    _dispatchTimers.clear();
    _wsSub?.cancel();
    _locationSub?.cancel();
    _fcmSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
