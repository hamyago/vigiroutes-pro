import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

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
        final prefs = await SharedPreferences.getInstance();
        final path  = options.path;

        // Routes /auth/* → aucun token nécessaire
        if (!path.startsWith('/auth/')) {
          final token = prefs.getString('sanctum_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }

        if (kDebugMode) {
          debugPrint('[API] ${options.method} ${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          if (!path.contains('/auth/')) {
            debugPrint('[API] Token invalide — déconnexion forcée');
            onUnauthorized?.call();
          }
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

  // ══════════════════════════════════════════════════════════════════════
  //  Auth — Termii OTP (nouveau flux)
  // ══════════════════════════════════════════════════════════════════════

  /// Demande l'envoi d'un OTP au numéro donné.
  Future<void> sendOtp(String phone) async {
    await post('/auth/otp/send', data: {'phone': phone});
  }

  /// Vérifie l'OTP et connecte/crée un PRESTATAIRE.
  Future<Map<String, dynamic>> verifyOtpProvider({
    required String phone,
    required String otp,
    String? fcmToken,
    String? name,
    List<String>? serviceTypes,
    String? sector,
  }) async {
    final res = await _dio.post(
      '/auth/otp/verify/provider',
      data: {
        'phone': phone,
        'otp':   otp,
        if (fcmToken     != null) 'fcm_token':     fcmToken,
        if (name         != null) 'name':           name,
        if (serviceTypes != null) 'service_types':  serviceTypes,
        if (sector       != null) 'sector':         sector,
      },
      options: Options(
        validateStatus: (status) => status != null && status < 300,
      ),
    );
    final data = (res.data as Map).cast<String, dynamic>();

    // Nouveau prestataire : le backend renvoie is_new sans token
    if (data['is_new'] == true && data['token'] == null) {
      return {'is_new': true, 'phone': phone};
    }

    final token = data['token'] as String?;
    if (token != null) await saveToken(token);
    return data;
  }

  /// Complète le profil prestataire après OTP (quand is_new = true).
  Future<Map<String, dynamic>> completeProviderProfile({
    required String phone,
    required String name,
    required String sector,
    required List<String> serviceTypes,
    String? fcmToken,
    double? latitude,
    double? longitude,
  }) async {
    final res = await post('/auth/provider/complete-profile', data: {
      'phone':         phone,
      'name':          name,
      'sector':        sector,
      'service_types': serviceTypes,
      if (fcmToken  != null) 'fcm_token': fcmToken,
      if (latitude  != null) 'latitude':  latitude,
      if (longitude != null) 'longitude': longitude,
    });
    final data = (res.data as Map).cast<String, dynamic>();
    final token = data['token'] as String?;
    if (token != null) await saveToken(token);
    return data;
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
    final res = await get('/provider/interventions/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelIntervention(String id, {String? reason}) =>
      post('/user/interventions/$id/cancel', data: {'reason': reason});

  Future<void> declineDispatchedIntervention(String id) =>
      post('/provider/interventions/$id/decline');

  Future<List<dynamic>> getProviderInterventions({int page = 1}) async {
    final res = await get('/provider/interventions', params: {'page': page});
    return (res.data['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> acceptIntervention(String id,
      {int? assignedAssistantId}) async {
    final res = await post('/provider/interventions/$id/accept',
        data: assignedAssistantId != null
            ? {'assigned_assistant_id': assignedAssistantId}
            : null);
    return res.data as Map<String, dynamic>;
  }

  // ── Équipe / intervenants (max 3) ─────────────────────────────────────
  Future<List<ProviderAssistant>> getAssistants() async {
    final res = await get('/provider/assistants');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => ProviderAssistant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProviderAssistant> createAssistant({
    required String name,
    String? phone,
    String? photoBase64,
  }) async {
    final res = await post('/provider/assistants', data: {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (photoBase64 != null) 'photo_base64': photoBase64,
    });
    return ProviderAssistant.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<ProviderAssistant> updateAssistant(int id, {
    String? name,
    String? phone,
    String? photoBase64,
  }) async {
    final res = await patch('/provider/assistants/$id', data: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (photoBase64 != null) 'photo_base64': photoBase64,
    });
    return ProviderAssistant.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteAssistant(int id) => delete('/provider/assistants/$id');

  Future<Map<String, dynamic>> assignAssistant(
      String interventionId, int? assistantId) async {
    final res = await post('/provider/interventions/$interventionId/assign',
        data: {'assigned_assistant_id': assistantId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startIntervention(String id) async {
    final res = await post('/provider/interventions/$id/start');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeIntervention(String id, {required double finalAmount}) async {
    final res = await post('/provider/interventions/$id/complete', data: {
      'final_amount': finalAmount,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitReview({
    required String interventionId,
    required int    rating,
    String?         comment,
  }) async {
    final res = await post('/provider/interventions/$interventionId/review', data: {
      'rating':  rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getReviews() async {
    try {
      final res = await get('/provider/reviews');
      final d = res.data;
      if (d is Map && d['data'] is List) return d['data'] as List;
      return (d as List?) ?? [];
    } catch (_) { return []; }
  }

  Future<List<dynamic>> getReviewsGiven() async {
    try {
      final res = await get('/provider/reviews/given');
      final d = res.data;
      if (d is Map && d['data'] is List) return d['data'] as List;
      return (d as List?) ?? [];
    } catch (_) { return []; }
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

  Future<List<dynamic>> getProviderSubscriptionHistory() async {
    final res = await get('/provider/subscription/history');
    final data = res.data;
    if (data is Map && data['subscriptions'] is List) {
      return data['subscriptions'] as List<dynamic>;
    }
    return const [];
  }

  Future<Map<String, dynamic>> subscribeProvider(Map<String, dynamic> data) async {
    final res = await post('/provider/subscription/subscribe', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rechargeProvider({
    required double amount,
    required String paymentMethod,
  }) async {
    final res = await post('/provider/subscription/recharge', data: {
      'amount':         amount,
      'payment_method': paymentMethod,
    });
    return res.data as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Recharge DigitalPaye (Mobile Money reel)
  // ══════════════════════════════════════════════════════════════════════

  /// Initie une recharge via DigitalPaye.
  ///
  /// [operatorCode] : 'ORANGE_MONEY_CI' | 'MTN_MONEY_CI'
  /// [otp] : requis pour Orange Money (code genere par le prestataire).
  /// [payerPhone] : numero Mobile Money qui paie.
  ///
  /// Retourne { success, reference, status, payment_url, message }.
  /// En cas d'erreur metier (OTP manquant, echec DigitalPaye...), Dio leve
  /// une DioException dont response.data contient { message, code }.
  Future<Map<String, dynamic>> initiateProviderRecharge({
    required int amount,
    required String operatorCode,
    required String payerPhone,
    String? otp,
  }) async {
    final res = await post('/provider/recharge/initiate', data: {
      'amount':        amount,
      'operator_code': operatorCode,
      'payer_phone':   payerPhone,
      if (otp != null && otp.isNotEmpty) 'otp': otp,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Recupere le statut d'une recharge : 'pending' | 'success' | 'failed'.
  Future<Map<String, dynamic>> getProviderRechargeStatus(String reference) async {
    final res = await get('/provider/recharge/$reference/status');
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Retourne les magasins les plus proches sans critère de pièce.
  /// Utilisé pour pré-remplir l'écran de recherche avant toute saisie.
  Future<List<dynamic>> getNearbyStores({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
  }) async {
    final res = await get('/provider/parts/stores/nearby', params: {
      'latitude':  latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
    });
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> searchParts({
    required String query,
    required double latitude,
    required double longitude,
    double radiusKm = 3,
  }) async {
    final res = await get('/provider/parts/search', params: {
      'q': query,
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStoreDetail(String storeId) async {
    final res = await get('/provider/parts/stores/$storeId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPartOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    String? note,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryAddress,
  }) async {
    final res = await post('/provider/parts/orders', data: {
      'store_id': storeId,
      'items': items,
      if (note != null && note.isNotEmpty) 'note': note,
      if (deliveryLatitude != null) 'delivery_latitude': deliveryLatitude,
      if (deliveryLongitude != null) 'delivery_longitude': deliveryLongitude,
      if (deliveryAddress != null && deliveryAddress.isNotEmpty)
        'delivery_address': deliveryAddress,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyPartOrders({int page = 1}) async {
    try {
      final res = await get('/provider/parts/orders', params: {'page': page});
      return (res.data['data'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }
}
