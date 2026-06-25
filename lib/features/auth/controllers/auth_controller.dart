import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  final _firebaseAuth = FirebaseAuth.instance;
  final _api          = ApiService.instance;

  AuthState      _state          = AuthState.unknown;
  ProviderModel? _provider;
  bool           _isLoading      = false;
  String?        _error;
  String?        _verificationId;

  // ── Getters ──────────────────────────────────────────────────────────────────
  AuthState      get state      => _state;
  ProviderModel? get provider   => _provider;
  bool           get isLoading  => _isLoading;
  String?        get error      => _error;
  bool           get isProvider => _provider != null;
  bool           get isUser     => false;
  String?        get role       => _provider != null ? 'provider' : null;
  bool           get otpSent    => _verificationId != null;

  AuthController() {
    _init();
    _api.onUnauthorized = () {
      _state    = AuthState.unauthenticated;
      _provider = null;
      notifyListeners();
    };
  }

  Future<void> _init() async {
    final hasToken     = await _api.hasToken;
    final firebaseUser = _firebaseAuth.currentUser;
    if (hasToken && firebaseUser != null) {
      await _refreshProvider(firebaseUser);
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  // ── OTP ──────────────────────────────────────────────────────────────────────
  Future<void> sendOtp(String phoneNumber) async {
    _isLoading      = true;
    _error          = null;
    _verificationId = null;           // reset pour éviter les résidus
    notifyListeners();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          debugPrint('[ProviderAuth] verificationCompleted — auto sign-in');
          await _signIn(credential);
        },
        verificationFailed: (e) {
          debugPrint('[ProviderAuth] verificationFailed: ${e.code} — ${e.message}');
          _error     = _friendlyFirebaseError(e.code, e.message);
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (id, resendToken) {
          debugPrint('[ProviderAuth] codeSent — verificationId recu');
          _verificationId = id;
          _isLoading      = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (id) {
          debugPrint('[ProviderAuth] codeAutoRetrievalTimeout');
          _verificationId ??= id;
        },
      );
    } catch (e) {
      debugPrint('[ProviderAuth] sendOtp exception: $e');
      _error     = 'Erreur inattendue lors de l\'envoi du code.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp(String phone) => sendOtp(phone);

  Future<bool> verifyOtp(String otp) async {
    if (_verificationId == null) {
      _error = 'Session expirée. Veuillez renvoyer le code.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error     = null;
    notifyListeners();
    return _signIn(PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    ));
  }

  // ── Authentification interne ─────────────────────────────────────────────────
  Future<bool> _signIn(AuthCredential credential) async {
    try {
      final uc = await _firebaseAuth.signInWithCredential(credential);
      await _refreshProvider(uc.user!);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[ProviderAuth] signIn error: ${e.code}');
      _error     = _friendlyFirebaseError(e.code, e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _refreshProvider(User firebaseUser, {
    String? name,
    String? phone,
    List<String>? serviceTypes,
    String? sector,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final idToken  = await firebaseUser.getIdToken(true);
      final fcmToken = await FirebaseMessaging.instance.getToken();

      final response = await _api.loginProvider(
        firebaseToken: idToken!,
        name:          name,
        phone:         phone ?? firebaseUser.phoneNumber,
        fcmToken:      fcmToken,
        serviceTypes:  serviceTypes,
        sector:        sector,
      );

      _provider  = ProviderModel.fromJson(response['provider'] as Map<String, dynamic>);
      _state     = AuthState.authenticated;
      _isLoading = false;

      await RealtimeService.instance.init(response['token'] as String);
      notifyListeners();
    } catch (e) {
      debugPrint('[ProviderAuth] _refreshProvider error: $e');
      _error     = 'Impossible de se connecter au serveur. Vérifiez votre connexion.';
      _isLoading = false;
      _state     = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  // ── Profil ───────────────────────────────────────────────────────────────────
  Future<void> completeProviderProfile({
    required String name,
    required String phone,
    required String sector,
    required List<String> serviceTypes,
    required double latitude,
    required double longitude,
  }) async {
    _isLoading = true;
    notifyListeners();
    final u = _firebaseAuth.currentUser;
    if (u != null) {
      await _refreshProvider(u,
          name: name, phone: phone,
          serviceTypes: serviceTypes,
          sector: sector,
          latitude: latitude, longitude: longitude);
    }
  }

  Future<void> completeUserProfile(
      {required String name, required String phone}) async {}

  Future<void> refreshProvider() async {
    final u = _firebaseAuth.currentUser;
    if (u != null) await _refreshProvider(u);
  }

  Future<void> signOut() => logout();

  Future<void> logout() async {
    await _api.logout();
    await _firebaseAuth.signOut();
    await RealtimeService.instance.disconnect();
    _provider = null;
    _state    = AuthState.unauthenticated;
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _friendlyFirebaseError(String code, String? defaultMsg) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide. Vérifiez le format (+225...).';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'invalid-verification-code':
        return 'Code incorrect. Vérifiez le SMS et réessayez.';
      case 'session-expired':
        return 'Session expirée. Veuillez renvoyer le code.';
      case 'network-request-failed':
        return 'Pas de connexion réseau. Vérifiez votre connexion.';
      case 'billing-not-enabled':
        return 'Service SMS non activé. Contactez le support.';
      case 'operation-not-allowed':
        return 'Authentification par SMS non activée dans Firebase Console.';
      default:
        return defaultMsg ?? 'Une erreur est survenue. Réessayez.';
    }
  }
}

