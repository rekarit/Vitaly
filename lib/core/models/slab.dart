import 'dart:typed_data';

enum SlabStatus { available, reserved, sold, damaged, unavailable }

/// AppSheet-aligned Slab / StoneInventory Model.
/// Backwards-compatible with all existing modules and slab usages.
class Slab {
  final String id;                    // Key e.g. '1201-01' or 's_0001'
  final String materialId;            // MaterialCode e.g. '1201'
  final String slabNo;                // Sequential Slab Number e.g. '1201-01'
  final String bundleNumber;          // Legacy / Batch Bundle e.g. 'BND-1201'
  final int slabNumber;               // Numerical sequence e.g. 1
  final double lengthCm;
  final double widthCm;
  final double thicknessCm;
  final double lengthMm;              // Length in millimeters (AppSheet specification)
  final double widthMm;               // Width in millimeters (AppSheet specification)
  final double thicknessMm;          // Thickness in millimeters (default: 20mm)
  final double areaSqm;               // Auto-calculated area: (lengthMm * widthMm) / 1,000,000
  final double netAreaSqm;            // Net area minus defects
  final SlabStatus status;            // available, reserved, sold, damaged
  final String? defectNotes;          // Notes / Defect description
  final bool hasDefect;               // Whether defects exist
  final String warehouseLocation;     // RackCode e.g. "RACK-A1" or "Block A - Row 3"
  final DateTime receivedDate;        // ReceivedDate in warehouse
  final double? reservedPrice;        // Optional reserved price
  final String? batchId;              // BatchID e.g. "BATCH-1201-01"
  final Uint8List? photoBytes;        // Slab Photo in-memory bytes
  final String? photoUrl;             // Photo URL / path
  final String? inventoryId;          // AppSheet InventoryID (e.g. 'ef219868' - 2 letters + 6 digits)
  final String? customQrData;         // Explicit unique QR payload
  final String? customPrintLabelText; // Explicit print label formula
  final String? reservedFor;          // AppSheet ReservedFor
  final String? reservedFrom;         // AppSheet ReservedFrom
  final String? reservedUntil;        // AppSheet ReservedUntil
  final String? reservationExpired;   // AppSheet ReservationExpired ('Yes', etc.)
  final String? pickedUp;             // AppSheet PickedUp
  final String? pickupDate;           // AppSheet PickupDate
  final String? signatureNote;        // AppSheet SignatureNote
  final String? locationType;         // AppSheet LocationType ('Yard', 'Field')
  final bool? visibleInCatalog;       // AppSheet VisibleInCatalog (TRUE/FALSE)
  final String? sourceReturnId;       // AppSheet SourceReturnID
  final String? scanCode;             // AppSheet ScanCode
  final int? quantity;                // AppSheet Quantity

  const Slab({
    required this.id,
    required this.materialId,
    String? slabNo,
    String? bundleNumber,
    int? slabNumber,
    double? lengthMm,
    double? widthMm,
    double? thicknessMm,
    double? lengthCm,
    double? widthCm,
    double? thicknessCm,
    double? areaSqm,
    double? netAreaSqm,
    this.status = SlabStatus.available,
    this.defectNotes,
    this.hasDefect = false,
    String? warehouseLocation,
    String? rackCode,
    DateTime? receivedDate,
    this.reservedPrice,
    this.batchId,
    this.photoBytes,
    this.photoUrl,
    this.inventoryId,
    this.customQrData,
    this.customPrintLabelText,
    this.reservedFor,
    this.reservedFrom,
    this.reservedUntil,
    this.reservationExpired,
    this.pickedUp,
    this.pickupDate,
    this.signatureNote,
    this.locationType,
    this.visibleInCatalog,
    this.sourceReturnId,
    this.scanCode,
    this.quantity,
  })  : slabNo = slabNo ?? id,
        bundleNumber = bundleNumber ?? (batchId ?? 'BND-$materialId'),
        slabNumber = slabNumber ?? 1,
        lengthMm = lengthMm ?? ((lengthCm ?? 234.4) * 10),
        widthMm = widthMm ?? ((widthCm ?? 234.4) * 10),
        thicknessMm = thicknessMm ?? ((thicknessCm ?? 2.0) * 10),
        lengthCm = lengthCm ?? ((lengthMm ?? 2344.0) / 10),
        widthCm = widthCm ?? ((widthMm ?? 2344.0) / 10),
        thicknessCm = thicknessCm ?? ((thicknessMm ?? 20.0) / 10),
        areaSqm = areaSqm ??
            (((lengthMm ?? ((lengthCm ?? 234.4) * 10)) *
                    (widthMm ?? ((widthCm ?? 234.4) * 10))) /
                1000000.0),
        netAreaSqm = netAreaSqm ??
            (areaSqm ??
                (((lengthMm ?? ((lengthCm ?? 234.4) * 10)) *
                        (widthMm ?? ((widthCm ?? 234.4) * 10))) /
                    1000000.0)),
        warehouseLocation = warehouseLocation ?? (rackCode ?? 'RACK-A1'),
        receivedDate = receivedDate ?? const _ConstantDateTime();

