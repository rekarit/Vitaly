enum ReservationStatus { active, converted, expired, cancelled }

class Reservation {
  final String id;
  final String customerId;
  final List<String> slabIds;
  final DateTime reservedAt;
  final DateTime expiresAt;
  final ReservationStatus status;
  final String? notes;
  final double depositAmount;

  const Reservation({
    required this.id,
    required this.customerId,
    required this.slabIds,
    required this.reservedAt,
    required this.expiresAt,
    required this.status,
    this.notes,
    required this.depositAmount,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Reservation copyWith({ReservationStatus? status, List<String>? slabIds, String? notes}) =>
      Reservation(
        id:            id,
        customerId:    customerId,
        slabIds:       slabIds    ?? this.slabIds,
        reservedAt:    reservedAt,
        expiresAt:     expiresAt,
        status:        status     ?? this.status,
        notes:         notes      ?? this.notes,
        depositAmount: depositAmount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'slabIds': slabIds,
        'reservedAt': reservedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'status': status.name,
        'notes': notes,
        'depositAmount': depositAmount,
      };

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status']?.toString() ?? 'active').toLowerCase();
    ReservationStatus status = ReservationStatus.active;
    if (statusStr.contains('convert')) {
      status = ReservationStatus.converted;
    } else if (statusStr.contains('expir')) {
      status = ReservationStatus.expired;
    } else if (statusStr.contains('cancel')) {
      status = ReservationStatus.cancelled;
    }

    final List<String> slabIds = [];
    if (json['slabIds'] is List) {
      slabIds.addAll((json['slabIds'] as List).map((e) => e.toString()));
    }

    return Reservation(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      slabIds: slabIds,
      reservedAt: json['reservedAt'] != null
          ? DateTime.tryParse(json['reservedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString()) ?? DateTime.now().add(const Duration(days: 7))
          : DateTime.now().add(const Duration(days: 7)),
      status: status,
      notes: json['notes']?.toString(),
      depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() => 'Reservation($id)';
}
