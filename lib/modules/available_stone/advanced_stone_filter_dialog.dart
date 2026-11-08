import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/material_item.dart';
import '../../core/models/slab.dart';
import '../../core/theme/app_theme.dart';

/// Filter state holding all customizable dimensions and attributes
class AdvancedStoneFilter {
  String? category;
  String? stoneType;
  String? finish;
  String? rackLocation;
  String? defectStatus; // 'all', 'flawless', 'defective'
  double? minLengthMm;
  double? maxLengthMm;
  double? minWidthMm;
  double? maxWidthMm;
  double? minAreaSqm;
  double? maxAreaSqm;
  double? thicknessMm;
  String? batchId;
  String? origin;

  bool get isActive =>
      category != null ||
      stoneType != null ||
      finish != null ||
      rackLocation != null ||
      (defectStatus != null && defectStatus != 'all') ||
      minLengthMm != null ||
      maxLengthMm != null ||
      minWidthMm != null ||
      maxWidthMm != null ||
      minAreaSqm != null ||
      maxAreaSqm != null ||
      thicknessMm != null ||
      (batchId != null && batchId!.isNotEmpty) ||
      (origin != null && origin!.isNotEmpty);

  bool get hasSlabCriteria =>
      rackLocation != null ||
      (defectStatus != null && defectStatus != 'all') ||
      minLengthMm != null ||
      maxLengthMm != null ||
      minWidthMm != null ||
      maxWidthMm != null ||
      minAreaSqm != null ||
      maxAreaSqm != null ||
      thicknessMm != null ||
      (batchId != null && batchId!.isNotEmpty);

  int get activeCount {
    int c = 0;
    if (category != null) c++;
    if (stoneType != null) c++;
    if (finish != null) c++;
    if (rackLocation != null) c++;
    if (defectStatus != null && defectStatus != 'all') c++;
    if (minLengthMm != null || maxLengthMm != null) c++;
    if (minWidthMm != null || maxWidthMm != null) c++;
    if (minAreaSqm != null || maxAreaSqm != null) c++;
    if (thicknessMm != null) c++;
    if (batchId != null && batchId!.isNotEmpty) c++;
    if (origin != null && origin!.isNotEmpty) c++;
    return c;
  }

  void reset() {
    category = null;
    stoneType = null;
    finish = null;
    rackLocation = null;
    defectStatus = null;
    minLengthMm = null;
    maxLengthMm = null;
    minWidthMm = null;
    maxWidthMm = null;
    minAreaSqm = null;
    maxAreaSqm = null;
    thicknessMm = null;
    batchId = null;
    origin = null;
  }

  AdvancedStoneFilter clone() {
    return AdvancedStoneFilter()
      ..category = category
      ..stoneType = stoneType
      ..finish = finish
      ..rackLocation = rackLocation
      ..defectStatus = defectStatus
      ..minLengthMm = minLengthMm
      ..maxLengthMm = maxLengthMm
      ..minWidthMm = minWidthMm
      ..maxWidthMm = maxWidthMm
      ..minAreaSqm = minAreaSqm
      ..maxAreaSqm = maxAreaSqm
      ..thicknessMm = thicknessMm
      ..batchId = batchId
      ..origin = origin;
  }

  bool matchesMaterial(MaterialItem m) {
    if (category != null && m.categoryId.toLowerCase() != category!.toLowerCase()) {
      return false;
    }
    if (stoneType != null && m.stoneType.toLowerCase() != stoneType!.toLowerCase()) {
      return false;
    }
    if (finish != null && m.finish.toLowerCase() != finish!.toLowerCase()) {
      return false;
    }
    if (origin != null && origin!.isNotEmpty && !m.origin.toLowerCase().contains(origin!.toLowerCase())) {
      return false;
    }
    return true;
  }

