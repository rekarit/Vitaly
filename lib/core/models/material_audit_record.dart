class MaterialAuditRecord {
  final String materialId;
  final String codeText;
  final String materialName;
  final int categoryCode;
  final double? physicalSqm;
  final bool isCounted;
  final double erpInSqm;
  final double erpOutSqm;
  final double? erpBalanceOverride;
  final double? appSqmOverride;
  final String lastErpUpdate;
  final String notes;
  final String lastCountDate;

  const MaterialAuditRecord({
    required this.materialId,
    String? codeText,
    this.materialName = '',
    this.categoryCode = 12,
    this.physicalSqm,
    this.isCounted = false,
    this.erpInSqm = 0.0,
    this.erpOutSqm = 0.0,
    this.erpBalanceOverride,
    this.appSqmOverride,
    this.lastErpUpdate = '6/20/2026',
    this.notes = 'Imported from ERP movement summary',
    this.lastCountDate = '',
  }) : codeText = codeText ?? materialId;

  String get displayName => materialName.isNotEmpty ? '$codeText - $materialName' : codeText;
  double get erpBalanceSqm => erpBalanceOverride ?? (erpInSqm - erpOutSqm);
  String get checkStatus => isCounted ? 'COUNTED' : 'NOT COUNTED';
  double get appVsErp => (appSqmOverride ?? 0.0) - erpBalanceSqm;

  MaterialAuditRecord copyWith({
    String? codeText,
    String? materialName,
    int? categoryCode,
    double? physicalSqm,
    bool? isCounted,
    double? erpInSqm,
    double? erpOutSqm,
    double? erpBalanceOverride,
    double? appSqmOverride,
    String? lastErpUpdate,
    String? notes,
    String? lastCountDate,
  }) {
    return MaterialAuditRecord(
      materialId: materialId,
      codeText: codeText ?? this.codeText,
      materialName: materialName ?? this.materialName,
      categoryCode: categoryCode ?? this.categoryCode,
      physicalSqm: physicalSqm ?? this.physicalSqm,
      isCounted: isCounted ?? this.isCounted,
      erpInSqm: erpInSqm ?? this.erpInSqm,
      erpOutSqm: erpOutSqm ?? this.erpOutSqm,
      erpBalanceOverride: erpBalanceOverride ?? this.erpBalanceOverride,
      appSqmOverride: appSqmOverride ?? this.appSqmOverride,
      lastErpUpdate: lastErpUpdate ?? this.lastErpUpdate,
      notes: notes ?? this.notes,
      lastCountDate: lastCountDate ?? this.lastCountDate,
    );
  }
}
