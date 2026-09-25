import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  final _api = ApiService.instance;

  AuthState      _state     = AuthState.unknown;
  ProviderModel? _provider;
  bool           _isLoading = false;
  String?        _error;
  bool           _otpSent   = false;

  /// Numéro de téléphone pour lequel l'OTP a été envoyé.
  String? _otpPhone;

  AuthState      get state      => _state;
  ProviderModel? get provider   => _provider;
  bool           get isLoading  => _isLoading;
  String?        get error      => _error;
  bool           get isProvider => _provider != null;
  bool           get isUser     => false;
  String?        get role       => _provider != null ? 'provider' : null;
  bool           get otpSent    => _otpSent;

  /// Numéro qui a reçu l'OTP — nécessaire pour la complétion du profil.
  String?        get otpPhone   => _otpPhone;

  AuthController() {
    _init();
    _api.onUnauthorized = () {
      _state    = AuthState.unauthenticated;
      _provider = null;
      notifyListeners();
    };
  }

  Future<void> _init() async {
    final hasToken = await _api.hasToken;
    if (hasToken) {
      await _refreshProvider();
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  OTP via Termii (backend API)
  // ══════════════════════════════════════════════════════════════════════

  /// Envoie un OTP au numéro donné via le backend → Termii.
  Future<void> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _error     = null;
    _otpSent   = false;
    _otpPhone  = phoneNumber;
    notifyListeners();

    try {
      await _api.sendOtp(phoneNumber);
      _otpSent   = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[ProviderAuth] sendOtp error: $e');
      _error     = _extractError(e, 'Erreur lors de l\'envoi du code.');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp(String phone) => sendOtp(phone);

  /// Vérifie l'OTP saisi et connecte/crée le prestataire.
  ///
  /// [phone] peut être passé explicitement par l'écran OTP pour éviter la
  /// perte de [_otpPhone] après un logout/reset d'état.
  Future<bool> verifyOtp(String otp, {String? phone}) async {
    // Priorité au paramètre explicite, puis à la valeur mémorisée.
    final targetPhone = phone ?? _otpPhone;
    if (targetPhone == null || targetPhone.isEmpty) {
      _error = 'Session expirée. Veuillez renvoyer le code.';
      notifyListeners();
      return false;
    }
    // Resynchronise _otpPhone si besoin (ex : retour après logout partiel).
    _otpPhone = targetPhone;
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      // Récupérer le token FCM (non-bloquant)
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[ProviderAuth] getToken non-fatal: $e');
      }

      final response = await _api.verifyOtpProvider(
        phone:    targetPhone,
        otp:      otp,
        fcmToken: fcmToken,
      );

      // 200 + is_new = true → profil à compléter (pas encore de provider)
      if (response['is_new'] == true) {
        debugPrint('[ProviderAuth] Nouveau prestataire → profile-setup');
        _state     = AuthState.unauthenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Prestataire existant → connecté
      final providerJson = response['provider'];
      if (providerJson is! Map) {
        debugPrint('[ProviderAuth] provider absent de la réponse: $response');
        _state     = AuthState.unauthenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _provider = ProviderModel.fromJson(
        Map<String, dynamic>.from(providerJson),
      );
      _state     = AuthState.authenticated;
      _isLoading = false;

      // Temps réel
      final token = response['token'];
      if (token is String && token.isNotEmpty) {
        try {
          await RealtimeService.instance.init(token);
        } catch (e) {
          debugPrint('[ProviderAuth] RealtimeService.init non-fatal: $e');
        }
      }

      notifyListeners();
      return true;

    } catch (e) {
      debugPrint('[ProviderAuth] verifyOtp error: $e');
      _error     = _extractError(e, 'Code incorrect ou expiré.');
      _isLoading = false;
      _state     = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Profil & session
  // ══════════════════════════════════════════════════════════════════════

  Future<void> completeProviderProfile({
    required String name,
    required String phone,
    required String sector,
    required List<String> serviceTypes,
    required double latitude,
    required double longitude,
  }) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      // Récupérer le token FCM (non-bloquant)
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[ProviderAuth] getToken non-fatal: $e');
      }

      final response = await _api.completeProviderProfile(
        phone:        phone,
        name:         name,
        sector:       sector,
        serviceTypes: serviceTypes,
        fcmToken:     fcmToken,
        latitude:     latitude,
        longitude:    longitude,
      );

      final providerJson = response['provider'];
      if (providerJson is Map) {
        _provider = ProviderModel.fromJson(
          Map<String, dynamic>.from(providerJson),
        );
        _state = AuthState.authenticated;

        final token = response['token'];
        if (token is String && token.isNotEmpty) {
          try {
            await RealtimeService.instance.init(token);
          } catch (e) {
            debugPrint('[ProviderAuth] RealtimeService.init non-fatal: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[ProviderAuth] completeProviderProfile: $e');
      _error = _extractError(
        e,
        'Impossible d\'enregistrer votre profil. Vérifiez votre connexion et réessayez.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeUserProfile(
      {required String name, required String phone}) async {}

  Future<void> refreshProvider() async {
    await _refreshProvider();
  }

  Future<void> signOut() => logout();

  Future<void> logout() async {
    await _api.logout();
    await RealtimeService.instance.disconnect();
    _provider = null;
    _state    = AuthState.unauthenticated;
    _otpSent  = false;
    _otpPhone = null;
    notifyListeners();
  }

  // ── Privé ─────────────────────────────────────────────────────────────

  Future<void> _refreshProvider() async {
    try {
      final res = await _api.get('/provider/me');
      final data = res.data;
      if (data is Map) {
        _provider = ProviderModel.fromJson(Map<String, dynamic>.from(data));
        _state    = AuthState.authenticated;
      } else {
        // Réponse inattendue mais pas une erreur réseau → on garde l'état actuel
        if (_state == AuthState.unknown) _state = AuthState.unauthenticated;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ProviderAuth] _refreshProvider error: $e');
      // Erreur réseau / timeout : NE PAS déconnecter si on était déjà authentifié.
      // Seul un 401 déclenche la déconnexion (géré par onUnauthorized dans le constructeur).
      final msg = e.toString();
      final is401 = msg.contains('401') || msg.contains('Unauthorized');
      if (is401 || _state == AuthState.unknown) {
        _state = AuthState.unauthenticated;
      }
      // Si on était authenticated et que c'est une erreur réseau, on garde l'état.
      notifyListeners();
    }
  }

  /// Extrait un message d'erreur lisible depuis une DioException ou autre.
  ///
  /// Dio 5.x : l'exception est directement de type [DioException], plus besoin
  /// du check sur toString(). On lit response.data['message'] en priorité, puis
  /// response.data['error'], puis le fallback.
  String _extractError(dynamic e, String fallback) {
    try {
      // Dio 5.x — DioException est exporté directement par le package.
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          final msg = data['message'] ?? data['error'];
          if (msg != null && msg.toString().trim().isNotEmpty) {
            return msg.toString();
          }
        }
      }
    } catch (_) {}
    return fallback;
  }
}
