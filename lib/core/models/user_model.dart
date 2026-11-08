/// Represents all granular permissions across Vitaly ERP sections and actions.
class UserPermissions {
  // ── 1. Data Entry ──
  final bool canViewDataEntry;
  final bool canAddCategory;
  final bool canManageCategories;
  final bool canFilterCategories;
  final bool canAddMaterial;
  final bool canEditMaterial;
  final bool canDeleteMaterial;
  final bool canAddSlab;
  final bool canEditSlab;
  final bool canDeleteSlab;
  final bool canExportData;

  // ── 2. Stone Types ──
  final bool canViewStoneTypes;
  final bool canFilterStoneTypes;
  final bool canAdvancedFilterStone;
  final bool canMarkSlabDamagedInStone;
  final bool canQuickRepairSlab;

  // ── 3. Customer Profile ──
  final bool canViewCustomerProfile;
  final bool canAddCustomer;
  final bool canEditCustomer;
  final bool canDeleteCustomer;

  // ── 4. Reservations ──
  final bool canViewReservations;
  final bool canCreateReservation;
  final bool canCancelReservation;
  final bool canConvertReservationToSale;

  // ── 5. Sales ──
  final bool canViewSales;
  final bool canCreateSale;
  final bool canProcessPayment;
  final bool canCancelSale;

  // ── 6. Returns ──
  final bool canViewReturns;
  final bool canCreateReturn;
  final bool canApproveReturn;
  final bool canProcessReturn;

  // ── 7. Category Check ──
  final bool canViewCategoryCheck;
  final bool canExportCategoryCheck;

  // ── 8. Data Check ──
  final bool canViewDataCheck;
  final bool canExportDataCheck;
  final bool canEditAuditRecord;

  // ── 9. Print Labels ──
  final bool canViewPrintLabels;
  final bool canPrintSingleLabel;
  final bool canBatchPrintLabels;

  // ── 10. Scan ──
  final bool canViewScan;
  final bool canOpenCameraScanner;
  final bool canExportScanData;
  final bool canDirectMarkDamagedInScan;

  const UserPermissions({
    // 1. Data Entry
    this.canViewDataEntry = true,
    this.canAddCategory = true,
    this.canManageCategories = true,
    this.canFilterCategories = true,
    this.canAddMaterial = true,
    this.canEditMaterial = true,
    this.canDeleteMaterial = true,
    this.canAddSlab = true,
    this.canEditSlab = true,
    this.canDeleteSlab = true,
    this.canExportData = true,

    // 2. Stone Types
    this.canViewStoneTypes = true,
    this.canFilterStoneTypes = true,
    this.canAdvancedFilterStone = true,
    this.canMarkSlabDamagedInStone = true,
    this.canQuickRepairSlab = true,

    // 3. Customer Profile
    this.canViewCustomerProfile = true,
    this.canAddCustomer = true,
    this.canEditCustomer = true,
    this.canDeleteCustomer = true,

    // 4. Reservations
    this.canViewReservations = true,
    this.canCreateReservation = true,
    this.canCancelReservation = true,
    this.canConvertReservationToSale = true,

    // 5. Sales
    this.canViewSales = true,
    this.canCreateSale = true,
    this.canProcessPayment = true,
    this.canCancelSale = true,

    // 6. Returns
    this.canViewReturns = true,
    this.canCreateReturn = true,
    this.canApproveReturn = true,
    this.canProcessReturn = true,

    // 7. Category Check
    this.canViewCategoryCheck = true,
    this.canExportCategoryCheck = true,

    // 8. Data Check
    this.canViewDataCheck = true,
    this.canExportDataCheck = true,
    this.canEditAuditRecord = true,

    // 9. Print Labels
    this.canViewPrintLabels = true,
    this.canPrintSingleLabel = true,
    this.canBatchPrintLabels = true,

    // 10. Scan
    this.canViewScan = true,
    this.canOpenCameraScanner = true,
    this.canExportScanData = true,
    this.canDirectMarkDamagedInScan = true,
  });

