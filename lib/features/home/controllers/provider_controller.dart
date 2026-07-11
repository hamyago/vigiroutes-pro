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
  InterventionModel?      _pendingDispatch;   // alerte dispatch entrante
  List<ProviderAssistant> _assistants       = []; // équipe du prestataire
  bool                    _isAvailable = true;
  bool                    _isLoading   = false;
  bool                    _initialized = false;

  StreamSubscription<Position>? _locationSub;
  StreamSubscription?           _wsSub;
  StreamSubscription<RemoteMessage>? _fcmSub;
  Timer?                        _pollTimer;

  ProviderModel?          get provider          => _provider;
  List<InterventionModel> get myInterventions   => _myInterventions;
  InterventionModel?      get pendingDispatch   => _pendingDispatch;
  List<ProviderAssistant> get assistants        => List.unmodifiable(_assistants);
  bool                    get canAddAssistant   =>
      _assistants.where((a) => a.isActive).length < 3;
  bool                    get isAvailable       => _isAvailable;
  bool                    get isLoading         => _isLoading;

  // Interventions actives (acceptées/en cours) — n'inclut PAS les pending dispatch
  List<InterventionModel> get pendingRequests =>
      _myInterventions.where((i) => i.isPending && i.dispatchedProviderId == _provider?.id).toList();

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

  /// Charge les interventions à l'ouverture et, si une demande est déjà en
  /// attente (typiquement un push de dispatch tapé alors que l'app était en
  /// arrière-plan — cas où onMessage ne se déclenche pas), lève l'alarme
  /// sonore pour que le prestataire ne rate pas la demande.
  Future<void> _bootstrapDispatch() async {
    await _loadInterventions();
    final pending = pendingRequests;
    if (pending.isNotEmpty) {
      ProviderAlertService.instance.newOrder(
        dispatchId:  pending.first.id,
        serviceName: pending.first.serviceTypeName,
      );
      notifyListeners();
    }
  }

  // ── Rafraîchissement automatique par sondage (secours) ──────────────────
  // AJOUTÉ : malgré plusieurs corrections successives (auth de canal,
  // jeton Firebase périmé...), la fiabilité du WebSocket en conditions
  // réelles n'a pas pu être confirmée. Ce sondage toutes les 4s repose
  // uniquement sur les endpoints REST, dont le bon fonctionnement a été
  // vérifié à de multiples reprises tout au long des sessions de debug -
  // garantie de secours simple, robuste, et qui ne dépend d'aucune
  // configuration WebSocket/Reverb. Tourne EN PLUS du WebSocket (les deux
  // ne se gênent pas).
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

    // Ne déclencher l'alarme QUE pour une demande qui vient d'apparaître
    // (pas à chaque sondage, sinon elle sonnerait toutes les 4s en boucle).
    final freshlyArrived = newPendingIds.difference(previousPendingIds);
    if (freshlyArrived.isNotEmpty) {
      final id = freshlyArrived.first;
      final match = _myInterventions.where((i) => i.id == id);
      if (match.isNotEmpty) {
        debugPrint('[ProviderController] Nouvelle demande détectée par sondage: $id');
        ProviderAlertService.instance.newOrder(
          dispatchId:  id,
          serviceName: match.first.serviceTypeName,
        );
      }
    }
  }

  // BUG CORRIGÉ : aucun gestionnaire n'existait pour les notifications FCM
  // reçues pendant que l'app est au premier plan (et _bgHandler dans
  // main.dart ne fait rien). Android affiche la notification système, mais
  // rien ne déclenchait l'alarme sonore/vocale interne (ProviderAlertService
  // ne joue jamais de son via le canal de notification Android — c'est un
  // lecteur audio + TTS entièrement côté Dart) ni ne rafraîchissait la
  // liste des demandes en attente. Redondant avec le WebSocket par
  // sécurité tant que sa fiabilité n'est pas confirmée.
  void _subscribeFcm() {
    _fcmSub = FirebaseMessaging.onMessage.listen((message) {
      final type = message.data['type'];
      if (type != 'dispatch_alert') return;

      final interventionId = message.data['intervention_id'] as String?;
      final serviceType    = message.data['service_type'] as String?;
      if (interventionId == null) return;

      debugPrint('[ProviderController] FCM dispatch_alert reçu: $interventionId');

      ProviderAlertService.instance.newOrder(
        dispatchId:  interventionId,
        serviceName: serviceType,
      );

      // Rafraîchir pour faire apparaître la nouvelle demande immédiatement.
      _loadInterventions();
    });
  }

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

  // ── WebSocket — remplace les streams Firestore ────────────────────────────

  void _subscribeWebSocket() {
    if (_provider == null) return;
    _wsSub = _realtime.subscribeToDispatch(_provider!.id).listen((data) {
      final updated = InterventionModel.fromJson(data);

      // Nouvelle demande de dispatch → afficher l'alerte + sonnerie
      if (updated.dispatchedProviderId == _provider!.id && updated.isPending) {
        _pendingDispatch = updated;
        ProviderAlertService.instance.newOrder(
          dispatchId:  updated.id,
          serviceName: updated.serviceTypeName,
        );
        notifyListeners();
        return;
      }

      // Mise à jour d'une intervention existante
      final idx = _myInterventions.indexWhere((i) => i.id == updated.id);
      if (idx >= 0) {
        _myInterventions[idx] = updated;
      } else {
        _myInterventions.insert(0, updated);
      }

      // Effacer l'alerte si résolue
      if (_pendingDispatch?.id == updated.id && !updated.isPending) {
        _pendingDispatch = null;
        ProviderAlertService.instance.stop();
      }
      notifyListeners();
    });
  }

  // ── GPS continu ───────────────────────────────────────────────────────────

  void _startLocationUpdates() {
    // BUG CORRIGÉ : le flux GPS (distanceFilter: 10) n'envoie une mise à
    // jour qu'après 10 mètres de déplacement RÉEL — tant que le
    // prestataire ne bouge pas (très courant juste après avoir accepté,
    // ou en tests en intérieur), AUCUNE position n'était jamais envoyée,
    // donc le client ne voyait même pas le point du prestataire sur sa
    // carte (pas juste "il ne bouge pas" — littéralement absent). On
    // envoie maintenant systématiquement une position immédiate au
    // démarrage, puis le flux filtré prend le relais pour les
    // déplacements réels.
    _sendImmediatePosition();

    _locationSub = _location.positionStream().listen(
      (pos) async {
        if (_provider == null) return;
        // BUG CRITIQUE CORRIGÉ : ce listener se déclenche à chaque mise à
        // jour GPS (potentiellement plusieurs fois par minute), en tâche de
        // fond, sans lien avec une action de l'utilisateur. Sans try/catch,
        // la moindre erreur serveur (même transitoire, ex: 500 ponctuel)
        // plantait l'app à N'IMPORTE QUEL MOMENT, y compris en pleine
        // intervention — le pire endroit possible pour un crash silencieux.
        try {
          await _api.updateGlobalLocation(pos.latitude, pos.longitude);

          // Mettre aussi à jour la position dans l'intervention active
          final active = activeIntervention;
          if (active != null) {
            await _api.updateProviderLocation(active.id, pos.latitude, pos.longitude);
          }
        } catch (e) {
          debugPrint('[ProviderController] Erreur mise à jour position : $e');
          // Volontairement silencieux : un ping GPS manqué n'est pas assez
          // grave pour interrompre le prestataire ou afficher une erreur —
          // le prochain ping (quelques secondes plus tard) réessaiera.
        }
      },
      onError: (e) {
        // Le FLUX GPS natif lui-même peut émettre une erreur (permission
        // révoquée en cours de route, service localisation coupé) — sans
        // ce handler, ça échapperait au try/catch ci-dessus et planterait
        // l'app pareil.
        debugPrint('[ProviderController] Erreur flux position : $e');
      },
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
      // Silencieux : le flux GPS ci-dessous réessaiera dès le premier
      // déplacement de toute façon.
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
      _isAvailable = !_isAvailable; // rollback
      notifyListeners();
    }
  }

  Future<bool> acceptIntervention(String id, {int? assignedAssistantId}) async {
    _isLoading = true;
    _actionError = null;
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
      // AJOUTÉ : au démarrage de l'app, aucune intervention n'est encore
      // active, donc l'envoi de position immédiate ne renseignait que la
      // position générale du prestataire, jamais provider_latitude sur
      // CETTE intervention précise. Sans ça, le client ne voyait aucun
      // point prestataire sur sa carte tant que celui-ci n'avait pas
      // parcouru 10m après avoir accepté.
      _sendImmediatePosition();
      return true;
    } catch (e) {
      debugPrint('[ProviderController] acceptIntervention error: $e');
      FirebaseCrashlytics.instance.log('[ProviderController] acceptIntervention error: $e');
      // BUG CORRIGÉ : ne définissait jamais _actionError, donc l'UI
      // affichait un message resté d'une précédente action (ex: "Impossible
      // de refuser cette demande" au clic sur "Accepter").
      _actionError = 'Impossible d\'accepter cette demande. Réessayez.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String? _actionError;
  String? get actionError => _actionError;

  /// AVANT : aucun try/catch ici. La moindre erreur reseau/backend lors du
  /// clic sur "Demarrer" plantait l'app entiere (exception non rattrapee
  /// remontant jusqu'au handler global -> crash -> retour splashscreen).
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
      debugPrint('[ProviderController] startIntervention error: $e');
      FirebaseCrashlytics.instance.log('[ProviderController] startIntervention error: $e');
      _actionError = 'Impossible de démarrer l\'intervention. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  /// Meme correctif : aucune protection avant, meme symptome que
  /// startIntervention (crash au clic sur "Terminer").
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

  /// Meme correctif que startIntervention/completeIntervention : aucune
  /// protection avant, meme symptome (crash au clic sur "Refuser").
  Future<bool> declineIntervention(String id) async {
    _actionError = null;
    try {
      ProviderAlertService.instance.stop();
      // BUG CORRIGÉ : appelait cancelIntervention() -> /user/interventions/
      // {id}/cancel, l'endpoint CLIENT. Un token prestataire ne passe
      // jamais ce contrôle (401 systématique), et comme l'app se
      // déconnecte automatiquement sur toute erreur 401, refuser une
      // demande plantait littéralement l'app et renvoyait au splashscreen.
      await _api.declineDispatchedIntervention(id).timeout(const Duration(seconds: 30));
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

  // ── Équipe / intervenants ────────────────────────────────────────────────

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

  /// Renvoie null en cas de succès, sinon un message d'erreur à afficher.
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

  /// Réaffecte l'intervenant d'une commande déjà acceptée (null = moi-même).
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
    _wsSub?.cancel();
    _locationSub?.cancel();
    _fcmSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
