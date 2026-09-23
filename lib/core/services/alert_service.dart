import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service d'alerte sonore + vocale pour les nouvelles courses.
///
/// Option C — Complet :
///   "Nouvelle course ! Client : [nom]. Type : [service].
///    Adresse : [adresse]. Montant estimé : [montant] francs."
///
/// Usage :
///   ProviderAlertService.instance.newOrder(
///     dispatchId : '42',
///     clientName : 'Moussa Diallo',
///     serviceType: 'Dépannage pneu',
///     address    : 'Avenue Cheikh Anta Diop, Dakar',
///     estimatedPrice: '15000',
///   );
class ProviderAlertService {
  ProviderAlertService._();
  static final instance = ProviderAlertService._();

  final _player = AudioPlayer();
  final _tts    = FlutterTts();

  String? _ringingDispatchId;
  bool    _ttsReady = false;

  // ── Initialisation TTS (appelée une fois au démarrage) ─────────────────

  Future<void> init() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Certains moteurs ont besoin d'un "warm-up" silencieux.
    await _tts.speak(' ');
    await _tts.stop();

    _ttsReady = true;
  }

  // ── Déclenchement alerte ───────────────────────────────────────────────

  /// Lance l'alarme sonore en boucle + annonce vocale détaillée.
  ///
  /// [dispatchId]     : identifiant unique de la course (évite les doublons).
  /// [clientName]     : nom complet du client.
  /// [serviceType]    : type de service (dépannage pneu, remorquage…).
  /// [address]        : adresse / lieu de la panne.
  /// [estimatedPrice] : montant estimé en FCFA (string, peut être vide).
  Future<void> newOrder({
    required String dispatchId,
    String? clientName,
    String? serviceType,
    String? address,
    String? estimatedPrice,
  }) async {
    // Idempotent : on ne re-sonne pas pour la même course.
    if (_ringingDispatchId == dispatchId) return;
    _ringingDispatchId = dispatchId;

    // ── 1. Alarme sonore en boucle ────────────────────────────────────────
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('raw/alarm.wav'));
    } catch (_) {
      // Fichier audio absent ou erreur → on continue quand même avec la voix.
    }

    // ── 2. Annonce vocale détaillée (Option C) ────────────────────────────
    await Future.delayed(const Duration(milliseconds: 800)); // laisse le son démarrer
    await _speakDetails(
      clientName    : clientName,
      serviceType   : serviceType,
      address       : address,
      estimatedPrice: estimatedPrice,
    );
  }

  // ── Arrêt ──────────────────────────────────────────────────────────────

  Future<void> stop() async {
    _ringingDispatchId = null;
    await _player.stop();
    await _tts.stop();
  }

  // ── Lecture vocale ─────────────────────────────────────────────────────

  Future<void> _speakDetails({
    String? clientName,
    String? serviceType,
    String? address,
    String? estimatedPrice,
  }) async {
    if (!_ttsReady) {
      await init(); // init de secours
    }

    final parts = <String>['Nouvelle course !'];

    if (clientName != null && clientName.trim().isNotEmpty) {
      parts.add('Client : ${clientName.trim()}.');
    }

    if (serviceType != null && serviceType.trim().isNotEmpty) {
      parts.add('Type : ${serviceType.trim()}.');
    }

    if (address != null && address.trim().isNotEmpty) {
      parts.add('Adresse : ${address.trim()}.');
    }

    if (estimatedPrice != null && estimatedPrice.trim().isNotEmpty) {
      final price = estimatedPrice.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (price.isNotEmpty) {
        parts.add('Montant estimé : $price francs.');
      }
    }

    parts.add('Veuillez accepter ou refuser la demande.');

    final fullText = parts.join(' ');

    try {
      await _tts.speak(fullText);

      // Répète l'annonce une 2e fois après 4 s pour s'assurer que le prestataire l'entend.
      await Future.delayed(const Duration(seconds: 4));
      if (_ringingDispatchId != null) {
        await _tts.speak(fullText);
      }
    } catch (_) {
      // TTS non disponible → l'alarme sonore suffit.
    }
  }
}