  /// Factory for SuperAdmin (all permissions true)
  factory UserPermissions.all() => const UserPermissions();

  /// Factory for completely restricted permissions
  factory UserPermissions.none() => const UserPermissions(
        canViewDataEntry: false,
        canAddCategory: false,
        canManageCategories: false,
        canFilterCategories: false,
        canAddMaterial: false,
        canEditMaterial: false,
        canDeleteMaterial: false,
        canAddSlab: false,
        canEditSlab: false,
        canDeleteSlab: false,
        canExportData: false,
        canViewStoneTypes: false,
        canFilterStoneTypes: false,
        canAdvancedFilterStone: false,
        canMarkSlabDamagedInStone: false,
        canQuickRepairSlab: false,
        canViewCustomerProfile: false,
        canAddCustomer: false,
        canEditCustomer: false,
        canDeleteCustomer: false,
        canViewReservations: false,
        canCreateReservation: false,
        canCancelReservation: false,
        canConvertReservationToSale: false,
        canViewSales: false,
        canCreateSale: false,
        canProcessPayment: false,
        canCancelSale: false,
        canViewReturns: false,
        canCreateReturn: false,
        canApproveReturn: false,
        canProcessReturn: false,
        canViewCategoryCheck: false,
        canExportCategoryCheck: false,
        canViewDataCheck: false,
        canExportDataCheck: false,
        canEditAuditRecord: false,
        canViewPrintLabels: false,
        canPrintSingleLabel: false,
        canBatchPrintLabels: false,
        canViewScan: false,
        canOpenCameraScanner: false,
        canExportScanData: false,
        canDirectMarkDamagedInScan: false,
      );

  /// Factory for Staff role:
  /// Staff CANNOT create new categories or materials (fixed/pre-loaded catalog).
  /// Staff CAN add slabs into materials, view catalog, and perform operations.
  factory UserPermissions.staff() => const UserPermissions(
        canViewDataEntry: true,
        canAddCategory: false,       // Staff cannot create categories
        canManageCategories: false,  // Staff cannot manage categories
        canFilterCategories: true,
        canAddMaterial: false,       // Staff cannot add new materials
        canEditMaterial: false,      // Staff cannot edit materials
        canDeleteMaterial: false,    // Staff cannot delete materials
        canAddSlab: true,            // Staff CAN add slabs into existing materials
        canEditSlab: true,
        canDeleteSlab: false,
        canExportData: true,
        canViewStoneTypes: true,
        canFilterStoneTypes: true,
        canAdvancedFilterStone: true,
        canMarkSlabDamagedInStone: true,
        canQuickRepairSlab: true,
        canViewCustomerProfile: true,
        canAddCustomer: true,
        canEditCustomer: true,
        canDeleteCustomer: false,
        canViewReservations: true,
        canCreateReservation: true,
        canCancelReservation: false,
        canConvertReservationToSale: true,
        canViewSales: true,
        canCreateSale: true,
        canProcessPayment: false,
        canCancelSale: false,
        canViewReturns: true,
        canCreateReturn: true,
        canApproveReturn: false,
        canProcessReturn: false,
        canViewCategoryCheck: true,
        canExportCategoryCheck: true,
        canViewDataCheck: true,
        canExportDataCheck: false,
        canEditAuditRecord: false,
        canViewPrintLabels: true,
        canPrintSingleLabel: true,
        canBatchPrintLabels: true,
        canViewScan: true,
        canOpenCameraScanner: true,
        canExportScanData: true,
        canDirectMarkDamagedInScan: true,
      );

