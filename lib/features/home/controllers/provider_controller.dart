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

/// Durée affichée dans l'UI avant l'auto-déclin d'une demande dispatch.
const kDispatchTimeoutSeconds = 30;

class ProviderController extends ChangeNotifier {
  final _api      = ApiService.instance;
  final _realtime = RealtimeService.instance;
  final _location = LocationService();

  ProviderModel?          _provider;
  List<InterventionModel> _myInterventions = [];
  InterventionModel?      _pendingDispatch;
  List<ProviderAssistant> _assistants      = [];
  bool                    _isAvailable = true;
  bool                    _isLoading   = false;
  bool                    _initialized = false;
  String?                 _actionError;

  StreamSubscription<Position>?    _locationSub;
  StreamSubscription?              _wsSub;
  StreamSubscription<RemoteMessage>? _fcmSub;
  Timer?                           _pollTimer;

  // Timer 30 s par demande dispatch — auto-déclin si pas de réponse.
  // Stocke aussi la date de départ pour afficher le compte à rebours à l'UI.
  final Map<String, Timer>    _dispatchTimers   = {};
  final Map<String, DateTime> _dispatchDeadlines = {};

  // ── Getters ───────────────────────────────────────────────────────────────

  ProviderModel?          get provider        => _provider;
  List<InterventionModel> get myInterventions => _myInterventions;
  InterventionModel?      get pendingDispatch => _pendingDispatch;
  List<ProviderAssistant> get assistants      => List.unmodifiable(_assistants);
  bool get canAddAssistant =>
      _assistants.where((a) => a.isActive).length < 3;
  bool    get isAvailable => _isAvailable;
  bool    get isLoading   => _isLoading;
  String? get actionError => _actionError;

  List<InterventionModel> get pendingRequests =>
      _myInterventions
          .where((i) => i.isPending && i.dispatchedProviderId == _provider?.id)
          .toList();

  InterventionModel? get activeIntervention =>
      _myInterventions
          .where((i) => i.isAccepted || i.isInProgress)
          .firstOrNull;

  double get todayEarnings {
    final today = DateTime.now();
    return _myInterventions
        .where((i) =>
            i.isCompleted &&
            i.completedAt != null &&
            i.completedAt!.day   == today.day &&
            i.completedAt!.month == today.month &&
            i.completedAt!.year  == today.year)
        .fold(0.0, (sum, i) => sum + i.totalPrice * 0.85);
  }

  double get totalEarnings => _myInterventions
      .where((i) => i.isCompleted)
      .fold(0.0, (sum, i) => sum + i.totalPrice * 0.85);

  int get completedCount =>
      _myInterventions.where((i) => i.isCompleted).length;

  /// Secondes restantes avant auto-déclin pour [interventionId].
  /// Retourne null si aucun timer actif.
  int? dispatchSecondsLeft(String interventionId) {
    final deadline = _dispatchDeadlines[interventionId];
    if (deadline == null) return null;
    final remaining =
        deadline.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

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

  /// Charge les interventions au démarrage et, si une demande est déjà en
  /// attente (push tapé en arrière-plan), déclenche l'alarme + le timer.
  Future<void> _bootstrapDispatch() async {
    await _loadInterventions();
    final pending = pendingRequests;
    if (pending.isNotEmpty) {
      final first = pending.first;
      // CORRECTION : le timer était manquant ici — sans lui, aucun auto-déclin
      // n'était déclenché pour une demande trouvée au démarrage de l'app.
      _startDispatchTimer(first.id);
      ProviderAlertService.instance.newOrder(
        dispatchId    : first.id,
        clientName    : first.clientName,
        serviceType   : first.serviceTypeName,
        address       : first.address,
        estimatedPrice: first.estimatedPrice,
      );
      notifyListeners();
    }
  }

  // ── Polling (filet de secours) ─────────────────────────────────────────────
  // CORRECTION : 4s → 15s. Avec WebSocket + FCM, le polling n'est qu'un
  // filet de secours. 4s était inutilement agressif et chargeait le serveur.
  void _startPolling() {
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollForUpdates(),
    );
  }

