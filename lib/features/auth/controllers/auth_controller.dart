import 'dart:async';
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
  Future<bool> verifyOtp(String otp) async {
    if (_otpPhone == null) {
      _error = 'Session expirée. Veuillez renvoyer le code.';
      notifyListeners();
      return false;
    }
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
        phone:    _otpPhone!,
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
      _error = 'Impossible d\'enregistrer votre profil. Vérifiez votre connexion et réessayez.';
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
        _state = AuthState.unauthenticated;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ProviderAuth] _refreshProvider error: $e');
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  /// Extrait un message d'erreur lisible depuis une exception Dio ou autre.
  String _extractError(dynamic e, String fallback) {
    try {
      if (e is Exception && e.toString().contains('DioException')) {
        final dynamic resp = (e as dynamic).response;
        if (resp != null) {
          final data = resp.data;
          if (data is Map && data['message'] != null) {
            return data['message'] as String;
          }
        }
      }
    } catch (_) {}
    return fallback;
  }
}
