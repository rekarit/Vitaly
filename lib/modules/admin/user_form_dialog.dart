import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';

/// Form dialog to create or edit a user with custom role name, credentials,
/// and comprehensive checkboxes for every section and sub-section.
class UserFormDialog extends StatefulWidget {
  final AppUser? existingUser;
  final VoidCallback onSaved;

  const UserFormDialog({
    super.key,
    this.existingUser,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    AppUser? existingUser,
    required VoidCallback onSaved,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => UserFormDialog(
        existingUser: existingUser,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _roleNameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isSuperAdmin = false;
  late UserPermissions _permissions;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.existingUser != null) {
      final u = widget.existingUser!;
      _usernameCtrl.text = u.username;
      _passwordCtrl.text = u.password;
      _roleNameCtrl.text = u.roleName;
      _isSuperAdmin = u.isSuperAdmin;
      _permissions = u.permissions;
    } else {
      _roleNameCtrl.text = 'Staff';
      _permissions = UserPermissions.staff();
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _roleNameCtrl.dispose();
    super.dispose();
  }

  void _toggleAllPermissions(bool value) {
    setState(() {
      _permissions = value ? UserPermissions.all() : UserPermissions.none();
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final roleName = _roleNameCtrl.text.trim();

    bool success;
    if (widget.existingUser != null) {
      final updated = widget.existingUser!.copyWith(
        username: username,
        password: password,
        roleName: roleName,
        isSuperAdmin: _isSuperAdmin,
        permissions: _isSuperAdmin ? UserPermissions.all() : _permissions,
      );
      success = await AuthService.instance.updateUser(updated);
    } else {
      success = await AuthService.instance.createUser(
        username: username,
        password: password,
        roleName: roleName,
        isSuperAdmin: _isSuperAdmin,
        permissions: _isSuperAdmin ? UserPermissions.all() : _permissions,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      widget.onSaved();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Username "$username" already exists or is invalid.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final isEdit = widget.existingUser != null;

    final usernameField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Username', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _usernameCtrl,
          style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. jaber_inventory',
            filled: true,
            fillColor: colors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );

    final passwordField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter password',
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 16, color: colors.textSecondary),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: colors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
      ],
    );

    final roleField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Role Name / Title', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _roleNameCtrl,
          style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Warehouse Lead, Sales Executive',
            filled: true,
            fillColor: colors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );

    final superAdminCheckbox = Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isSuperAdmin ? colors.primary.withAlpha(80) : colors.border),
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        title: Text(
          'Super Admin Role',
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        subtitle: Text(
          'Full bypass access to all settings',
          style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
        ),
        value: _isSuperAdmin,
        activeColor: colors.primary,
        onChanged: (val) {
          setState(() {
            _isSuperAdmin = val ?? false;
            if (_isSuperAdmin) _toggleAllPermissions(true);
          });
        },
      ),
    );

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * (isMobile ? 0.94 : 0.88),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: isMobile ? 36 : 40,
                      height: isMobile ? 36 : 40,
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isEdit ? Icons.edit_rounded : Icons.person_add_rounded, color: colors.primary, size: isMobile ? 19 : 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit User & Permissions' : 'Create New User',
                            style: GoogleFonts.inter(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          Text(
                            'Configure credentials, role title, and modular permissions',
                            style: GoogleFonts.inter(fontSize: isMobile ? 11 : 12, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: colors.border, height: 1),
                const SizedBox(height: 12),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.error.withAlpha(60)),
                    ),
                    child: Text(_errorMessage!, style: GoogleFonts.inter(color: colors.error, fontSize: 12)),
                  ),
                ],

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Details (Responsive)
                        if (isMobile) ...[
                          usernameField,
                          const SizedBox(height: 12),
                          passwordField,
                          const SizedBox(height: 12),
                          roleField,
                          const SizedBox(height: 12),
                          superAdminCheckbox,
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: usernameField),
                              const SizedBox(width: 14),
                              Expanded(child: passwordField),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: roleField),
                              const SizedBox(width: 14),
                              Expanded(child: superAdminCheckbox),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Permissions Header with Select All / Deselect All
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              'Permissions Matrix (Visible & Accessible)',
                              style: GoogleFonts.inter(fontSize: isMobile ? 12.5 : 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            if (!_isSuperAdmin)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => _toggleAllPermissions(true),
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                    child: Text('Select All', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => _toggleAllPermissions(false),
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                    child: Text('Clear All', style: GoogleFonts.inter(fontSize: 11, color: colors.error)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_isSuperAdmin) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.primary.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.stars_rounded, color: colors.primary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Super Admin automatically possesses unrestricted permission over all modules and actions.',
                                    style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // 1. DATA ENTRY
                          _buildModuleCard(
                            moduleIndex: 1,
                            title: 'Data Entry',
                            icon: Icons.add_box_rounded,
                            isVisible: _permissions.canViewDataEntry,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(1, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(1, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
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
                            )),
                            colors: colors,
                            children: [
                              _permTile('New Category Button', _permissions.canAddCategory, (v) => setState(() => _permissions = _permissions.copyWith(canAddCategory: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Category Manager Button', _permissions.canManageCategories, (v) => setState(() => _permissions = _permissions.copyWith(canManageCategories: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Filter Categories Button', _permissions.canFilterCategories, (v) => setState(() => _permissions = _permissions.copyWith(canFilterCategories: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Add Material Action', _permissions.canAddMaterial, (v) => setState(() => _permissions = _permissions.copyWith(canAddMaterial: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Edit Material Action', _permissions.canEditMaterial, (v) => setState(() => _permissions = _permissions.copyWith(canEditMaterial: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Delete Material Action', _permissions.canDeleteMaterial, (v) => setState(() => _permissions = _permissions.copyWith(canDeleteMaterial: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Add Slab Action', _permissions.canAddSlab, (v) => setState(() => _permissions = _permissions.copyWith(canAddSlab: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Edit Slab Action', _permissions.canEditSlab, (v) => setState(() => _permissions = _permissions.copyWith(canEditSlab: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Delete Slab Action', _permissions.canDeleteSlab, (v) => setState(() => _permissions = _permissions.copyWith(canDeleteSlab: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                              _permTile('Export Data (CSV/PDF)', _permissions.canExportData, (v) => setState(() => _permissions = _permissions.copyWith(canExportData: v, canViewDataEntry: v ? true : _permissions.canViewDataEntry)), parentVisible: _permissions.canViewDataEntry),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 2. STONE TYPES
                          _buildModuleCard(
                            moduleIndex: 2,
                            title: 'Stone Types',
                            icon: Icons.grid_view_rounded,
                            isVisible: _permissions.canViewStoneTypes,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(2, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(2, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canFilterStoneTypes: false,
                              canAdvancedFilterStone: false,
                              canMarkSlabDamagedInStone: false,
                              canQuickRepairSlab: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('Filter Tabs (Available/Unavailable/Damaged)', _permissions.canFilterStoneTypes, (v) => setState(() => _permissions = _permissions.copyWith(canFilterStoneTypes: v, canViewStoneTypes: v ? true : _permissions.canViewStoneTypes)), parentVisible: _permissions.canViewStoneTypes),
                              _permTile('Advanced Stone Filter Button', _permissions.canAdvancedFilterStone, (v) => setState(() => _permissions = _permissions.copyWith(canAdvancedFilterStone: v, canViewStoneTypes: v ? true : _permissions.canViewStoneTypes)), parentVisible: _permissions.canViewStoneTypes),
                              _permTile('Record Damaged Slab Button', _permissions.canMarkSlabDamagedInStone, (v) => setState(() => _permissions = _permissions.copyWith(canMarkSlabDamagedInStone: v, canViewStoneTypes: v ? true : _permissions.canViewStoneTypes)), parentVisible: _permissions.canViewStoneTypes),
                              _permTile('Quick Repair/Restore Slab Button', _permissions.canQuickRepairSlab, (v) => setState(() => _permissions = _permissions.copyWith(canQuickRepairSlab: v, canViewStoneTypes: v ? true : _permissions.canViewStoneTypes)), parentVisible: _permissions.canViewStoneTypes),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 3. CUSTOMER PROFILE
                          _buildModuleCard(
                            moduleIndex: 3,
                            title: 'Customer Profile',
                            icon: Icons.badge_rounded,
                            isVisible: _permissions.canViewCustomerProfile,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(3, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(3, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canAddCustomer: false,
                              canEditCustomer: false,
                              canDeleteCustomer: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('Add New Customer Button', _permissions.canAddCustomer, (v) => setState(() => _permissions = _permissions.copyWith(canAddCustomer: v, canViewCustomerProfile: v ? true : _permissions.canViewCustomerProfile)), parentVisible: _permissions.canViewCustomerProfile),
                              _permTile('Edit Customer Details', _permissions.canEditCustomer, (v) => setState(() => _permissions = _permissions.copyWith(canEditCustomer: v, canViewCustomerProfile: v ? true : _permissions.canViewCustomerProfile)), parentVisible: _permissions.canViewCustomerProfile),
                              _permTile('Delete Customer Record', _permissions.canDeleteCustomer, (v) => setState(() => _permissions = _permissions.copyWith(canDeleteCustomer: v, canViewCustomerProfile: v ? true : _permissions.canViewCustomerProfile)), parentVisible: _permissions.canViewCustomerProfile),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 4. RESERVATIONS
                          _buildModuleCard(
                            moduleIndex: 4,
                            title: 'Reservations',
                            icon: Icons.bookmark_added_rounded,
                            isVisible: _permissions.canViewReservations,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(4, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(4, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canCreateReservation: false,
                              canCancelReservation: false,
                              canConvertReservationToSale: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('New Reservation Button', _permissions.canCreateReservation, (v) => setState(() => _permissions = _permissions.copyWith(canCreateReservation: v, canViewReservations: v ? true : _permissions.canViewReservations)), parentVisible: _permissions.canViewReservations),
                              _permTile('Cancel/Expire Reservation', _permissions.canCancelReservation, (v) => setState(() => _permissions = _permissions.copyWith(canCancelReservation: v, canViewReservations: v ? true : _permissions.canViewReservations)), parentVisible: _permissions.canViewReservations),
                              _permTile('Convert Reservation to Sale', _permissions.canConvertReservationToSale, (v) => setState(() => _permissions = _permissions.copyWith(canConvertReservationToSale: v, canViewReservations: v ? true : _permissions.canViewReservations)), parentVisible: _permissions.canViewReservations),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 5. SALES
                          _buildModuleCard(
                            moduleIndex: 5,
                            title: 'Sales',
                            icon: Icons.point_of_sale_rounded,
                            isVisible: _permissions.canViewSales,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(5, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(5, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canCreateSale: false,
                              canProcessPayment: false,
                              canCancelSale: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('New Sale / Invoice Button', _permissions.canCreateSale, (v) => setState(() => _permissions = _permissions.copyWith(canCreateSale: v, canViewSales: v ? true : _permissions.canViewSales)), parentVisible: _permissions.canViewSales),
                              _permTile('Payment Recording Action', _permissions.canProcessPayment, (v) => setState(() => _permissions = _permissions.copyWith(canProcessPayment: v, canViewSales: v ? true : _permissions.canViewSales)), parentVisible: _permissions.canViewSales),
                              _permTile('Cancel / Refund Sale', _permissions.canCancelSale, (v) => setState(() => _permissions = _permissions.copyWith(canCancelSale: v, canViewSales: v ? true : _permissions.canViewSales)), parentVisible: _permissions.canViewSales),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 6. RETURNS
                          _buildModuleCard(
                            moduleIndex: 6,
                            title: 'Returns',
                            icon: Icons.assignment_return_rounded,
                            isVisible: _permissions.canViewReturns,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(6, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(6, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canCreateReturn: false,
                              canApproveReturn: false,
                              canProcessReturn: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('New Return Button', _permissions.canCreateReturn, (v) => setState(() => _permissions = _permissions.copyWith(canCreateReturn: v, canViewReturns: v ? true : _permissions.canViewReturns)), parentVisible: _permissions.canViewReturns),
                              _permTile('Approve/Reject Return Action', _permissions.canApproveReturn, (v) => setState(() => _permissions = _permissions.copyWith(canApproveReturn: v, canViewReturns: v ? true : _permissions.canViewReturns)), parentVisible: _permissions.canViewReturns),
                              _permTile('Process Restock & Credit', _permissions.canProcessReturn, (v) => setState(() => _permissions = _permissions.copyWith(canProcessReturn: v, canViewReturns: v ? true : _permissions.canViewReturns)), parentVisible: _permissions.canViewReturns),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 7. CATEGORY CHECK
                          _buildModuleCard(
                            moduleIndex: 7,
                            title: 'Category Check',
                            icon: Icons.pie_chart_rounded,
                            isVisible: _permissions.canViewCategoryCheck,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(7, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(7, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canExportCategoryCheck: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('Export Category Report (CSV)', _permissions.canExportCategoryCheck, (v) => setState(() => _permissions = _permissions.copyWith(canExportCategoryCheck: v, canViewCategoryCheck: v ? true : _permissions.canViewCategoryCheck)), parentVisible: _permissions.canViewCategoryCheck),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 8. DATA CHECK
                          _buildModuleCard(
                            moduleIndex: 8,
                            title: 'Data Check',
                            icon: Icons.fact_check_rounded,
                            isVisible: _permissions.canViewDataCheck,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(8, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(8, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canExportDataCheck: false,
                              canEditAuditRecord: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('Export 2 (Audit CSV Button)', _permissions.canExportDataCheck, (v) => setState(() => _permissions = _permissions.copyWith(canExportDataCheck: v, canViewDataCheck: v ? true : _permissions.canViewDataCheck)), parentVisible: _permissions.canViewDataCheck),
                              _permTile('Edit Audit Record Values', _permissions.canEditAuditRecord, (v) => setState(() => _permissions = _permissions.copyWith(canEditAuditRecord: v, canViewDataCheck: v ? true : _permissions.canViewDataCheck)), parentVisible: _permissions.canViewDataCheck),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 9. PRINT LABELS
                          _buildModuleCard(
                            moduleIndex: 9,
                            title: 'Print Labels',
                            icon: Icons.print_rounded,
                            isVisible: _permissions.canViewPrintLabels,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(9, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(9, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canPrintSingleLabel: false,
                              canBatchPrintLabels: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('Print Single Slab Label', _permissions.canPrintSingleLabel, (v) => setState(() => _permissions = _permissions.copyWith(canPrintSingleLabel: v, canViewPrintLabels: v ? true : _permissions.canViewPrintLabels)), parentVisible: _permissions.canViewPrintLabels),
                              _permTile('Batch Print Selected Slabs', _permissions.canBatchPrintLabels, (v) => setState(() => _permissions = _permissions.copyWith(canBatchPrintLabels: v, canViewPrintLabels: v ? true : _permissions.canViewPrintLabels)), parentVisible: _permissions.canViewPrintLabels),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 10. SCAN
                          _buildModuleCard(
                            moduleIndex: 10,
                            title: 'Scan',
                            icon: Icons.qr_code_scanner_rounded,
                            isVisible: _permissions.canViewScan,
                            onToggleVisibility: (v) => setState(() => _permissions = _permissions.toggleModule(10, v)),
                            onSelectAll: () => setState(() => _permissions = _permissions.toggleModule(10, true)),
                            onClearAll: () => setState(() => _permissions = _permissions.copyWith(
                              canOpenCameraScanner: false,
                              canExportScanData: false,
                              canDirectMarkDamagedInScan: false,
                            )),
                            colors: colors,
                            children: [
                              _permTile('Open Camera Button (Fast Scanner)', _permissions.canOpenCameraScanner, (v) => setState(() => _permissions = _permissions.copyWith(canOpenCameraScanner: v, canViewScan: v ? true : _permissions.canViewScan)), parentVisible: _permissions.canViewScan),
                              _permTile('Export Labels (CSV Button)', _permissions.canExportScanData, (v) => setState(() => _permissions = _permissions.copyWith(canExportScanData: v, canViewScan: v ? true : _permissions.canViewScan)), parentVisible: _permissions.canViewScan),
                              _permTile('Mark Damaged Directly in Scan', _permissions.canDirectMarkDamagedInScan, (v) => setState(() => _permissions = _permissions.copyWith(canDirectMarkDamagedInScan: v, canViewScan: v ? true : _permissions.canViewScan)), parentVisible: _permissions.canViewScan),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: colors.border, height: 1),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(color: colors.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Save Changes' : 'Create User', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required int moduleIndex,
    required String title,
    required IconData icon,
    required bool isVisible,
    required ValueChanged<bool> onToggleVisibility,
    required VoidCallback onSelectAll,
    required VoidCallback onClearAll,
    required AppColorsExtension colors,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isVisible ? colors.primary.withAlpha(80) : colors.border,
          width: isVisible ? 1.2 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Icon(icon, color: isVisible ? colors.primary : colors.textDisabled, size: 20),
          title: Row(
            children: [
              Text(
                '$moduleIndex. $title',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isVisible ? colors.textPrimary : colors.textDisabled,
                ),
              ),
              const SizedBox(width: 8),
              if (!isVisible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Hidden',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: colors.error),
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Tab Visibility Checkbox
              Tooltip(
                message: 'Toggle Tab Visibility in Sidebar',
                child: Checkbox(
                  value: isVisible,
                  activeColor: colors.primary,
                  onChanged: (v) => onToggleVisibility(v ?? false),
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sub-Actions & Action Buttons:',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: onSelectAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text('All Actions', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.primary)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onClearAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text('None', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.error)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _permTile(String label, bool value, ValueChanged<bool> onChanged, {bool parentVisible = true}) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final textColor = parentVisible ? context.colors.textPrimary : context.colors.textDisabled;
    return SizedBox(
      width: isMobile ? double.infinity : 240,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Checkbox(
                value: value,
                activeColor: context.colors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => onChanged(v ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
