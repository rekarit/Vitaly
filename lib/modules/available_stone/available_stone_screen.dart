import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/material_item.dart';
import '../../core/models/slab.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../reservations/reservations_screen.dart';
import 'advanced_stone_filter_dialog.dart';
import '../../core/services/auth_service.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// Available Stone Screen
/// Clean, fast, minimalist inventory viewing and monitoring screen.
/// - Live source: appState.slabs.where((s) => s.status == SlabStatus.available)
/// - Grouped by Category and Material
/// - Stock metrics: [X] Slabs Available | [X.XX] m² In Stock
/// - Drill-down into Material reveals individual available slabs with defects
enum StoneStockTab { available, unavailable, damaged }

/// ──────────────────────────────────────────────────────────────────────────
/// Available Stone Screen (Stone Types)
/// Clean, fast, minimalist inventory viewing and monitoring screen.
/// - Tab filters: Available (green), Unavailable (slate/red), Damaged (amber/orange)
/// - Grouped by Category and Material
/// - Direct Damaged recording, defect tracking, and quick repair/restore
/// - Multi-slab status actions & full inventory drill-down
/// ──────────────────────────────────────────────────────────────────────────
class AvailableStoneScreen extends StatefulWidget {
  const AvailableStoneScreen({super.key});

  static final GlobalKey<AvailableStoneScreenState> globalKey =
      GlobalKey<AvailableStoneScreenState>();

  @override
  State<AvailableStoneScreen> createState() => AvailableStoneScreenState();
}

