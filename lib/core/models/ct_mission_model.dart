class CtMissionModel {
  final String id;
  final String reference;
  final String clientName;
  final String clientPhone;
  final String registrationNumber;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehicleColor;
  final String slotTime;
  final String status;
  final String centerName;
  final String centerAddress;
  final double centerLat;
  final double centerLng;
  final double? estimatedFee;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  const CtMissionModel({
    required this.id,
    required this.reference,
    required this.clientName,
    required this.clientPhone,
    required this.registrationNumber,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.slotTime,
    required this.status,
    required this.centerName,
    required this.centerAddress,
    required this.centerLat,
    required this.centerLng,
    this.estimatedFee,
    this.arrivedAt,
    this.completedAt,
  });

  factory CtMissionModel.fromJson(Map<String, dynamic> json) {
    return CtMissionModel(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      clientPhone: json['client_phone']?.toString() ?? '',
      registrationNumber: json['registration_number']?.toString() ?? '',
      vehicleBrand: json['vehicle_brand']?.toString() ?? '',
      vehicleModel: json['vehicle_model']?.toString() ?? '',
      vehicleColor: json['vehicle_color']?.toString() ?? '',
      slotTime: json['slot_time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'assigned',
      centerName: json['center_name']?.toString() ?? '',
      centerAddress: json['center_address']?.toString() ?? '',
      centerLat: (json['center_lat'] as num?)?.toDouble() ?? 0.0,
      centerLng: (json['center_lng'] as num?)?.toDouble() ?? 0.0,
      estimatedFee: (json['estimated_fee'] as num?)?.toDouble(),
      arrivedAt: json['arrived_at'] != null
          ? DateTime.tryParse(json['arrived_at'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }

  bool get isPending => status == 'assigned' || status == 'pending';
  bool get isEnRoute => status == 'en_route';
  bool get isArrived => status == 'arrived';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get statusLabel {
    switch (status) {
      case 'assigned':
        return 'Assignée';
      case 'en_route':
        return 'En route';
      case 'arrived':
        return 'Arrivé';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  CtMissionModel copyWith({String? status, DateTime? arrivedAt, DateTime? completedAt}) {
    return CtMissionModel(
      id: id,
      reference: reference,
      clientName: clientName,
      clientPhone: clientPhone,
      registrationNumber: registrationNumber,
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      slotTime: slotTime,
      status: status ?? this.status,
      centerName: centerName,
      centerAddress: centerAddress,
      centerLat: centerLat,
      centerLng: centerLng,
      estimatedFee: estimatedFee,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
