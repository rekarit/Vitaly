import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/category_model.dart';
import '../../core/models/material_item.dart';
import '../../core/models/slab.dart';
import '../../core/theme/app_theme.dart';

/// Filter state holding all customizable dimensions and attributes for Data Entry
class DataEntryFilter {
  String? stockStatus; // 'all', 'inStock', 'empty'
  String? stoneType;
  String? finish;
  String? rackLocation;
  String? origin;
  double? minAreaSqm;
  double? maxAreaSqm;
  int? minSlabs;
  int? maxSlabs;

  bool get isActive =>
      (stockStatus != null && stockStatus != 'all') ||
      stoneType != null ||
      finish != null ||
      rackLocation != null ||
      origin != null ||
      minAreaSqm != null ||
      maxAreaSqm != null ||
      minSlabs != null ||
      maxSlabs != null;

  int get activeCount {
    int c = 0;
    if (stockStatus != null && stockStatus != 'all') c++;
    if (stoneType != null) c++;
    if (finish != null) c++;
    if (rackLocation != null) c++;
    if (origin != null) c++;
    if (minAreaSqm != null || maxAreaSqm != null) c++;
    if (minSlabs != null || maxSlabs != null) c++;
    return c;
  }

  int get activeFilterCount => activeCount;

  bool matchesCategoryWithState(CategoryModel category, dynamic appState) {
    final totalSlabs = appState.totalSlabsForCategory(category.categoryName) as int;
    final totalAreaSqm = appState.totalAreaSqmForCategory(category.categoryName) as double;
    final materials = appState.materialsForCategory(category.categoryName) as List<MaterialItem>;
    final allCategorySlabs = <Slab>[];
    for (final m in materials) {
      allCategorySlabs.addAll(appState.slabsForMaterial(m.materialCode) as List<Slab>);
    }
    return matchesCategory(
      category: category,
      totalSlabs: totalSlabs,
      totalAreaSqm: totalAreaSqm,
      materials: materials,
      allCategorySlabs: allCategorySlabs,
    );
  }

  void reset() {
    stockStatus = null;
    stoneType = null;
    finish = null;
    rackLocation = null;
    origin = null;
    minAreaSqm = null;
    maxAreaSqm = null;
    minSlabs = null;
    maxSlabs = null;
  }

  DataEntryFilter clone() {
    return DataEntryFilter()
      ..stockStatus = stockStatus
      ..stoneType = stoneType
      ..finish = finish
      ..rackLocation = rackLocation
      ..origin = origin
      ..minAreaSqm = minAreaSqm
      ..maxAreaSqm = maxAreaSqm
      ..minSlabs = minSlabs
      ..maxSlabs = maxSlabs;
  }

  bool matchesCategory({
    required CategoryModel category,
    required int totalSlabs,
    required double totalAreaSqm,
    required List<MaterialItem> materials,
    required List<Slab> allCategorySlabs,
  }) {
    if (stockStatus == 'inStock' && totalSlabs <= 0) return false;
    if (stockStatus == 'empty' && totalSlabs > 0) return false;

    if (minSlabs != null && totalSlabs < minSlabs!) return false;
    if (maxSlabs != null && totalSlabs > maxSlabs!) return false;

    if (minAreaSqm != null && totalAreaSqm < minAreaSqm!) return false;
    if (maxAreaSqm != null && totalAreaSqm > maxAreaSqm!) return false;

    if (stoneType != null) {
      final qType = stoneType!.toLowerCase();
      final hasType = materials.any((m) => m.stoneType.toLowerCase() == qType) ||
          category.categoryName.toLowerCase().contains(qType);
      if (!hasType) return false;
    }

    if (finish != null) {
      final qFinish = finish!.toLowerCase();
      final hasFinish = materials.any((m) => m.finish.toLowerCase() == qFinish);
      if (!hasFinish) return false;
    }

    if (origin != null) {
      final qOrigin = origin!.toLowerCase();
      final hasOrigin = materials.any((m) => m.origin.toLowerCase().contains(qOrigin));
      if (!hasOrigin) return false;
    }

    if (rackLocation != null) {
      final qRack = rackLocation!.toLowerCase();
      final hasRack = allCategorySlabs.any((s) => s.warehouseLocation.toLowerCase() == qRack);
      if (!hasRack) return false;
    }

    return true;
  }
}

