import 'dart:typed_data';

/// AppSheet-aligned Material Model representing materials under Categories.
/// Backwards-compatible with legacy [MaterialItem] usages across the codebase.
class MaterialItem {
  final String id;                    // Key, e.g. '1201' or 'mat_01'
  final String name;                  // MaterialName, e.g. 'CALACATTA GOLD'
  final String categoryId;            // Category name or ID, e.g. 'Quartzite / Crystal'
  final int categoryCode;             // Category code, e.g. 12
  final String materialCode;          // MaterialCode*, e.g. '1201'
  final String stoneType;             // StoneType, e.g. 'Quartzite'
  final String origin;                // Country of origin
  final String finish;                // Finish e.g. 'Polish', 'Honed', 'Sandblast'
  final String referenceCode;         // ReferenceCode e.g. '1201'
  final String erpDescription;        // ERPDescription
  final String erpUnit;               // ERPUnit (default: 'sqm')
  final String displayLabel;          // DisplayLabel (default: '-')
  final double totalAreaSqm;          // TotalAreaSqm (read-only formula, default: 0.00)
  final int totalSlabs;               // TotalSlabs (read-only formula, default: 0)
  final String categoryAndName;       // CategoryAndName formula: [CategoryName] - [MaterialName]
  final String stockSummary;          // StockSummary formula: [TotalAreaSqm] sqm • [TotalSlabs] slabs
  final String codeAndFinish;         // CodeAndFinish formula: [MaterialCode] - [TotalAreaSqm]m² - [Finish]
  final String categoryStock;         // CategoryStock formula: [CatArea] sqm - [CatSlabs] slabs
  final double pricePerSqm;           // USD per m²
  final String colorFamily;           // Legacy grouping
  final String? imageUrl;             // Image URL / path
  final Uint8List? imageBytes;        // In-memory image bytes for preview / upload

  MaterialItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.categoryCode = 12,
    String? materialCode,
    String? stoneType,
    this.origin = 'Unknown',
    required this.finish,
    String? referenceCode,
    this.erpDescription = '',
    this.erpUnit = 'sqm',
    this.displayLabel = '-',
    this.totalAreaSqm = 0.0,
    this.totalSlabs = 0,
    String? categoryAndName,
    String? stockSummary,
    String? codeAndFinish,
    String? categoryStock,
    this.pricePerSqm = 100.0,
    String? colorFamily,
    this.imageUrl,
    this.imageBytes,
  })  : materialCode = materialCode ?? id,
        stoneType = stoneType ?? categoryId,
        referenceCode = referenceCode ?? (materialCode ?? id),
        categoryAndName = categoryAndName ?? '$categoryId - ${name.toUpperCase()}',
        stockSummary = stockSummary ?? '${totalAreaSqm.toStringAsFixed(0)} sqm • $totalSlabs slabs',
        codeAndFinish = codeAndFinish ?? '$id - ${totalAreaSqm.toStringAsFixed(0)}m² - $finish',
        categoryStock = categoryStock ?? '0 sqm - 0 slabs',
        colorFamily = colorFamily ?? categoryId;

  // Convenience getters
  String get materialName => name;

  MaterialItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    int? categoryCode,
    String? materialCode,
    String? stoneType,
    String? origin,
    String? finish,
    String? referenceCode,
    String? erpDescription,
    String? erpUnit,
    String? displayLabel,
    double? totalAreaSqm,
    int? totalSlabs,
    String? categoryAndName,
    String? stockSummary,
    String? codeAndFinish,
    String? categoryStock,
    double? pricePerSqm,
    String? colorFamily,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryCode: categoryCode ?? this.categoryCode,
      materialCode: materialCode ?? this.materialCode,
      stoneType: stoneType ?? this.stoneType,
      origin: origin ?? this.origin,
      finish: finish ?? this.finish,
      referenceCode: referenceCode ?? this.referenceCode,
      erpDescription: erpDescription ?? this.erpDescription,
      erpUnit: erpUnit ?? this.erpUnit,
      displayLabel: displayLabel ?? this.displayLabel,
      totalAreaSqm: totalAreaSqm ?? this.totalAreaSqm,
      totalSlabs: totalSlabs ?? this.totalSlabs,
      categoryAndName: categoryAndName ?? this.categoryAndName,
      stockSummary: stockSummary ?? this.stockSummary,
      codeAndFinish: codeAndFinish ?? this.codeAndFinish,
      categoryStock: categoryStock ?? this.categoryStock,
      pricePerSqm: pricePerSqm ?? this.pricePerSqm,
      colorFamily: colorFamily ?? this.colorFamily,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'categoryId': categoryId,
    'categoryCode': categoryCode,
    'materialCode': materialCode,
    'stoneType': stoneType,
    'origin': origin,
    'finish': finish,
    'referenceCode': referenceCode,
    'erpDescription': erpDescription,
    'erpUnit': erpUnit,
    'displayLabel': displayLabel,
    'totalAreaSqm': totalAreaSqm,
    'totalSlabs': totalSlabs,
    'pricePerSqm': pricePerSqm,
    'colorFamily': colorFamily,
    'imageUrl': imageUrl,
  };

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    categoryId: json['categoryId']?.toString() ?? 'Quartzite / Crystal',
    categoryCode: (json['categoryCode'] as num?)?.toInt() ?? 12,
    materialCode: json['materialCode']?.toString(),
    stoneType: json['stoneType']?.toString(),
    origin: json['origin']?.toString() ?? 'Unknown',
    finish: json['finish']?.toString() ?? 'Polish',
    referenceCode: json['referenceCode']?.toString(),
    erpDescription: json['erpDescription']?.toString() ?? '',
    erpUnit: json['erpUnit']?.toString() ?? 'sqm',
    displayLabel: json['displayLabel']?.toString() ?? '-',
    totalAreaSqm: (json['totalAreaSqm'] as num?)?.toDouble() ?? 0.0,
    totalSlabs: (json['totalSlabs'] as num?)?.toInt() ?? 0,
    pricePerSqm: (json['pricePerSqm'] as num?)?.toDouble() ?? 100.0,
    colorFamily: json['colorFamily']?.toString(),
    imageUrl: json['imageUrl']?.toString(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialItem &&
          runtimeType == other.runtimeType &&
          (id == other.id || materialCode == other.materialCode);

  @override
  int get hashCode => materialCode.hashCode;

  @override
  String toString() => 'MaterialItem($materialCode - $name)';
}

/// Alias for AppSheet alignment
typedef MaterialModel = MaterialItem;
