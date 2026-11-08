import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/category_model.dart';
import '../../core/models/material_item.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';

/// Modal dialog for managing materials (Edit, Delete with safety checks, Transfer slabs).
/// Built identically to CategoryManagerDialog for consistency and power.
class MaterialManagerDialog extends StatefulWidget {
  final CategoryModel? initialCategory;
  final VoidCallback onAddNewMaterial;

  const MaterialManagerDialog({
    super.key,
    this.initialCategory,
    required this.onAddNewMaterial,
  });

  static Future<void> show(
    BuildContext context, {
    CategoryModel? category,
    required VoidCallback onAddNewMaterial,
  }) {
    return AdaptiveDialog.show(
      context: context,
      isDismissible: true,
      builder: (ctx) => MaterialManagerDialog(
        initialCategory: category,
        onAddNewMaterial: onAddNewMaterial,
      ),
    );
  }

  @override
  State<MaterialManagerDialog> createState() => _MaterialManagerDialogState();
}

class _MaterialManagerDialogState extends State<MaterialManagerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategoryFilter = widget.initialCategory!.categoryName;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCategories = appState.categoryModels;

    final filteredMaterials = appState.materials.where((m) {
      // Category filter
      if (_selectedCategoryFilter != null && _selectedCategoryFilter!.isNotEmpty) {
        if (m.categoryId.toLowerCase() != _selectedCategoryFilter!.toLowerCase()) {
          return false;
        }
      }

      // Search query filter
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.materialCode.toLowerCase().contains(q) ||
          m.categoryId.toLowerCase().contains(q) ||
          m.finish.toLowerCase().contains(q) ||
          m.stoneType.toLowerCase().contains(q);
    }).toList();

    // Sort by materialCode ascending
    filteredMaterials.sort((a, b) => a.materialCode.compareTo(b.materialCode));

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final maxH = (mq.size.height - mq.viewInsets.bottom - (isMobile ? 32 : 80)).clamp(360.0, 780.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 740, maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Header ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tune_rounded, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Material Manager',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 16 : 19,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedCategoryFilter != null
                              ? 'Manage materials under $_selectedCategoryFilter'
                              : 'Manage and edit all materials',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // New Material Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: isDark ? const Color(0xFF111418) : Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onAddNewMaterial();
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(
                      isMobile ? 'Add' : 'Add Material',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 14),

              // ── Filter & Search Row ──────────────────────────────────────
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Category Dropdown Filter
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedCategoryFilter,
                        dropdownColor: colors.surface,
                        hint: Text(
                          'All Categories',
                          style: GoogleFonts.inter(fontSize: 12.5, color: colors.textSecondary),
                        ),
                        icon: Icon(Icons.arrow_drop_down_rounded, color: colors.textSecondary, size: 20),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'All Categories (${appState.materials.length})',
                              style: GoogleFonts.inter(fontSize: 12.5, color: colors.textPrimary),
                            ),
                          ),
                          ...allCategories.map((c) {
                            final count = appState.materialsForCategory(c.categoryName).length;
                            return DropdownMenuItem<String?>(
                              value: c.categoryName,
                              child: Text(
                                '${c.categoryName} ($count)',
                                style: GoogleFonts.inter(fontSize: 12.5, color: colors.textPrimary),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryFilter = val;
                          });
                        },
                      ),
                    ),
                  ),

                  // Search Bar
                  Container(
                    height: 40,
                    width: isMobile ? double.infinity : 260,
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 17, color: colors.textDisabled),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _searchQuery = v.trim()),
                            style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search code, name, finish...',
                              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: colors.textDisabled),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.clear_rounded, size: 16, color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),

                  // Total count badge
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${filteredMaterials.length} Materials',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Materials List ───────────────────────────────────────────
              Expanded(
                child: filteredMaterials.isEmpty
                    ? Center(
                        child: Text(
                          'No materials found',
                          style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredMaterials.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final mat = filteredMaterials[index];
                          final slabs = appState.slabsForMaterial(mat.materialCode);
                          final slabCount = slabs.isNotEmpty ? slabs.length : mat.totalSlabs;
                          final double areaSqm = slabs.isNotEmpty
                              ? slabs.fold(0.0, (sum, s) => sum + s.areaSqm)
                              : mat.totalAreaSqm;
                          final isEmpty = slabCount == 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                // Material Thumbnail or Stone Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colors.border),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: mat.imageBytes != null
                                      ? Image.memory(mat.imageBytes!, fit: BoxFit.cover)
                                      : Center(
                                          child: Icon(Icons.layers_rounded, size: 22, color: colors.primary),
                                        ),
                                ),
                                const SizedBox(width: 12),

                                // Code Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(isDark ? 35 : 25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.primary.withAlpha(isDark ? 80 : 60)),
                                  ),
                                  child: Text(
                                    mat.materialCode,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Name & Specs & Stats
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mat.name.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: colors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${mat.categoryId} • ${mat.finish} • ${mat.stoneType}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          color: colors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            isEmpty ? Icons.check_circle_outline_rounded : Icons.grid_view_rounded,
                                            size: 13,
                                            color: isEmpty ? colors.success : colors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isEmpty
                                                ? 'Empty (0 slabs, 0.0 m²)'
                                                : '$slabCount slabs (${areaSqm.toStringAsFixed(1)} m²)',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: isEmpty ? colors.success : colors.textSecondary,
                                              fontWeight: isEmpty ? FontWeight.w500 : FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions: Edit, Delete
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Edit Button
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
                                      tooltip: 'Edit Material',
                                      splashRadius: 18,
                                      onPressed: () => _openEditDialog(context, mat, appState, colors, isDark),
                                    ),
                                    // Delete Button
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, size: 19, color: colors.error),
                                      tooltip: 'Delete Material',
                                      splashRadius: 18,
                                      onPressed: () => _handleDeleteMaterial(context, mat, slabCount, areaSqm, appState, colors, isDark),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Edit Material Dialog
  // ──────────────────────────────────────────────────────────────────────────
  void _openEditDialog(
    BuildContext context,
    MaterialItem mat,
    AppState appState,
    AppColorsExtension colors,
    bool isDark,
  ) {
    final nameCtrl = TextEditingController(text: mat.name);
    final finishCtrl = TextEditingController(text: mat.finish);
    final stoneTypeCtrl = TextEditingController(text: mat.stoneType);
    final refCodeCtrl = TextEditingController(text: mat.referenceCode);
    final erpDescCtrl = TextEditingController(text: mat.erpDescription);
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
                        categoryAndName: '$selectedCategory - ${newName.toUpperCase()}',
                        displayLabel: '$selectedCategory - ${newName.toUpperCase()}',
                        codeAndFinish: '${mat.materialCode} - ${mat.totalAreaSqm.toStringAsFixed(0)}m² - ${finishCtrl.text.trim()}',
                      );

                      appState.updateMaterial(updated);
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

  // ──────────────────────────────────────────────────────────────────────────

  // ──────────────────────────────────────────────────────────────────────────
  // Handle Delete Material with Safety Warnings
  // ──────────────────────────────────────────────────────────────────────────
  void _handleDeleteMaterial(
    BuildContext context,
    MaterialItem mat,
    int slabCount,
    double areaSqm,
    AppState appState,
    AppColorsExtension colors,
    bool isDark,
  ) {
    final hasSlabs = slabCount > 0;

    // Rule 1: If empty (0 slabs), directly confirm & delete
    if (!hasSlabs) {
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

    // Rule 2: Material HAS slabs -> Show Safe Warning Modal (requires typing "Delete")
    _openDeleteConfirmationDialog(context, mat, slabCount, areaSqm, appState, colors, isDark);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Safe Delete: Requires typing "Delete" to permanently delete material + slabs
  // ──────────────────────────────────────────────────────────────────────────
  void _openDeleteConfirmationDialog(
    BuildContext context,
    MaterialItem mat,
    int slabCount,
    double areaSqm,
    AppState appState,
    AppColorsExtension colors,
    bool isDark,
  ) {
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
                      color: colors.error.withAlpha(25),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Material:', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                            Text('${mat.materialCode} - ${mat.name}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Category:', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                            Text(mat.categoryId, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Finish & Type:', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                            Text('${mat.finish} (${mat.stoneType})', style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Slabs:', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                            Text('$slabCount Slabs (${areaSqm.toStringAsFixed(1)} m²)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This action will permanently delete this material along with all $slabCount slabs associated with it. This cannot be undone!',
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
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Type Delete here...',
                      hintStyle: GoogleFonts.inter(color: colors.textDisabled),
                      filled: true,
                      fillColor: colors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.error, width: 1.5)),
                    ),
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
                    backgroundColor: colors.error,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.surfaceVariant,
                    disabledForegroundColor: colors.textDisabled,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: isConfirmed
                      ? () {
                          appState.deleteMaterialCascade(mat);
                          Navigator.pop(delCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Material "${mat.materialCode} - ${mat.name}" and all linked $slabCount slabs were deleted.'),
                              backgroundColor: colors.error,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Delete Material'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