  Future<void> _pollForUpdates() async {
    final previousPendingIds =
        pendingRequests.map((r) => r.id).toSet();
    await _loadInterventions();
    final newPendingIds =
        pendingRequests.map((r) => r.id).toSet();

    // Demandes disparues (client annulé, timeout)
    final disappeared = previousPendingIds.difference(newPendingIds);
    for (final id in disappeared) {
      _cancelDispatchTimer(id);
      if (_pendingDispatch?.id == id) _pendingDispatch = null;
    }
    if (disappeared.isNotEmpty && newPendingIds.isEmpty) {
      ProviderAlertService.instance.stop();
    }

    // Nouvelles demandes détectées par polling
    final freshlyArrived = newPendingIds.difference(previousPendingIds);
    if (freshlyArrived.isNotEmpty) {
      final id = freshlyArrived.first;
      final match =
          _myInterventions.where((i) => i.id == id);
      if (match.isNotEmpty) {
        final intervention = match.first;
        debugPrint(
            '[ProviderController] Nouvelle demande (polling): $id');
        _startDispatchTimer(id);
        ProviderAlertService.instance.newOrder(
          dispatchId    : id,
          clientName    : intervention.clientName,
          serviceType   : intervention.serviceTypeName,
          address       : intervention.address,
          estimatedPrice: intervention.estimatedPrice,
        );
      }
    }
  }

