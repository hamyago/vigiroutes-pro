// ── UserModel ─────────────────────────────────────────────────────────────────

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String? fcmToken;
  final bool isActive;
  final String subscriptionPlan;
  final DateTime? subscriptionExpiresAt;
  final int totalInterventions;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    this.fcmToken,
    required this.isActive,
    required this.subscriptionPlan,
    this.subscriptionExpiresAt,
    required this.totalInterventions,
  });

  bool get hasSubscription =>
      subscriptionPlan != 'none' &&
      (subscriptionExpiresAt == null || subscriptionExpiresAt!.isAfter(DateTime.now()));

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:                    json['id'] as String,
        name:                  json['name'] as String,
        phone:                 json['phone'] as String,
        email:                 json['email'] as String?,
        photoUrl:              json['photo_url'] as String?,
        fcmToken:              json['fcm_token'] as String?,
        isActive:              json['is_active'] as bool? ?? true,
        subscriptionPlan:      json['subscription_plan'] as String? ?? 'none',
        subscriptionExpiresAt: json['subscription_expires_at'] != null
            ? DateTime.parse(json['subscription_expires_at'] as String)
            : null,
        totalInterventions: json['total_interventions'] as int? ?? 0,
      );
}

// ── ProviderModel ─────────────────────────────────────────────────────────────

class ProviderModel {
  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  final String? fcmToken;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final bool isActive;
  final bool isVerified;
  final List<String> serviceTypes;
  final double rating;
  final int ratingCount;
  final double totalEarnings;
  final int totalInterventions;
  double? distanceKm;

