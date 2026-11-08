class Customer {
  final String id;
  final String fullName;
  final String company;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String notes;
  final double balanceDue;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.fullName,
    this.company = '',
    required this.phone,
    this.email = '',
    this.address = '',
    this.city = '',
    this.notes = '',
    this.balanceDue = 0.0,
    required this.createdAt,
  });

  Customer copyWith({
    String? id,
    String? fullName,
    String? company,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? notes,
    double? balanceDue,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      notes: notes ?? this.notes,
      balanceDue: balanceDue ?? this.balanceDue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'company': company,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'notes': notes,
      'balanceDue': balanceDue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['customer_name']?.toString() ?? '',
      company: json['company']?.toString() ?? json['customer_code']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? json['address']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      balanceDue: (json['balanceDue'] as num?)?.toDouble() ??
          (json['balance_due'] as num?)?.toDouble() ??
          0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  @override
  String toString() => 'Customer($fullName)';
}