  bool matchesSlab(Slab s) {
    if (rackLocation != null && s.warehouseLocation.toLowerCase() != rackLocation!.toLowerCase()) {
      return false;
    }
    if (defectStatus == 'flawless') {
      final hasDefect = (s.defectNotes != null && s.defectNotes!.trim().isNotEmpty) || s.hasDefect;
      if (hasDefect) return false;
    } else if (defectStatus == 'defective') {
      final hasDefect = (s.defectNotes != null && s.defectNotes!.trim().isNotEmpty) || s.hasDefect;
      if (!hasDefect) return false;
    }
    if (thicknessMm != null && s.thicknessMm.round() != thicknessMm!.round()) {
      return false;
    }
    if (minLengthMm != null && s.lengthMm < minLengthMm!) {
      return false;
    }
    if (maxLengthMm != null && s.lengthMm > maxLengthMm!) {
      return false;
    }
    if (minWidthMm != null && s.widthMm < minWidthMm!) {
      return false;
    }
    if (maxWidthMm != null && s.widthMm > maxWidthMm!) {
      return false;
    }
    if (minAreaSqm != null && s.areaSqm < minAreaSqm!) {
      return false;
    }
    if (maxAreaSqm != null && s.areaSqm > maxAreaSqm!) {
      return false;
    }
    if (batchId != null && batchId!.isNotEmpty) {
      if (s.batchId == null || !s.batchId!.toLowerCase().contains(batchId!.toLowerCase())) {
        return false;
      }
    }
    return true;
  }
}

/// Ultra-Modern Sliding Drawer Filter Panel
class AdvancedStoneFilterDialog extends StatefulWidget {
  final AdvancedStoneFilter currentFilter;
  final List<String> categories;
  final List<String> stoneTypes;
  final List<String> finishes;
  final List<String> racks;
  final List<MaterialItem> allMaterials;
  final List<Slab> allAvailableSlabs;

  const AdvancedStoneFilterDialog({
    super.key,
    required this.currentFilter,
    required this.categories,
    required this.stoneTypes,
    required this.finishes,
    required this.racks,
    required this.allMaterials,
    required this.allAvailableSlabs,
  });

  static Future<AdvancedStoneFilter?> show(
    BuildContext context, {
    required AdvancedStoneFilter currentFilter,
    required List<String> categories,
    required List<String> stoneTypes,
    required List<String> finishes,
    required List<String> racks,
    required List<MaterialItem> allMaterials,
    required List<Slab> allAvailableSlabs,
  }) {
    return showGeneralDialog<AdvancedStoneFilter>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Filter',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: AdvancedStoneFilterDialog(
              currentFilter: currentFilter,
              categories: categories,
              stoneTypes: stoneTypes,
              finishes: finishes,
              racks: racks,
              allMaterials: allMaterials,
              allAvailableSlabs: allAvailableSlabs,
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
  State<AdvancedStoneFilterDialog> createState() => _AdvancedStoneFilterDialogState();
}

class _AdvancedStoneFilterDialogState extends State<AdvancedStoneFilterDialog> {
  late AdvancedStoneFilter _filter;
  late TextEditingController _batchCtrl;
  late TextEditingController _minLengthCtrl;
  late TextEditingController _maxLengthCtrl;
  late TextEditingController _minWidthCtrl;
  late TextEditingController _maxWidthCtrl;
  late TextEditingController _minAreaCtrl;
  late TextEditingController _maxAreaCtrl;

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter.clone();
    _batchCtrl = TextEditingController(text: _filter.batchId ?? '');
    _minLengthCtrl = TextEditingController(text: _filter.minLengthMm?.toStringAsFixed(0) ?? '');
    _maxLengthCtrl = TextEditingController(text: _filter.maxLengthMm?.toStringAsFixed(0) ?? '');
    _minWidthCtrl = TextEditingController(text: _filter.minWidthMm?.toStringAsFixed(0) ?? '');
    _maxWidthCtrl = TextEditingController(text: _filter.maxWidthMm?.toStringAsFixed(0) ?? '');
    _minAreaCtrl = TextEditingController(text: _filter.minAreaSqm?.toStringAsFixed(2) ?? '');
    _maxAreaCtrl = TextEditingController(text: _filter.maxAreaSqm?.toStringAsFixed(2) ?? '');
  }

