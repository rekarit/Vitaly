import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/state/app_state_scope.dart';
import '../../core/models/material_audit_record.dart';
import '../../core/utils/export_utils.dart';
import '../../core/theme/app_theme.dart';
import 'data_check_detail_panel.dart';
import '../../core/services/auth_service.dart';

class DataCheckScreen extends StatefulWidget {
  final String? initialCategory;
  final int? initialCategoryCode;
  const DataCheckScreen({super.key, this.initialCategory, this.initialCategoryCode});

  @override
  State<DataCheckScreen> createState() => _DataCheckScreenState();
}

class _DataCheckScreenState extends State<DataCheckScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _activeCategoryCode = -1; // -1 means All
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  // Selected audit for right-side detail drawer (Screenshot 2)
  MaterialAuditRecord? _selectedAudit;
  bool _isPanelExpanded = false;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryCode != null) {
      _activeCategoryCode = widget.initialCategoryCode!;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MaterialAuditRecord> _getFilteredAudits(dynamic state) {
    final List<MaterialAuditRecord> allRecords = List.of(state.materialAudits.values);

    // Also include any materials not yet in audits
    for (final mat in state.materials) {
      if (!allRecords.any((a) => a.materialId == mat.id || a.codeText == mat.materialCode)) {
        allRecords.add(MaterialAuditRecord(
          materialId: mat.id,
          codeText: mat.materialCode,
          materialName: mat.name,
          categoryCode: mat.categoryCode,
          appSqmOverride: mat.totalAreaSqm,
        ));
      }
    }

    // Filter by category
    final filtered = allRecords.where((a) {
      if (_activeCategoryCode != -1 && a.categoryCode != _activeCategoryCode) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!a.codeText.toLowerCase().contains(q) &&
            !a.materialName.toLowerCase().contains(q) &&
            !a.notes.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) => a.codeText.compareTo(b.codeText));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final records = _getFilteredAudits(state);

    // Keep _selectedAudit up to date with appState changes
    MaterialAuditRecord? currentSelected;
    int currentIndex = -1;
    if (_selectedAudit != null) {
      currentIndex = records.indexWhere((a) => a.materialId == _selectedAudit!.materialId);
      if (currentIndex != -1) {
        currentSelected = records[currentIndex];
      } else {
        currentSelected = _selectedAudit;
      }
    }

    final isWide = MediaQuery.of(context).size.width >= 900;
    final isMobile = MediaQuery.of(context).size.width < 680;
    final panelWidth = _isPanelExpanded
        ? MediaQuery.of(context).size.width
        : (isWide ? 490.0 : (isMobile ? MediaQuery.of(context).size.width : MediaQuery.of(context).size.width * 0.88));

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ───────────────────────────────────────────────────────
            _buildTopBar(context, records, colors, isDark),
            Divider(color: colors.border, height: 1, thickness: 1),

            // Optional Search / Filter Bar
            if (_showSearchBar) ...[
              _buildFilterBar(context, state, colors, isDark),
              Divider(color: colors.border, height: 1, thickness: 1),
            ],

            // ── Content Area ──────────────────────────────────────────────────
            Expanded(
              child: isMobile
                  // Mobile: table only, row tap opens bottom sheet
                  ? records.isEmpty
                      ? Center(
                          child: Text(
                            'No audit records found',
                            style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 14),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildMobileTable(context, state, records, colors, isDark),
                          ),
                        )
                  // Tablet/Desktop: side panel overlay
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: records.isEmpty
                              ? Center(
                                  child: Text(
                                    'No audit records found',
                                    style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 14),
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: _buildTable(context, state, records, currentSelected, colors, isDark),
                                  ),
                                ),
                        ),
                        if (currentSelected != null)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: panelWidth,
                            child: DataCheckDetailPanel(
                              audit: currentSelected,
                              allRecords: records,
                              currentIndex: currentIndex != -1 ? currentIndex : 0,
                              isExpanded: _isPanelExpanded,
                              onClose: () {
                                setState(() {
                                  _selectedAudit = null;
                                  _isPanelExpanded = false;
                                });
                              },
                              onNavigate: (newAudit) {
                                setState(() => _selectedAudit = newAudit);
                              },
                              onToggleExpand: () {
                                setState(() => _isPanelExpanded = !_isPanelExpanded);
                              },
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a simplified table for mobile with tap-to-open bottom sheet.
  Widget _buildMobileTable(
    BuildContext context,
    dynamic state,
    List<MaterialAuditRecord> records,
    AppColorsExtension colors,
    bool isDark,
  ) {
    return DataTable(
      headingRowHeight: 44,
      dataRowMinHeight: 52,
      dataRowMaxHeight: 56,
      columnSpacing: 18,
      horizontalMargin: 14,
      headingRowColor: WidgetStateProperty.all(colors.surfaceVariant.withAlpha(isDark ? 70 : 120)),
      border: TableBorder(bottom: BorderSide(color: colors.border, width: 1)),
      headingTextStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
      dataTextStyle: GoogleFonts.inter(fontSize: 12.5, color: colors.textPrimary),
      columns: const [
        DataColumn(label: Text('Code')),
        DataColumn(label: Text('ERP Bal.')),
        DataColumn(label: Text('App m²')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('')),
      ],
      rows: records.map((audit) {
        final slabs = state.slabsForMaterial(audit.materialId);
        final liveAppSqm = slabs.isNotEmpty
            ? slabs.fold(0.0, (s, sl) => s + (sl as dynamic).areaSqm)
            : (audit.appSqmOverride ?? 0.0);
        final erpBalance = audit.erpBalanceSqm;

        return DataRow(
          cells: [
            DataCell(Text(audit.codeText, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colors.textPrimary))),
            DataCell(Text(_fmt.format(erpBalance), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(_fmt.format(liveAppSqm), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(audit.checkStatus, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary))),
            DataCell(
              InkWell(
                onTap: () {
                  final idx = records.indexWhere((a) => a.materialId == audit.materialId);
                  _openMobileDetailSheet(context, audit, records, idx >= 0 ? idx : 0);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 22),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// Opens the DataCheckDetailPanel as a bottom sheet on mobile.
  void _openMobileDetailSheet(
    BuildContext context,
    MaterialAuditRecord audit,
    List<MaterialAuditRecord> records,
    int idx,
  ) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: DataCheckDetailPanel(
                  audit: audit,
                  allRecords: records,
                  currentIndex: idx,
                  isExpanded: false,
                  onClose: () => Navigator.pop(ctx),
                  onNavigate: (a) {
                    setState(() => _selectedAudit = a);
                    Navigator.pop(ctx);
                  },
                  onToggleExpand: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, List<MaterialAuditRecord> records, AppColorsExtension colors, bool isDark) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: "Data Chek" (Matching Screenshot 1) or Breadcrumbs if drilled down
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.initialCategoryCode != null) ...[
                InkWell(
                  onTap: () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'CategoryCheck',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 18, color: colors.textDisabled),
                const SizedBox(width: 8),
              ],
              Text(
                'Data Chek',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),

          // Right: Action Buttons (Search Toggle + blue "export 2")
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search toggle
              IconButton(
                icon: Icon(
                  _showSearchBar ? Icons.search_off_rounded : Icons.search_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
                tooltip: 'Search & Filter',
                splashRadius: 18,
                onPressed: () {
                  setState(() {
                    _showSearchBar = !_showSearchBar;
                  });
                },
              ),
              const SizedBox(width: 8),

              // Blue "export 2" button (Matching Screenshot 1)
              if (AuthService.instance.currentPermissions.canExportDataCheck) ...[
                InkWell(
                  onTap: () => _exportData(context, records),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 50 : 20),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'export 2',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, dynamic state, AppColorsExtension colors, bool isDark) {
    final availableCategoryCodes = [-1, ...state.categoryModels.map((c) => c.categoryCode).toSet()];

    return Container(
      color: colors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by CodeText, Name, Notes...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
                filled: true,
                fillColor: colors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 14),
          DropdownButton<int>(
            value: _activeCategoryCode,
            dropdownColor: colors.surface,
            style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
            underline: const SizedBox.shrink(),
            items: availableCategoryCodes.map<DropdownMenuItem<int>>((code) {
              final label = code == -1 ? 'All Categories' : 'Category $code';
              return DropdownMenuItem<int>(
                value: code,
                child: Text(label),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _activeCategoryCode = val);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    dynamic state,
    List<MaterialAuditRecord> records,
    MaterialAuditRecord? selected,
    AppColorsExtension colors,
    bool isDark,
  ) {
    // Columns exactly matching Screenshot 1:
    final columns = [
      'CodeText',
      'ERP_Balance_sqm',
      'App_sqm',
      'Physical_sqm',
      'CheckStatus',
      'App_vs_ERP',
      'ERP_In_sqm',
      'ERP_Out_sqm',
      'LastERPUpdate',
      'Notes',
      'LastCountDate',
      '',
    ];

    return DataTable(
      headingRowHeight: 46,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 52,
      columnSpacing: 26,
      horizontalMargin: 20,
      headingRowColor: WidgetStateProperty.all(colors.surfaceVariant.withAlpha(isDark ? 70 : 120)),
      border: TableBorder(bottom: BorderSide(color: colors.border, width: 1)),
      headingTextStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
      dataTextStyle: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
      columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
      rows: records.map((audit) {
        final isSelected = selected?.materialId == audit.materialId;

        final slabs = state.slabsForMaterial(audit.materialId);
        final liveAppSqm = slabs.isNotEmpty
            ? slabs.fold(0.0, (s, sl) => s + (sl as dynamic).areaSqm)
            : (audit.appSqmOverride ?? 0.0);
        final erpBalance = audit.erpBalanceSqm;
        final appVsErp = liveAppSqm - erpBalance;
        final physicalSqmStr = audit.physicalSqm != null && audit.isCounted ? _fmt.format(audit.physicalSqm) : '';

        return DataRow(
          color: WidgetStateProperty.resolveWith<Color?>((states) {
            if (isSelected) {
              return isDark ? const Color(0xFF242424) : const Color(0xFFE2E8F0);
            }
            if (states.contains(WidgetState.hovered)) {
              return isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9);
            }
            return null;
          }),
          onSelectChanged: (_) {
            setState(() {
              _selectedAudit = audit;
            });
          },
          cells: [
            DataCell(Text(audit.codeText, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colors.textPrimary))),
            DataCell(Text(_fmt.format(erpBalance), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(_fmt.format(liveAppSqm), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(physicalSqmStr, style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(audit.checkStatus, style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(_fmt.format(appVsErp), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(_fmt.format(audit.erpInSqm), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(_fmt.format(audit.erpOutSqm), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(audit.lastErpUpdate, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(audit.notes, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(audit.lastCountDate, style: TextStyle(color: colors.textSecondary))),
            // Trailing arrow chevron button matching screenshot 1
            DataCell(
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedAudit = audit;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 20),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _exportData(BuildContext context, List<MaterialAuditRecord> records) async {
    final state = AppStateScope.of(context);
    final headers = [
      'CodeText',
      'ERP_Balance_sqm',
      'App_sqm',
      'Physical_sqm',
      'CheckStatus',
      'App_vs_ERP',
      'ERP_In_sqm',
      'ERP_Out_sqm',
      'LastERPUpdate',
      'Notes',
      'LastCountDate',
    ];

    final dataRows = records.map((a) {
      final slabs = state.slabsForMaterial(a.materialId);
      final liveAppSqm = slabs.isNotEmpty
          ? slabs.fold(0.0, (s, sl) => s + (sl as dynamic).areaSqm)
          : (a.appSqmOverride ?? 0.0);
      final erpBalance = a.erpBalanceSqm;
      final appVsErp = liveAppSqm - erpBalance;
      final physicalStr = a.physicalSqm != null && a.isCounted ? _fmt.format(a.physicalSqm) : '';

      return [
        a.codeText,
        _fmt.format(erpBalance),
        _fmt.format(liveAppSqm),
        physicalStr,
        a.checkStatus,
        _fmt.format(appVsErp),
        _fmt.format(a.erpInSqm),
        _fmt.format(a.erpOutSqm),
        a.lastErpUpdate,
        a.notes,
        a.lastCountDate,
      ];
    }).toList();

    await ExportUtils.exportCsv(
      context,
      defaultFileName: 'DataCheck_Export',
      headers: headers,
      rows: dataRows,
    );
  }
}