  // Backwards-compatibility getters
  String get rackCode => warehouseLocation;
  String? get notes => defectNotes;

  // Unique QR Code: encodes direct deep-link web URL so scanning directly opens the material detail tab
  String get qrCode {
    if (customQrData != null && customQrData!.isNotEmpty) {
      return customQrData!;
    }
    return 'https://rekarit.github.io/vitaly-app/?material=$materialId&slab=$slabNo';
  }

  // Print label formula text e.g. "1201-69 · Quartzite / CALACATTA GOLD · Polish"
  String get printLabelText {
    if (customPrintLabelText != null && customPrintLabelText!.isNotEmpty) {
      return customPrintLabelText!;
    }
    return '$slabNo · $materialId · ${lengthMm.toStringAsFixed(0)}×${widthMm.toStringAsFixed(0)}×${thicknessMm.toStringAsFixed(0)}mm · ${areaSqm.toStringAsFixed(2)} sqm';
  }

  Slab copyWith({
    String? id,
    String? materialId,
    String? slabNo,
    String? bundleNumber,
    int? slabNumber,
    double? lengthMm,
    double? widthMm,
    double? thicknessMm,
    double? lengthCm,
    double? widthCm,
    double? areaSqm,
    double? netAreaSqm,
    SlabStatus? status,
    String? defectNotes,
    bool? hasDefect,
    String? warehouseLocation,
    String? rackCode,
    DateTime? receivedDate,
    double? reservedPrice,
    String? batchId,
    Uint8List? photoBytes,
    String? photoUrl,
    String? inventoryId,
    String? customQrData,
    String? customPrintLabelText,
    String? reservedFor,
    String? reservedFrom,
    String? reservedUntil,
    String? reservationExpired,
    String? pickedUp,
    String? pickupDate,
    String? signatureNote,
    String? locationType,
    bool? visibleInCatalog,
    String? sourceReturnId,
    String? scanCode,
    int? quantity,
  }) {
    final computedLengthMm = lengthMm ?? (lengthCm != null ? lengthCm * 10 : this.lengthMm);
    final computedWidthMm = widthMm ?? (widthCm != null ? widthCm * 10 : this.widthMm);
    final computedArea = areaSqm ?? ((computedLengthMm * computedWidthMm) / 1000000.0);

    return Slab(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      slabNo: slabNo ?? this.slabNo,
      bundleNumber: bundleNumber ?? this.bundleNumber,
      slabNumber: slabNumber ?? this.slabNumber,
      lengthMm: computedLengthMm,
      widthMm: computedWidthMm,
      thicknessMm: thicknessMm ?? this.thicknessMm,
      areaSqm: computedArea,
      netAreaSqm: netAreaSqm ?? (defectNotes != null && defectNotes.isNotEmpty ? computedArea * 0.95 : computedArea),
      status: status ?? this.status,
      defectNotes: defectNotes ?? this.defectNotes,
      hasDefect: hasDefect ?? this.hasDefect,
      warehouseLocation: warehouseLocation ?? (rackCode ?? this.warehouseLocation),
      receivedDate: receivedDate ?? this.receivedDate,
      reservedPrice: reservedPrice ?? this.reservedPrice,
      batchId: batchId ?? this.batchId,
      photoBytes: photoBytes ?? this.photoBytes,
      photoUrl: photoUrl ?? this.photoUrl,
      inventoryId: inventoryId ?? this.inventoryId,
      customQrData: customQrData ?? this.customQrData,
      customPrintLabelText: customPrintLabelText ?? this.customPrintLabelText,
      reservedFor: reservedFor ?? this.reservedFor,
      reservedFrom: reservedFrom ?? this.reservedFrom,
      reservedUntil: reservedUntil ?? this.reservedUntil,
      reservationExpired: reservationExpired ?? this.reservationExpired,
      pickedUp: pickedUp ?? this.pickedUp,
      pickupDate: pickupDate ?? this.pickupDate,
      signatureNote: signatureNote ?? this.signatureNote,
      locationType: locationType ?? this.locationType,
      visibleInCatalog: visibleInCatalog ?? this.visibleInCatalog,
      sourceReturnId: sourceReturnId ?? this.sourceReturnId,
      scanCode: scanCode ?? this.scanCode,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'materialId': materialId,
        'slabNo': slabNo,
        'bundleNumber': bundleNumber,
        'slabNumber': slabNumber,
        'lengthMm': lengthMm,
        'widthMm': widthMm,
        'thicknessMm': thicknessMm,
        'areaSqm': areaSqm,
        'status': status.name,
        'defectNotes': defectNotes,
        'hasDefect': hasDefect,
        'warehouseLocation': warehouseLocation,
        'receivedDate': receivedDate.toIso8601String(),
        'reservedPrice': reservedPrice,
        'batchId': batchId,
        'photoUrl': photoUrl,
        'inventoryId': inventoryId,
        'customQrData': customQrData,
        'customPrintLabelText': customPrintLabelText,
        if (reservedFor != null) 'reservedFor': reservedFor,
        if (reservedFrom != null) 'reservedFrom': reservedFrom,
        if (reservedUntil != null) 'reservedUntil': reservedUntil,
        if (reservationExpired != null) 'reservationExpired': reservationExpired,
        if (pickedUp != null) 'pickedUp': pickedUp,
        if (pickupDate != null) 'pickupDate': pickupDate,
        if (signatureNote != null) 'signatureNote': signatureNote,
        if (locationType != null) 'locationType': locationType,
        if (visibleInCatalog != null) 'visibleInCatalog': visibleInCatalog,
        if (sourceReturnId != null) 'sourceReturnId': sourceReturnId,
        if (scanCode != null) 'scanCode': scanCode,
        if (quantity != null) 'quantity': quantity,
      };

  factory Slab.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status']?.toString() ?? 'available').toLowerCase();
    SlabStatus status = SlabStatus.available;
    if (statusStr.contains('unavail')) {
      status = SlabStatus.unavailable;
    } else if (statusStr.contains('reserv')) {
      status = SlabStatus.reserved;
    } else if (statusStr.contains('sold')) {
      status = SlabStatus.sold;
    } else if (statusStr.contains('damag')) {
      status = SlabStatus.damaged;
    }

    return Slab(
      id: json['id']?.toString() ?? '',
      materialId: json['materialId']?.toString() ?? '',
      slabNo: json['slabNo']?.toString(),
      bundleNumber: json['bundleNumber']?.toString(),
      slabNumber: (json['slabNumber'] as num?)?.toInt() ?? 1,
      lengthMm: (json['lengthMm'] as num?)?.toDouble(),
      widthMm: (json['widthMm'] as num?)?.toDouble(),
      thicknessMm: (json['thicknessMm'] as num?)?.toDouble(),
      areaSqm: (json['areaSqm'] as num?)?.toDouble(),
      status: status,
      defectNotes: json['defectNotes']?.toString(),
      hasDefect: json['hasDefect'] == true,
      warehouseLocation: json['warehouseLocation']?.toString(),
      receivedDate: json['receivedDate'] != null
          ? DateTime.tryParse(json['receivedDate'].toString())
          : null,
      reservedPrice: (json['reservedPrice'] as num?)?.toDouble(),
      batchId: json['batchId']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      inventoryId: json['inventoryId']?.toString(),
      customQrData: json['customQrData']?.toString(),
      customPrintLabelText: json['customPrintLabelText']?.toString(),
      reservedFor: json['reservedFor']?.toString(),
      reservedFrom: json['reservedFrom']?.toString(),
      reservedUntil: json['reservedUntil']?.toString(),
      reservationExpired: json['reservationExpired']?.toString(),
      pickedUp: json['pickedUp']?.toString(),
      pickupDate: json['pickupDate']?.toString(),
      signatureNote: json['signatureNote']?.toString(),
      locationType: json['locationType']?.toString(),
      visibleInCatalog: json['visibleInCatalog'] is bool
          ? json['visibleInCatalog'] as bool
          : (json['visibleInCatalog']?.toString().toUpperCase() == 'TRUE'
              ? true
              : (json['visibleInCatalog']?.toString().toUpperCase() == 'FALSE' ? false : null)),
      sourceReturnId: json['sourceReturnId']?.toString(),
      scanCode: json['scanCode']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? int.tryParse(json['quantity']?.toString() ?? ''),
    );
  }

