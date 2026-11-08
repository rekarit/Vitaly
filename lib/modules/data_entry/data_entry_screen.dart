import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/category_model.dart';
import '../../core/models/material_item.dart';
import '../../core/models/slab.dart';
import '../../core/mock/mock_data.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import 'material_form_dialog.dart';
import 'slab_form_dialog.dart';
import 'rack_detail_dialog.dart';
import 'data_entry_filter_dialog.dart';
import 'category_manager_dialog.dart';
import 'material_manager_dialog.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/stone_image_widget.dart';

class DataEntryScreen extends StatefulWidget {
  const DataEntryScreen({super.key});
  static final GlobalKey<DataEntryScreenState> globalKey = GlobalKey<DataEntryScreenState>();
  static String? pendingMaterialCode;

  static void openMaterialDetail({required String materialCode, String? slabNo}) {
    pendingMaterialCode = materialCode;
    if (globalKey.currentState != null) {
      globalKey.currentState!.selectMaterialByCode(materialCode, slabNo: slabNo);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalKey.currentState?.selectMaterialByCode(materialCode, slabNo: slabNo);
    });
  }

  @override
  State<DataEntryScreen> createState() => DataEntryScreenState();
}

class DataEntryScreenState extends State<DataEntryScreen> {
  CategoryModel? _selectedCategory;
  MaterialItem? _selectedMaterial;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final DataEntryFilter _categoryFilter = DataEntryFilter();
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DataEntryScreen.pendingMaterialCode != null) {
        selectMaterialByCode(DataEntryScreen.pendingMaterialCode!);
        DataEntryScreen.pendingMaterialCode = null;
      }
    });
  }

  void selectMaterialByCode(String inputCode, {String? slabNo}) {
    final appState = AppStateScope.read(context);
    String query = inputCode.trim();

    // 1. Check if query is a URL with ?material=
    if (query.contains('?')) {
      final uri = Uri.tryParse(query.startsWith('http') ? query : 'https://$query');
      if (uri != null) {
        query = uri.queryParameters['material'] ?? uri.queryParameters['mat'] ?? query;
      }
    }

    // 2. Direct match or alias via AppState materialById
    MaterialItem? mat = appState.materialById(query);

    // 3. If not found directly, check if query is a slabNo / inventoryId / QR in slabs
    if (mat == null) {
      final slab = appState.slabs.where((s) =>
          s.slabNo.toLowerCase() == query.toLowerCase() ||
          (s.inventoryId != null && s.inventoryId!.toLowerCase() == query.toLowerCase()) ||
          (s.customQrData != null && s.customQrData!.toLowerCase() == query.toLowerCase()) ||
          s.qrCode.toLowerCase() == query.toLowerCase() ||
          s.id.toLowerCase() == query.toLowerCase()).firstOrNull;
      if (slab != null) {
        mat = appState.materialById(slab.materialId);
      }
    }

    // 4. If query has a hyphen e.g. "1202-01" or "1202 - CRISTALLO TIFFANY", extract prefix e.g. "1202"
    if (mat == null && query.contains('-')) {
      final prefix = query.split('-').first.trim();
      mat = appState.materialById(prefix);
    }

    // 5. Fallback check to master catalog
    if (mat == null) {
      final master = MockData.masterMaterials.where((m) =>
          m.materialCode.toLowerCase() == query.toLowerCase() ||
          m.id.toLowerCase() == query.toLowerCase() ||
          (query.contains('-') && m.materialCode.toLowerCase() == query.split('-').first.trim().toLowerCase())).firstOrNull;
      if (master != null) {
        appState.addMaterial(master);
        mat = master;
      }
    }

    // 6. If STILL not found but looks like a material code (e.g. 1202), auto-create under the right category!
    if (mat == null) {
      final cleanCode = query.contains('-') ? query.split('-').first.trim() : query;
      final parsedInt = int.tryParse(cleanCode);
      if (parsedInt != null && cleanCode.length >= 3) {
        // Derive category code from first 2 digits e.g. 12 from 1202
        final catCode = int.tryParse(cleanCode.substring(0, 2)) ?? 12;
        final targetCat = appState.categoryModels.firstWhere(
          (c) => c.categoryCode == catCode,
          orElse: () => appState.categoryModels.first,
        );
        final created = MaterialItem(
          id: cleanCode,
          materialCode: cleanCode,
          name: 'Material $cleanCode',
          categoryId: targetCat.categoryName,
          categoryCode: targetCat.categoryCode,
          finish: 'Polish',
          stoneType: targetCat.categoryName.split('/').first.trim(),
        );
        appState.addMaterial(created);
        mat = created;
      }
    }

    if (mat != null) {
      final foundMat = mat;
      final cat = appState.categoryModelByName(foundMat.categoryId) ??
          appState.categoryModels.firstWhere(
            (c) => c.categoryCode == foundMat.categoryCode,
            orElse: () => CategoryModel(categoryCode: foundMat.categoryCode, categoryName: foundMat.categoryId),
          );
      setState(() {
        _selectedCategory = cat;
        _selectedMaterial = foundMat;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Categories Form Dialog
  // Only CategoryCode and CategoryName are editable.
  // All other fields are read-only / auto-calculated by the system.
  // ──────────────────────────────────────────────────────────────────────────
  // Categories Form Dialog
  // CategoryCode is auto-sequenced and non-editable (read-only).
  // CategoryName is editable.
  // RBAC permissions are now handled via user roles/permissions directly
  Future<void> _requirePermission(VoidCallback onAuthorized, {String actionTitle = ''}) async {
    final perms = AuthService.instance.currentPermissions;
    if (actionTitle == 'New Material' && !perms.canAddMaterial) {
      _showPermissionDeniedDialog('You do not have permission to add new materials.');
      return;
    }
    if (actionTitle == 'New Category' && !perms.canAddCategory) {
      _showPermissionDeniedDialog('You do not have permission to add new categories.');
      return;
    }
    if (actionTitle == 'Material Manager' && (!perms.canManageCategories && !perms.canAddMaterial && !perms.canEditMaterial && !perms.canDeleteMaterial)) {
      _showPermissionDeniedDialog('You do not have permission to access Material Manager.');
      return;
    }
    if (actionTitle == 'Category Manager' && !perms.canManageCategories) {
      _showPermissionDeniedDialog('You do not have permission to access Category Manager.');
      return;
    }
    onAuthorized();
  }

  void _showPermissionDeniedDialog(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _openCategoriesFormDialog() {
    final appState = AppStateScope.read(context);

    // Auto-sequence next integer code (e.g. 19, then 20, etc.)
    final nextCode = appState.nextCategoryCode;

    // Controllers
    final codeCtrl = TextEditingController(text: '$nextCode');
    final nameCtrl = TextEditingController();

    AdaptiveDialog.show(
      context: context,
      isDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final colors = context.colors;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBtnTextColor = isDark ? const Color(0xFF111418) : Colors.white;

            final mq = MediaQuery.of(dialogCtx);
            final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - (context.isMobile ? 16 : 48)).clamp(220.0, 780.0);

            return Dialog(
              backgroundColor: colors.surface,
              insetPadding: context.isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.border),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, maxHeight: availableHeight),
                child: Padding(
                  padding: EdgeInsets.all(context.isMobile ? 16 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.close, color: colors.textSecondary),
                                  onPressed: () => Navigator.pop(ctx),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Categories Form',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: context.isMobile ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.textSecondary,
                                  side: BorderSide(color: colors.border),
                                  padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 10 : 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: dialogBtnTextColor,
                                  padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 14 : 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                ),
                                onPressed: () => _saveCategoryFromDialog(
                                  codeCtrl: codeCtrl,
                                  nameCtrl: nameCtrl,
                                  dialogCtx: ctx,
                                ),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: colors.border, height: 1),
                      const SizedBox(height: 16),

                      // Form Body: Only CategoryCode (read-only auto-sequence) and CategoryName (autoFocus)
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDialogField(
                                label: 'CategoryCode*',
                                controller: codeCtrl,
                                isReadOnly: true,
                                isRequired: true,
                                helperText: 'Auto-sequence generated code (non-editable)',
                                colors: colors,
                              ),
                              const SizedBox(height: 16),
                              _buildDialogField(
                                label: 'CategoryName',
                                controller: nameCtrl,
                                isReadOnly: false,
                                autoFocus: true,
                                isRequired: true,
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: dialogBtnTextColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => _saveCategoryFromDialog(
                          codeCtrl: codeCtrl,
                          nameCtrl: nameCtrl,
                          dialogCtx: ctx,
                        ),
                        child: Text(
                          'Save Category',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _saveCategoryFromDialog({
    required TextEditingController codeCtrl,
    required TextEditingController nameCtrl,
    required BuildContext dialogCtx,
  }) {
    final colors = context.colors;
    final codeInt = int.tryParse(codeCtrl.text.trim());
    final name = nameCtrl.text.trim();

    if (codeInt == null || codeInt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid CategoryCode'),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('CategoryName is required'),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    final catModel = CategoryModel(
      categoryCode: codeInt,
      categoryName: name,
      categoryHeader: '$name - $codeInt',
    );

    // Persist permanently into AppState
    final appState = AppStateScope.read(context);
    appState.addCategoryModel(catModel);

    setState(() {
      _selectedCategory = catModel;
    });

    Navigator.pop(dialogCtx);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Category "$name" ($codeInt) added successfully.'),
        backgroundColor: colors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDialogField({
    required String label,
    required TextEditingController controller,
    required AppColorsExtension colors,
    bool isReadOnly = false,
    bool isRequired = false,
    bool autoFocus = false,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                text: label.endsWith('*') ? label.substring(0, label.length - 1) : label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isReadOnly ? colors.textDisabled : colors.textSecondary,
                ),
                children: label.endsWith('*')
                    ? [
                        TextSpan(
                          text: '*',
                          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                        )
                      ]
                    : [],
              ),
            ),
            if (isReadOnly)
              Text(
                'Read-Only',
                style: GoogleFonts.inter(fontSize: 10, color: colors.textDisabled),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isReadOnly
                ? colors.surfaceVariant.withValues(alpha: 0.35)
                : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isReadOnly
                  ? colors.border.withValues(alpha: 0.5)
                  : colors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            readOnly: isReadOnly,
            autofocus: autoFocus,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: GoogleFonts.inter(
              color: isReadOnly ? colors.textSecondary : colors.textPrimary,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (helperText != null && isReadOnly) ...[
          const SizedBox(height: 3),
          Text(
            helperText,
            style: GoogleFonts.inter(fontSize: 10, color: colors.textDisabled),
          ),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Main Data Entry Screen Body
  // Switches between Categories Grid and Category Detail ("Related Materials")
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBtnTextColor = isDark ? const Color(0xFF111418) : Colors.white;

    // If a material is selected, render Material Slab View ("Related StoneInventorys")
    if (_selectedMaterial != null) {
      return _buildMaterialSlabView(appState, colors);
    }

    // If a category is selected, render Category Detail View with "Related Materials"
    if (_selectedCategory != null) {
      return _buildCategoryDetailView(appState, colors);
    }

    // Otherwise render the Categories Grid
    final filteredCategories = appState.categoryModels.where((cat) {
      if (!_categoryFilter.matchesCategoryWithState(cat, appState)) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return cat.categoryName.toLowerCase().contains(q) ||
          cat.categoryCode.toString().contains(q) ||
          cat.categoryHeader.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // Header Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.screenPadding, 24, context.screenPadding, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Data Entry',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Inventory hierarchy',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (AuthService.instance.currentPermissions.canFilterCategories)
                            _buildCategoryFilterButton(colors, isDark, appState),
                          if (AuthService.instance.currentPermissions.canManageCategories)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.tune_rounded, size: 17),
                              label: const Text('Category Manager', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.border),
                                padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 12 : 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _requirePermission(
                                () => CategoryManagerDialog.show(
                                  context,
                                  onAddNewCategory: () => _requirePermission(_openCategoriesFormDialog, actionTitle: 'New Category'),
                                ),
                                actionTitle: 'Category Manager',
                              ),
                            ),
                          if (AuthService.instance.currentPermissions.canAddCategory)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('New Category', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: primaryBtnTextColor,
                                padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 14 : 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () => _requirePermission(_openCategoriesFormDialog, actionTitle: 'New Category'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (_categoryFilter.isActive) ...[
                    const SizedBox(height: 14),
                    _buildActiveCategoryFilterChips(colors, isDark),
                  ],
                  const SizedBox(height: 20),

                  // Search Box and Count Badge
                  if (context.isMobile) ...[
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 18, color: colors.textDisabled),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                              onChanged: (val) => setState(() => _searchQuery = val.trim()),
                              decoration: InputDecoration(
                                hintText: 'Search categories...',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(Icons.clear, size: 16, color: colors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${filteredCategories.length} Categories',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        _buildViewModeToggle(colors, isDark),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.search, size: 18, color: colors.textDisabled),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                    decoration: InputDecoration(
                                      hintText: 'Search categories by name or code...',
                                      hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: Icon(Icons.clear, size: 16, color: colors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${filteredCategories.length} Categories',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // View Mode Toggle (Grid vs List)
                        _buildViewModeToggle(colors, isDark),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Categories Grid / List View
          if (filteredCategories.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 48, color: colors.textDisabled),
                    const SizedBox(height: 12),
                    Text(
                      'No categories found',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Click "+ New Category" to create a new category.',
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else if (_isGridView)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(context.screenPadding, 8, context.screenPadding, 36),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: context.responsiveValue(mobile: 500, tablet: 380, desktop: 380),
                  mainAxisExtent: 175,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = filteredCategories[index];
                    final totalSlabs = appState.totalSlabsForCategory(cat.categoryName);
                    final totalArea = appState.totalAreaSqmForCategory(cat.categoryName);

                    return _buildCategoryCard(
                      category: cat,
                      totalSlabs: totalSlabs,
                      totalAreaSqm: totalArea,
                      colors: colors,
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    );
                  },
                  childCount: filteredCategories.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(context.screenPadding, 8, context.screenPadding, 36),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = filteredCategories[index];
                    final totalSlabs = appState.totalSlabsForCategory(cat.categoryName);
                    final totalArea = appState.totalAreaSqmForCategory(cat.categoryName);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCategoryListItem(
                        category: cat,
                        totalSlabs: totalSlabs,
                        totalAreaSqm: totalArea,
                        colors: colors,
                        isDark: isDark,
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      ),
                    );
                  },
                  childCount: filteredCategories.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Category Detail View (Matching Attached Photo 2 & Photo 4)
  // Shows CategoryHeader, CategoryStock, and "Related Materials" subsection
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryDetailView(dynamic appState, AppColorsExtension colors) {
    final cat = _selectedCategory!;
    final totalSlabs = appState.totalSlabsForCategory(cat.categoryName);
    final totalArea = appState.totalAreaSqmForCategory(cat.categoryName);
    final relatedMaterials = appState.materialsForCategory(cat.categoryName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBtnTextColor = isDark ? const Color(0xFF111418) : Colors.white;

    return Scaffold(
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(context.screenPadding, 20, context.screenPadding, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation Bar with Back Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.textPrimary),
                        onPressed: () {
                          setState(() {
                            _selectedCategory = null;
                          });
                        },
                        tooltip: 'Back to Categories',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: context.isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (AuthService.instance.currentPermissions.canManageCategories || AuthService.instance.currentPermissions.canAddMaterial || AuthService.instance.currentPermissions.canEditMaterial)
                      IconButton(
                        icon: Icon(Icons.layers_outlined, color: colors.textSecondary, size: 21),
                        tooltip: 'Material Manager',
                        onPressed: () => _requirePermission(
                          () => MaterialManagerDialog.show(
                            context,
                            category: cat,
                            onAddNewMaterial: () => _requirePermission(() => _openMaterialFormDialog(cat), actionTitle: 'New Material'),
                          ),
                          actionTitle: 'Material Manager',
                        ),
                      ),
                    if (AuthService.instance.currentPermissions.canManageCategories) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.tune_rounded, color: colors.textSecondary, size: 20),
                        tooltip: 'Category Manager',
                        onPressed: () => _requirePermission(
                          () => CategoryManagerDialog.show(
                            context,
                            onAddNewCategory: () => _requirePermission(_openCategoriesFormDialog, actionTitle: 'New Category'),
                          ),
                          actionTitle: 'Category Manager',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: colors.border, height: 1),
            const SizedBox(height: 20),

            // Category Info Section (Matching Photo 2)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CategoryHeader',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cat.categoryName} - ${cat.categoryCode}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'CategoryStock',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalSlabs > 0
                        ? '${totalArea.toStringAsFixed(0)} sqm - $totalSlabs slabs'
                        : '0 sqm - 0 slabs',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Subsection: "Related Materials" (Matching AppSheet Photo 3 & 4)
            if (context.isMobile) ...[
              Row(
                children: [
                  Text(
                    'Related Materials',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      '${relatedMaterials.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (AuthService.instance.currentPermissions.canAddMaterial || AuthService.instance.currentPermissions.canManageCategories || AuthService.instance.currentPermissions.canEditMaterial) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (AuthService.instance.currentPermissions.canAddMaterial)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('New Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: primaryBtnTextColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => _requirePermission(() => _openMaterialFormDialog(cat), actionTitle: 'New Material'),
                        ),
                      ),
                    if (AuthService.instance.currentPermissions.canManageCategories || AuthService.instance.currentPermissions.canEditMaterial) ...[
                      if (AuthService.instance.currentPermissions.canAddMaterial) const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('Manager', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _requirePermission(
                          () => MaterialManagerDialog.show(
                            context,
                            category: cat,
                            onAddNewMaterial: () => _requirePermission(() => _openMaterialFormDialog(cat), actionTitle: 'New Material'),
                          ),
                          actionTitle: 'Material Manager',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ] else ...[
              Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Related Materials',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          '${relatedMaterials.length}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (AuthService.instance.currentPermissions.canManageCategories || AuthService.instance.currentPermissions.canEditMaterial)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Material Manager', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _requirePermission(
                            () => MaterialManagerDialog.show(
                              context,
                              category: cat,
                              onAddNewMaterial: () => _requirePermission(() => _openMaterialFormDialog(cat), actionTitle: 'New Material'),
                            ),
                            actionTitle: 'Material Manager',
                          ),
                        ),
                      if (AuthService.instance.currentPermissions.canAddMaterial)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('New Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: primaryBtnTextColor,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => _requirePermission(() => _openMaterialFormDialog(cat), actionTitle: 'New Material'),
                        ),
                    ],
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Materials Structure List (Matching AppSheet Photo 3)
            if (relatedMaterials.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.layers_outlined, size: 44, color: colors.textDisabled),
                    const SizedBox(height: 12),
                    Text(
                      'No Materials under "${cat.categoryName}" yet',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Click "+ New Material" above to add materials under this category.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: relatedMaterials.length,
                separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
                itemBuilder: (ctx, i) {
                  final MaterialItem mat = relatedMaterials[i];
                  final matSlabs = appState.slabsForMaterial(mat.materialCode);
                  final double matArea = matSlabs.isNotEmpty
                      ? matSlabs.fold(0.0, (s, sl) => s + sl.areaSqm)
                      : mat.totalAreaSqm;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMaterial = mat;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: colors.surfaceVariant.withValues(alpha: 0.5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      child: Row(
                        children: [
                          // Left Thumbnail with Master Stone Photo
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: StoneImageWidget(
                              material: mat,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              enablePreviewOnTap: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${mat.materialCode} - ${matArea.toStringAsFixed(0)}m² - ${mat.finish}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${cat.categoryName} - ${mat.name.toUpperCase()}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: colors.textDisabled.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openMaterialFormDialog(CategoryModel cat) async {
    final result = await MaterialFormDialog.show(context, cat);
    if (result != null) {
      setState(() {});
    }
  }

  void _openSlabFormDialog(MaterialItem mat) async {
    final result = await SlabFormDialog.show(context, mat);
    if (result != null) {
      setState(() {
        final updatedMat = AppStateScope.read(context).materialById(mat.id) ??
            AppStateScope.read(context).materialById(mat.materialCode);
        if (updatedMat != null) {
          _selectedMaterial = updatedMat;
        }
      });
    }
  }

  void _cycleMaterial(int delta) {
    if (_selectedCategory == null || _selectedMaterial == null) return;
    final appState = AppStateScope.read(context);
    final mats = appState.materialsForCategory(_selectedCategory!.categoryName);
    if (mats.isEmpty) return;
    final currentIndex = mats.indexWhere((m) => m.id == _selectedMaterial!.id);
    if (currentIndex == -1) return;
    final newIndex = (currentIndex + delta) % mats.length;
    final validIndex = newIndex < 0 ? mats.length - 1 : newIndex;
    setState(() {
      _selectedMaterial = mats[validIndex];
    });
  }

  void _openEditMaterialDialog(MaterialItem mat) {
    final appState = AppStateScope.read(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameCtrl = TextEditingController(text: mat.name);
    final finishCtrl = TextEditingController(text: mat.finish);
    final stoneTypeCtrl = TextEditingController(text: mat.stoneType);
    final refCodeCtrl = TextEditingController(text: mat.referenceCode);
    final erpDescCtrl = TextEditingController(text: mat.erpDescription);
    final imageUrlCtrl = TextEditingController(text: mat.imageUrl ?? '');
    Uint8List? editImageBytes = mat.imageBytes;
    String selectedCategory = mat.categoryId;

    final categories = appState.categoryModels;

    showDialog(
      context: context,
      builder: (editCtx) {
        return StatefulBuilder(
          builder: (ctx, setInnerState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.border),
              ),
              title: Text(
                'Edit Material ${mat.materialCode}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: colors.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MaterialCode: ${mat.materialCode} (Unique Key)',
                      style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    // Material Name
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'MaterialName*',
                        labelStyle: GoogleFonts.inter(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: categories.any((c) => c.categoryName == selectedCategory)
                          ? selectedCategory
                          : (categories.isNotEmpty ? categories.first.categoryName : null),
                      dropdownColor: colors.surface,
                      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Category*',
                        labelStyle: GoogleFonts.inter(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.categoryName,
                          child: Text('${c.categoryName} (${c.categoryCode})'),
                        );
                      }).toList(),
                      onChanged: (newCat) {
                        if (newCat != null) {
                          setInnerState(() {
                            selectedCategory = newCat;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Finish
                    TextField(
                      controller: finishCtrl,
                      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Finish (e.g. Polish, Honed, Leather)',
                        labelStyle: GoogleFonts.inter(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stone Type
                    TextField(
                      controller: stoneTypeCtrl,
                      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'StoneType',
                        labelStyle: GoogleFonts.inter(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reference Code
                    TextField(
                      controller: refCodeCtrl,
                      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'ReferenceCode',
                        labelStyle: GoogleFonts.inter(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ERP Description
                    TextField(
                      controller: erpDescCtrl,
                      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'ERP Description',
                        labelStyle: GoogleFonts.inter(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Master Image URL / Upload
                    TextField(
                      controller: imageUrlCtrl,
                      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Master Stone Image URL',
                        labelStyle: GoogleFonts.inter(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.upload_file, size: 20),
                          tooltip: 'Upload Image File',
                          onPressed: () async {
                            final files = await FilePicker.pickFiles(type: FileType.image);
                            if (files.isNotEmpty) {
                              final bytes = await files.first.readAsBytes();
                              setInnerState(() {
                                editImageBytes = bytes;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(editCtx),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: isDark ? const Color(0xFF111418) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final newName = nameCtrl.text.trim();
                    if (newName.isNotEmpty) {
                      final targetCatModel = appState.categoryModelByName(selectedCategory);
                      final catCode = targetCatModel?.categoryCode ?? mat.categoryCode;
                      final updated = mat.copyWith(
                        name: newName,
                        categoryId: selectedCategory,
                        categoryCode: catCode,
                        finish: finishCtrl.text.trim().isNotEmpty ? finishCtrl.text.trim() : mat.finish,
                        stoneType: stoneTypeCtrl.text.trim().isNotEmpty ? stoneTypeCtrl.text.trim() : mat.stoneType,
                        referenceCode: refCodeCtrl.text.trim().isNotEmpty ? refCodeCtrl.text.trim() : mat.referenceCode,
                        erpDescription: erpDescCtrl.text.trim(),
                        imageUrl: imageUrlCtrl.text.trim().isNotEmpty ? imageUrlCtrl.text.trim() : mat.imageUrl,
                        imageBytes: editImageBytes,
                        categoryAndName: '$selectedCategory - ${newName.toUpperCase()}',
                        displayLabel: '$selectedCategory - ${newName.toUpperCase()}',
                        codeAndFinish: '${mat.materialCode} - ${mat.totalAreaSqm.toStringAsFixed(0)}m² - ${finishCtrl.text.trim()}',
                      );

                      appState.updateMaterial(updated);
                      setState(() {
                        _selectedMaterial = updated;
                      });
                      Navigator.pop(editCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Updated material "${mat.materialCode} - $newName"'),
                          backgroundColor: colors.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleDeleteMaterialFromView(MaterialItem mat, int slabCount, double areaSqm) {
    final appState = AppStateScope.read(context);
    final colors = context.colors;

    if (slabCount == 0) {
      showDialog(
        context: context,
        builder: (confirmCtx) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Delete Material ${mat.materialCode}?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: colors.textPrimary),
          ),
          content: Text(
            'This material has no slabs recorded.\nAre you sure you want to delete "${mat.materialCode} - ${mat.name}"?',
            style: GoogleFonts.inter(fontSize: 13.5, color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              onPressed: () {
                appState.deleteMaterialEmpty(mat);
                Navigator.pop(confirmCtx);
                setState(() {
                  _selectedMaterial = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Material "${mat.materialCode} - ${mat.name}" was deleted.'),
                    backgroundColor: colors.error,
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      return;
    }

    final deleteTextCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (delCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isConfirmed = deleteTextCtrl.text.trim().toLowerCase() == 'delete';

            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.border),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: colors.error, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delete Material ${mat.materialCode}?',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: colors.error),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action will permanently delete "${mat.materialCode} - ${mat.name}" along with all $slabCount slabs (${areaSqm.toStringAsFixed(1)} m²) associated with it.',
                    style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'To confirm deletion, please type "Delete" below:',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: deleteTextCtrl,
                    autofocus: true,
                    style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Type Delete',
                      hintStyle: GoogleFonts.inter(color: colors.textDisabled),
                      filled: true,
                      fillColor: colors.surfaceVariant,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.error)),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(delCtx),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirmed ? colors.error : colors.textDisabled,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  onPressed: isConfirmed
                      ? () {
                          appState.deleteMaterialCascade(mat);
                          Navigator.pop(delCtx);
                          setState(() {
                            _selectedMaterial = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Material "${mat.materialCode} - ${mat.name}" and all $slabCount slabs were deleted.'),
                              backgroundColor: colors.error,
                            ),
                          );
                        }
                      : null,
                  child: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSlabThumbnail(Slab slab, MaterialItem mat, AppColorsExtension colors) {
    return StoneImageWidget(
      material: mat,
      imageUrl: (slab.photoUrl != null && slab.photoUrl!.isNotEmpty) ? slab.photoUrl : mat.imageUrl,
      imageBytes: slab.photoBytes ?? mat.imageBytes,
      fit: BoxFit.cover,
      enablePreviewOnTap: true,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Material Slab View (Matching AppSheet Photos 1 & 2)
  // Shows breadcrumb tabs, material info card, and "Related StoneInventorys"
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMaterialSlabView(dynamic appState, AppColorsExtension colors) {
    final mat = appState.materialById(_selectedMaterial!.id) ??
        appState.materialById(_selectedMaterial!.materialCode) ??
        _selectedMaterial!;
    final cat = _selectedCategory ??
        appState.categoryModelByName(mat.categoryId) ??
        CategoryModel(categoryCode: mat.categoryCode, categoryName: mat.categoryId);
    final slabs = appState.slabsForMaterial(mat.materialCode);
    final totalArea = slabs.isNotEmpty
        ? slabs.fold(0.0, (sum, s) => sum + s.areaSqm)
        : mat.totalAreaSqm;
    final totalCount = slabs.isNotEmpty ? slabs.length : mat.totalSlabs;
    final availCount = slabs.where((s) => s.status == SlabStatus.available).length;
    final soldOrUnavailCount = slabs.where((s) => s.status == SlabStatus.unavailable || s.status == SlabStatus.sold || s.status == SlabStatus.reserved).length;
    final damagedCount = slabs.where((s) => s.status == SlabStatus.damaged).length;
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(context.screenPadding, 20, context.screenPadding, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Breadcrumb / Tabs Bar (Matching Photo 1) ─────────────
            if (isMobile) ...[
              // Mobile Responsive Top Bar: Clean Breadcrumbs + Action Bar
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMaterial = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            cat.categoryName,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${mat.materialCode} - ${mat.name.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMaterial = null;
                              });
                            },
                            child: Icon(Icons.close, size: 16, color: colors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (AuthService.instance.currentPermissions.canAddSlab)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('Add Slab', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF86B9E0),
                          foregroundColor: const Color(0xFF111418),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => _openSlabFormDialog(mat),
                      ),
                    ),
                  if (AuthService.instance.currentPermissions.canManageCategories || AuthService.instance.currentPermissions.canAddMaterial || AuthService.instance.currentPermissions.canEditMaterial) ...[
                    if (AuthService.instance.currentPermissions.canAddSlab) const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Manager', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _requirePermission(
                        () => MaterialManagerDialog.show(
                          context,
                          category: cat,
                          onAddNewMaterial: () => _requirePermission(() => _openMaterialFormDialog(cat), actionTitle: 'New Material'),
                        ),
                        actionTitle: 'Material Manager',
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: colors.surfaceVariant,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, size: 18, color: colors.textSecondary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
                          onPressed: () => _cycleMaterial(-1),
                          tooltip: 'Previous Material',
                        ),
                        VerticalDivider(color: colors.border, width: 1),
                        IconButton(
                          icon: Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
                          onPressed: () => _cycleMaterial(1),
                          tooltip: 'Next Material',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Breadcrumb Tab Bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Inactive Category Tab
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedMaterial = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Text(
                            cat.categoryName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      // Active Material Tab with Close 'X'
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${mat.materialCode} - ${mat.name.toUpperCase()}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMaterial = null;
                                });
                              },
                              child: Icon(Icons.close, size: 16, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Top Right Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (AuthService.instance.currentPermissions.canManageCategories || AuthService.instance.currentPermissions.canAddMaterial || AuthService.instance.currentPermissions.canEditMaterial)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Material Manager', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _requirePermission(
                            () => MaterialManagerDialog.show(
                              context,
                              category: cat,
                              onAddNewMaterial: () => _requirePermission(() => _openMaterialFormDialog(cat), actionTitle: 'New Material'),
                            ),
                            actionTitle: 'Material Manager',
                          ),
                        ),
                      if (AuthService.instance.currentPermissions.canEditMaterial) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit Material', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _openEditMaterialDialog(mat),
                        ),
                      ],
                      if (AuthService.instance.currentPermissions.canDeleteMaterial) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: Icon(Icons.delete_outline_rounded, size: 15, color: colors.error),
                          label: Text('Delete Material', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colors.error)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                            side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _handleDeleteMaterialFromView(mat, slabs.length, totalArea),
                        ),
                      ],
                      if (AuthService.instance.currentPermissions.canAddSlab) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Slab', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF86B9E0), // Matching AppSheet Blue button in Photo 1
                            foregroundColor: const Color(0xFF111418),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          onPressed: () => _openSlabFormDialog(mat),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left, size: 18, color: colors.textSecondary),
                              padding: EdgeInsets.zero,
                              onPressed: () => _cycleMaterial(-1),
                              tooltip: 'Previous Material',
                            ),
                            VerticalDivider(color: colors.border, width: 1),
                            IconButton(
                              icon: Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
                              padding: EdgeInsets.zero,
                              onPressed: () => _cycleMaterial(1),
                              tooltip: 'Next Material',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            Divider(color: colors.border, height: 1),
            const SizedBox(height: 20),

            // ── Material Header Details Card (Matching Photo 1) ──────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master Stone Image Banner with tap-to-preview
                  if (mat.imageBytes != null || (mat.imageUrl != null && mat.imageUrl!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: isMobile ? 140 : 180,
                          width: double.infinity,
                          color: colors.surfaceVariant,
                          child: StoneImageWidget(
                            material: mat,
                            height: isMobile ? 140 : 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            enablePreviewOnTap: true,
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mat.name.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mat.stoneType,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Card Direct Action Buttons (Edit & Delete for Admins)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (AuthService.instance.currentPermissions.canEditMaterial)
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 20, color: colors.primary),
                              tooltip: 'Edit Material (${mat.materialCode})',
                              onPressed: () => _openEditMaterialDialog(mat),
                            ),
                          if (AuthService.instance.currentPermissions.canDeleteMaterial)
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 20, color: colors.error),
                              tooltip: 'Delete Material (${mat.materialCode})',
                              onPressed: () => _handleDeleteMaterialFromView(mat, slabs.length, totalArea),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${totalArea.toStringAsFixed(2)} sqm • $totalCount slabs',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Live Stock Availability Breakdown (Available, Sold/Unavailable, Damaged)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 5),
                            Text(
                              'Available: $availCount',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64748B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.do_not_disturb_on_rounded, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 5),
                            Text(
                              'Sold / Unavailable: $soldOrUnavailCount',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_rounded, size: 14, color: Color(0xFFEA580C)),
                            const SizedBox(width: 5),
                            Text(
                              'Damaged: $damagedCount',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: colors.border, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MaterialCode',
                              style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              mat.materialCode,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Finish',
                              style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              mat.finish,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Related StoneInventorys Subsection (Matching Photo 2) ────
            Row(
              children: [
                Text(
                  'Related StoneInventorys',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    '${slabs.length}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Slabs List
            if (slabs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 44, color: colors.textDisabled),
                    const SizedBox(height: 12),
                    Text(
                      'No slabs recorded for ${mat.name.toUpperCase()} yet',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Click "Add Slab" above to record the first slab.',
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: slabs.length,
                separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
                itemBuilder: (ctx, i) {
                  final Slab slab = slabs[i];
                  final double lCm = slab.lengthCm > 0 ? slab.lengthCm : (slab.lengthMm / 10.0);
                  final double wCm = slab.widthCm > 0 ? slab.widthCm : (slab.widthMm / 10.0);
                  final String lStr = lCm % 1 == 0 ? lCm.toInt().toString() : lCm.toStringAsFixed(1);
                  final String wStr = wCm % 1 == 0 ? wCm.toInt().toString() : wCm.toStringAsFixed(1);

                  return InkWell(
                    onTap: () => _showSlabDetailDialog(slab, mat),
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: colors.surfaceVariant.withValues(alpha: 0.5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      child: Row(
                        children: [
                          // Left Thumbnail / Auto-linked Slab Photo from Material
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildSlabThumbnail(slab, mat, colors),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Line 1: CALACATTA GOLD - 1201-03 - 5m²
                                Text(
                                  '${mat.name.toUpperCase()} - ${slab.slabNo} - ${slab.areaSqm.round()}m²',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Line 2: 234.4×234.4 cm (20mm) · 5.49 sqm
                                Text(
                                  '$lStr×$wStr cm (${slab.thicknessMm.round()}mm) · ${slab.areaSqm.toStringAsFixed(2)} sqm',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // QR Code Preview Badge Button
                          IconButton(
                            icon: Icon(Icons.qr_code_2_rounded, size: 22, color: colors.textSecondary),
                            onPressed: () => _showSlabDetailDialog(slab, mat),
                            tooltip: 'View QR Code',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSlabDetailDialog(Slab slab, MaterialItem mat) {
    final colors = context.colors;
    AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final appState = AppStateScope.of(context);
            // Fetch the latest state of this slab if updated
            final currentSlab = appState.slabs.cast<Slab?>().firstWhere(
                  (s) => s?.id == slab.id,
                  orElse: () => slab,
                ) ?? slab;

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF1B1D21) : colors.surface;
            final headerBorder = isDark ? Colors.white12 : colors.border;
            final closeIconColor = isDark ? Colors.white70 : colors.textSecondary;

            final mq = MediaQuery.of(dialogCtx);
            final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - (context.isMobile ? 16 : 48)).clamp(220.0, 850.0);

            return Dialog(
              backgroundColor: dialogBg,
              insetPadding: context.isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.border),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, maxHeight: availableHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header (Matching Screenshot 1: [MaterialName...] [Delete] | < > ⤢ ✕) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${mat.name.toUpperCase()}...',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          // Delete Button (Permission Guarded)
                          if (AuthService.instance.currentPermissions.canDeleteSlab)
                            OutlinedButton.icon(
                              icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
                              label: Text('Delete', style: TextStyle(color: colors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: colors.error.withValues(alpha: 0.4)),
                                backgroundColor: colors.error.withValues(alpha: 0.08),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: colors.surface,
                                    title: Text('Delete Slab', style: TextStyle(color: colors.textPrimary)),
                                    content: Text(
                                      'Are you sure you want to delete slab "${currentSlab.slabNo}"?',
                                      style: TextStyle(color: colors.textSecondary),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: colors.error),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  final appState = AppStateScope.read(context);
                                  appState.deleteSlab(currentSlab.id);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                }
                              },
                            ),
                          const SizedBox(width: 8),
                          // Close button
                          IconButton(
                            icon: Icon(Icons.close, size: 20, color: closeIconColor),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: headerBorder, height: 1),

                    // ── Action Buttons Row (Edit & Copy SlabNo) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          // Edit Button (Permission Guarded)
                          if (AuthService.instance.currentPermissions.canEditSlab) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final updated = await SlabFormDialog.show(
                                    context,
                                    mat,
                                    initialSlab: currentSlab,
                                  );
                                  if (updated != null) {
                                    setDialogState(() {});
                                  }
                                },
                                icon: Icon(Icons.edit_outlined, size: 16, color: colors.primary),
                                label: Text(
                                  'Edit',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: colors.border),
                                  backgroundColor: isDark ? const Color(0xFF22252B) : const Color(0xFFF8F9FA),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          // Copy SlabNo Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: currentSlab.slabNo));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('SlabNo ${currentSlab.slabNo} copied to clipboard!'),
                                    backgroundColor: colors.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: Icon(Icons.copy_rounded, size: 16, color: colors.primary),
                              label: Text(
                                'Copy SlabNo',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: colors.border),
                                backgroundColor: isDark ? const Color(0xFF22252B) : const Color(0xFFF8F9FA),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: headerBorder, height: 1),

                    // ── Scrollable Details & QR Section ───────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SlabNo
                            _buildAppSheetDetailItem('SlabNo', currentSlab.slabNo),
                            const SizedBox(height: 16),

                            // MaterialCode
                            _buildAppSheetDetailItem(
                              'MaterialCode',
                              '${mat.materialCode} - ${mat.name.toUpperCase()}',
                              leadingIcon: Icons.warning_amber_rounded,
                            ),
                            const SizedBox(height: 16),

                            // StoneType
                            _buildAppSheetDetailItem('StoneType', mat.stoneType),
                            const SizedBox(height: 16),

                            // Finish
                            _buildAppSheetDetailItem('Finish', mat.finish),
                            const SizedBox(height: 16),

                            // Length_cm
                            _buildAppSheetDetailItem(
                              'Length_cm',
                              (currentSlab.lengthCm > 0
                                  ? (currentSlab.lengthCm % 1 == 0
                                      ? currentSlab.lengthCm.toInt().toString()
                                      : currentSlab.lengthCm.toStringAsFixed(1))
                                  : ((currentSlab.lengthMm / 10.0) % 1 == 0
                                      ? (currentSlab.lengthMm / 10.0).toInt().toString()
                                      : (currentSlab.lengthMm / 10.0).toStringAsFixed(1))),
                            ),
                            const SizedBox(height: 16),

                            // Width_cm
                            _buildAppSheetDetailItem(
                              'Width_cm',
                              (currentSlab.widthCm > 0
                                  ? (currentSlab.widthCm % 1 == 0
                                      ? currentSlab.widthCm.toInt().toString()
                                      : currentSlab.widthCm.toStringAsFixed(1))
                                  : ((currentSlab.widthMm / 10.0) % 1 == 0
                                      ? (currentSlab.widthMm / 10.0).toInt().toString()
                                      : (currentSlab.widthMm / 10.0).toStringAsFixed(1))),
                            ),
                            const SizedBox(height: 16),

                            // Thickness_mm
                            _buildAppSheetDetailItem(
                              'Thickness_mm',
                              currentSlab.thicknessMm.round().toString(),
                            ),
                            const SizedBox(height: 16),

                            // Area_sqm
                            _buildAppSheetDetailItem(
                              'Area_sqm',
                              currentSlab.areaSqm.toStringAsFixed(2),
                            ),
                            const SizedBox(height: 16),

                            // RackCode (Clickable drilldown matching Screenshot 3 & 4)
                            InkWell(
                              onTap: () {
                                final appState = AppStateScope.read(context);
                                final rack = appState.rackByCode(currentSlab.warehouseLocation);
                                RackDetailDialog.show(context, rack);
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: _buildAppSheetDetailItem(
                                  'RackCode',
                                  currentSlab.warehouseLocation,
                                  trailingIcon: Icons.chevron_right,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Status
                            _buildAppSheetDetailItem('Status', 'In Stock'),
                            const SizedBox(height: 16),

                            // Slab / Material Photo (Auto-linked)
                            Text(
                              'Photo',
                              style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 160,
                                width: double.infinity,
                                color: colors.surfaceVariant,
                                child: _buildSlabThumbnail(currentSlab, mat, colors),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // QRCodeImage & InventoryID (Matching Screenshot 2)
                            Text(
                              'QRCodeImage',
                              style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: currentSlab.qrCode,
                                version: QrVersions.auto,
                                size: 140,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // InventoryID
                            _buildAppSheetDetailItem(
                              'InventoryID',
                              currentSlab.inventoryId ?? (currentSlab.customQrData ?? currentSlab.qrCode),
                              colors: colors,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppSheetDetailItem(
    String label,
    String value, {
    IconData? leadingIcon,
    IconData? trailingIcon,
    AppColorsExtension? colors,
  }) {
    final activeColors = colors ?? context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: activeColors.textSecondary),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 18, color: activeColors.textSecondary),
                  const SizedBox(width: 8),
                ],
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: activeColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, size: 20, color: activeColors.textSecondary),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Spacious Category Grid Card
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryCard({
    required CategoryModel category,
    required int totalSlabs,
    required double totalAreaSqm,
    required AppColorsExtension colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: colors.surfaceVariant.withValues(alpha: 0.6),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Code Badge & Folder Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'Code: ${category.categoryCode}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.folder_open_rounded,
                    size: 20,
                    color: colors.textDisabled,
                  ),
                ],
              ),

              // Middle: Category Name & Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.categoryName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.categoryName} - ${category.categoryCode}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Bottom Stats Badge (Auto-Calculated sqm and slabs count, starts at 0 sqm - 0 slabs)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.grid_on_rounded,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          totalSlabs > 0
                              ? '${totalAreaSqm.toStringAsFixed(0)} sqm - $totalSlabs slabs'
                              : '0 sqm - 0 slabs',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: colors.textDisabled,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryListItem({
    required CategoryModel category,
    required int totalSlabs,
    required double totalAreaSqm,
    required AppColorsExtension colors,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              // Code Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'Code: ${category.categoryCode}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Folder Icon
              Icon(Icons.folder_open_rounded, size: 22, color: colors.primary),
              const SizedBox(width: 14),

              // Category Name & Header
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.categoryName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category.categoryName} - ${category.categoryCode}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Stock summary badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_on_rounded, size: 14, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      totalSlabs > 0
                          ? '${totalAreaSqm.toStringAsFixed(0)} sqm - $totalSlabs slabs'
                          : '0 sqm - 0 slabs',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Arrow
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle(AppColorsExtension colors, bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grid
          InkWell(
            onTap: () => setState(() => _isGridView = true),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isGridView ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: _isGridView
                        ? (isDark ? const Color(0xFF111418) : Colors.white)
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Grid',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: _isGridView ? FontWeight.bold : FontWeight.w500,
                      color: _isGridView
                          ? (isDark ? const Color(0xFF111418) : Colors.white)
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          // List
          InkWell(
            onTap: () => setState(() => _isGridView = false),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: !_isGridView ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.view_list_rounded,
                    size: 16,
                    color: !_isGridView
                        ? (isDark ? const Color(0xFF111418) : Colors.white)
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'List',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: !_isGridView ? FontWeight.bold : FontWeight.w500,
                      color: !_isGridView
                          ? (isDark ? const Color(0xFF111418) : Colors.white)
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Category Filter Dialog & Chips
  // ---------------------------------------------------------------------------

  Widget _buildCategoryFilterButton(AppColorsExtension colors, bool isDark, AppState appState) {
    final bool active = _categoryFilter.isActive;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCategoryFilterDialog(appState),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? colors.primary : colors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: active ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.w600,
                  color: active ? colors.primary : colors.textSecondary,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_categoryFilter.activeFilterCount}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF111418) : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCategoryFilterChips(AppColorsExtension colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_outlined, size: 14, color: colors.primary),
              const SizedBox(width: 4),
              Text(
                'Active Filters:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          if (_categoryFilter.stockStatus != null && _categoryFilter.stockStatus != 'all')
            _buildFilterTag(
              label: _categoryFilter.stockStatus == 'inStock'
                  ? 'In Stock (>0)'
                  : 'Empty (0 Slabs)',
              onDeleted: () => setState(() => _categoryFilter.stockStatus = 'all'),
              colors: colors,
            ),
          if (_categoryFilter.stoneType != null)
            _buildFilterTag(
              label: 'Type: ${_categoryFilter.stoneType}',
              onDeleted: () => setState(() => _categoryFilter.stoneType = null),
              colors: colors,
            ),
          if (_categoryFilter.finish != null)
            _buildFilterTag(
              label: 'Finish: ${_categoryFilter.finish}',
              onDeleted: () => setState(() => _categoryFilter.finish = null),
              colors: colors,
            ),
          if (_categoryFilter.rackLocation != null)
            _buildFilterTag(
              label: 'Rack: ${_categoryFilter.rackLocation}',
              onDeleted: () => setState(() => _categoryFilter.rackLocation = null),
              colors: colors,
            ),
          if (_categoryFilter.origin != null)
            _buildFilterTag(
              label: 'Origin: ${_categoryFilter.origin}',
              onDeleted: () => setState(() => _categoryFilter.origin = null),
              colors: colors,
            ),
          if (_categoryFilter.minSlabs != null)
            _buildFilterTag(
              label: '≥ ${_categoryFilter.minSlabs} Slabs',
              onDeleted: () => setState(() => _categoryFilter.minSlabs = null),
              colors: colors,
            ),
          if (_categoryFilter.minAreaSqm != null)
            _buildFilterTag(
              label: '≥ ${_categoryFilter.minAreaSqm!.toStringAsFixed(1)} m²',
              onDeleted: () => setState(() => _categoryFilter.minAreaSqm = null),
              colors: colors,
            ),
          InkWell(
            onTap: () => setState(() => _categoryFilter.reset()),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                'Clear All',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.error,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTag({
    required String label,
    required VoidCallback onDeleted,
    required AppColorsExtension colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            child: Icon(Icons.close, size: 13, color: colors.primary),
          ),
        ],
      ),
    );
  }

  Future<void> _openCategoryFilterDialog(AppState appState) async {
    final categoryExtractedStoneTypes = appState.categoryModels
        .map((c) => c.categoryName.contains('/') ? c.categoryName.split('/').first.trim() : c.categoryName.trim())
        .where((s) => s.isNotEmpty && s.length <= 25);

    final availableStoneTypes = {
      ...appState.materials.map((m) => m.stoneType).where((s) => s.isNotEmpty),
      ...categoryExtractedStoneTypes,
    }.toList()
      ..sort();

    final availableFinishes = appState.materials
        .map((m) => m.finish)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final availableRacks = appState.racks
        .map((r) => r.rackCode)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final availableOrigins = appState.materials
        .map((m) => m.origin)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final res = await DataEntryFilterDialog.show(
      context,
      currentFilter: _categoryFilter,
      allCategories: appState.categoryModels,
      stoneTypes: availableStoneTypes,
      finishes: availableFinishes,
      racks: availableRacks,
      origins: availableOrigins,
      appState: appState,
    );

    if (res != null) {
      setState(() {
        _categoryFilter.stockStatus = res.stockStatus;
        _categoryFilter.stoneType = res.stoneType;
        _categoryFilter.finish = res.finish;
        _categoryFilter.rackLocation = res.rackLocation;
        _categoryFilter.origin = res.origin;
        _categoryFilter.minAreaSqm = res.minAreaSqm;
        _categoryFilter.maxAreaSqm = res.maxAreaSqm;
        _categoryFilter.minSlabs = res.minSlabs;
        _categoryFilter.maxSlabs = res.maxSlabs;
      });
    }
  }
}