  ProviderModel({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.fcmToken,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
    required this.isActive,
    required this.isVerified,
    required this.serviceTypes,
    required this.rating,
    required this.ratingCount,
    required this.totalEarnings,
    required this.totalInterventions,
    this.distanceKm,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) => ProviderModel(
        id:                 json['id'] as String,
        name:               json['name'] as String,
        phone:              json['phone'] as String? ?? '',
        photoUrl:           json['photo_url'] as String?,
        fcmToken:           json['fcm_token'] as String?,
        latitude:           (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude:          (json['longitude'] as num?)?.toDouble() ?? 0,
        isAvailable:        json['is_available'] as bool? ?? true,
        isActive:           json['is_active'] as bool? ?? true,
        isVerified:         json['is_verified'] as bool? ?? false,
        serviceTypes:       (json['service_types'] as List?)
                                ?.map((e) => e as String).toList() ?? [],
        rating:             (json['rating'] as num?)?.toDouble() ?? 0,
        ratingCount:        json['rating_count'] as int? ?? 0,
        totalEarnings:      (json['total_earnings'] as num?)?.toDouble() ?? 0,
        totalInterventions: json['total_interventions'] as int? ?? 0,
        distanceKm:         (json['distance_km'] as num?)?.toDouble(),
      );
}

// ── InterventionModel ─────────────────────────────────────────────────────────

class InterventionModel {
  final String id;
  final String userId;
  final String? providerId;
  final String serviceTypeId;
  final String serviceTypeName;
  final String status;
  final double userLatitude;
  final double userLongitude;
  final String? userAddress;
  final double? providerLatitude;
  final double? providerLongitude;
  final double basePrice;
  final double distanceKm;
  final double kmCost;
  final double subtotal;
  final double commission;
  final double totalPrice;
  final bool subscriptionDiscountApplied;
  final String paymentMethod;
  final String paymentStatus;
  final String? dispatchedProviderId;
  final DateTime? dispatchExpiresAt;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final ProviderModel? provider;

  const InterventionModel({
    required this.id,
    required this.userId,
    this.providerId,
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.status,
    required this.userLatitude,
    required this.userLongitude,
    this.userAddress,
    this.providerLatitude,
    this.providerLongitude,
    required this.basePrice,
    required this.distanceKm,
    required this.kmCost,
    required this.subtotal,
    required this.commission,
    required this.totalPrice,
    required this.subscriptionDiscountApplied,
    required this.paymentMethod,
    required this.paymentStatus,
    this.dispatchedProviderId,
    this.dispatchExpiresAt,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.provider,
  });

  bool get isPending    => status == 'pending' || status == 'dispatching';
  bool get isAccepted   => status == 'accepted';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted  => status == 'completed';
  bool get isCancelled  => status == 'cancelled';
  bool get isActive     => isPending || isAccepted || isInProgress;

  factory InterventionModel.fromJson(Map<String, dynamic> json) => InterventionModel(
        id:                          json['id'] as String,
        userId:                      json['user_id'] as String,
        providerId:                  json['provider_id'] as String?,
        serviceTypeId:               json['service_type_id'] as String,
        serviceTypeName:             json['service_type_name'] as String,
        status:                      json['status'] as String,
        userLatitude:                (json['user_latitude'] as num).toDouble(),
        userLongitude:               (json['user_longitude'] as num).toDouble(),
        userAddress:                 json['user_address'] as String?,
        providerLatitude:            (json['provider_latitude'] as num?)?.toDouble(),
        providerLongitude:           (json['provider_longitude'] as num?)?.toDouble(),
        basePrice:                   (json['base_price'] as num).toDouble(),
        distanceKm:                  (json['distance_km'] as num).toDouble(),
        kmCost:                      (json['km_cost'] as num).toDouble(),
        subtotal:                    (json['subtotal'] as num).toDouble(),
        commission:                  (json['commission'] as num).toDouble(),
        totalPrice:                  (json['total_price'] as num).toDouble(),
        subscriptionDiscountApplied: json['subscription_discount_applied'] as bool? ?? false,
        paymentMethod:               json['payment_method'] as String,
        paymentStatus:               json['payment_status'] as String? ?? 'pending',
        dispatchedProviderId:        json['dispatched_provider_id'] as String?,
        dispatchExpiresAt:           json['dispatch_expires_at'] != null
            ? DateTime.parse(json['dispatch_expires_at'] as String)
            : null,
        createdAt:    DateTime.parse(json['created_at'] as String),
        acceptedAt:   json['accepted_at'] != null  ? DateTime.parse(json['accepted_at'] as String)  : null,
        startedAt:    json['started_at'] != null   ? DateTime.parse(json['started_at'] as String)   : null,
        completedAt:  json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
        provider:     json['provider'] != null
            ? ProviderModel.fromJson(json['provider'] as Map<String, dynamic>)
            : null,
      );

  /// Mise à jour partielle depuis un événement WebSocket
  InterventionModel copyWithWs(Map<String, dynamic> data) => InterventionModel(
        id:                          id,
        userId:                      userId,
        providerId:                  data['provider_id'] as String? ?? providerId,
        serviceTypeId:               serviceTypeId,
        serviceTypeName:             serviceTypeName,
        status:                      data['status'] as String? ?? status,
        userLatitude:                userLatitude,
        userLongitude:               userLongitude,
        userAddress:                 userAddress,
        providerLatitude:            (data['provider_latitude'] as num?)?.toDouble() ?? providerLatitude,
        providerLongitude:           (data['provider_longitude'] as num?)?.toDouble() ?? providerLongitude,
        basePrice:                   basePrice,
        distanceKm:                  distanceKm,
        kmCost:                      kmCost,
        subtotal:                    subtotal,
        commission:                  commission,
        totalPrice:                  totalPrice,
        subscriptionDiscountApplied: subscriptionDiscountApplied,
        paymentMethod:               paymentMethod,
        paymentStatus:               paymentStatus,
        dispatchedProviderId:        data['dispatched_provider_id'] as String? ?? dispatchedProviderId,
        dispatchExpiresAt:           data['dispatch_expires_at'] != null
            ? DateTime.parse(data['dispatch_expires_at'] as String)
            : dispatchExpiresAt,
        createdAt:   createdAt,
        acceptedAt:  acceptedAt,
        startedAt:   startedAt,
        completedAt: completedAt,
        provider:    provider,
      );
}