  @override
  String toString() => 'Slab($slabNo · ${areaSqm.toStringAsFixed(2)}m²)';
}

/// Fallback constant DateTime helper for const constructors
class _ConstantDateTime implements DateTime {
  const _ConstantDateTime();

  @override
  DateTime toLocal() => DateTime.now();

  @override
  DateTime toUtc() => DateTime.now().toUtc();

  @override
  bool get isUtc => true;

  @override
  String toIso8601String() => DateTime.now().toIso8601String();

  @override
  bool isBefore(DateTime other) => false;

  @override
  bool isAfter(DateTime other) => false;

  @override
  bool isAtSameMomentAs(DateTime other) => true;

  @override
  int compareTo(DateTime other) => 0;

  @override
  int get millisecondsSinceEpoch => 1789948800000;

  @override
  int get microsecondsSinceEpoch => 1789948800000000;

  @override
  String get timeZoneName => 'UTC';

  @override
  Duration get timeZoneOffset => Duration.zero;

  @override
  int get year => 2026;

  @override
  int get month => 9;

  @override
  int get day => 22;

  @override
  int get hour => 0;

  @override
  int get minute => 0;

  @override
  int get second => 0;

  @override
  int get millisecond => 0;

  @override
  int get microsecond => 0;

  @override
  int get weekday => 2;

  @override
  DateTime add(Duration duration) => DateTime.now().add(duration);

  @override
  DateTime subtract(Duration duration) => DateTime.now().subtract(duration);

  @override
  Duration difference(DateTime other) => DateTime.now().difference(other);
}