  @override
  void dispose() {
    _batchCtrl.dispose();
    _minLengthCtrl.dispose();
    _maxLengthCtrl.dispose();
    _minWidthCtrl.dispose();
    _maxWidthCtrl.dispose();
    _minAreaCtrl.dispose();
    _maxAreaCtrl.dispose();
    super.dispose();
  }

  (int count, double area) _calculateMatchingMetrics() {
    int matchingCount = 0;
    double matchingArea = 0.0;
    final slabsByMat = <String, List<Slab>>{};
    for (final s in widget.allAvailableSlabs) {
      slabsByMat.putIfAbsent(s.materialId, () => []).add(s);
    }

    for (final m in widget.allMaterials) {
      if (!_filter.matchesMaterial(m)) continue;
      final mSlabs = slabsByMat[m.materialCode] ?? [];
      for (final s in mSlabs) {
        if (_filter.matchesSlab(s)) {
          matchingCount++;
          matchingArea += s.areaSqm;
        }
      }
    }
    return (matchingCount, matchingArea);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width > 600 ? 520.0 : mediaQuery.size.width;
    final (matchingCount, matchingArea) = _calculateMatchingMetrics();

    final cardBg = isDark ? const Color(0xFF17191E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF20232A) : const Color(0xFFF1F5F9);

    return Container(
      width: width,
      height: mediaQuery.size.height,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.border, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
            blurRadius: 30,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Premium Top Bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withValues(alpha: 0.25),
                          colors.primary.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.tune_rounded, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Filter Inventory',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (_filter.isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(10),
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
                          'Refine available stone stock by any detail',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_filter.isActive)
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          _filter.reset();
                          _batchCtrl.clear();
                          _minLengthCtrl.clear();
                          _maxLengthCtrl.clear();
                          _minWidthCtrl.clear();
                          _maxWidthCtrl.clear();
                          _minAreaCtrl.clear();
                          _maxAreaCtrl.clear();
                        });
                      },
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 22),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body with Clean Grouped Cards ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Stone Category
                    _buildSectionCard(
                      title: 'Material Category',
                      icon: Icons.category_outlined,
                      cardBg: cardBg,
                      colors: colors,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterPill(
                            label: 'All Categories',
                            isSelected: _filter.category == null,
                            colors: colors,
                            isDark: isDark,
                            onTap: () => setState(() => _filter.category = null),
                          ),
                          ...widget.categories.map((cat) {
                            return _buildFilterPill(
                              label: cat,
                              isSelected: _filter.category == cat,
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.category = cat),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Stone Type
                    if (widget.stoneTypes.isNotEmpty) ...[
                      _buildSectionCard(
                        title: 'Stone Type',
                        icon: Icons.terrain_outlined,
                        cardBg: cardBg,
                        colors: colors,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterPill(
                              label: 'All Types',
                              isSelected: _filter.stoneType == null,
                              colors: colors,
                              isDark: isDark,
                              onTap: () => setState(() => _filter.stoneType = null),
                            ),
                            ...widget.stoneTypes.map((type) {
                              return _buildFilterPill(
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
                      const SizedBox(height: 16),
                    ],

                    // 4. Surface Finish
                    _buildSectionCard(
                      title: 'Surface Finish',
                      icon: Icons.auto_awesome_outlined,
                      cardBg: cardBg,
                      colors: colors,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterPill(
                            label: 'All Finishes',
                            isSelected: _filter.finish == null,
                            colors: colors,
                            isDark: isDark,
                            onTap: () => setState(() => _filter.finish = null),
                          ),
                          ...widget.finishes.map((f) {
                            return _buildFilterPill(
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
                    const SizedBox(height: 16),

                    // 5. Thickness (mm)
                    _buildSectionCard(
                      title: 'Thickness (mm)',
                      icon: Icons.layers_outlined,
                      cardBg: cardBg,
                      colors: colors,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildFilterPill(
                              label: 'Any',
                              isSelected: _filter.thicknessMm == null,
                              colors: colors,
                              isDark: isDark,
                              isCenter: true,
                              onTap: () => setState(() => _filter.thicknessMm = null),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFilterPill(
                              label: '20 mm',
                              isSelected: _filter.thicknessMm == 20.0,
                              colors: colors,
                              isDark: isDark,
                              isCenter: true,
                              onTap: () => setState(() => _filter.thicknessMm = 20.0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFilterPill(
                              label: '30 mm',
                              isSelected: _filter.thicknessMm == 30.0,
                              colors: colors,
                              isDark: isDark,
                              isCenter: true,
                              onTap: () => setState(() => _filter.thicknessMm = 30.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Warehouse Rack / Location
                    _buildSectionCard(
                      title: 'Warehouse Rack / Location',
                      icon: Icons.warehouse_outlined,
                      cardBg: cardBg,
                      colors: colors,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterPill(
                            label: 'All Locations',
                            icon: Icons.grid_view_rounded,
                            isSelected: _filter.rackLocation == null,
                            colors: colors,
                            isDark: isDark,
                            onTap: () => setState(() => _filter.rackLocation = null),
                          ),
                          ...widget.racks.map((rack) {
                            return _buildFilterPill(
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
                    const SizedBox(height: 16),

                    // 7. Dimensions & Area Range
                    _buildSectionCard(
                      title: 'Dimensions & Area',
                      icon: Icons.straighten_rounded,
                      cardBg: cardBg,
                      colors: colors,
                      child: Column(
                        children: [
                          // Quick Area Presets
                          Row(
                            children: [
                              _buildPresetChip('Any Area', _filter.minAreaSqm == null && _filter.maxAreaSqm == null, () {
                                setState(() {
                                  _filter.minAreaSqm = null;
                                  _filter.maxAreaSqm = null;
                                  _minAreaCtrl.clear();
                                  _maxAreaCtrl.clear();
                                });
                              }, colors, isDark),
                              const SizedBox(width: 8),
                              _buildPresetChip('< 3 m²', _filter.maxAreaSqm == 3.0, () {
                                setState(() {
                                  _filter.minAreaSqm = null;
                                  _filter.maxAreaSqm = 3.0;
                                  _minAreaCtrl.clear();
                                  _maxAreaCtrl.text = '3.00';
                                });
                              }, colors, isDark),
                              const SizedBox(width: 8),
                              _buildPresetChip('3 - 5 m²', _filter.minAreaSqm == 3.0 && _filter.maxAreaSqm == 5.0, () {
                                setState(() {
                                  _filter.minAreaSqm = 3.0;
                                  _filter.maxAreaSqm = 5.0;
                                  _minAreaCtrl.text = '3.00';
                                  _maxAreaCtrl.text = '5.00';
                                });
                              }, colors, isDark),
                              const SizedBox(width: 8),
                              _buildPresetChip('> 5 m²', _filter.minAreaSqm == 5.0, () {
                                setState(() {
                                  _filter.minAreaSqm = 5.0;
                                  _filter.maxAreaSqm = null;
                                  _minAreaCtrl.text = '5.00';
                                  _maxAreaCtrl.clear();
                                });
                              }, colors, isDark),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Area custom range
                          _buildRangeRow(
                            label: 'Area (m²)',
                            unit: 'm²',
                            minCtrl: _minAreaCtrl,
                            maxCtrl: _maxAreaCtrl,
                            inputBg: inputBg,
                            colors: colors,
                            onMinChanged: (v) => setState(() => _filter.minAreaSqm = double.tryParse(v)),
                            onMaxChanged: (v) => setState(() => _filter.maxAreaSqm = double.tryParse(v)),
                          ),
                          const SizedBox(height: 12),

                          // Length custom range
                          _buildRangeRow(
                            label: 'Length (mm)',
                            unit: 'mm',
                            minCtrl: _minLengthCtrl,
                            maxCtrl: _maxLengthCtrl,
                            inputBg: inputBg,
                            colors: colors,
                            onMinChanged: (v) => setState(() => _filter.minLengthMm = double.tryParse(v)),
                            onMaxChanged: (v) => setState(() => _filter.maxLengthMm = double.tryParse(v)),
                          ),
                          const SizedBox(height: 12),

                          // Width custom range
                          _buildRangeRow(
                            label: 'Width (mm)',
                            unit: 'mm',
                            minCtrl: _minWidthCtrl,
                            maxCtrl: _maxWidthCtrl,
                            inputBg: inputBg,
                            colors: colors,
                            onMinChanged: (v) => setState(() => _filter.minWidthMm = double.tryParse(v)),
                            onMaxChanged: (v) => setState(() => _filter.maxWidthMm = double.tryParse(v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 8. Origin & Batch ID
                    _buildSectionCard(
                      title: 'Origin & Batch',
                      icon: Icons.public_outlined,
                      cardBg: cardBg,
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Country of Origin',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterPill(
                                label: 'All Countries',
                                isSelected: _filter.origin == null,
                                colors: colors,
                                isDark: isDark,
                                onTap: () => setState(() => _filter.origin = null),
                              ),
                              ...['Italy', 'Brazil', 'Spain', 'Turkey', 'Greece', 'India'].map((c) {
                                return _buildFilterPill(
                                  label: c,
                                  isSelected: _filter.origin == c,
                                  colors: colors,
                                  isDark: isDark,
                                  onTap: () => setState(() => _filter.origin = c),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Batch Identifier',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.tag_rounded, size: 16, color: colors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _batchCtrl,
                                    style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. BATCH-1201 or 1301',
                                      hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (val) {
                                      setState(() => _filter.batchId = val.trim().isEmpty ? null : val.trim());
                                    },
                                  ),
                                ),
                                if (_batchCtrl.text.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _batchCtrl.clear();
                                      setState(() => _filter.batchId = null);
                                    },
                                    child: Icon(Icons.clear_rounded, size: 16, color: colors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Sticky Footer with Live Metrics & Glow Button ──
            Container(
              padding: EdgeInsets.fromLTRB(mediaQuery.size.width > 400 ? 24 : 16, 14, mediaQuery.size.width > 400 ? 24 : 16, 16),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Live Stock Counter
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
                                color: matchingCount > 0 ? colors.success : colors.textDisabled,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$matchingCount Slabs Found',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${matchingArea.toStringAsFixed(2)} m² Total Area',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Apply Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'Apply Filters',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: isDark ? const Color(0xFF111418) : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color cardBg,
    required AppColorsExtension colors,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
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

  Widget _buildFilterPill({
    required String label,
    IconData? icon,
    required bool isSelected,
    required AppColorsExtension colors,
    required bool isDark,
    bool isCenter = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: isCenter ? Alignment.center : null,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.16)
              : (isDark ? const Color(0xFF20232A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: isCenter ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: isCenter ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colors.primary : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildGlassSegment({
    required String label,
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
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.18)
              : (isDark ? const Color(0xFF20232A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colors.primary : colors.textSecondary,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colors.primary : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRangeRow({
    required String label,
    required String unit,
    required TextEditingController minCtrl,
    required TextEditingController maxCtrl,
    required Color inputBg,
    required AppColorsExtension colors,
    required ValueChanged<String> onMinChanged,
    required ValueChanged<String> onMaxChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: minCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Min',
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
          child: Text('—', style: TextStyle(color: colors.textDisabled)),
        ),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: maxCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
              decoration: InputDecoration(
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
    );
  }
}
