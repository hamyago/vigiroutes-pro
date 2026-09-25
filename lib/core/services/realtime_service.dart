import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service WebSocket natif — compatible avec Laravel Reverb
/// Remplace pusher_channels_flutter (incompatible AGP 8.11+)
///
/// AMÉLIORATIONS v2 :
/// - Backoff exponentiel avec cap à 60s (évite l'accumulation de timers)
/// - Compteur de tentatives pour le diagnostic
/// - Reconnexion propre : on ferme le canal précédent avant de rouvrir
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  static const String _host    = 'api.vigiroutes.com';
  static const String _appKey  = '642e796713cd4093e508862ee725e601';
  static const int    _port    = 443;
  static const String _authUrl =
      'https://$_host/api/provider/broadcasting/auth';

  WebSocketChannel? _channel;
  String?           _token;
  String?           _socketId;
  bool              _connected = false;
  Timer?            _pingTimer;
  Timer?            _reconnectTimer;

  // ── Backoff exponentiel ───────────────────────────────────────────────────
  int _reconnectAttempts = 0;
  static const int _maxBackoffSeconds = 60;

  Duration get _nextBackoff {
    // 5s, 10s, 20s, 40s, 60s max
    final secs = min(5 * pow(2, _reconnectAttempts).toInt(), _maxBackoffSeconds);
    return Duration(seconds: secs);
  }

  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  final Map<String, Set<String>> _subscriptions = {};
  final Dio _authDio = Dio();

  bool get isConnected => _connected;

  // ── Connexion ──────────────────────────────────────────────────────────────

  Future<void> init(String sanctumToken) async {
    _token = sanctumToken;
    _reconnectAttempts = 0;
    await _connect();
  }

  Future<void> _connect() async {
    // Fermer proprement un éventuel canal zombie avant reconnexion
    try { await _channel?.sink.close(); } catch (_) {}
    _channel = null;

    try {
      final uri = Uri.parse(
        'wss://$_host:$_port/app/$_appKey'
        '?protocol=7&client=dart&version=1.0&flash=false',
      );

      _channel = WebSocketChannel.connect(uri);

      // Sans `await ready`, les erreurs DNS/réseau ne sont pas rattrapées
      // de façon fiable et remontent comme exceptions non gérées → crash.
      await _channel!.ready;

      _connected = true;
      _reconnectAttempts = 0; // succès → réinitialiser le compteur

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
      );

      _pingTimer?.cancel();
      _pingTimer =
          Timer.periodic(const Duration(seconds: 30), (_) => _ping());

      debugPrint('[WS] Connecté à Reverb');
    } catch (e) {
      debugPrint('[WS] Erreur connexion (tentative $_reconnectAttempts) : $e');
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg   = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String? ?? '';
      final chan   = msg['channel'] as String? ?? '';

      if (event == 'pusher:ping') {
        _send({'event': 'pusher:pong', 'data': {}});
        return;
      }

      if (event == 'pusher:connection_established') {
        try {
          final data = msg['data'];
          final parsed = data is String
              ? jsonDecode(data) as Map<String, dynamic>
              : Map<String, dynamic>.from(data as Map);
          _socketId = parsed['socket_id'] as String?;
        } catch (e) {
          debugPrint('[WS] Impossible de lire le socket_id: $e');
        }
        debugPrint('[WS] Handshake Reverb OK (socket_id=$_socketId)');
        // Re-souscrire aux canaux actifs après reconnexion
        for (final channel in _subscriptions.keys) {
          _subscribeChannel(channel);
        }
        return;
      }

      final key = '$chan:$event';
      if (_controllers.containsKey(key)) {
        final data = msg['data'];
        Map<String, dynamic> parsed;
        if (data is String) {
          parsed = jsonDecode(data) as Map<String, dynamic>;
        } else if (data is Map) {
          parsed = Map<String, dynamic>.from(data);
        } else {
          parsed = {};
        }
        _controllers[key]!.add(parsed);
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[WS] Erreur: $error');
    _connected = false;
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WS] Connexion fermée');
    _connected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    final delay = _nextBackoff;
    _reconnectAttempts++;
    debugPrint('[WS] Reconnexion dans ${delay.inSeconds}s '
        '(tentative $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      await _connect();
    });
  }

  void _ping() {
    _send({'event': 'pusher:ping', 'data': {}});
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('[WS] Send error: $e');
    }
  }

  // ── Souscription aux canaux privés ─────────────────────────────────────────

  Future<void> _subscribeChannel(String channel) async {
    if (!channel.startsWith('private-')) {
      _send({'event': 'pusher:subscribe', 'data': {'channel': channel}});
      return;
    }

    if (_socketId == null) {
      debugPrint('[WS] Abonnement à $channel différé (socket_id pas encore prêt)');
      return;
    }

    final freshToken = _token;
    if (freshToken == null) {
      debugPrint('[WS] Abonnement à $channel différé (aucun jeton)');
      return;
    }

    try {
      final response = await _authDio.post(
        _authUrl,
        data: {
          'socket_id':    _socketId,
          'channel_name': channel,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $freshToken'},
          contentType: 'application/json',
        ),
      );
      final auth = response.data['auth'] as String?;
      if (auth == null) {
        debugPrint('[WS] Auth vide reçue pour $channel');
        return;
      }
      _send({
        'event': 'pusher:subscribe',
        'data': {
          'channel': channel,
          'auth':    auth,
        },
      });
      debugPrint('[WS] Abonné à $channel');
    } catch (e) {
      debugPrint('[WS] Échec auth canal $channel : $e');
    }
  }

  Stream<Map<String, dynamic>> subscribeToIntervention(String userId) =>
      _subscribe('private-provider.$userId', 'intervention.updated');

  Stream<Map<String, dynamic>> subscribeToDispatch(String providerId) =>
      _subscribe('private-provider.$providerId', 'intervention.updated');

  Stream<Map<String, dynamic>> subscribeToAdminInterventions() =>
      _subscribe('private-admin.interventions', 'intervention.updated');

  Stream<Map<String, dynamic>> subscribeToEmergencies() =>
      _subscribe('private-admin.interventions', 'emergency.created');

  Stream<Map<String, dynamic>> _subscribe(String channel, String event) {
    final key = '$channel:$event';

    if (!_controllers.containsKey(key)) {
      _controllers[key] = StreamController<Map<String, dynamic>>.broadcast();
      _subscriptions.putIfAbsent(channel, () => {}).add(event);
      if (_connected) _subscribeChannel(channel);
    }

    return _controllers[key]!.stream;
  }

  // ── Déconnexion ────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try { await _channel?.sink.close(); } catch (_) {}
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
    _subscriptions.clear();
    _connected = false;
    _reconnectAttempts = 0;
    debugPrint('[WS] Déconnecté');
  }
}