  UserPermissions copyWith({
    bool? canViewDataEntry,
    bool? canAddCategory,
    bool? canManageCategories,
    bool? canFilterCategories,
    bool? canAddMaterial,
    bool? canEditMaterial,
    bool? canDeleteMaterial,
    bool? canAddSlab,
    bool? canEditSlab,
    bool? canDeleteSlab,
    bool? canExportData,
    bool? canViewStoneTypes,
    bool? canFilterStoneTypes,
    bool? canAdvancedFilterStone,
    bool? canMarkSlabDamagedInStone,
    bool? canQuickRepairSlab,
    bool? canViewCustomerProfile,
    bool? canAddCustomer,
    bool? canEditCustomer,
    bool? canDeleteCustomer,
    bool? canViewReservations,
    bool? canCreateReservation,
    bool? canCancelReservation,
    bool? canConvertReservationToSale,
    bool? canViewSales,
    bool? canCreateSale,
    bool? canProcessPayment,
    bool? canCancelSale,
    bool? canViewReturns,
    bool? canCreateReturn,
    bool? canApproveReturn,
    bool? canProcessReturn,
    bool? canViewCategoryCheck,
    bool? canExportCategoryCheck,
    bool? canViewDataCheck,
    bool? canExportDataCheck,
    bool? canEditAuditRecord,
    bool? canViewPrintLabels,
    bool? canPrintSingleLabel,
    bool? canBatchPrintLabels,
    bool? canViewScan,
    bool? canOpenCameraScanner,
    bool? canExportScanData,
    bool? canDirectMarkDamagedInScan,
  }) {
    return UserPermissions(
      canViewDataEntry: canViewDataEntry ?? this.canViewDataEntry,
      canAddCategory: canAddCategory ?? this.canAddCategory,
      canManageCategories: canManageCategories ?? this.canManageCategories,
      canFilterCategories: canFilterCategories ?? this.canFilterCategories,
      canAddMaterial: canAddMaterial ?? this.canAddMaterial,
      canEditMaterial: canEditMaterial ?? this.canEditMaterial,
      canDeleteMaterial: canDeleteMaterial ?? this.canDeleteMaterial,
      canAddSlab: canAddSlab ?? this.canAddSlab,
      canEditSlab: canEditSlab ?? this.canEditSlab,
      canDeleteSlab: canDeleteSlab ?? this.canDeleteSlab,
      canExportData: canExportData ?? this.canExportData,
      canViewStoneTypes: canViewStoneTypes ?? this.canViewStoneTypes,
      canFilterStoneTypes: canFilterStoneTypes ?? this.canFilterStoneTypes,
      canAdvancedFilterStone: canAdvancedFilterStone ?? this.canAdvancedFilterStone,
      canMarkSlabDamagedInStone: canMarkSlabDamagedInStone ?? this.canMarkSlabDamagedInStone,
      canQuickRepairSlab: canQuickRepairSlab ?? this.canQuickRepairSlab,
      canViewCustomerProfile: canViewCustomerProfile ?? this.canViewCustomerProfile,
      canAddCustomer: canAddCustomer ?? this.canAddCustomer,
      canEditCustomer: canEditCustomer ?? this.canEditCustomer,
      canDeleteCustomer: canDeleteCustomer ?? this.canDeleteCustomer,
      canViewReservations: canViewReservations ?? this.canViewReservations,
      canCreateReservation: canCreateReservation ?? this.canCreateReservation,
      canCancelReservation: canCancelReservation ?? this.canCancelReservation,
      canConvertReservationToSale: canConvertReservationToSale ?? this.canConvertReservationToSale,
      canViewSales: canViewSales ?? this.canViewSales,
      canCreateSale: canCreateSale ?? this.canCreateSale,
      canProcessPayment: canProcessPayment ?? this.canProcessPayment,
      canCancelSale: canCancelSale ?? this.canCancelSale,
      canViewReturns: canViewReturns ?? this.canViewReturns,
      canCreateReturn: canCreateReturn ?? this.canCreateReturn,
      canApproveReturn: canApproveReturn ?? this.canApproveReturn,
      canProcessReturn: canProcessReturn ?? this.canProcessReturn,
      canViewCategoryCheck: canViewCategoryCheck ?? this.canViewCategoryCheck,
      canExportCategoryCheck: canExportCategoryCheck ?? this.canExportCategoryCheck,
      canViewDataCheck: canViewDataCheck ?? this.canViewDataCheck,
      canExportDataCheck: canExportDataCheck ?? this.canExportDataCheck,
      canEditAuditRecord: canEditAuditRecord ?? this.canEditAuditRecord,
      canViewPrintLabels: canViewPrintLabels ?? this.canViewPrintLabels,
      canPrintSingleLabel: canPrintSingleLabel ?? this.canPrintSingleLabel,
      canBatchPrintLabels: canBatchPrintLabels ?? this.canBatchPrintLabels,
      canViewScan: canViewScan ?? this.canViewScan,
      canOpenCameraScanner: canOpenCameraScanner ?? this.canOpenCameraScanner,
      canExportScanData: canExportScanData ?? this.canExportScanData,
      canDirectMarkDamagedInScan: canDirectMarkDamagedInScan ?? this.canDirectMarkDamagedInScan,
    );
  }

