/// AppSheet-aligned Category Model representing the Root (Trunk) of the warehouse inventory hierarchy.
class CategoryModel {
  final int categoryCode;            // Key, Required, Editable e.g. 12, 13, 14, 18
  final String categoryName;          // Label, Required, Editable e.g. "Quartzite / Crystal"
  final String categoryHeader;        // Formula: CONCATENATE([CategoryName], " - ", [CategoryCode])
  final double catErpSqm;             // Read-Only Formula: SUM(SELECT(ERP_Stock...))
  final double catPhysicalSqm;        // Read-Only Formula: SUM(SELECT(ERP_Stock...))

  const CategoryModel({
    required this.categoryCode,
    required this.categoryName,
    this.categoryHeader = '-',
    this.catErpSqm = 0.0,
    this.catPhysicalSqm = 0.0,
  });

  // String ID convenience
  String get id => categoryCode.toString();
  String get name => categoryName;

  CategoryModel copyWith({
    int? categoryCode,
    String? categoryName,
    String? categoryHeader,
    double? catErpSqm,
    double? catPhysicalSqm,
  }) {
    return CategoryModel(
      categoryCode: categoryCode ?? this.categoryCode,
      categoryName: categoryName ?? this.categoryName,
      categoryHeader: categoryHeader ?? this.categoryHeader,
      catErpSqm: catErpSqm ?? this.catErpSqm,
      catPhysicalSqm: catPhysicalSqm ?? this.catPhysicalSqm,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel && runtimeType == other.runtimeType && categoryCode == other.categoryCode;

  @override
  int get hashCode => categoryCode.hashCode;

  @override
  String toString() => 'CategoryModel($categoryCode - $categoryName)';
}
