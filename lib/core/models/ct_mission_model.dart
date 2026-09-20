// ignore_for_file: always_specify_types

class CtMissionReportModel {
  final String result;
  final String pvNumber;
  final String? observations;
  final String? nextVisitDate;
  final DateTime? submittedAt;

  const CtMissionReportModel({
    required this.result,
    required this.pvNumber,
    this.observations,
    this.nextVisitDate,
    this.submittedAt,
  });

  factory CtMissionReportModel.fromJson(Map<String, dynamic> json) {
    return CtMissionReportModel(
      result: json['result'] as String,
      pvNumber: json['pv_number'] as String,
      observations: json['observations'] as String?,
      nextVisitDate: json['next_visit_date'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
    );
  }

  CtMissionReportModel copyWith({
    String? result,
    String? pvNumber,
    String? observations,
    String? nextVisitDate,
    DateTime? submittedAt,
  }) {
    return CtMissionReportModel(
      result: result ?? this.result,
      pvNumber: pvNumber ?? this.pvNumber,
      observations: observations ?? this.observations,
      nextVisitDate: nextVisitDate ?? this.nextVisitDate,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}

class CtMissionModel {
  final String id;
  final String reference;
  final String status;
  final String providerStatus;
  final String vehicleId;
  final String registrationNumber;
  final String vehicleBrand;
  final String vehicleModel;
  final String? vehicleColor;
  final String vehicleCategory;
  final String clientName;
  final String? clientPhone;
  final String centerName;
  final String centerAddress;
  final double? centerLatitude;
  final double? centerLongitude;
  final DateTime? slotStartsAt;
  final String transportMode;
  final double? totalAmount;
  final String? paymentStatus;
  final String? qrCodeUrl;
  final DateTime? createdAt;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final CtMissionReportModel? report;

  const CtMissionModel({
    required this.id,
    required this.reference,
    required this.status,
    required this.providerStatus,
    required this.vehicleId,
    required this.registrationNumber,
    required this.vehicleBrand,
    required this.vehicleModel,
    this.vehicleColor,
    required this.vehicleCategory,
    required this.clientName,
    this.clientPhone,
    required this.centerName,
    required this.centerAddress,
    this.centerLatitude,
    this.centerLongitude,
    this.slotStartsAt,
    required this.transportMode,
    this.totalAmount,
    this.paymentStatus,
    this.qrCodeUrl,
    this.createdAt,
    this.enRouteAt,
    this.arrivedAt,
    this.completedAt,
    this.report,
  });

  factory CtMissionModel.fromJson(Map<String, dynamic> json) {
    return CtMissionModel(
      id: json['id'] as String,
      reference: json['reference'] as String,
      status: json['status'] as String,
      providerStatus: json['provider_status'] as String? ?? json['status'] as String,
      vehicleId: json['vehicle_id'] as String,
      registrationNumber: json['registration_number'] as String,
      vehicleBrand: json['vehicle_brand'] as String,
      vehicleModel: json['vehicle_model'] as String,
      vehicleColor: json['vehicle_color'] as String?,
      vehicleCategory: json['vehicle_category'] as String,
      clientName: json['client_name'] as String,
      clientPhone: json['client_phone'] as String?,
      centerName: json['center_name'] as String,
      centerAddress: json['center_address'] as String,
      centerLatitude: (json['center_lat'] as num?)?.toDouble(),
      centerLongitude: (json['center_lng'] as num?)?.toDouble(),
      slotStartsAt: json['slot_starts_at'] != null
          ? DateTime.tryParse(json['slot_starts_at'] as String)
          : null,
      transportMode: json['transport_mode'] as String,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      paymentStatus: json['payment_status'] as String?,
      qrCodeUrl: json['qr_code_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      enRouteAt: json['en_route_at'] != null
          ? DateTime.tryParse(json['en_route_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.tryParse(json['arrived_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      report: json['report'] != null
          ? CtMissionReportModel.fromJson(json['report'] as Map<String, dynamic>)
          : null,
    );
  }

  // ── Status helpers (use providerStatus) ───────────────────────────────────
  bool get isPending => providerStatus == 'pending';
  bool get isAccepted => providerStatus == 'accepted';
  bool get isEnRoute => providerStatus == 'en_route';
  bool get isInProgress => providerStatus == 'in_progress';
  bool get isArrived => providerStatus == 'arrived' || providerStatus == 'in_progress';
  bool get isCompleted => providerStatus == 'completed';
  bool get isCancelled => providerStatus == 'cancelled';
  bool get isReported => report != null;

  // ── Computed helpers ───────────────────────────────────────────────────────
  double? get centerLat => centerLatitude;
  double? get centerLng => centerLongitude;

  String get slotTime {
    if (slotStartsAt == null) return '';
    final h = slotStartsAt!.hour.toString().padLeft(2, '0');
    final m = slotStartsAt!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get statusLabel {
    switch (providerStatus) {
      case 'pending': return 'En attente';
      case 'accepted': return 'Acceptée';
      case 'en_route': return 'En route';
      case 'in_progress': return 'En cours';
      case 'arrived': return 'Arrivé';
      case 'completed': return 'Terminée';
      case 'cancelled': return 'Annulée';
      default: return providerStatus;
    }
  }

  CtMissionModel copyWith({
    String? id,
    String? reference,
    String? status,
    String? providerStatus,
    String? vehicleId,
    String? registrationNumber,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleCategory,
    String? clientName,
    String? clientPhone,
    String? centerName,
    String? centerAddress,
    double? centerLatitude,
    double? centerLongitude,
    DateTime? slotStartsAt,
    String? transportMode,
    double? totalAmount,
    String? paymentStatus,
    String? qrCodeUrl,
    DateTime? createdAt,
    DateTime? enRouteAt,
    DateTime? arrivedAt,
    DateTime? completedAt,
    CtMissionReportModel? report,
  }) {
    return CtMissionModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      providerStatus: providerStatus ?? this.providerStatus,
      vehicleId: vehicleId ?? this.vehicleId,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      centerName: centerName ?? this.centerName,
      centerAddress: centerAddress ?? this.centerAddress,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      slotStartsAt: slotStartsAt ?? this.slotStartsAt,
      transportMode: transportMode ?? this.transportMode,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      createdAt: createdAt ?? this.createdAt,
      enRouteAt: enRouteAt ?? this.enRouteAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completedAt: completedAt ?? this.completedAt,
      report: report ?? this.report,
    );
  }
}
