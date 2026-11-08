import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/category_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';

/// Modal dialog for managing categories (Edit, Delete with safety checks, Transfer).
class CategoryManagerDialog extends StatefulWidget {
  final VoidCallback onAddNewCategory;

  const CategoryManagerDialog({
    super.key,
    required this.onAddNewCategory,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onAddNewCategory}) {
    return AdaptiveDialog.show(
      context: context,
      isDismissible: true,
      builder: (ctx) => CategoryManagerDialog(onAddNewCategory: onAddNewCategory),
    );
  }

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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

    final categories = appState.categoryModels.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.categoryName.toLowerCase().contains(q) ||
          c.categoryCode.toString().contains(q);
    }).toList();

    // Sort by CategoryCode ascending
    categories.sort((a, b) => a.categoryCode.compareTo(b.categoryCode));

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
        constraints: BoxConstraints(maxWidth: 680, maxHeight: maxH),
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
                          'Category Manager',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 16 : 19,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage and edit categories',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // New Category Button (Permission Guarded)
                  if (AuthService.instance.currentPermissions.canAddCategory)
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
                        widget.onAddNewCategory();
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        isMobile ? 'Add' : 'Add Category',
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

              // ── Search & Total Info ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
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
                                hintText: 'Search by code or name...',
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
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(Icons.clear_rounded, size: 16, color: colors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                      '${categories.length} Categories',
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

              // ── Categories List ──────────────────────────────────────────
              Expanded(
                child: categories.isEmpty
                    ? Center(
                        child: Text(
                          'No categories found',
                          style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final cat = categories[index];
                          final mats = appState.materialsForCategory(cat.categoryName);
                          final slabsCount = appState.totalSlabsForCategory(cat.categoryName);
                          final areaSqm = appState.totalAreaSqmForCategory(cat.categoryName);
                          final isEmpty = mats.isEmpty && slabsCount == 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                // Code Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(isDark ? 35 : 25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.primary.withAlpha(isDark ? 80 : 60)),
                                  ),
                                  child: Text(
                                    '${cat.categoryCode}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Name & Stats
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cat.categoryName,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: colors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            isEmpty ? Icons.check_circle_outline_rounded : Icons.layers_outlined,
                                            size: 13,
                                            color: isEmpty ? colors.success : colors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isEmpty
                                                ? 'Empty (0 materials, 0 slabs)'
                                                : '${mats.length} materials • $slabsCount slabs (${areaSqm.toStringAsFixed(1)} m²)',
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

                                // Actions: Edit & Delete (Permission Guarded)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Edit Button
                                    if (AuthService.instance.currentPermissions.canManageCategories)
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
                                        tooltip: 'Edit Category Name',
                                        splashRadius: 18,
                                        onPressed: () => _openEditDialog(context, cat, appState, colors, isDark),
                                      ),
                                    // Delete Button
                                    if (AuthService.instance.currentPermissions.canManageCategories)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded, size: 19, color: colors.error),
                                        tooltip: 'Delete Category',
                                        splashRadius: 18,
                                        onPressed: () => _handleDeleteCategory(context, cat, mats.length, slabsCount, appState, colors, isDark),
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
  // Edit Category Dialog
  // ──────────────────────────────────────────────────────────────────────────
  void _openEditDialog(
    BuildContext context,
    CategoryModel cat,
    AppState appState,
    AppColorsExtension colors,
    bool isDark,
  ) {
    final nameCtrl = TextEditingController(text: cat.categoryName);

    showDialog(
      context: context,
      builder: (editCtx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Edit Category ${cat.categoryCode}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: colors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CategoryCode: ${cat.categoryCode} (Auto-assigned)',
                style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'CategoryName',
                  labelStyle: GoogleFonts.inter(color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                ),
              ),
            ],
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
                  appState.renameCategory(cat, newName);
                  Navigator.pop(editCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated category to "$newName"'),
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
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Handle Delete with Safety Warnings
  // ──────────────────────────────────────────────────────────────────────────
  void _handleDeleteCategory(
    BuildContext context,
    CategoryModel cat,
    int materialCount,
    int slabCount,
    AppState appState,
    AppColorsExtension colors,
    bool isDark,
  ) {
    final hasContents = materialCount > 0 || slabCount > 0;

    // Rule 1: If empty, directly confirm & delete
    if (!hasContents) {
      showDialog(
        context: context,
        builder: (confirmCtx) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Delete Category ${cat.categoryCode}?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: colors.textPrimary),
          ),
          content: Text(
            'This category has no materials or slabs.\nAre you sure you want to delete "${cat.categoryName}"?',
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
                appState.deleteCategoryEmpty(cat);
                Navigator.pop(confirmCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "${cat.categoryName}" was deleted.'),
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

    // Rule 2: Category HAS materials or slabs -> Show Warning Modal (requires typing "Delete")
    _openDeleteConfirmationDialog(context, cat, materialCount, slabCount, appState, colors, isDark);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Safe Delete: Requires typing "Delete" to permanently delete category + items
  // ──────────────────────────────────────────────────────────────────────────
  void _openDeleteConfirmationDialog(
    BuildContext context,
    CategoryModel cat,
    int materialCount,
    int slabCount,
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
                      'Delete Category ${cat.categoryCode}?',
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
                            Text('Category:', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                            Text('${cat.categoryName} (${cat.categoryCode})', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Materials:', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                            Text('$materialCount Materials', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Slabs:', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                            Text('$slabCount Slabs', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This action will permanently delete this category along with all $materialCount materials and $slabCount slabs associated with it. This cannot be undone!',
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
                          appState.deleteCategoryCascade(cat);
                          Navigator.pop(delCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Category "${cat.categoryName}" and all linked materials and slabs were deleted.'),
                              backgroundColor: colors.error,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Delete Category'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