class AvailableStoneScreenState extends State<AvailableStoneScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final AdvancedStoneFilter _advancedFilter = AdvancedStoneFilter();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String? _expandedMaterialCode;
  bool _isGridView = false;
  StoneStockTab _currentTab = StoneStockTab.available; // Available, Unavailable, or Damaged
  final Set<String> _selectedSlabIds = {}; // Multi-selection for bulk status updates

  void resetFilterToAll() {
    if (mounted) {
      setState(() {
        _selectedCategory = 'All';
        _searchCtrl.clear();
        _searchQuery = '';
        _expandedMaterialCode = null;
        _advancedFilter.reset();
        _isGridView = false;
        _currentTab = StoneStockTab.available;
        _selectedSlabIds.clear();
      });
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

    // 1. Live slabs based on Active Stock Tab: Available, Unavailable, or Damaged
    final activeSlabs = appState.slabs.where((s) {
      switch (_currentTab) {
        case StoneStockTab.available:
          return s.status == SlabStatus.available;
        case StoneStockTab.unavailable:
          return s.status == SlabStatus.unavailable;
        case StoneStockTab.damaged:
          return s.status == SlabStatus.damaged;
      }
    }).toList();

    // Map slabs by material code
    final Map<String, List<Slab>> slabsByMatCode = {};
    for (final slab in activeSlabs) {
      slabsByMatCode.putIfAbsent(slab.materialId, () => []).add(slab);
    }

    // Filter categories list
    final categoryList = ['All', ...appState.categories];

    // Filter materials according to search, selected category, and advanced filter
    final List<MaterialItem> filteredMaterials = appState.materials.where((m) {
      if (_selectedCategory != 'All' &&
          m.categoryId.trim().toLowerCase() != _selectedCategory.trim().toLowerCase()) {
        return false;
      }
      if (!_advancedFilter.matchesMaterial(m)) {
        return false;
      }

      final allSlabs = slabsByMatCode[m.materialCode] ?? [];
      if (_advancedFilter.hasSlabCriteria && !allSlabs.any((s) => _advancedFilter.matchesSlab(s))) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        if (!_materialMatchesSearch(m, allSlabs, _searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Total stock metrics across active query (based on displayed slabs)
    int totalDisplayedCount = 0;
    double totalDisplayedArea = 0.0;
    for (final m in filteredMaterials) {
      final allSlabs = slabsByMatCode[m.materialCode] ?? [];
      final mSlabs = _getDisplaySlabs(m, allSlabs, _searchQuery);
      totalDisplayedCount += mSlabs.length;
      totalDisplayedArea += mSlabs.fold(0.0, (sum, s) => sum + s.areaSqm);
    }

    // Global stock pool counts for top segmented badges
    final totalAvailCount = appState.slabs.where((s) => s.status == SlabStatus.available).length;
    final totalUnavailCount = appState.slabs.where((s) => s.status == SlabStatus.unavailable).length;
    final totalDamagedCount = appState.slabs.where((s) => s.status == SlabStatus.damaged).length;

    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: _selectedSlabIds.isEmpty
          ? null
          : _buildBulkActionBar(colors, isDark, appState),
      body: Column(
        children: [
          // ── Header Bar ──────────────────────────────────────────────
          _buildHeader(
            colors: colors,
            isDark: isDark,
            totalCount: totalDisplayedCount,
            totalArea: totalDisplayedArea,
            appState: appState,
            availableSlabs: activeSlabs,
            totalAvailCount: totalAvailCount,
            totalUnavailCount: totalUnavailCount,
            totalDamagedCount: totalDamagedCount,
          ),

          // ── Search & Filter Bar ──────────────────────────────────────
          _buildSearchAndFilters(colors, isDark, categoryList),

          // ── Materials & Slabs Content ────────────────────────────────
          Expanded(
            child: filteredMaterials.isEmpty
                ? _buildEmptyState(colors)
                : (_isGridView
                    ? GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          context.screenPadding, 12, context.screenPadding, 40,
                        ),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: context.responsiveValue(
                            mobile: MediaQuery.sizeOf(context).width,
                            tablet: 320,
                            desktop: 360,
                          ),
                          mainAxisExtent: context.isMobile ? 230 : 260,
                          crossAxisSpacing: context.isMobile ? 10 : 16,
                          mainAxisSpacing: context.isMobile ? 10 : 16,
                        ),
                        itemCount: filteredMaterials.length,
                        itemBuilder: (ctx, idx) {
                          final mat = filteredMaterials[idx];
                          final allSlabs = slabsByMatCode[mat.materialCode] ?? [];
                          final matSlabs = _getDisplaySlabs(mat, allSlabs, _searchQuery);
                          return _buildMaterialGridCard(
                            mat: mat,
                            slabs: matSlabs,
                            colors: colors,
                            isDark: isDark,
                            onTap: () {
                              _showMaterialSlabsSheet(context, mat, matSlabs, colors, isDark);
                            },
                          );
                        },
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          context.screenPadding, 12, context.screenPadding, 40,
                        ),
                        itemCount: filteredMaterials.length,
                        itemBuilder: (ctx, idx) {
                          final mat = filteredMaterials[idx];
                          final allSlabs = slabsByMatCode[mat.materialCode] ?? [];
                          final matSlabs = _getDisplaySlabs(mat, allSlabs, _searchQuery);
                          // Auto-expand if user is actively searching or filtering and there are few matching results
                          final isExpanded = _expandedMaterialCode == mat.materialCode ||
                              ((_searchQuery.isNotEmpty || _advancedFilter.isActive) && filteredMaterials.length <= 3 && _expandedMaterialCode == null);
                          return _buildMaterialCard(
                            mat: mat,
                            slabs: matSlabs,
                            isExpanded: isExpanded,
                            colors: colors,
                            isDark: isDark,
                            onToggleExpand: () {
                              setState(() {
                                if (_expandedMaterialCode == mat.materialCode) {
                                  _expandedMaterialCode = null;
                                } else {
                                  _expandedMaterialCode = mat.materialCode;
                                }
                              });
                            },
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  // ── Multi-Attribute Search Helpers ──────────────────────────────────────────

  bool _slabMatchesSearch(Slab s, String q) {
    if (s.slabNo.toLowerCase().contains(q)) return true;
    if (s.id.toLowerCase().contains(q)) return true;
    if (s.inventoryId != null && s.inventoryId!.toLowerCase().contains(q)) return true;
    if (s.warehouseLocation.toLowerCase().contains(q)) return true;
    if (s.batchId != null && s.batchId!.toLowerCase().contains(q)) return true;
    if (s.defectNotes != null && s.defectNotes!.toLowerCase().contains(q)) return true;
    if (s.customQrData != null && s.customQrData!.toLowerCase().contains(q)) return true;
    if (s.customPrintLabelText != null && s.customPrintLabelText!.toLowerCase().contains(q)) return true;
    if (s.lengthMm.round().toString().contains(q)) return true;
    if (s.widthMm.round().toString().contains(q)) return true;
    if (s.thicknessMm.round().toString().contains(q)) return true;
    if (s.areaSqm.toStringAsFixed(2).contains(q)) return true;
    return false;
  }

  bool _materialMatchesSearch(MaterialItem m, List<Slab> mSlabs, String query) {
    final cleanQ = query.toLowerCase().trim();
    if (cleanQ.isEmpty) return true;

    final matKeywords = [
      m.name,
      m.materialCode,
      m.id,
      m.categoryId,
      m.stoneType,
      m.finish,
      m.origin,
      m.referenceCode,
      m.erpDescription,
      m.displayLabel,
      m.colorFamily,
      m.categoryAndName,
      m.stockSummary,
      m.codeAndFinish,
    ].join(' ').toLowerCase();

    // Direct match on material properties
    if (matKeywords.contains(cleanQ)) return true;

    // Direct match on any slab under this material
    if (mSlabs.any((s) => _slabMatchesSearch(s, cleanQ))) return true;

    // Tokenized query: all space-separated words must match either the material or its slabs
    final tokens = cleanQ.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length > 1) {
      return tokens.every((token) =>
          matKeywords.contains(token) || mSlabs.any((s) => _slabMatchesSearch(s, token)));
    }

    return false;
  }

  List<Slab> _getDisplaySlabs(MaterialItem mat, List<Slab> allMatSlabs, String query) {
    var slabs = allMatSlabs;
    if (_advancedFilter.hasSlabCriteria) {
      slabs = slabs.where((s) => _advancedFilter.matchesSlab(s)).toList();
    }
    if (query.isEmpty) return slabs;
    final q = query.toLowerCase().trim();

    // If query matches specific slabs by slabNo, ID, location, etc., highlight/show those slabs
    final matchingSlabs = slabs.where((s) => _slabMatchesSearch(s, q)).toList();
    if (matchingSlabs.isNotEmpty) {
      return matchingSlabs;
    }

    // Token-matching for multi-words
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length > 1) {
      final tokenMatching = slabs.where((s) {
        return tokens.any((t) => _slabMatchesSearch(s, t));
      }).toList();
      if (tokenMatching.isNotEmpty) {
        return tokenMatching;
      }
    }

    return slabs;
  }

  // ── Stock Tab Selector: Available / Unavailable / Damaged ─────────────────
  Widget _buildStockTabSelector(
    AppColorsExtension colors,
    bool isDark,
    int availCount,
    int unavailCount,
    int damagedCount,
  ) {
    Widget tabBtn({
      required StoneStockTab tab,
      required String label,
      required IconData icon,
      required Color activeColor,
      required int count,
    }) {
      final isSelected = _currentTab == tab;
      return InkWell(
        onTap: () {
          if (_currentTab != tab) {
            setState(() {
              _currentTab = tab;
              _selectedSlabIds.clear();
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDark ? colors.surface : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _currentTab == StoneStockTab.available
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (_currentTab == StoneStockTab.damaged
                  ? const Color(0xFFEA580C).withValues(alpha: 0.5)
                  : const Color(0xFF64748B).withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBtn(
            tab: StoneStockTab.available,
            label: 'Available',
            icon: Icons.check_circle_rounded,
            activeColor: const Color(0xFF10B981),
            count: availCount,
          ),
          tabBtn(
            tab: StoneStockTab.unavailable,
            label: 'Unavailable',
            icon: Icons.cancel_rounded,
            activeColor: const Color(0xFF64748B),
            count: unavailCount,
          ),
          tabBtn(
            tab: StoneStockTab.damaged,
            label: 'Damaged',
            icon: Icons.broken_image_rounded,
            activeColor: const Color(0xFFEA580C),
            count: damagedCount,
          ),
        ],
      ),
    );
  }

  // ── Bulk Action Floating Bar (when slabs are selected) ─────────────────────
  Widget _buildBulkActionBar(AppColorsExtension colors, bool isDark, AppState appState) {
    final count = _selectedSlabIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2227) : Colors.white,
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count Slabs Selected',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentTab == StoneStockTab.damaged) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Restore to Available'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          appState.setMultipleSlabsStatus(_selectedSlabIds.toList(), SlabStatus.available);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully restored $count slabs to Available!'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                          setState(() => _selectedSlabIds.clear());
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cancel_rounded, size: 16),
                        label: const Text('Mark Unavailable'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF64748B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          appState.setMultipleSlabsStatus(_selectedSlabIds.toList(), SlabStatus.unavailable);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Marked $count slabs as Unavailable!'),
                              backgroundColor: const Color(0xFF64748B),
                            ),
                          );
                          setState(() => _selectedSlabIds.clear());
                        },
                      ),
                    ] else ...[
                      if (_currentTab != StoneStockTab.available) ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text('Mark Available'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            appState.setMultipleSlabsStatus(_selectedSlabIds.toList(), SlabStatus.available);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Successfully marked $count slabs as Available!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                            setState(() => _selectedSlabIds.clear());
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_currentTab != StoneStockTab.unavailable) ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cancel_rounded, size: 16),
                          label: const Text('Mark Unavailable'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF64748B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            appState.setMultipleSlabsStatus(_selectedSlabIds.toList(), SlabStatus.unavailable);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Successfully marked $count slabs as Unavailable!'),
                                backgroundColor: const Color(0xFF64748B),
                              ),
                            );
                            setState(() => _selectedSlabIds.clear());
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                        label: const Text('Reserve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final selectedSlabsList = appState.slabs.where((s) => _selectedSlabIds.contains(s.id)).toList();
                          ReservationsFormDialog.show(
                            context,
                            preselectedSlabs: selectedSlabsList,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.broken_image_rounded, size: 16),
                        label: const Text('Mark Damaged'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          appState.setMultipleSlabsStatus(
                            _selectedSlabIds.toList(),
                            SlabStatus.damaged,
                            defectNotes: 'Marked damaged via bulk selection',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Moved $count slabs to Damaged stock!'),
                              backgroundColor: const Color(0xFFEA580C),
                            ),
                          );
                          setState(() {
                            _selectedSlabIds.clear();
                            _currentTab = StoneStockTab.damaged;
                          });
                        },
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                      tooltip: 'Deselect All',
                      onPressed: () => setState(() => _selectedSlabIds.clear()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Header Bar ──────────────────────────────────────────────────────────
  Widget _buildHeader({
    required AppColorsExtension colors,
    required bool isDark,
    required int totalCount,
    required double totalArea,
    required AppState appState,
    required List<Slab> availableSlabs,
    required int totalAvailCount,
    required int totalUnavailCount,
    required int totalDamagedCount,
  }) {
    final hPad = context.screenPadding;
    final isMobile = context.isMobile;

    final badgeLabel = _currentTab == StoneStockTab.available
        ? 'Available Slabs'
        : (_currentTab == StoneStockTab.unavailable ? 'Unavailable Slabs' : 'Damaged Slabs');

    final badgesRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
      children: [
        _buildStockTabSelector(colors, isDark, totalAvailCount, totalUnavailCount, totalDamagedCount),
        ElevatedButton.icon(
          icon: const Icon(Icons.bookmark_add_rounded, size: 15),
          label: Text(
            isMobile ? '+ Reserve' : '+ Reserve Stone',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 13, vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          onPressed: () => ReservationsFormDialog.show(context),
        ),
        if (AuthService.instance.currentPermissions.canAdvancedFilterStone)
          _buildAdvancedFilterButton(colors, isDark, appState, availableSlabs),
        _buildHeaderBadge(
          label: badgeLabel,
          value: NumberFormat('#,###').format(totalCount),
          colors: colors,
          isDark: isDark,
          isPrimary: _currentTab == StoneStockTab.damaged,
        ),
        _buildHeaderBadge(
          label: 'Total Area',
          value: '${totalArea.toStringAsFixed(2)} m²',
          colors: colors,
          isDark: isDark,
          isPrimary: true,
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, isMobile ? 14 : 20, hPad, isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: isMobile
          // ── Mobile: compact stacked layout ──
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stone Types',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                badgesRow,
              ],
            )
          // ── Tablet / Desktop: single-row layout ──
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Stone Types',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live inventory stock · available & unavailable slabs · warehouse locations',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                badgesRow,
              ],
            ),
    );
  }

  Widget _buildAdvancedFilterButton(
    AppColorsExtension colors,
    bool isDark,
    AppState appState,
    List<Slab> availableSlabs,
  ) {
    final hasActiveFilter = _advancedFilter.isActive;
    final activeCount = _advancedFilter.activeCount;

    return InkWell(
      onTap: () => _openAdvancedFilterDialog(appState, availableSlabs),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasActiveFilter
              ? colors.primary.withValues(alpha: 0.15)
              : (isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasActiveFilter ? colors.primary : colors.border,
            width: hasActiveFilter ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: hasActiveFilter ? colors.primary : colors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              'Filter',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasActiveFilter ? colors.primary : colors.textPrimary,
              ),
            ),
            if (hasActiveFilter) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF111418) : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAdvancedFilterDialog(AppState appState, List<Slab> availableSlabs) async {
    final stoneTypes = appState.materials.map((m) => m.stoneType).where((s) => s.isNotEmpty).toSet().toList()..sort();
    final finishes = appState.materials.map((m) => m.finish).where((s) => s.isNotEmpty).toSet().toList()..sort();
    final racks = appState.racks.map((r) => r.rackCode).where((s) => s.isNotEmpty).toSet().toList()..sort();

    final result = await AdvancedStoneFilterDialog.show(
      context,
      currentFilter: _advancedFilter,
      categories: appState.categories,
      stoneTypes: stoneTypes,
      finishes: finishes,
      racks: racks,
      allMaterials: appState.materials,
      allAvailableSlabs: availableSlabs,
    );

    if (result != null && mounted) {
      setState(() {
        _advancedFilter
          ..category = result.category
          ..stoneType = result.stoneType
          ..finish = result.finish
          ..rackLocation = result.rackLocation
          ..defectStatus = result.defectStatus
          ..minLengthMm = result.minLengthMm
          ..maxLengthMm = result.maxLengthMm
          ..minWidthMm = result.minWidthMm
          ..maxWidthMm = result.maxWidthMm
          ..minAreaSqm = result.minAreaSqm
          ..maxAreaSqm = result.maxAreaSqm
          ..thicknessMm = result.thicknessMm
          ..batchId = result.batchId
          ..origin = result.origin;
      });
    }
  }

  Widget _buildHeaderBadge({
    required String label,
    required String value,
    required AppColorsExtension colors,
    required bool isDark,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary
            ? colors.primary.withValues(alpha: 0.12)
            : (isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary ? colors.primary.withValues(alpha: 0.3) : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isPrimary ? colors.primary : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search & Filter Chips ───────────────────────────────────────────────────
  Widget _buildSearchAndFilters(AppColorsExtension colors, bool isDark, List<String> categories) {
    final hPad = context.screenPadding;
    final isMobile = context.isMobile;

    final searchBox = Container(
      height: context.minTouchTarget,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceVariant : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: isMobile ? 'Search stone...' : 'Search by stone name, ID...',
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
              child: Icon(Icons.cancel_rounded, size: 16, color: colors.textSecondary),
            ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // On mobile: search takes full width, toggle on next line if needed
          if (isMobile) ...[  
            searchBox,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildCategoryChips(colors, isDark, categories)),
                const SizedBox(width: 8),
                _buildViewModeToggle(colors, isDark),
              ],
            ),
          ] else ...[  
            Row(
              children: [
                SizedBox(
                  width: context.isTablet ? 240 : 300,
                  child: searchBox,
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildCategoryChips(colors, isDark, categories)),
                const SizedBox(width: 12),
                _buildViewModeToggle(colors, isDark),
              ],
            ),
          ],

          // Active Advanced Filter Chips
          if (_advancedFilter.isActive) ...[
            const SizedBox(height: 8),
            _buildActiveFilterChips(colors, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChips(AppColorsExtension colors, bool isDark, List<String> categories) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          final isSelected = _selectedCategory == cat;
          return InkWell(
            onTap: () => setState(() => _selectedCategory = cat),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary
                    : (isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? colors.primary : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? const Color(0xFF111418) : Colors.white)
                      : colors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveFilterChips(AppColorsExtension colors, bool isDark) {
    final chips = <Widget>[];

    void addChip(String label, VoidCallback onRemove) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 13, color: colors.primary),
              ),
            ],
          ),
        ),
      );
    }

    if (_advancedFilter.category != null) {
      addChip('Cat: ${_advancedFilter.category}', () {
        setState(() => _advancedFilter.category = null);
      });
    }
    if (_advancedFilter.stoneType != null) {
      addChip('Type: ${_advancedFilter.stoneType}', () {
        setState(() => _advancedFilter.stoneType = null);
      });
    }
    if (_advancedFilter.finish != null) {
      addChip('Finish: ${_advancedFilter.finish}', () {
        setState(() => _advancedFilter.finish = null);
      });
    }
    if (_advancedFilter.rackLocation != null) {
      addChip('Rack: ${_advancedFilter.rackLocation}', () {
        setState(() => _advancedFilter.rackLocation = null);
      });
    }
    if (_advancedFilter.defectStatus != null && _advancedFilter.defectStatus != 'all') {
      addChip(_advancedFilter.defectStatus == 'flawless' ? 'Flawless Only' : 'Defects Only', () {
        setState(() => _advancedFilter.defectStatus = null);
      });
    }
    if (_advancedFilter.thicknessMm != null) {
      addChip('${_advancedFilter.thicknessMm!.round()} mm', () {
        setState(() => _advancedFilter.thicknessMm = null);
      });
    }
    if (_advancedFilter.minLengthMm != null || _advancedFilter.maxLengthMm != null) {
      addChip('Length: ${_advancedFilter.minLengthMm?.round() ?? 0}-${_advancedFilter.maxLengthMm?.round() ?? "∞"} mm', () {
        setState(() {
          _advancedFilter.minLengthMm = null;
          _advancedFilter.maxLengthMm = null;
        });
      });
    }
    if (_advancedFilter.minWidthMm != null || _advancedFilter.maxWidthMm != null) {
      addChip('Width: ${_advancedFilter.minWidthMm?.round() ?? 0}-${_advancedFilter.maxWidthMm?.round() ?? "∞"} mm', () {
        setState(() {
          _advancedFilter.minWidthMm = null;
          _advancedFilter.maxWidthMm = null;
        });
      });
    }
    if (_advancedFilter.minAreaSqm != null || _advancedFilter.maxAreaSqm != null) {
      addChip('Area: ${_advancedFilter.minAreaSqm?.toStringAsFixed(1) ?? "0"}-${_advancedFilter.maxAreaSqm?.toStringAsFixed(1) ?? "∞"} m²', () {
        setState(() {
          _advancedFilter.minAreaSqm = null;
          _advancedFilter.maxAreaSqm = null;
        });
      });
    }
    if (_advancedFilter.batchId != null && _advancedFilter.batchId!.isNotEmpty) {
      addChip('Batch: ${_advancedFilter.batchId}', () {
        setState(() => _advancedFilter.batchId = null);
      });
    }
    if (_advancedFilter.origin != null && _advancedFilter.origin!.isNotEmpty) {
      addChip('Origin: ${_advancedFilter.origin}', () {
        setState(() => _advancedFilter.origin = null);
      });
    }

    return Row(
      children: [
        Text(
          'Filters:',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...chips.map((c) => Padding(padding: const EdgeInsets.only(right: 6), child: c)),
                InkWell(
                  onTap: () => setState(() => _advancedFilter.reset()),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Material Stock Overview Card ───────────────────────────────────────────
  Widget _buildMaterialCard({
    required MaterialItem mat,
    required List<Slab> slabs,
    required bool isExpanded,
    required AppColorsExtension colors,
    required bool isDark,
    required VoidCallback onToggleExpand,
  }) {
    final slabsCount = slabs.length;
    final totalAreaSqm = slabs.fold(0.0, (sum, s) => sum + s.areaSqm);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpanded ? colors.primary.withValues(alpha: 0.5) : colors.border,
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isExpanded)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Material Header & Summary Row ──
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: context.responsiveCardPadding,
              child: Builder(builder: (ctx) {
                final isMobile = ctx.isMobile;
                final thumbSize = isMobile ? 42.0 : 52.0;

                final thumbnail = Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: mat.imageBytes != null
                      ? Image.memory(mat.imageBytes!, fit: BoxFit.cover)
                      : (mat.imageUrl != null && mat.imageUrl!.isNotEmpty
                          ? Image.network(mat.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultStoneIcon(colors))
                          : _defaultStoneIcon(colors)),
                );

                final nameRow = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mat.materialCode,
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        mat.name.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 13 : 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                );

                final stockBadge = Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 14,
                    vertical: isMobile ? 5 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: slabsCount > 0
                        ? colors.success.withValues(alpha: 0.1)
                        : colors.textDisabled.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: slabsCount > 0
                          ? colors.success.withValues(alpha: 0.3)
                          : colors.border,
                    ),
                  ),
                  child: Builder(
                    builder: (bCtx) {
                      final tabStockText = switch (_currentTab) {
                        StoneStockTab.available => '$slabsCount Available',
                        StoneStockTab.unavailable => '$slabsCount Unavailable',
                        StoneStockTab.damaged => '$slabsCount Damaged',
                      };
                      final tabStockColor = switch (_currentTab) {
                        StoneStockTab.available => colors.success,
                        StoneStockTab.unavailable => const Color(0xFF64748B),
                        StoneStockTab.damaged => const Color(0xFFEA580C),
                      };

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tabStockText,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: slabsCount > 0 ? tabStockColor : colors.textDisabled,
                              ),
                            ),
                            Text(
                              '${totalAreaSqm.toStringAsFixed(2)} m²',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: slabsCount > 0 ? tabStockColor : colors.textDisabled,
                              ),
                            ),
                          ],
                        );
                      }

                      return Text(
                        '$tabStockText  |  ${totalAreaSqm.toStringAsFixed(2)} m²',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: slabsCount > 0 ? tabStockColor : colors.textDisabled,
                        ),
                      );
                    },
                  ),
                );

                final chevron = AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, size: 22, color: colors.textSecondary),
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    thumbnail,
                    SizedBox(width: isMobile ? 10 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          nameRow,
                          const SizedBox(height: 4),
                          Text(
                            '${mat.categoryId} · ${mat.stoneType} · ${mat.finish}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    stockBadge,
                    SizedBox(width: isMobile ? 4 : 12),
                    chevron,
                  ],
                );
              }),
            ),
          ),

          // ── Expanded Available Slabs Sub-Section ──
          if (isExpanded) ...[
            Divider(color: colors.border, height: 1),
            if (slabs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    switch (_currentTab) {
                      StoneStockTab.available => 'No available slabs for ${mat.name.toUpperCase()}',
                      StoneStockTab.unavailable => 'No unavailable slabs for ${mat.name.toUpperCase()}',
                      StoneStockTab.damaged => 'No damaged slabs for ${mat.name.toUpperCase()}',
                    },
                    style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Container(
                color: isDark ? const Color(0xFF131519) : const Color(0xFFF8FAFC),
                child: Column(
                  children: [
                    // Material-level Bulk Action Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? colors.surfaceVariant.withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                        border: Border(bottom: BorderSide(color: colors.border)),
                      ),
                      child: Row(
                        children: [
                          // Select All for this material
                          Builder(
                            builder: (bCtx) {
                              final allSelected = slabs.isNotEmpty && slabs.every((s) => _selectedSlabIds.contains(s.id));
                              final someSelected = slabs.any((s) => _selectedSlabIds.contains(s.id));
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (allSelected) {
                                      for (final s in slabs) {
                                        _selectedSlabIds.remove(s.id);
                                      }
                                    } else {
                                      for (final s in slabs) {
                                        _selectedSlabIds.add(s.id);
                                      }
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: allSelected ? true : (someSelected ? null : false),
                                        tristate: true,
                                        activeColor: colors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (_) {
                                          setState(() {
                                            if (allSelected) {
                                              for (final s in slabs) {
                                                _selectedSlabIds.remove(s.id);
                                              }
                                            } else {
                                              for (final s in slabs) {
                                                _selectedSlabIds.add(s.id);
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Select All (${slabs.length})',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          // Quick Reserve Action
                          Builder(
                            builder: (btnCtx) {
                              final selectedInMat = slabs.where((s) => _selectedSlabIds.contains(s.id)).toList();
                              return ElevatedButton.icon(
                                icon: const Icon(Icons.bookmark_add_rounded, size: 14),
                                label: Text(
                                  selectedInMat.isNotEmpty
                                      ? 'Reserve (${selectedInMat.length})'
                                      : 'Reserve',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  final targetSlabs = selectedInMat.isNotEmpty ? selectedInMat : slabs;
                                  ReservationsFormDialog.show(context, preselectedSlabs: targetSlabs);
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          // Quick set all to available
                          TextButton.icon(
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                            label: Text(
                              'All Available',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              final appState = AppStateScope.of(context);
                              appState.setMaterialSlabsAvailability(mat.materialCode, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('All slabs for ${mat.name} marked as Available!'),
                                  backgroundColor: const Color(0xFF10B981),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          // Quick set all to unavailable
                          TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFEF4444)),
                            label: Text(
                              'All Unavailable',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              final appState = AppStateScope.of(context);
                              appState.setMaterialSlabsAvailability(mat.materialCode, false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('All slabs for ${mat.name} marked as Unavailable!'),
                                  backgroundColor: const Color(0xFFEF4444),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: slabs.length,
                      separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
                      itemBuilder: (ctx, sIdx) {
                        final slab = slabs[sIdx];
                        return _buildSlabItemRow(slab, colors, isDark);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
  // ─── Individual Available Slab Item Row ─────────────────────────────────
  Widget _buildSlabItemRow(Slab slab, AppColorsExtension colors, bool isDark) {
    return Builder(builder: (ctx) {
      final isDamaged = slab.status == SlabStatus.damaged;
      final isAvailable = slab.status == SlabStatus.available;
      final isMobile = MediaQuery.of(ctx).size.width < 768;
      final isSelected = _selectedSlabIds.contains(slab.id);
      final hasDefect = slab.hasDefect || (slab.defectNotes != null && slab.defectNotes!.isNotEmpty);
      final defectText = slab.defectNotes != null && slab.defectNotes!.isNotEmpty
          ? slab.defectNotes!
          : 'Defect / Damage reported';
      final double hPad = isMobile ? 12 : 16;
      final double vPad = isMobile ? 10 : 12;

      final selectCheckbox = SizedBox(
        width: 22,
        height: 22,
        child: Checkbox(
          value: isSelected,
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedSlabIds.add(slab.id);
              } else {
                _selectedSlabIds.remove(slab.id);
              }
            });
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      );

      final slabNo = Text(
        '#${slab.slabNo}',
        style: GoogleFonts.inter(
          fontSize: isMobile ? 13 : 14,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      );

      // Status indicator widget
      final Widget statusWidget;
      if (isDamaged) {
        statusWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEA580C).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_rounded, size: 12, color: Color(0xFFEA580C)),
              const SizedBox(width: 4),
              Text(
                'Damaged',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEA580C),
                ),
              ),
            ],
          ),
        );
      } else {
        statusWidget = Tooltip(
          message: isAvailable ? 'Click to mark as Unavailable' : 'Click to mark as Available',
          child: InkWell(
            onTap: () {
              final appState = AppStateScope.of(ctx);
              final nextAvail = !isAvailable;
              appState.setSlabAvailability(slab.id, nextAvail);
              ScaffoldMessenger.of(ctx).clearSnackBars();
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    nextAvail
                        ? 'Slab ${slab.slabNo} marked as Available'
                        : 'Slab ${slab.slabNo} marked as Unavailable',
                  ),
                  backgroundColor: nextAvail ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: isAvailable
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFF64748B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isAvailable
                      ? const Color(0xFF10B981).withValues(alpha: 0.35)
                      : const Color(0xFF64748B).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 13,
                    color: isAvailable ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAvailable ? 'Available' : 'Unavailable',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isAvailable ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 11,
                    color: isAvailable
                        ? const Color(0xFF10B981).withValues(alpha: 0.7)
                        : const Color(0xFF64748B).withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Action button widget
      final Widget? actionButton;
      if (isDamaged) {
        actionButton = InkWell(
          onTap: () {
            final appState = AppStateScope.of(ctx);
            appState.restoreDamagedSlab(slab.id);
            ScaffoldMessenger.of(ctx).clearSnackBars();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text('Slab #${slab.slabNo} restored to Available stock!'),
                  ],
                ),
                backgroundColor: const Color(0xFF1E293B),
                duration: const Duration(seconds: 3),
              ),
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 10,
              vertical: isMobile ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.45 : 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.replay_rounded,
                  size: 13,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  'Restore Available',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 10.5 : 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Individual Mark Damaged button removed from slab row per user request
        // (Moved to bottom action bar upon slab selection to eliminate UI overflow)
        actionButton = null;
      }

      // Prominent Reserve button (Primary Action)
      final Widget? reserveButton = !isDamaged
          ? ElevatedButton.icon(
              icon: const Icon(Icons.bookmark_add_rounded, size: 13),
              label: Text(
                'Reserve',
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 11 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 12,
                  vertical: isMobile ? 6 : 7,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                ReservationsFormDialog.show(
                  ctx,
                  preselectedSlabs: [slab],
                );
              },
            )
          : null;

      if (isMobile) {
        // ── Mobile: two-line card layout with direct tap to Reserve ──
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isDamaged) {
                _showMarkDamagedDialogOrSheet(
                  context: ctx,
                  slab: slab,
                  colors: colors,
                  isDark: isDark,
                );
              } else {
                ReservationsFormDialog.show(
                  ctx,
                  preselectedSlabs: [slab],
                );
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: selection checkbox + slab no + status + reserve + action button
                  Row(
                    children: [
                      selectCheckbox,
                      const SizedBox(width: 6),
                      slabNo,
                      const Spacer(),
                      statusWidget,
                      if (reserveButton != null) ...[
                        const SizedBox(width: 6),
                        reserveButton,
                      ],
                      if (actionButton != null) ...[
                        const SizedBox(width: 6),
                        actionButton,
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  // Row 2: metrics wrap
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _buildSlabMetricChip(
                        icon: Icons.straighten_rounded,
                        label: '${NumberFormat("#,###").format(slab.lengthMm.round())}×${NumberFormat("#,###").format(slab.widthMm.round())} mm',
                        colors: colors,
                      ),
                      _buildSlabMetricChip(
                        icon: Icons.square_foot_rounded,
                        label: '${slab.areaSqm.toStringAsFixed(2)} m²',
                        isHighlight: true,
                        colors: colors,
                      ),
                      _buildSlabMetricChip(
                        icon: Icons.warehouse_outlined,
                        label: slab.warehouseLocation,
                        colors: colors,
                      ),
                      if (slab.inventoryId != null && slab.inventoryId!.isNotEmpty)
                        _buildSlabMetricChip(
                          icon: Icons.qr_code_2_rounded,
                          label: slab.inventoryId!,
                          colors: colors,
                        ),
                      if (hasDefect)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⚠️', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  defectText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // ── Tablet / Desktop: single-row layout with direct tap to Reserve ──
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDamaged) {
              _showMarkDamagedDialogOrSheet(
                context: ctx,
                slab: slab,
                colors: colors,
                isDark: isDark,
              );
            } else {
              ReservationsFormDialog.show(
                ctx,
                preselectedSlabs: [slab],
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              children: [
                selectCheckbox,
                const SizedBox(width: 8),
                slabNo,
                const SizedBox(width: 14),

                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildSlabMetricChip(
                        icon: Icons.straighten_rounded,
                        label: '${NumberFormat("#,###").format(slab.lengthMm.round())} × ${NumberFormat("#,###").format(slab.widthMm.round())} mm',
                        colors: colors,
                      ),
                      _buildSlabMetricChip(
                        icon: Icons.square_foot_rounded,
                        label: '${slab.areaSqm.toStringAsFixed(2)} m²',
                        isHighlight: true,
                        colors: colors,
                      ),
                      _buildSlabMetricChip(
                        icon: Icons.warehouse_outlined,
                        label: slab.warehouseLocation,
                        colors: colors,
                      ),
                      if (slab.inventoryId != null && slab.inventoryId!.isNotEmpty)
                        _buildSlabMetricChip(
                          icon: Icons.qr_code_2_rounded,
                          label: slab.inventoryId!,
                          colors: colors,
                        ),
                      if (slab.batchId != null && slab.batchId!.isNotEmpty)
                        _buildSlabMetricChip(
                          icon: Icons.layers_outlined,
                          label: slab.batchId!,
                          colors: colors,
                        ),
                      if (hasDefect)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⚠️', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                'Defect: $defectText',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),
                statusWidget,
                if (reserveButton != null) ...[
                  const SizedBox(width: 8),
                  reserveButton,
                ],
                if (actionButton != null) ...[
                  const SizedBox(width: 8),
                  actionButton,
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSlabMetricChip({
    required IconData icon,
    required String label,
    required AppColorsExtension colors,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isHighlight ? colors.primary : colors.textSecondary,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? colors.primary : colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _defaultStoneIcon(AppColorsExtension colors) {
    return Center(
      child: Icon(Icons.terrain_rounded, size: 24, color: colors.textDisabled),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(AppColorsExtension colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 54, color: colors.textDisabled),
          const SizedBox(height: 14),
          Text(
            'No matching stone inventory found',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search query or category filter.',
            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Grid Card Representation for Material ──────────────────────────────────
  Widget _buildMaterialGridCard({
    required MaterialItem mat,
    required List<Slab> slabs,
    required AppColorsExtension colors,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final slabsCount = slabs.length;
    final totalAreaSqm = slabs.fold(0.0, (sum, s) => sum + s.areaSqm);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: colors.surfaceVariant.withValues(alpha: 0.6),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Material Image Thumbnail Container with Overlays
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9),
                      child: mat.imageBytes != null
                          ? Image.memory(mat.imageBytes!, fit: BoxFit.cover)
                          : (mat.imageUrl != null && mat.imageUrl!.isNotEmpty
                              ? Image.network(mat.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultStoneIcon(colors))
                              : _defaultStoneIcon(colors)),
                    ),
                    // Gradient overlay at bottom of image
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Code badge top-left
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          mat.materialCode,
                          style: GoogleFonts.robotoMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                    // Finish badge top-right
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mat.finish,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Material Info & Stock Badge
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mat.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${mat.categoryId} · ${mat.stoneType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Stock Pill
                    Builder(
                      builder: (ctx) {
                        final statusColor = switch (_currentTab) {
                          StoneStockTab.available => colors.success,
                          StoneStockTab.unavailable => const Color(0xFF64748B),
                          StoneStockTab.damaged => const Color(0xFFEA580C),
                        };
                        final statusLabel = switch (_currentTab) {
                          StoneStockTab.available => '$slabsCount Available',
                          StoneStockTab.unavailable => '$slabsCount Unavailable',
                          StoneStockTab.damaged => '$slabsCount Damaged',
                        };
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: slabsCount > 0
                                ? statusColor.withValues(alpha: 0.1)
                                : colors.textDisabled.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: slabsCount > 0
                                  ? statusColor.withValues(alpha: 0.3)
                                  : colors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: slabsCount > 0 ? statusColor : colors.textDisabled,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    statusLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: slabsCount > 0 ? statusColor : colors.textDisabled,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${totalAreaSqm.toStringAsFixed(2)} m²',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  // ── Modal sheet displaying slabs for a clicked Grid Card ────────────────────
  void _showMaterialSlabsSheet(
    BuildContext context,
    MaterialItem mat,
    List<Slab> slabs,
    AppColorsExtension colors,
    bool isDark,
  ) {
    final slabsCount = slabs.length;
    final totalAreaSqm = slabs.fold(0.0, (sum, s) => sum + s.areaSqm);

    // Desktop/tablet dialog uses shared content without a scroll controller.
    // Mobile bottom sheet creates its own instance with the drag scroll controller wired in.

    if (context.isMobile) {
      // Mobile: full-height draggable bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.97,
          expand: false,
          builder: (ctx, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                // drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: _SlabsSheetContent(
                    mat: mat,
                    slabs: slabs,
                    slabsCount: slabsCount,
                    totalAreaSqm: totalAreaSqm,
                    colors: colors,
                    isDark: isDark,
                    buildSlabRow: _buildSlabItemRow,
                    scrollController: scrollCtrl,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Tablet / Desktop: centered dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.border),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 860,
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: _SlabsSheetContent(
              mat: mat,
              slabs: slabs,
              slabsCount: slabsCount,
              totalAreaSqm: totalAreaSqm,
              colors: colors,
              isDark: isDark,
              buildSlabRow: _buildSlabItemRow,
            ),
          ),
        ),
      );
    }
  }

  // ── Grid / List View Mode Toggle ───────────────────────────────────────────
  Widget _buildViewModeToggle(AppColorsExtension colors, bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // List View
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
          const SizedBox(width: 2),
          // Grid View
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
        ],
      ),
    );
  }

  // ── Show modal to pick and record a damaged stone ───────────────────────────
  // ignore: unused_element
  void _showAddDamagedStoneModal(
    BuildContext context,
    AppColorsExtension colors,
    bool isDark,
    AppState appState,
  ) {
    final activeCandidateSlabs = appState.slabs.where((s) => s.status != SlabStatus.damaged).toList();
    if (activeCandidateSlabs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active slabs in inventory to mark as damaged.'),
          backgroundColor: Color(0xFFEA580C),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (bCtx, setModalState) {
            final matches = activeCandidateSlabs.where((s) {
              if (filter.isEmpty) return true;
              final q = filter.toLowerCase();
              return s.slabNo.toLowerCase().contains(q) ||
                  s.materialId.toLowerCase().contains(q) ||
                  (s.inventoryId ?? '').toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.broken_image_rounded, color: Color(0xFFEA580C), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Record Damaged Stone',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: TextField(
                      onChanged: (val) => setModalState(() => filter = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search slab by number, material ID, or QR...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: matches.isEmpty
                        ? Center(
                            child: Text(
                              'No matching slabs found',
                              style: GoogleFonts.inter(color: colors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: colors.border),
                            itemBuilder: (lCtx, idx) {
                              final slab = matches[idx];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.crop_portrait_rounded, color: Color(0xFFEA580C), size: 18),
                                ),
                                title: Text(
                                  'Slab #${slab.slabNo} (${slab.materialId})',
                                  style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${slab.lengthMm.round()} × ${slab.widthMm.round()} mm · ${slab.areaSqm.toStringAsFixed(2)} m²',
                                  style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showMarkDamagedDialogOrSheet(
                                    context: context,
                                    slab: slab,
                                    colors: colors,
                                    isDark: isDark,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Show dialog or bottom sheet to directly mark slab damaged ──────────────
  void _showMarkDamagedDialogOrSheet({
    required BuildContext context,
    required Slab slab,
    required AppColorsExtension colors,
    required bool isDark,
  }) {
    AdaptiveDialog.show(
      context: context,
      builder: (ctx) => _MarkDamagedModal(
        slab: slab,
        colors: colors,
        isDark: isDark,
      ),
    );
  }
}

// ── Shared slab list content used by both dialog and bottom sheet ─────────────
class _SlabsSheetContent extends StatelessWidget {
  final MaterialItem mat;
  final List<Slab> slabs;
  final int slabsCount;
  final double totalAreaSqm;
  final AppColorsExtension colors;
  final bool isDark;
  final Widget Function(Slab, AppColorsExtension, bool) buildSlabRow;
  final ScrollController? scrollController;

  const _SlabsSheetContent({
    required this.mat,
    required this.slabs,
    required this.slabsCount,
    required this.totalAreaSqm,
    required this.colors,
    required this.isDark,
    required this.buildSlabRow,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  mat.materialCode,
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mat.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${mat.categoryId} · ${mat.stoneType} · ${mat.finish}',
                      style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.success.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$slabsCount · ${totalAreaSqm.toStringAsFixed(2)} m²',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.success,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        Divider(color: colors.border, height: 1),

        // Slabs List
        Expanded(
          child: slabs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No available slabs for ${mat.name.toUpperCase()}',
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: slabs.length,
                  separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
                  itemBuilder: (ctx, i) => buildSlabRow(slabs[i], colors, isDark),
                ),
        ),
      ],
    );
  }
}

// ── Interactive modal / bottom sheet to directly mark slab damaged ────────────
class _MarkDamagedModal extends StatefulWidget {
  final Slab slab;
  final AppColorsExtension colors;
  final bool isDark;

  const _MarkDamagedModal({
    required this.slab,
    required this.colors,
    required this.isDark,
  });

  @override
  State<_MarkDamagedModal> createState() => _MarkDamagedModalState();
}

class _MarkDamagedModalState extends State<_MarkDamagedModal> {
  String _selectedReason = 'Breakage / Crack';
  final _notesCtrl = TextEditingController();

  final List<String> _reasons = const [
    'Breakage / Crack',
    'Chipped Corner',
    'Severe Scratch',
    'Cutting / Sizing Flaw',
    'Transit Damage',
    'Stain / Discoloration',
    'Other Defect',
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isDark = widget.isDark;
    final slab = widget.slab;
    final isMobile = MediaQuery.sizeOf(context).width < 680;

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.fromLTRB(
        isMobile ? 18 : 24,
        isMobile ? 16 : 22,
        isMobile ? 18 : 24,
        isMobile ? 24 : 22,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle for mobile bottom sheet
            if (isMobile)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.report_problem_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MARK STONE DAMAGED',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFEF4444),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Slab #${slab.slabNo}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: colors.border, height: 1),
            const SizedBox(height: 14),

            // Stone specs chips preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceVariant.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _chip(Icons.straighten, '${slab.lengthMm.round()}×${slab.widthMm.round()} mm', colors),
                  _chip(Icons.square_foot, '${slab.areaSqm.toStringAsFixed(2)} m²', colors),
                  _chip(Icons.warehouse_outlined, slab.warehouseLocation, colors),
                  if (slab.inventoryId != null && slab.inventoryId!.isNotEmpty)
                    _chip(Icons.qr_code_2_rounded, slab.inventoryId!, colors),
                  if (slab.batchId != null && slab.batchId!.isNotEmpty)
                    _chip(Icons.layers_outlined, slab.batchId!, colors),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Select Damage / Defect Type',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: isSelected,
                  selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  backgroundColor: isDark ? colors.surfaceVariant : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFEF4444) : colors.border,
                    ),
                  ),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFFEF4444) : colors.textPrimary,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedReason = reason);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            Text(
              'Additional Defect Notes (Optional)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Broken corner during forklift movement, crack along grain...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: colors.textDisabled),
                filled: true,
                fillColor: isDark ? colors.surfaceVariant : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.broken_image_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Mark Damaged Directly',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      final appState = AppStateScope.of(context);
                      final note = _notesCtrl.text.trim();
                      final defectDescription = note.isNotEmpty
                          ? '$_selectedReason: $note'
                          : _selectedReason;
                      appState.markDamaged(slab.id, defectNotes: defectDescription);

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Slab #${slab.slabNo} marked as damaged and moved from available stock.',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF1E293B),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, AppColorsExtension colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: colors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

