import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String _baseUrl = 'https://api.vigiroutes.com/api';

  late final Dio _dio;

  VoidCallback? onUnauthorized;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Accept':       'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = (await SharedPreferences.getInstance()).getString('sanctum_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) {
          debugPrint('[API] ${options.method} ${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          debugPrint('[API] Token invalide — déconnexion forcée');
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sanctum_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sanctum_token');
  }

  Future<bool> get hasToken async =>
      ((await SharedPreferences.getInstance()).getString('sanctum_token')) != null;

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) =>
      _dio.delete(path);

  Future<Map<String, dynamic>> loginUser({
    required String firebaseToken,
    String? name,
    String? phone,
    String? fcmToken,
  }) async {
    final res = await post('/auth/user/login', data: {
      'firebase_token': firebaseToken,
      if (name     != null) 'name':      name,
      if (phone    != null) 'phone':     phone,
      if (fcmToken != null) 'fcm_token': fcmToken,
    });
    final token = res.data['token'] as String;
    await saveToken(token);
    return res.data as Map<String, dynamic>;
  }

  /// Connexion prestataire via token Firebase.
  /// Retourne {'is_new': true} si nouveau prestataire sans secteur (HTTP 202).
  Future<Map<String, dynamic>> loginProvider({
    required String firebaseToken,
    String? name,
    String? phone,
    String? fcmToken,
    List<String>? serviceTypes,
    String? sector,
  }) async {
    final res = await _dio.post(
      '/auth/provider/login',
      data: {
        'firebase_token': firebaseToken,
        if (name         != null) 'name':          name,
        if (phone        != null) 'phone':         phone,
        if (fcmToken     != null) 'fcm_token':     fcmToken,
        if (serviceTypes != null) 'service_types': serviceTypes,
        if (sector       != null) 'sector':        sector,
      },
      options: Options(
        validateStatus: (status) => status != null && status < 300,
      ),
    );
    // 202 = nouveau prestataire, profil incomplet → aller vers profile-setup
    if (res.statusCode == 202) {
      return {'is_new': true, 'requires': 'profile_setup'};
    }
    final token = res.data['token'] as String;
    await saveToken(token);
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try { await post('/auth/logout'); } catch (_) {}
    await clearToken();
  }

  Future<List<dynamic>> getNearbyProviders({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? serviceTypeId,
  }) async {
    final res = await get('/user/providers/nearby', params: {
      'latitude':  latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      if (serviceTypeId != null) 'service_type_id': serviceTypeId,
    });
    return res.data as List;
  }

  Future<Map<String, dynamic>> getEstimate({
    required String serviceTypeId,
    required String providerId,
    required double userLat,
    required double userLng,
  }) async {
    final res = await post('/user/interventions/estimate', data: {
      'service_type_id': serviceTypeId,
      'provider_id':     providerId,
      'user_latitude':   userLat,
      'user_longitude':  userLng,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createIntervention(Map<String, dynamic> data) async {
    final res = await post('/user/interventions', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getUserInterventions({int page = 1}) async {
    final res = await get('/user/interventions', params: {'page': page});
    return (res.data['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> getIntervention(String id) async {
    final res = await get('/user/interventions/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelIntervention(String id, {String? reason}) =>
      post('/user/interventions/$id/cancel', data: {'reason': reason});

  Future<List<dynamic>> getProviderInterventions({int page = 1}) async {
    final res = await get('/provider/interventions', params: {'page': page});
    return (res.data['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> acceptIntervention(String id) async {
    final res = await post('/provider/interventions/$id/accept');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startIntervention(String id) async {
    final res = await post('/provider/interventions/$id/start');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeIntervention(String id) async {
    final res = await post('/provider/interventions/$id/complete');
    return res.data as Map<String, dynamic>;
  }

  Future<void> updateProviderLocation(String interventionId, double lat, double lng) =>
      post('/provider/interventions/$interventionId/location', data: {
        'latitude': lat, 'longitude': lng,
      });

  Future<void> updateAvailability(bool available) =>
      patch('/provider/availability', data: {'is_available': available});

  Future<void> updateGlobalLocation(double lat, double lng) =>
      patch('/provider/location', data: {'latitude': lat, 'longitude': lng});

  Future<Map<String, dynamic>> createEmergencyAlert({
    required String type,
    required double latitude,
    required double longitude,
    String? address,
    String? description,
  }) async {
    final res = await post('/user/emergency', data: {
      'type':        type,
      'latitude':    latitude,
      'longitude':   longitude,
      if (address     != null) 'address':     address,
      if (description != null) 'description': description,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String,dynamic>> updateProvider(Map<String,dynamic> data) async {
    final res = await patch('/provider/me', data: data);
    return res.data as Map<String,dynamic>;
  }

  Future<List<dynamic>> getProviderSubscriptionPlans() async {
    final res = await get('/provider/subscription/plans');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>?> getProviderCurrentSubscription() async {
    try {
      final res = await get('/provider/subscription');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> subscribeProvider(Map<String, dynamic> data) async {
    final res = await post('/provider/subscription/subscribe', data: data);
    return res.data as Map<String, dynamic>;
  }
}
