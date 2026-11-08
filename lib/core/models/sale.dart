enum PaymentMethod { cash, bankTransfer, creditCard, check }
enum SaleStatus { draft, confirmed, invoiced, paid, delivered }

class SaleLineItem {
  final String slabId;
  final double agreedPricePerSqm;
  final double areaSqm;

  const SaleLineItem({
    required this.slabId,
    required this.agreedPricePerSqm,
    required this.areaSqm,
  });

  double get lineTotal => agreedPricePerSqm * areaSqm;

  Map<String, dynamic> toJson() => {
    'slabId': slabId,
    'agreedPricePerSqm': agreedPricePerSqm,
    'areaSqm': areaSqm,
  };

  factory SaleLineItem.fromJson(Map<String, dynamic> json) {
    return SaleLineItem(
      slabId: json['slabId'] as String? ?? '',
      agreedPricePerSqm: (json['agreedPricePerSqm'] as num?)?.toDouble() ?? 0.0,
      areaSqm: (json['areaSqm'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Sale {
  final String id;
  final String customerId;
  final List<SaleLineItem> lineItems;
  final DateTime saleDate;
  final SaleStatus status;
  final PaymentMethod paymentMethod;
  final double discountPercent;
  final double amountPaid;       // â† Phase 3: cash received
  final bool   pickedUp;         // â† Phase 3: fulfillment toggle
  final DateTime? pickupDate;    // â† Phase 3: pickup date
  final String? invoiceNumber;
  final String? notes;
  final String? fromReservationId; // â† Phase 3: traceability

  const Sale({
    required this.id,
    required this.customerId,
    required this.lineItems,
    required this.saleDate,
    required this.status,
    required this.paymentMethod,
    required this.discountPercent,
    this.amountPaid     = 0,
    this.pickedUp       = false,
    this.pickupDate,
    this.invoiceNumber,
    this.notes,
    this.fromReservationId,
  });

  double get subtotal    => lineItems.fold(0, (sum, item) => sum + item.lineTotal);
  double get discount    => subtotal * (discountPercent / 100);
  double get total       => subtotal - discount;
  double get balanceDue  => total - amountPaid;
  double get totalSqm    => lineItems.fold(0.0, (s, i) => s + i.areaSqm);

  @override
  String toString() => 'Sale($id - \$${total.toStringAsFixed(2)})';

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'lineItems': lineItems.map((li) => li.toJson()).toList(),
    'saleDate': saleDate.toIso8601String(),
    'status': status.name,
    'paymentMethod': paymentMethod.name,
    'discountPercent': discountPercent,
    'amountPaid': amountPaid,
    'pickedUp': pickedUp,
    'pickupDate': pickupDate?.toIso8601String(),
    'invoiceNumber': invoiceNumber,
    'notes': notes,
    'fromReservationId': fromReservationId,
  };

  factory Sale.fromJson(Map<String, dynamic> json) {
    SaleStatus parseStatus(String? name) {
      return SaleStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => SaleStatus.draft,
      );
    }

    PaymentMethod parsePaymentMethod(String? name) {
      return PaymentMethod.values.firstWhere(
        (e) => e.name == name,
        orElse: () => PaymentMethod.cash,
      );
    }

    return Sale(
      id: json['id'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      lineItems: (json['lineItems'] as List<dynamic>?)
              ?.map((li) => SaleLineItem.fromJson(li as Map<String, dynamic>))
              .toList() ??
          [],
      saleDate: json['saleDate'] != null
          ? DateTime.tryParse(json['saleDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: parseStatus(json['status'] as String?),
      paymentMethod: parsePaymentMethod(json['paymentMethod'] as String?),
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
      pickedUp: json['pickedUp'] as bool? ?? false,
      pickupDate: json['pickupDate'] != null
          ? DateTime.tryParse(json['pickupDate'] as String)
          : null,
      invoiceNumber: json['invoiceNumber'] as String?,
      notes: json['notes'] as String?,
      fromReservationId: json['fromReservationId'] as String?,
    );
  }
}

