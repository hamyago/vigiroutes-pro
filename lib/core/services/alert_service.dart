import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Alerte « nouvelle commande » pour le prestataire :
/// - joue `assets/raw/alarm.wav` EN BOUCLE (comme une sonnerie) tant que le
///   prestataire n'a pas accepté/refusé,
/// - annonce vocalement en français qu'une commande est en attente.
///
/// L'alarme est idempotente par commande (voir [stop]/[newOrder]) pour ne pas
/// re-sonner à chaque tick WebSocket de la même demande.
class ProviderAlertService {
  ProviderAlertService._();
  static final ProviderAlertService instance = ProviderAlertService._();

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  String? _ringingDispatchId;

  Future<void> _ensureTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ttsReady = true;
    } catch (e) {
      debugPrint('[ProviderAlert] init TTS: $e');
    }
  }

  /// Démarre la sonnerie + l'annonce pour une nouvelle commande.
  /// Ne fait rien si la même commande sonne déjà.
  Future<void> newOrder({required String dispatchId, String? serviceName}) async {
    if (_ringingDispatchId == dispatchId) return;
    _ringingDispatchId = dispatchId;

    // Sonnerie en boucle
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('raw/alarm.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('[ProviderAlert] alarme: $e');
    }

    // Annonce vocale (une fois)
    await _ensureTts();
    final svc = (serviceName != null && serviceName.trim().isNotEmpty)
        ? ' pour ${serviceName.trim()}'
        : '';
    try {
      await _tts.speak(
          'Nouvelle commande$svc ! Un client a besoin de vous. '
          'Veuillez accepter ou refuser la demande.');
    } catch (e) {
      debugPrint('[ProviderAlert] TTS: $e');
    }
  }

  /// Arrête la sonnerie et la voix (à l'acceptation, au refus, ou si la
  /// demande est résolue/expirée). Réarme pour la prochaine commande.
  Future<void> stop() async {
    _ringingDispatchId = null;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _tts.stop();
  }
}