  /// Toggles visibility of a root module and cascades the state to all its sub-actions.
  /// When [isVisible] is false, all sub-actions under this module are automatically disabled (unchecked).
  /// When [isVisible] is true, all sub-actions under this module are enabled (checked).
  UserPermissions toggleModule(int moduleIndex, bool isVisible) {
    switch (moduleIndex) {
      case 1: // Data Entry
        return copyWith(
          canViewDataEntry: isVisible,
          canAddCategory: isVisible,
          canManageCategories: isVisible,
          canFilterCategories: isVisible,
          canAddMaterial: isVisible,
          canEditMaterial: isVisible,
          canDeleteMaterial: isVisible,
          canAddSlab: isVisible,
          canEditSlab: isVisible,
          canDeleteSlab: isVisible,
          canExportData: isVisible,
        );
      case 2: // Stone Types
        return copyWith(
          canViewStoneTypes: isVisible,
          canFilterStoneTypes: isVisible,
          canAdvancedFilterStone: isVisible,
          canMarkSlabDamagedInStone: isVisible,
          canQuickRepairSlab: isVisible,
        );
      case 3: // Customer Profile
        return copyWith(
          canViewCustomerProfile: isVisible,
          canAddCustomer: isVisible,
          canEditCustomer: isVisible,
          canDeleteCustomer: isVisible,
        );
      case 4: // Reservations
        return copyWith(
          canViewReservations: isVisible,
          canCreateReservation: isVisible,
          canCancelReservation: isVisible,
          canConvertReservationToSale: isVisible,
        );
      case 5: // Sales
        return copyWith(
          canViewSales: isVisible,
          canCreateSale: isVisible,
          canProcessPayment: isVisible,
          canCancelSale: isVisible,
        );
      case 6: // Returns
        return copyWith(
          canViewReturns: isVisible,
          canCreateReturn: isVisible,
          canApproveReturn: isVisible,
          canProcessReturn: isVisible,
        );
      case 7: // Category Check
        return copyWith(
          canViewCategoryCheck: isVisible,
          canExportCategoryCheck: isVisible,
        );
      case 8: // Data Check
        return copyWith(
          canViewDataCheck: isVisible,
          canExportDataCheck: isVisible,
          canEditAuditRecord: isVisible,
        );
      case 9: // Print Labels
        return copyWith(
          canViewPrintLabels: isVisible,
          canPrintSingleLabel: isVisible,
          canBatchPrintLabels: isVisible,
        );
      case 10: // Scan
        return copyWith(
          canViewScan: isVisible,
          canOpenCameraScanner: isVisible,
          canExportScanData: isVisible,
          canDirectMarkDamagedInScan: isVisible,
        );
      default:
        return this;
    }
  }

