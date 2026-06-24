import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/models.dart';
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
  bool                    _isAvailable = true;
  bool                    _isLoading   = false;
  bool                    _initialized = false;

  StreamSubscription<Position>? _locationSub;
  StreamSubscription?           _wsSub;

  ProviderModel?          get provider          => _provider;
  List<InterventionModel> get myInterventions   => _myInterventions;
  InterventionModel?      get pendingDispatch   => _pendingDispatch;
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
    _loadInterventions();
    _startLocationUpdates();
    _subscribeWebSocket();
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

      // Nouvelle demande de dispatch → afficher l'alerte
      if (updated.dispatchedProviderId == _provider!.id && updated.isPending) {
        _pendingDispatch = updated;
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
      }
      notifyListeners();
    });
  }

  // ── GPS continu ───────────────────────────────────────────────────────────

  void _startLocationUpdates() {
    _locationSub = _location.positionStream().listen((pos) async {
      if (_provider == null) return;
      await _api.updateGlobalLocation(pos.latitude, pos.longitude);

      // Mettre aussi à jour la position dans l'intervention active
      final active = activeIntervention;
      if (active != null) {
        await _api.updateProviderLocation(active.id, pos.latitude, pos.longitude);
      }
    });
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

  Future<bool> acceptIntervention(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data    = await _api.acceptIntervention(id);
      final updated = InterventionModel.fromJson(data);
      _upsert(updated);
      _pendingDispatch = null;
      _isAvailable     = false;
      _isLoading       = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> startIntervention(String id) async {
    final data = await _api.startIntervention(id);
    _upsert(InterventionModel.fromJson(data));
    notifyListeners();
  }

  Future<void> completeIntervention(String id) async {
    final data = await _api.completeIntervention(id);
    _upsert(InterventionModel.fromJson(data));
    _isAvailable = true;
    notifyListeners();
  }

  Future<void> declineIntervention(String id) async {
    await _api.cancelIntervention(id);
    _pendingDispatch = null;
    notifyListeners();
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
    super.dispose();
  }
}