/// Ultra-Modern Sliding Drawer Filter Panel for Data Entry Screen
class DataEntryFilterDialog extends StatefulWidget {
  final DataEntryFilter currentFilter;
  final List<CategoryModel> allCategories;
  final List<String> stoneTypes;
  final List<String> finishes;
  final List<String> racks;
  final List<String> origins;
  final dynamic appState;

  const DataEntryFilterDialog({
    super.key,
    required this.currentFilter,
    required this.allCategories,
    required this.stoneTypes,
    required this.finishes,
    required this.racks,
    required this.origins,
    required this.appState,
  });

  static Future<DataEntryFilter?> show(
    BuildContext context, {
    required DataEntryFilter currentFilter,
    required List<CategoryModel> allCategories,
    required List<String> stoneTypes,
    required List<String> finishes,
    required List<String> racks,
    required List<String> origins,
    required dynamic appState,
  }) {
    return showGeneralDialog<DataEntryFilter>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Filter',
      barrierColor: Colors.black.withAlpha(140),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: DataEntryFilterDialog(
              currentFilter: currentFilter,
              allCategories: allCategories,
              stoneTypes: stoneTypes,
              finishes: finishes,
              racks: racks,
              origins: origins,
              appState: appState,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<DataEntryFilterDialog> createState() => _DataEntryFilterDialogState();
}

class _DataEntryFilterDialogState extends State<DataEntryFilterDialog> {
  late DataEntryFilter _filter;
  late TextEditingController _minSlabsCtrl;
  late TextEditingController _maxSlabsCtrl;
  late TextEditingController _minAreaCtrl;
  late TextEditingController _maxAreaCtrl;

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter.clone();
    _minSlabsCtrl = TextEditingController(text: _filter.minSlabs?.toString() ?? '');
    _maxSlabsCtrl = TextEditingController(text: _filter.maxSlabs?.toString() ?? '');
    _minAreaCtrl = TextEditingController(text: _filter.minAreaSqm?.toStringAsFixed(0) ?? '');
    _maxAreaCtrl = TextEditingController(text: _filter.maxAreaSqm?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _minSlabsCtrl.dispose();
    _maxSlabsCtrl.dispose();
    _minAreaCtrl.dispose();
    _maxAreaCtrl.dispose();
    super.dispose();
  }

  int _calculateMatchingCategoriesCount() {
    int count = 0;
    for (final cat in widget.allCategories) {
      final totalSlabs = widget.appState.totalSlabsForCategory(cat.categoryName) as int;
      final totalArea = widget.appState.totalAreaSqmForCategory(cat.categoryName) as double;
      final mats = widget.appState.materialsForCategory(cat.categoryName) as List<MaterialItem>;
      final slabs = <Slab>[];
      for (final m in mats) {
        slabs.addAll(widget.appState.slabsForMaterial(m.materialCode));
      }

      if (_filter.matchesCategory(
        category: cat,
        totalSlabs: totalSlabs,
        totalAreaSqm: totalArea,
        materials: mats,
        allCategorySlabs: slabs,
      )) {
        count++;
      }
    }
    return count;
  }

  void _resetAllFilters() {
    setState(() {
      _filter.reset();
      _minSlabsCtrl.clear();
      _maxSlabsCtrl.clear();
      _minAreaCtrl.clear();
      _maxAreaCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final drawerWidth = isMobile ? mediaQuery.size.width : (mediaQuery.size.width > 700 ? 500.0 : mediaQuery.size.width * 0.9);
    final matchingCount = _calculateMatchingCategoriesCount();

    final cardBg = isDark ? const Color(0xFF16191E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF1F232B) : const Color(0xFFF8FAFC);

    return Container(
      width: drawerWidth,
      height: mediaQuery.size.height,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 140 : 45),
            blurRadius: 36,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withAlpha(60),
                          colors.primary.withAlpha(20),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.primary.withAlpha(80)),
                    ),
                    child: Icon(Icons.tune_rounded, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Filter Categories',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (_filter.isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_filter.activeCount}',
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
                        const SizedBox(height: 2),
                        Text(
                          'Filter by stock status, types, locations & volume',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_filter.isActive)
                    TextButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded, size: 15),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _resetAllFilters,
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 20),
                    tooltip: 'Close',
                    splashRadius: 18,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Active Filters Quick Strip ─────────────────────────────────
            if (_filter.isActive) _buildActiveFiltersQuickStrip(colors, isDark),

            // ── Scrollable Body ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Stock Status Segment
                    _buildSectionContainer(
                      title: 'Stock Availability Status',
                      icon: Icons.inventory_2_outlined,
                      cardBg: cardBg,
                      colors: colors,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModernSegment(
                              label: 'All Categories',
                              icon: Icons.apps_rounded,
                              isSelected: _filter.stockStatus == null || _filter.stockStatus == 'all',
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.stockStatus = 'all'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModernSegment(
                              label: 'In Stock',
                              subLabel: '> 0 Slabs',
                              statusDotColor: const Color(0xFF10B981),
                              icon: Icons.check_circle_outline_rounded,
                              isSelected: _filter.stockStatus == 'inStock',
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.stockStatus = 'inStock'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModernSegment(
                              label: 'Empty',
                              subLabel: '0 Slabs',
                              statusDotColor: const Color(0xFFF59E0B),
                              icon: Icons.remove_circle_outline_rounded,
                              isSelected: _filter.stockStatus == 'empty',
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.stockStatus = 'empty'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Stone Types (Only if available)
                    if (widget.stoneTypes.isNotEmpty) ...[
                      _buildSectionContainer(
                        title: 'Stone Types Included',
                        badgeText: _filter.stoneType,
                        icon: Icons.terrain_rounded,
                        cardBg: cardBg,
                        colors: colors,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPillChip(
                              label: 'All Types',
                              icon: Icons.all_inclusive_rounded,
                              isSelected: _filter.stoneType == null,
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.stoneType = null),
                            ),
                            ...widget.stoneTypes.map((type) {
                              return _buildPillChip(
                                label: type,
                                isSelected: _filter.stoneType == type,
                                colors: colors,
                                isDark: isDark,
                                onTap: () => setState(() => _filter.stoneType = type),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 3. Surface Finish (Only if finishes exist)
                    if (widget.finishes.isNotEmpty) ...[
                      _buildSectionContainer(
                        title: 'Surface Finish',
                        badgeText: _filter.finish,
                        icon: Icons.auto_awesome_rounded,
                        cardBg: cardBg,
                        colors: colors,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPillChip(
                              label: 'All Finishes',
                              icon: Icons.all_inclusive_rounded,
                              isSelected: _filter.finish == null,
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.finish = null),
                            ),
                            ...widget.finishes.map((f) {
                              return _buildPillChip(
                                label: f,
                                isSelected: _filter.finish == f,
                                colors: colors,
                                isDark: isDark,
                                onTap: () => setState(() => _filter.finish = f),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 4. Warehouse Rack Location
                    if (widget.racks.isNotEmpty) ...[
                      _buildSectionContainer(
                        title: 'Warehouse & Storage Location',
                        badgeText: _filter.rackLocation,
                        icon: Icons.warehouse_rounded,
                        cardBg: cardBg,
                        colors: colors,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPillChip(
                              label: 'All Locations',
                              icon: Icons.grid_view_rounded,
                              isSelected: _filter.rackLocation == null,
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.rackLocation = null),
                            ),
                            ...widget.racks.map((rack) {
                              return _buildPillChip(
                                label: rack,
                                icon: Icons.inventory_2_outlined,
                                isSelected: _filter.rackLocation == rack,
                                colors: colors,
                                isDark: isDark,
                                onTap: () => setState(() => _filter.rackLocation = rack),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 5. Volume & Quantity Filters
                    _buildSectionContainer(
                      title: 'Stock Volume & Quantity',
                      icon: Icons.bar_chart_rounded,
                      cardBg: cardBg,
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Slabs count quick presets
                          Text(
                            'Quick Presets:',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildPresetChip('Any Count', _filter.minSlabs == null && _filter.maxSlabs == null, () {
                                setState(() {
                                  _filter.minSlabs = null;
                                  _filter.maxSlabs = null;
                                  _minSlabsCtrl.clear();
                                  _maxSlabsCtrl.clear();
                                });
                              }, colors, isDark),
                              _buildPresetChip('> 10 Slabs', _filter.minSlabs == 10 && _filter.maxSlabs == null, () {
                                setState(() {
                                  _filter.minSlabs = 10;
                                  _filter.maxSlabs = null;
                                  _minSlabsCtrl.text = '10';
                                  _maxSlabsCtrl.clear();
                                });
                              }, colors, isDark),
                              _buildPresetChip('> 50 Slabs', _filter.minSlabs == 50 && _filter.maxSlabs == null, () {
                                setState(() {
                                  _filter.minSlabs = 50;
                                  _filter.maxSlabs = null;
                                  _minSlabsCtrl.text = '50';
                                  _maxSlabsCtrl.clear();
                                });
                              }, colors, isDark),
                              _buildPresetChip('> 100 Slabs', _filter.minSlabs == 100 && _filter.maxSlabs == null, () {
                                setState(() {
                                  _filter.minSlabs = 100;
                                  _filter.maxSlabs = null;
                                  _minSlabsCtrl.text = '100';
                                  _maxSlabsCtrl.clear();
                                });
                              }, colors, isDark),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(color: colors.border.withAlpha(80), height: 1),
                          const SizedBox(height: 14),

                          // Slabs Custom Range
                          _buildModernRangeRow(
                            label: 'Total Slabs',
                            unit: 'slabs',
                            icon: Icons.layers_outlined,
                            minCtrl: _minSlabsCtrl,
                            maxCtrl: _maxSlabsCtrl,
                            inputBg: inputBg,
                            colors: colors,
                            onMinChanged: (v) => setState(() => _filter.minSlabs = int.tryParse(v)),
                            onMaxChanged: (v) => setState(() => _filter.maxSlabs = int.tryParse(v)),
                          ),
                          const SizedBox(height: 12),

                          // Area Custom Range
                          _buildModernRangeRow(
                            label: 'Total Area',
                            unit: 'm²',
                            icon: Icons.square_foot_rounded,
                            minCtrl: _minAreaCtrl,
                            maxCtrl: _maxAreaCtrl,
                            inputBg: inputBg,
                            colors: colors,
                            onMinChanged: (v) => setState(() => _filter.minAreaSqm = double.tryParse(v)),
                            onMaxChanged: (v) => setState(() => _filter.maxAreaSqm = double.tryParse(v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 6. Country of Origin
                    if (widget.origins.isNotEmpty) ...[
                      _buildSectionContainer(
                        title: 'Country of Origin',
                        badgeText: _filter.origin,
                        icon: Icons.public_rounded,
                        cardBg: cardBg,
                        colors: colors,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPillChip(
                              label: 'All Countries',
                              icon: Icons.all_inclusive_rounded,
                              isSelected: _filter.origin == null,
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.origin = null),
                            ),
                            ...widget.origins.map((country) {
                              return _buildPillChip(
                                label: country,
                                isSelected: _filter.origin == country,
                                colors: colors,
                                isDark: isDark,
                                onTap: () => setState(() => _filter.origin = country),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),

            // ── Sticky Footer with Live Matching Counter ──────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 15),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: matchingCount > 0 ? const Color(0xFF10B981) : colors.error,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (matchingCount > 0 ? const Color(0xFF10B981) : colors.error).withAlpha(120),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$matchingCount Categories Matching',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 12.5 : 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Out of ${widget.allCategories.length} Total in Database',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      'Apply Filters',
                      style: GoogleFonts.inter(fontSize: isMobile ? 12 : 13.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: isDark ? const Color(0xFF111418) : Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context, _filter),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active Filters Quick Strip ──────────────────────────────────────────────
  Widget _buildActiveFiltersQuickStrip(AppColorsExtension colors, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 25 : 15),
        border: Border(bottom: BorderSide(color: colors.primary.withAlpha(isDark ? 60 : 40))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Active:',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.primary),
            ),
            const SizedBox(width: 8),
            if (_filter.stockStatus != null && _filter.stockStatus != 'all')
              _buildActiveFilterTag(
                'Stock: ${_filter.stockStatus == 'inStock' ? 'In Stock' : 'Empty'}',
                () => setState(() => _filter.stockStatus = 'all'),
                colors,
              ),
            if (_filter.stoneType != null)
              _buildActiveFilterTag(
                'Type: ${_filter.stoneType}',
                () => setState(() => _filter.stoneType = null),
                colors,
              ),
            if (_filter.finish != null)
              _buildActiveFilterTag(
                'Finish: ${_filter.finish}',
                () => setState(() => _filter.finish = null),
                colors,
              ),
            if (_filter.rackLocation != null)
              _buildActiveFilterTag(
                'Location: ${_filter.rackLocation}',
                () => setState(() => _filter.rackLocation = null),
                colors,
              ),
            if (_filter.minSlabs != null || _filter.maxSlabs != null)
              _buildActiveFilterTag(
                'Slabs: ${_filter.minSlabs ?? 0}..${_filter.maxSlabs ?? '∞'}',
                () => setState(() {
                  _filter.minSlabs = null;
                  _filter.maxSlabs = null;
                  _minSlabsCtrl.clear();
                  _maxSlabsCtrl.clear();
                }),
                colors,
              ),
            if (_filter.minAreaSqm != null || _filter.maxAreaSqm != null)
              _buildActiveFilterTag(
                'Area: ${_filter.minAreaSqm?.toStringAsFixed(0) ?? '0'}..${_filter.maxAreaSqm?.toStringAsFixed(0) ?? '∞'} m²',
                () => setState(() {
                  _filter.minAreaSqm = null;
                  _filter.maxAreaSqm = null;
                  _minAreaCtrl.clear();
                  _maxAreaCtrl.clear();
                }),
                colors,
              ),
            if (_filter.origin != null)
              _buildActiveFilterTag(
                'Origin: ${_filter.origin}',
                () => setState(() => _filter.origin = null),
                colors,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterTag(String label, VoidCallback onClear, AppColorsExtension colors) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.primary.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(10),
            child: Icon(Icons.close_rounded, size: 13, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  Widget _buildSectionContainer({
    required String title,
    String? badgeText,
    required IconData icon,
    required Color cardBg,
    required AppColorsExtension colors,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.primary.withAlpha(80)),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildModernSegment({
    required String label,
    String? subLabel,
    Color? statusDotColor,
    required IconData icon,
    required bool isSelected,
    required AppColorsExtension colors,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withAlpha(isDark ? 45 : 30)
              : (isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (statusDotColor != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: statusDotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ] else ...[
                  Icon(icon, size: 14, color: isSelected ? colors.primary : colors.textSecondary),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? colors.primary : colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (subLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? colors.primary.withAlpha(200) : colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPillChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required AppColorsExtension colors,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withAlpha(isDark ? 45 : 30)
              : (isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 13, color: colors.primary),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(icon, size: 13, color: colors.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.primary : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    AppColorsExtension colors,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withAlpha(35) : (isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? colors.primary : colors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colors.primary : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildModernRangeRow({
    required String label,
    required String unit,
    required IconData icon,
    required TextEditingController minCtrl,
    required TextEditingController maxCtrl,
    required Color inputBg,
    required AppColorsExtension colors,
    required ValueChanged<String> onMinChanged,
    required ValueChanged<String> onMaxChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: colors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              'unit: $unit',
              style: GoogleFonts.inter(fontSize: 10.5, color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: minCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 12.5, color: colors.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('Min', style: GoogleFonts.inter(fontSize: 11, color: colors.textDisabled, fontWeight: FontWeight.bold)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: '0',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: colors.textDisabled),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: onMinChanged,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('—', style: TextStyle(color: colors.textDisabled, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: maxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 12.5, color: colors.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('Max', style: GoogleFonts.inter(fontSize: 11, color: colors.textDisabled, fontWeight: FontWeight.bold)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: 'Max',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: colors.textDisabled),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: onMaxChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