  Map<String, dynamic> toJson() => {
        'canViewDataEntry': canViewDataEntry,
        'canAddCategory': canAddCategory,
        'canManageCategories': canManageCategories,
        'canFilterCategories': canFilterCategories,
        'canAddMaterial': canAddMaterial,
        'canEditMaterial': canEditMaterial,
        'canDeleteMaterial': canDeleteMaterial,
        'canAddSlab': canAddSlab,
        'canEditSlab': canEditSlab,
        'canDeleteSlab': canDeleteSlab,
        'canExportData': canExportData,
        'canViewStoneTypes': canViewStoneTypes,
        'canFilterStoneTypes': canFilterStoneTypes,
        'canAdvancedFilterStone': canAdvancedFilterStone,
        'canMarkSlabDamagedInStone': canMarkSlabDamagedInStone,
        'canQuickRepairSlab': canQuickRepairSlab,
        'canViewCustomerProfile': canViewCustomerProfile,
        'canAddCustomer': canAddCustomer,
        'canEditCustomer': canEditCustomer,
        'canDeleteCustomer': canDeleteCustomer,
        'canViewReservations': canViewReservations,
        'canCreateReservation': canCreateReservation,
        'canCancelReservation': canCancelReservation,
        'canConvertReservationToSale': canConvertReservationToSale,
        'canViewSales': canViewSales,
        'canCreateSale': canCreateSale,
        'canProcessPayment': canProcessPayment,
        'canCancelSale': canCancelSale,
        'canViewReturns': canViewReturns,
        'canCreateReturn': canCreateReturn,
        'canApproveReturn': canApproveReturn,
        'canProcessReturn': canProcessReturn,
        'canViewCategoryCheck': canViewCategoryCheck,
        'canExportCategoryCheck': canExportCategoryCheck,
        'canViewDataCheck': canViewDataCheck,
        'canExportDataCheck': canExportDataCheck,
        'canEditAuditRecord': canEditAuditRecord,
        'canViewPrintLabels': canViewPrintLabels,
        'canPrintSingleLabel': canPrintSingleLabel,
        'canBatchPrintLabels': canBatchPrintLabels,
        'canViewScan': canViewScan,
        'canOpenCameraScanner': canOpenCameraScanner,
        'canExportScanData': canExportScanData,
        'canDirectMarkDamagedInScan': canDirectMarkDamagedInScan,
      };

  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions(
      canViewDataEntry: json['canViewDataEntry'] ?? true,
      canAddCategory: json['canAddCategory'] ?? true,
      canManageCategories: json['canManageCategories'] ?? true,
      canFilterCategories: json['canFilterCategories'] ?? true,
      canAddMaterial: json['canAddMaterial'] ?? true,
      canEditMaterial: json['canEditMaterial'] ?? true,
      canDeleteMaterial: json['canDeleteMaterial'] ?? true,
      canAddSlab: json['canAddSlab'] ?? true,
      canEditSlab: json['canEditSlab'] ?? true,
      canDeleteSlab: json['canDeleteSlab'] ?? true,
      canExportData: json['canExportData'] ?? true,
      canViewStoneTypes: json['canViewStoneTypes'] ?? true,
      canFilterStoneTypes: json['canFilterStoneTypes'] ?? true,
      canAdvancedFilterStone: json['canAdvancedFilterStone'] ?? true,
      canMarkSlabDamagedInStone: json['canMarkSlabDamagedInStone'] ?? true,
      canQuickRepairSlab: json['canQuickRepairSlab'] ?? true,
      canViewCustomerProfile: json['canViewCustomerProfile'] ?? true,
      canAddCustomer: json['canAddCustomer'] ?? true,
      canEditCustomer: json['canEditCustomer'] ?? true,
      canDeleteCustomer: json['canDeleteCustomer'] ?? true,
      canViewReservations: json['canViewReservations'] ?? true,
      canCreateReservation: json['canCreateReservation'] ?? true,
      canCancelReservation: json['canCancelReservation'] ?? true,
      canConvertReservationToSale: json['canConvertReservationToSale'] ?? true,
      canViewSales: json['canViewSales'] ?? true,
      canCreateSale: json['canCreateSale'] ?? true,
      canProcessPayment: json['canProcessPayment'] ?? true,
      canCancelSale: json['canCancelSale'] ?? true,
      canViewReturns: json['canViewReturns'] ?? true,
      canCreateReturn: json['canCreateReturn'] ?? true,
      canApproveReturn: json['canApproveReturn'] ?? true,
      canProcessReturn: json['canProcessReturn'] ?? true,
      canViewCategoryCheck: json['canViewCategoryCheck'] ?? true,
      canExportCategoryCheck: json['canExportCategoryCheck'] ?? true,
      canViewDataCheck: json['canViewDataCheck'] ?? true,
      canExportDataCheck: json['canExportDataCheck'] ?? true,
      canEditAuditRecord: json['canEditAuditRecord'] ?? true,
      canViewPrintLabels: json['canViewPrintLabels'] ?? true,
      canPrintSingleLabel: json['canPrintSingleLabel'] ?? true,
      canBatchPrintLabels: json['canBatchPrintLabels'] ?? true,
      canViewScan: json['canViewScan'] ?? true,
      canOpenCameraScanner: json['canOpenCameraScanner'] ?? true,
      canExportScanData: json['canExportScanData'] ?? true,
      canDirectMarkDamagedInScan: json['canDirectMarkDamagedInScan'] ?? true,
    );
  }
}