  // ── FCM foreground ─────────────────────────────────────────────────────────
  void _subscribeFcm() {
    _fcmSub = FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      final type = data['type'] as String?;
      if (type != 'dispatch_alert' && type != 'new_order') return;

      final interventionId = data['intervention_id'] as String?;
      if (interventionId == null) return;

      final clientName     = data['client_name']     as String?;
      final serviceType    = data['service_type']    as String?;
      final address        = data['address']         as String?;
      final estimatedPrice = data['estimated_price'] as String?;

      debugPrint(
          '[ProviderController] FCM $type: $interventionId — $clientName');

      _startDispatchTimer(interventionId);
      ProviderAlertService.instance.newOrder(
        dispatchId    : interventionId,
        clientName    : clientName,
        serviceType   : serviceType,
        address       : address,
        estimatedPrice: estimatedPrice,
      );
      _loadInterventions();
    });
  }

  // ── Timer dispatch (30s → auto-déclin) ────────────────────────────────────

  void _startDispatchTimer(String interventionId) {
    _dispatchTimers[interventionId]?.cancel();

    final deadline = DateTime.now()
        .add(const Duration(seconds: kDispatchTimeoutSeconds));
    _dispatchDeadlines[interventionId] = deadline;

    // Notifier l'UI chaque seconde pour mettre à jour le compte à rebours
    int remaining = kDispatchTimeoutSeconds;
    _dispatchTimers[interventionId] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        remaining--;
        notifyListeners(); // rafraîchit le compte à rebours dans l'UI

        if (remaining <= 0) {
          timer.cancel();
          _dispatchTimers.remove(interventionId);
          _dispatchDeadlines.remove(interventionId);
          _autoDeny(interventionId);
        }
      },
    );

    notifyListeners();
  }

  void _cancelDispatchTimer(String interventionId) {
    _dispatchTimers[interventionId]?.cancel();
    _dispatchTimers.remove(interventionId);
    _dispatchDeadlines.remove(interventionId);
  }

  void _autoDeny(String interventionId) {
    debugPrint(
        '[ProviderController] Timeout 30s — auto-déclin $interventionId');
    _myInterventions.removeWhere((i) => i.id == interventionId);
    if (_pendingDispatch?.id == interventionId) {
      _pendingDispatch = null;
    }
    ProviderAlertService.instance.stop();
    notifyListeners();
    _api.declineDispatchedIntervention(interventionId).catchError(
      (e) => debugPrint(
          '[ProviderController] auto-déclin API error: $e'),
    );
  }

  Future<void> _loadInterventions() async {
    try {
      final data = await _api.getProviderInterventions();
      _myInterventions = data
          .map((e) => InterventionModel.fromJson(
              e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[ProviderController] Erreur chargement : $e');
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  void _subscribeWebSocket() {
    if (_provider == null) return;
    _wsSub =
        _realtime.subscribeToDispatch(_provider!.id).listen((data) {
      final updated = InterventionModel.fromJson(data);

      if (updated.dispatchedProviderId == _provider!.id &&
          updated.isPending) {
        _pendingDispatch = updated;
        _startDispatchTimer(updated.id);
        ProviderAlertService.instance.newOrder(
          dispatchId    : updated.id,
          clientName    : updated.clientName,
          serviceType   : updated.serviceTypeName,
          address       : updated.address,
          estimatedPrice: updated.estimatedPrice,
        );
        notifyListeners();
        return;
      }

      final idx =
          _myInterventions.indexWhere((i) => i.id == updated.id);
      if (idx >= 0) {
        _myInterventions[idx] = updated;
      } else {
        _myInterventions.insert(0, updated);
      }

      if (!updated.isPending) {
        if (_pendingDispatch?.id == updated.id) {
          _pendingDispatch = null;
        }
        _cancelDispatchTimer(updated.id);
        ProviderAlertService.instance.stop();
      }
      notifyListeners();
    });
  }

  // ── GPS continu ────────────────────────────────────────────────────────────

  void _startLocationUpdates() {
    _sendImmediatePosition();
    _locationSub = _location.positionStream().listen(
      (pos) async {
        if (_provider == null) return;
        try {
          await _api.updateGlobalLocation(pos.latitude, pos.longitude);
          final active = activeIntervention;
          if (active != null) {
            await _api.updateProviderLocation(
                active.id, pos.latitude, pos.longitude);
          }
        } catch (e) {
          debugPrint(
              '[ProviderController] Erreur mise à jour position : $e');
        }
      },
      onError: (e) =>
          debugPrint('[ProviderController] Erreur flux position : $e'),
    );
  }

  Future<void> _sendImmediatePosition() async {
    try {
      final pos = await _location.getCurrentPosition();
      if (pos == null || _provider == null) return;
      await _api.updateGlobalLocation(pos.latitude, pos.longitude);
      final active = activeIntervention;
      if (active != null) {
        await _api.updateProviderLocation(
            active.id, pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint(
          '[ProviderController] Erreur position immédiate : $e');
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

  Future<bool> acceptIntervention(String id,
      {int? assignedAssistantId}) async {
    _isLoading   = true;
    _actionError = null;
    _cancelDispatchTimer(id);
    ProviderAlertService.instance.stop();
    notifyListeners();
    try {
      final data = await _api
          .acceptIntervention(id,
              assignedAssistantId: assignedAssistantId)
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
      debugPrint(
          '[ProviderController] acceptIntervention error: $e');
      FirebaseCrashlytics.instance
          .log('[ProviderController] acceptIntervention error: $e');
      _actionError =
          'Impossible d\'accepter cette demande. Réessayez.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> startIntervention(String id) async {
    _actionError = null;
    try {
      final data = await _api
          .startIntervention(id)
          .timeout(const Duration(seconds: 30));
      _upsert(InterventionModel.fromJson(data));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
          '[ProviderController] startIntervention error: $e');
      FirebaseCrashlytics.instance
          .log('[ProviderController] startIntervention error: $e');
      _actionError =
          'Impossible de démarrer l\'intervention. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeIntervention(String id,
      {required double finalAmount}) async {
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
      debugPrint(
          '[ProviderController] completeIntervention error: $e');
      FirebaseCrashlytics.instance
          .log('[ProviderController] completeIntervention error: $e');
      _actionError =
          'Impossible de terminer l\'intervention. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  /// Annule une intervention déjà acceptée.
  /// CORRECTION : utilise désormais la route provider (cancelAcceptedIntervention)
  /// au lieu de la route user (cancelUserIntervention).
  Future<bool> cancelIntervention(String id) async {
    _actionError = null;
    try {
      await _api
          .cancelAcceptedIntervention(id)
          .timeout(const Duration(seconds: 30));
      _myInterventions.removeWhere((i) => i.id == id);
      _isAvailable = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
          '[ProviderController] cancelIntervention error: $e');
      FirebaseCrashlytics.instance
          .log('[ProviderController] cancelIntervention error: $e');
      _actionError =
          'Impossible d\'annuler cette intervention. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> declineIntervention(String id) async {
    _actionError = null;
    _cancelDispatchTimer(id);
    ProviderAlertService.instance.stop();
    _myInterventions.removeWhere((i) => i.id == id);
    if (_pendingDispatch?.id == id) {
      _pendingDispatch = null;
    }
    notifyListeners();
    try {
      await _api
          .declineDispatchedIntervention(id)
          .timeout(const Duration(seconds: 30));
      return true;
    } catch (e) {
      debugPrint(
          '[ProviderController] declineIntervention error: $e');
      FirebaseCrashlytics.instance
          .log('[ProviderController] declineIntervention error: $e');
      _actionError =
          'Impossible de refuser cette demande. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  // ── Équipe / intervenants ─────────────────────────────────────────────────

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

  Future<bool> assignAssistant(
      String interventionId, int? assistantId) async {
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
      _actionError =
          'Impossible de réaffecter cette commande. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  void _upsert(InterventionModel updated) {
    final idx =
        _myInterventions.indexWhere((i) => i.id == updated.id);
    if (idx >= 0) {
      _myInterventions[idx] = updated;
    } else {
      _myInterventions.insert(0, updated);
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _locationSub?.cancel();
    _fcmSub?.cancel();
    _pollTimer?.cancel();
    for (final t in _dispatchTimers.values) {
      t.cancel();
    }
    _dispatchTimers.clear();
    _dispatchDeadlines.clear();
    super.dispose();
  }
}
