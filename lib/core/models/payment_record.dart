class PaymentRecord {
  final String id;
  final DateTime paymentDate;
  final String customerId;
  final String? relatedSaleId;
  final String? relatedReservationId;
  final double amountPaid;
  final String paymentType;
  final String? notes;

  const PaymentRecord({
    required this.id,
    required this.paymentDate,
    required this.customerId,
    this.relatedSaleId,
    this.relatedReservationId,
    required this.amountPaid,
    required this.paymentType,
    this.notes,
  });

  @override
  String toString() => 'PaymentRecord($id - \$$amountPaid)';
}
