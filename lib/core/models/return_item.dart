enum ReturnStatus { pending, approved, completed, rejected }
enum ReturnCondition { good, flawless, minorScratch, cracked, damaged }
enum ReturnReason { defective, customerChangedMind, orderCancelled, wrongItem, veinMismatch, transitDamage }

class ReturnItem {
  final String id;
  final DateTime returnDate;
  final String? originalSaleId;
  final String customerId;
  final String? materialCode;
  final String? inventoryId;
  final double quantityReturnedSqm;
  final String returnReason;
  final String condition;
  final bool restockToInventory;
  final ReturnStatus status;
  final String? notes;

  const ReturnItem({
    required this.id,
    required this.returnDate,
    this.originalSaleId,
    required this.customerId,
    this.materialCode,
    this.inventoryId,
    required this.quantityReturnedSqm,
    required this.returnReason,
    required this.condition,
    this.restockToInventory = true,
    this.status = ReturnStatus.completed,
    this.notes,
  });

  ReturnItem copyWith({
    String? id,
    DateTime? returnDate,
    String? originalSaleId,
    String? customerId,
    String? materialCode,
    String? inventoryId,
    double? quantityReturnedSqm,
    String? returnReason,
    String? condition,
    bool? restockToInventory,
    ReturnStatus? status,
    String? notes,
  }) {
    return ReturnItem(
      id: id ?? this.id,
      returnDate: returnDate ?? this.returnDate,
      originalSaleId: originalSaleId ?? this.originalSaleId,
      customerId: customerId ?? this.customerId,
      materialCode: materialCode ?? this.materialCode,
      inventoryId: inventoryId ?? this.inventoryId,
      quantityReturnedSqm: quantityReturnedSqm ?? this.quantityReturnedSqm,
      returnReason: returnReason ?? this.returnReason,
      condition: condition ?? this.condition,
      restockToInventory: restockToInventory ?? this.restockToInventory,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => 'ReturnItem($id - ${quantityReturnedSqm.toStringAsFixed(2)} sqm)';
}
