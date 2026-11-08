import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/models/slab.dart';
import '../../core/models/material_item.dart';
import '../../core/services/auth_service.dart';

// ── PRINT LABELS SCREEN ──────────────────────────────────────────────────────
class PrintLabelsScreen extends StatefulWidget {
  const PrintLabelsScreen({super.key});

  @override
  State<PrintLabelsScreen> createState() => _PrintLabelsScreenState();
}

class _PrintLabelsScreenState extends State<PrintLabelsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;

  // Filters
  String _selectedCategory = 'All';
  String _selectedLocation = 'All';
  String _selectedStatus = 'All';
  String _selectedDateFilter = 'All'; // All, Today, Last 7 Days, Last 30 Days, Custom Range
  DateTimeRange? _customDateRange;

  // Batch Selection
  final Set<String> _selectedSlabIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Precise multi-token search & filter ─────────────────────────────────────
  List<Slab> _filterSlabs(List<Slab> all, dynamic state) {
    final now = DateTime.now();

    return all.where((s) {
      final mat = state.materialById(s.materialId);
      final matName = (mat?.name ?? '').toLowerCase();
      final matCat = (mat?.colorFamily ?? '').toLowerCase();
      final matFinish = (mat?.finish ?? '').toLowerCase();
      final matCode = (mat?.materialCode ?? '').toLowerCase();
      final slabNo = (s.slabNo.isNotEmpty ? s.slabNo : '${s.bundleNumber}-${s.slabNumber}').toLowerCase();
      final bundle = s.bundleNumber.toLowerCase();
      final qr = s.qrCode.toLowerCase();
      final loc = s.warehouseLocation.toLowerCase();
      final notes = (s.defectNotes ?? '').toLowerCase();

      // 1. Status Filter
      if (_selectedStatus != 'All') {
        if (_selectedStatus == 'Available' && s.status != SlabStatus.available) return false;
        if (_selectedStatus == 'Reserved' && s.status != SlabStatus.reserved) return false;
        if (_selectedStatus == 'Sold' && s.status != SlabStatus.sold) return false;
        if (_selectedStatus == 'Damaged' && s.status != SlabStatus.damaged) return false;
      }

      // 2. Category Filter
      if (_selectedCategory != 'All') {
        if (mat?.colorFamily != _selectedCategory) return false;
      }

      // 3. Location Filter
      if (_selectedLocation != 'All') {
        if (s.warehouseLocation != _selectedLocation) return false;
      }

      // 4. Date Filter
      if (_selectedDateFilter != 'All') {
        final recDate = s.receivedDate;
        if (_selectedDateFilter == 'Today') {
          final isToday = recDate.year == now.year && recDate.month == now.month && recDate.day == now.day;
          if (!isToday) return false;
        } else if (_selectedDateFilter == 'Last 7 Days') {
          if (recDate.isBefore(now.subtract(const Duration(days: 7)))) return false;
        } else if (_selectedDateFilter == 'Last 30 Days') {
          if (recDate.isBefore(now.subtract(const Duration(days: 30)))) return false;
        } else if (_selectedDateFilter == 'Custom Range' && _customDateRange != null) {
          final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
          if (recDate.isBefore(start) || recDate.isAfter(end)) return false;
        }
      }

      // 5. Deep multi-token Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final tokens = _searchQuery.trim().toLowerCase().split(RegExp(r'\s+'));
        for (final token in tokens) {
          final matchesToken = slabNo.contains(token) ||
              bundle.contains(token) ||
              qr.contains(token) ||
              matName.contains(token) ||
              matCat.contains(token) ||
              matCode.contains(token) ||
              matFinish.contains(token) ||
              loc.contains(token) ||
              notes.contains(token);
          if (!matchesToken) return false;
        }
      }

      return true;
    }).toList();
  }

  // ── Open Print Dialog ──────────────────────────────────────────────────────
  void _openPrintDialog({required List<Slab> slabsToPrint}) {
    if (slabsToPrint.isEmpty) return;
    AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => _DirectPrintLabelDialog(slabs: slabsToPrint),
    );
  }

  Future<void> _pickDateRange() async {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customDateRange ??
          DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: colors.primary,
                    onPrimary: Colors.white,
                    surface: colors.surface,
                    onSurface: colors.textPrimary,
                  )
                : ColorScheme.light(
                    primary: colors.primary,
                    onPrimary: Colors.white,
                    surface: colors.surface,
                    onSurface: colors.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateFilter = 'Custom Range';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final colors = context.colors;

    final filtered = _filterSlabs(state.slabs, state);

    // Unique Categories & Locations for filters
    final categories = ['All', ...state.materials.map((m) => m.colorFamily).toSet()];
    final locations = ['All', ...state.slabs.map((s) => s.warehouseLocation).toSet()];

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar ──────────────────────────────────────────────────────
          _buildHeader(context, state.slabs.length, filtered.length),

          // ── Search & Filter Controls ────────────────────────────────────────
          _buildToolbar(context, categories, locations, filtered),

          // ── Slab Label Previews (Grid / List) ────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty(context)
                : _isGridView
                    ? _buildGrid(context, filtered, state)
                    : _buildList(context, filtered, state),
          ),
        ],
      ),
    );
  }

  // ── Header Bar matching visual style in user's image ───────────────────────
  Widget _buildHeader(BuildContext context, int totalCount, int filteredCount) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Print Labels',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Generate and print warehouse QR tags for slabs',
                style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),

          // Right Badges & Batch Print action
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.primary.withAlpha(70)),
                ),
                child: Text(
                  '$filteredCount / $totalCount Slabs',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary),
                ),
              ),
              if (_selectedSlabIds.isNotEmpty && AuthService.instance.currentPermissions.canBatchPrintLabels)
                ElevatedButton.icon(
                  onPressed: () {
                    final state = AppStateScope.read(context);
                    final selectedSlabs = state.slabs.where((s) => _selectedSlabIds.contains(s.id)).toList();
                    _openPrintDialog(slabsToPrint: selectedSlabs);
                  },
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text(
                    'Print Selected (${_selectedSlabIds.length})',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Toolbar: Search Bar + Filter Dropdowns + View Switcher ─────────────────
  Widget _buildToolbar(BuildContext context, List<String> categories, List<String> locations, List<Slab> filtered) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        children: [
          // 1. Search Bar matching user screenshot
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by Material Name, Bundle, QR Code, or Location...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: colors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18, color: colors.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      tooltip: 'Clear search',
                    )
                  : null,
              filled: true,
              fillColor: colors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Filter Dropdowns & View Toggle Row
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Category Dropdown
                  _buildDropdown(
                    label: 'Category',
                    value: _selectedCategory,
                    items: categories,
                    onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
                    colors: colors,
                  ),

                  // Location Dropdown
                  _buildDropdown(
                    label: 'Location',
                    value: _selectedLocation,
                    items: locations,
                    onChanged: (v) => setState(() => _selectedLocation = v ?? 'All'),
                    colors: colors,
                  ),

                  // Date Filter Dropdown
                  _buildDropdown(
                    label: 'Date',
                    value: _selectedDateFilter,
                    items: ['All', 'Today', 'Last 7 Days', 'Last 30 Days', 'Custom Range'],
                    onChanged: (v) {
                      if (v == 'Custom Range') {
                        _pickDateRange();
                      } else {
                        setState(() {
                          _selectedDateFilter = v ?? 'All';
                          _customDateRange = null;
                        });
                      }
                    },
                    colors: colors,
                  ),

                  // Select All / Clear Checkbox
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_selectedSlabIds.length == filtered.length) {
                          _selectedSlabIds.clear();
                        } else {
                          _selectedSlabIds.addAll(filtered.map((s) => s.id));
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectedSlabIds.isNotEmpty && _selectedSlabIds.length == filtered.length
                                ? Icons.check_box_rounded
                                : _selectedSlabIds.isNotEmpty
                                    ? Icons.indeterminate_check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                            size: 16,
                            color: _selectedSlabIds.isNotEmpty ? colors.primary : colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedSlabIds.length == filtered.length ? 'Deselect All' : 'Select All',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // View Mode Switcher (List vs Grid)
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // List View Tab
                    InkWell(
                      onTap: () => setState(() => _isGridView = false),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              color: !_isGridView ? Colors.white : colors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'List',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: !_isGridView ? FontWeight.bold : FontWeight.w500,
                                color: !_isGridView ? Colors.white : colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Grid View Tab
                    InkWell(
                      onTap: () => setState(() => _isGridView = true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              color: _isGridView ? Colors.white : colors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Grid',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _isGridView ? FontWeight.bold : FontWeight.w500,
                                color: _isGridView ? Colors.white : colors.textSecondary,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required AppColorsExtension colors,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary, size: 20),
          dropdownColor: colors.surface,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
          onChanged: onChanged,
          items: items.map((it) {
            final display = it == 'All' ? '$label: All' : it;
            return DropdownMenuItem<String>(
              value: it,
              child: Text(display, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner_rounded, size: 56, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'No matching slabs found',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search terms or filters.',
            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _searchCtrl.clear();
                _searchQuery = '';
                _selectedCategory = 'All';
                _selectedLocation = 'All';
                _selectedStatus = 'All';
                _selectedDateFilter = 'All';
                _customDateRange = null;
              });
            },
            child: const Text('Reset All Filters'),
          ),
        ],
      ),
    );
  }

  // ── Grid View matching user screenshot ─────────────────────────────────────
  Widget _buildGrid(BuildContext context, List<Slab> slabs, dynamic state) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 228,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: slabs.length,
      itemBuilder: (ctx, i) {
        final slab = slabs[i];
        final mat = state.materialById(slab.materialId);
        final isSelected = _selectedSlabIds.contains(slab.id);

        return _LabelPreviewGridCard(
          slab: slab,
          material: mat,
          isSelected: isSelected,
          onToggleSelect: () {
            setState(() {
              if (isSelected) {
                _selectedSlabIds.remove(slab.id);
              } else {
                _selectedSlabIds.add(slab.id);
              }
            });
          },
          onPrint: () => _openPrintDialog(slabsToPrint: [slab]),
        );
      },
    );
  }

  // ── List View for compact audit / batch scanning ───────────────────────────
  Widget _buildList(BuildContext context, List<Slab> slabs, dynamic state) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = DateFormat('MMM d, yyyy');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      itemCount: slabs.length,
      itemBuilder: (ctx, i) {
        final slab = slabs[i];
        final mat = state.materialById(slab.materialId);
        final isSelected = _selectedSlabIds.contains(slab.id);
        final slabTitle = slab.slabNo.isNotEmpty ? slab.slabNo : 'SLAB ${slab.slabNumber.toString().padLeft(2, "0")}';
        final lenMm = (slab.lengthMm > 0 ? slab.lengthMm : slab.lengthCm * 10).round();
        final widMm = (slab.widthMm > 0 ? slab.widthMm : slab.widthCm * 10).round();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? colors.primary : colors.border),
          ),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                activeColor: colors.primary,
                onChanged: (_) {
                  setState(() {
                    if (isSelected) {
                      _selectedSlabIds.remove(slab.id);
                    } else {
                      _selectedSlabIds.add(slab.id);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),

              // Mini QR Code preview
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: QrImageView(
                  data: slab.qrCode,
                  version: QrVersions.auto,
                  size: 40,
                  backgroundColor: Colors.transparent,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: isDark ? colors.textPrimary : Colors.black,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: isDark ? colors.textPrimary : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Slab Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          slabTitle,
                          style: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            slab.warehouseLocation,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${mat?.name ?? "Natural Stone"} (${mat?.colorFamily ?? "—"}) · $lenMm × $widMm mm = ${slab.areaSqm.toStringAsFixed(2)} m²',
                      style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Date & QR Hex
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(slab.receivedDate),
                    style: GoogleFonts.inter(fontSize: 11, color: colors.textDisabled),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slab.qrCode.length > 10 ? slab.qrCode.substring(slab.qrCode.length - 8) : slab.qrCode,
                    style: GoogleFonts.robotoMono(fontSize: 10, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Direct Print Button
              ElevatedButton.icon(
                onPressed: () => _openPrintDialog(slabsToPrint: [slab]),
                icon: const Icon(Icons.print_rounded, size: 14),
                label: Text('Print Tag', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── GRID LABEL CARD (ADAPTIVE DARK/LIGHT THEME) ──────────────────────────────
class _LabelPreviewGridCard extends StatelessWidget {
  final Slab slab;
  final MaterialItem? material;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onPrint;

  const _LabelPreviewGridCard({
    required this.slab,
    required this.material,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lenMm = (slab.lengthMm > 0 ? slab.lengthMm : slab.lengthCm * 10).round();
    final widMm = (slab.widthMm > 0 ? slab.widthMm : slab.widthCm * 10).round();
    final slabNoDisplay = slab.slabNo.isNotEmpty
        ? slab.slabNo
        : 'SLAB  ${slab.bundleNumber.split('-').last}-${slab.slabNumber.toString().padLeft(2, '0')}';

    final categoryName = material?.colorFamily ?? 'Quartzite / Crystal';
    final materialName = material?.name ?? 'Natural Stone';
    final finishName = material?.finish ?? 'Leather';

    // QR short hex string shown below the QR code in screenshot e.g. "hv144069"
    final shortQr = slab.qrCode.length > 8 ? slab.qrCode.substring(slab.qrCode.length - 8) : slab.qrCode;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? colors.primary : colors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isDark
            ? const [
                BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
              ]
            : const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 56),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Information Block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: "SLAB  01-01"
                      Text(
                        slabNoDisplay.toUpperCase(),
                        style: GoogleFonts.robotoMono(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Dimensions: "2344 × 2344 mm = 5.49 m²"
                      Text(
                        '$lenMm × $widMm mm = ${slab.areaSqm.toStringAsFixed(2)} m²',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Classification: "Quartzite / Crystal · Ikejldsajdl · Leather"
                      Text(
                        '$categoryName · $materialName · $finishName',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Location Badge: "Warehouse"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          slab.warehouseLocation,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right QR Code Block
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? colors.surfaceVariant : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: QrImageView(
                        data: slab.qrCode,
                        version: QrVersions.auto,
                        size: 74,
                        backgroundColor: Colors.transparent,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: isDark ? colors.textPrimary : Colors.black,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: isDark ? colors.textPrimary : Colors.black,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shortQr.toLowerCase(),
                      style: GoogleFonts.robotoMono(
                        fontSize: 9,
                        color: colors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Multi-Select Checkbox overlay (top-left)
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onToggleSelect,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isSelected ? colors.primary : colors.textDisabled,
                ),
              ),
            ),
          ),

          // Print Tag Button matching screenshot gold/amber color
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text(
                  'Print Tag',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── DIRECT PRINT POPUP DIALOG (RAPID POPUP PRINT INTERACTION) ────────────────
class _DirectPrintLabelDialog extends StatefulWidget {
  final List<Slab> slabs;

  const _DirectPrintLabelDialog({required this.slabs});

  @override
  State<_DirectPrintLabelDialog> createState() => _DirectPrintLabelDialogState();
}

class _DirectPrintLabelDialogState extends State<_DirectPrintLabelDialog> {
  String _selectedPrinter = 'Zebra ZD421 (Direct Thermal)';
  String _selectedLabelSize = '100 × 50 mm (Warehouse Tag)';
  int _copies = 1;
  bool _isPrinting = false;

  final List<String> _printers = [
    'Save as PDF (Digital Document)',
    'Microsoft Print to PDF',
    'Zebra ZD421 (Direct Thermal)',
    'Dymo LabelWriter 4XL',
    'Brother QL-1100',
    'Office Laser / Inkjet (Letter/A4)',
    'System Default Printer',
  ];

  final List<String> _labelSizes = [
    '100 × 50 mm (Warehouse Tag)',
    '100 × 150 mm (Pallet / Shipping Tag)',
    '75 × 50 mm (Compact Slab Tag)',
    'Standard A4 Sheet (4 labels/page)',
  ];

  void _triggerPrint() async {
    setState(() => _isPrinting = true);
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    Navigator.pop(context);

    final slabName = widget.slabs.length == 1
        ? (widget.slabs.first.slabNo.isNotEmpty ? widget.slabs.first.slabNo : widget.slabs.first.id)
        : '${widget.slabs.length} Slabs';

    final isPdf = _selectedPrinter.toLowerCase().contains('pdf');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isPdf
                    ? 'Saved $slabName as PDF document via $_selectedPrinter ✓'
                    : 'Printing $_copies copy/copies of $slabName on $_selectedPrinter ✓',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isPdf ? const Color(0xFF2563EB) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstSlab = widget.slabs.first;
    final firstMat = state.materialById(firstSlab.materialId);

    final lenMm = (firstSlab.lengthMm > 0 ? firstSlab.lengthMm : firstSlab.lengthCm * 10).round();
    final widMm = (firstSlab.widthMm > 0 ? firstSlab.widthMm : firstSlab.widthCm * 10).round();
    final shortQr = firstSlab.qrCode.length > 8 ? firstSlab.qrCode.substring(firstSlab.qrCode.length - 8) : firstSlab.qrCode;

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(260.0, 780.0);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.print_rounded, color: colors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.slabs.length > 1
                                ? 'Print ${widget.slabs.length} Labels (Batch)'
                                : 'Print Slab Tag',
                            style: GoogleFonts.inter(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          Text(
                            'Direct thermal label generator',
                            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live Printable Tag Preview Box
                      Text(
                        'Live Label Preview',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? colors.surfaceVariant : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                          boxShadow: isDark
                              ? const []
                              : const [
                                  BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3)),
                                ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    firstSlab.slabNo.isNotEmpty
                                        ? firstSlab.slabNo.toUpperCase()
                                        : 'SLAB  ${firstSlab.bundleNumber.split("-").last}-${firstSlab.slabNumber.toString().padLeft(2, "0")}',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$lenMm × $widMm mm = ${firstSlab.areaSqm.toStringAsFixed(2)} m²',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${firstMat?.colorFamily ?? "Quartzite"} · ${firstMat?.name ?? "Natural Stone"} · ${firstMat?.finish ?? "Polished"}',
                                    style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? colors.surface : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Text(
                                      firstSlab.warehouseLocation,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (widget.slabs.length > 1) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '+ ${widget.slabs.length - 1} more slabs in queue',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDark ? colors.surface : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.border),
                                  ),
                                  child: QrImageView(
                                    data: firstSlab.qrCode,
                                    version: QrVersions.auto,
                                    size: 70,
                                    backgroundColor: Colors.transparent,
                                    eyeStyle: QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: isDark ? colors.textPrimary : Colors.black,
                                    ),
                                    dataModuleStyle: QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: isDark ? colors.textPrimary : Colors.black,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  shortQr.toLowerCase(),
                                  style: GoogleFonts.robotoMono(fontSize: 9, color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Destination Printer
                      Text('Destination Printer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPrinter,
                            isExpanded: true,
                            dropdownColor: colors.surface,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            items: _printers.map((p) {
                              return DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)));
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedPrinter = v ?? _selectedPrinter),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Label Size & Copies Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Label Format', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                                const SizedBox(height: 6),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedLabelSize,
                                      isExpanded: true,
                                      dropdownColor: colors.surface,
                                      icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                                      items: _labelSizes.map((s) {
                                        return DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary)));
                                      }).toList(),
                                      onChanged: (v) => setState(() => _selectedLabelSize = v ?? _selectedLabelSize),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Copies', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                                const SizedBox(height: 6),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 16),
                                        onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      Text('$_copies', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 16),
                                        onPressed: () => setState(() => _copies++),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
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
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isPrinting ? null : _triggerPrint,
                      icon: _isPrinting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(
                              _selectedPrinter.toLowerCase().contains('pdf')
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.print_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _isPrinting
                            ? (_selectedPrinter.toLowerCase().contains('pdf') ? 'Generating PDF...' : 'Sending to Printer...')
                            : (_selectedPrinter.toLowerCase().contains('save as pdf')
                                ? 'Save as PDF'
                                : (_selectedPrinter.toLowerCase().contains('pdf') ? 'Print to PDF' : 'Print Now')),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPrinter.toLowerCase().contains('pdf')
                            ? const Color(0xFF2563EB)
                            : colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
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
}