/// App user model with role, credentials, and custom permissions.
class AppUser {
  final String id;
  final String username;
  final String password;
  final String roleName; // e.g., 'Super Admin', 'Inventory Lead', 'Sales Specialist'
  final bool isSuperAdmin;
  final bool isHidden; // Hidden testing account: hidden from user list, logs not recorded
  final bool mustChangeCredentials;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final UserPermissions permissions;

  const AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.roleName,
    this.isSuperAdmin = false,
    this.isHidden = false,
    this.mustChangeCredentials = false,
    required this.createdAt,
    this.lastLogin,
    this.permissions = const UserPermissions(),
  });

  AppUser copyWith({
    String? id,
    String? username,
    String? password,
    String? roleName,
    bool? isSuperAdmin,
    bool? isHidden,
    bool? mustChangeCredentials,
    DateTime? createdAt,
    DateTime? lastLogin,
    UserPermissions? permissions,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      roleName: roleName ?? this.roleName,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      isHidden: isHidden ?? this.isHidden,
      mustChangeCredentials: mustChangeCredentials ?? this.mustChangeCredentials,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'password': password,
        'roleName': roleName,
        'isSuperAdmin': isSuperAdmin,
        'isHidden': isHidden,
        'mustChangeCredentials': mustChangeCredentials,
        'createdAt': createdAt.toIso8601String(),
        'lastLogin': lastLogin?.toIso8601String(),
        'permissions': permissions.toJson(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      roleName: json['roleName']?.toString() ?? 'User',
      isSuperAdmin: json['isSuperAdmin'] == true,
      isHidden: json['isHidden'] == true,
      mustChangeCredentials: json['mustChangeCredentials'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'].toString())
          : null,
      permissions: json['permissions'] != null
          ? UserPermissions.fromJson(Map<String, dynamic>.from(json['permissions']))
          : const UserPermissions(),
    );
  }
}

/// Audit log record for tracking all user actions (create, update, delete).
class UserActivityLog {
  final String id;
  final String username;
  final String roleName;
  final String actionType; // 'CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'SECURITY'
  final String section; // 'Data Entry', 'Stone Types', 'Customer Profile', 'Sales', etc.
  final String details;
  final DateTime timestamp;

  const UserActivityLog({
    required this.id,
    required this.username,
    required this.roleName,
    required this.actionType,
    required this.section,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'roleName': roleName,
        'actionType': actionType,
        'section': section,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
      };

  factory UserActivityLog.fromJson(Map<String, dynamic> json) {
    return UserActivityLog(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      roleName: json['roleName']?.toString() ?? 'User',
      actionType: json['actionType']?.toString() ?? 'INFO',
      section: json['section']?.toString() ?? 'General',
      details: json['details']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
