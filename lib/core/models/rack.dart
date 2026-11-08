/// AppSheet-aligned Warehouse Rack Model.
class Rack {
  final String rackCode;       // e.g. "WAREHOUSE", "RACK-A1", "SHOWROOM"
  final String rackName;       // e.g. "Warehouse", "Rack A1", "Showroom"
  final String warehouse;      // e.g. "Warehouse", "Main Depot"
  final String active;         // "Y" or "N"
  final String locationType;   // "Yard" or "Field"

  const Rack({
    required this.rackCode,
    required this.rackName,
    required this.warehouse,
    this.active = 'Y',
    this.locationType = 'Yard',
  });

  Rack copyWith({
    String? rackCode,
    String? rackName,
    String? warehouse,
    String? active,
    String? locationType,
  }) {
    return Rack(
      rackCode: rackCode ?? this.rackCode,
      rackName: rackName ?? this.rackName,
      warehouse: warehouse ?? this.warehouse,
      active: active ?? this.active,
      locationType: locationType ?? this.locationType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rack &&
          runtimeType == other.runtimeType &&
          rackCode.toUpperCase() == other.rackCode.toUpperCase();

  @override
  int get hashCode => rackCode.toUpperCase().hashCode;
}
