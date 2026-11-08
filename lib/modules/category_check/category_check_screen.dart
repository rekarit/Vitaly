import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/models/material_audit_record.dart';
import '../../core/utils/export_utils.dart';
import '../../core/theme/app_theme.dart';
import '../data_check/data_check_detail_panel.dart';
import '../../core/services/auth_service.dart';

class CategoryCheckScreen extends StatefulWidget {
  final int? initialCategoryCode;
  const CategoryCheckScreen({super.key, this.initialCategoryCode});

  @override
  State<CategoryCheckScreen> createState() => _CategoryCheckScreenState();
}

class _CategoryCheckScreenState extends State<CategoryCheckScreen> {
  int? _selectedCategoryCode;
  bool _sortAscending = true;
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  // Detail panel state
  MaterialAuditRecord? _selectedAudit;
  bool _isPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryCode = widget.initialCategoryCode;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCategoryCode != null) {
      return _buildDataChekView(context, _selectedCategoryCode!);
    }
    return _buildCategoryCheckView(context);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCREEN 1: CategoryCheck Overview (Exact match to Image 1)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryCheckView(BuildContext context) {
    final state = AppStateScope.of(context);

    // Compute stats per category code only for categories with actual materials or audits
    final Map<int, _CategoryRowData> rowMap = {};

    // 1. Only include categories that have actual materials or audits in the system
    final activeCategoryCodes = <int>{
      ...state.materials.map((m) => m.categoryCode),
      ...state.materialAudits.values.map((a) => a.categoryCode),
    };

    for (final code in activeCategoryCodes) {
      rowMap[code] = _CategoryRowData(categoryCode: code);
    }

    // 2. Aggregate from materialAudits
    for (final audit in state.materialAudits.values) {
      final code = audit.categoryCode;
      rowMap.putIfAbsent(code, () => _CategoryRowData(categoryCode: code));
      rowMap[code]!.erpSqm += audit.erpBalanceSqm;
      
      // Calculate live App Sqm if slabs exist, else use audit appSqmOverride
      final slabs = state.slabsForMaterial(audit.materialId);
      if (slabs.isNotEmpty) {
        rowMap[code]!.appSqm += slabs.fold(0.0, (s, sl) => s + sl.areaSqm);
      } else {
        rowMap[code]!.appSqm += (audit.appSqmOverride ?? 0.0);
      }
    }

    // 3. Aggregate any additional materials in state.materials not in audits
    for (final mat in state.materials) {
      if (!state.materialAudits.containsKey(mat.id) && !state.materialAudits.containsKey(mat.materialCode)) {
        final code = mat.categoryCode;
        rowMap.putIfAbsent(code, () => _CategoryRowData(categoryCode: code));
        final slabs = state.slabsForMaterial(mat.id);
        if (slabs.isNotEmpty) {
          rowMap[code]!.appSqm += slabs.fold(0.0, (s, sl) => s + sl.areaSqm);
        } else {
          rowMap[code]!.appSqm += mat.totalAreaSqm;
        }
      }
    }

    final rows = rowMap.values.toList();
    rows.sort((a, b) => _sortAscending 
        ? a.categoryCode.compareTo(b.categoryCode) 
        : b.categoryCode.compareTo(a.categoryCode));

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            _buildCategoryCheckTopBar(context, rows, colors, isDark),
            Divider(color: colors.border, height: 1, thickness: 1),

            // Main Table or Clean Empty State
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pie_chart_outline_rounded, size: 56, color: colors.textDisabled),
                          const SizedBox(height: 16),
                          Text(
                            'No category records found',
                            style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Category metrics will calculate automatically when materials or slabs are entered.',
                            style: GoogleFonts.inter(color: colors.textDisabled, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: double.infinity,
                        child: _buildCategoryTable(context, rows, colors, isDark),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCheckTopBar(BuildContext context, List<_CategoryRowData> rows, AppColorsExtension colors, bool isDark) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title
          Text(
            'CategoryCheck',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),

          // Actions: Export & Filter
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue Export Button
              if (AuthService.instance.currentPermissions.canExportCategoryCheck) ...[
                InkWell(
                  onTap: () => _exportCategoryCheck(context, rows),
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
                          'Export',
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
                const SizedBox(width: 14),
              ],

              // Filter Icon
              IconButton(
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                },
                icon: Icon(Icons.filter_list_rounded, color: colors.textSecondary, size: 22),
                tooltip: 'Sort CategoryCode',
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTable(BuildContext context, List<_CategoryRowData> rows, AppColorsExtension colors, bool isDark) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.6),
        3: FixedColumnWidth(48),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header Row
        TableRow(
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withAlpha(isDark ? 70 : 120),
            border: Border(bottom: BorderSide(color: colors.border, width: 1)),
          ),
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CategoryCode',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Cat_ERP_sqm',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Cat_App_sqm',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ),
            const SizedBox.shrink(),
          ],
        ),

        // Data Rows
        ...rows.map((row) {
          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border, width: 1)),
            ),
            children: [
              _buildRowInkWell(
                row.categoryCode,
                Text(
                  '${row.categoryCode}',
                  style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                ),
                isDark,
              ),
              _buildRowInkWell(
                row.categoryCode,
                Text(
                  _fmt.format(row.erpSqm),
                  style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                ),
                isDark,
              ),
              _buildRowInkWell(
                row.categoryCode,
                Text(
                  _fmt.format(row.appSqm),
                  style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                ),
                isDark,
              ),
              _buildRowInkWell(
                row.categoryCode,
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 20),
                ),
                isDark,
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildRowInkWell(int categoryCode, Widget child, bool isDark) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategoryCode = categoryCode;
        });
      },
      splashColor: isDark ? Colors.white10 : Colors.black12,
      hoverColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: child,
      ),
    );
  }

  Future<void> _exportCategoryCheck(BuildContext context, List<_CategoryRowData> rows) async {
    final headers = ['CategoryCode', 'Cat_ERP_sqm', 'Cat_App_sqm'];
    final dataRows = rows.map((r) => [
      r.categoryCode,
      _fmt.format(r.erpSqm),
      _fmt.format(r.appSqm),
    ]).toList();

    await ExportUtils.exportCsv(
      context,
      defaultFileName: 'CategoryCheck',
      headers: headers,
      rows: dataRows,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCREEN 2: Data Chek Detail Drill-Down (Exact match to Image 2)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDataChekView(BuildContext context, int categoryCode) {
    final state = AppStateScope.of(context);

    // Filter audits for this categoryCode
    final audits = state.materialAudits.values
        .where((a) => a.categoryCode == categoryCode)
        .toList();

    // Also include any materials belonging to this categoryCode
    final catMaterials = state.materials.where((m) => m.categoryCode == categoryCode).toList();
    for (final mat in catMaterials) {
      if (!audits.any((a) => a.materialId == mat.id || a.codeText == mat.materialCode)) {
        audits.add(MaterialAuditRecord(
          materialId: mat.id,
          codeText: mat.materialCode,
          categoryCode: categoryCode,
          appSqmOverride: mat.totalAreaSqm,
        ));
      }
    }

    // Sort by codeText ascending (e.g. 1201, 1202, ...)
    audits.sort((a, b) => a.codeText.compareTo(b.codeText));

    // Keep _selectedAudit up to date
    MaterialAuditRecord? currentSelected;
    int currentIndex = -1;
    if (_selectedAudit != null) {
      currentIndex = audits.indexWhere((a) => a.materialId == _selectedAudit!.materialId);
      if (currentIndex != -1) {
        currentSelected = audits[currentIndex];
      } else {
        currentSelected = _selectedAudit;
      }
    }

    final isWide = MediaQuery.of(context).size.width >= 900;
    final isMobile = MediaQuery.of(context).size.width < 680;
    final panelWidth = _isPanelExpanded
        ? MediaQuery.of(context).size.width
        : (isWide ? 490.0 : MediaQuery.of(context).size.width * 0.9);

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar with Breadcrumbs & export 2
            _buildDataChekTopBar(context, categoryCode, audits, colors, isDark),
            Divider(color: colors.border, height: 1, thickness: 1),

            // Scrollable Data Table + Right-Side Detail Panel
            Expanded(
              child: isMobile
                  ? (audits.isEmpty
                      ? Center(
                          child: Text(
                            'No audit records found for category $categoryCode',
                            style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 14),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildDataChekTable(context, state, audits, currentSelected, colors, isDark),
                          ),
                        ))
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: audits.isEmpty
                              ? Center(
                                  child: Text(
                                    'No audit records found for category $categoryCode',
                                    style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 14),
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: _buildDataChekTable(context, state, audits, currentSelected, colors, isDark),
                                  ),
                                ),
                        ),

                        // Right-side detail panel on tablet / desktop
                        if (currentSelected != null)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: panelWidth,
                            child: DataCheckDetailPanel(
                              audit: currentSelected,
                              allRecords: audits,
                              currentIndex: currentIndex != -1 ? currentIndex : 0,
                              isExpanded: _isPanelExpanded,
                              onClose: () {
                                setState(() {
                                  _selectedAudit = null;
                                  _isPanelExpanded = false;
                                });
                              },
                              onNavigate: (newAudit) {
                                setState(() {
                                  _selectedAudit = newAudit;
                                });
                              },
                              onToggleExpand: () {
                                setState(() {
                                  _isPanelExpanded = !_isPanelExpanded;
                                });
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

  Widget _buildDataChekTopBar(BuildContext context, int categoryCode, List<MaterialAuditRecord> audits, AppColorsExtension colors, bool isDark) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumbs: CategoryCheck > Data Chek
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryCode = null;
                  });
                },
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
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: colors.textDisabled),
              const SizedBox(width: 8),
              Text(
                'Data Chek',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),

          // Action: export 2 Button
          InkWell(
            onTap: () => _exportDataChek(context, categoryCode, audits),
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
      ),
    );
  }

  Widget _buildDataChekTable(
    BuildContext context,
    dynamic state,
    List<MaterialAuditRecord> audits,
    MaterialAuditRecord? selected,
    AppColorsExtension colors,
    bool isDark,
  ) {
    // Columns list exactly as in Image 2
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
      border: TableBorder(
        bottom: BorderSide(color: colors.border, width: 1),
      ),
      headingTextStyle: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      dataTextStyle: GoogleFonts.inter(
        fontSize: 13,
        color: colors.textPrimary,
      ),
      columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
      rows: audits.map((audit) {
        final isSelected = selected?.materialId == audit.materialId;

        // App Sqm: live slabs or override
        final slabs = state.slabsForMaterial(audit.materialId);
        final liveAppSqm = slabs.isNotEmpty
            ? slabs.fold(0.0, (s, sl) => s + (sl as dynamic).areaSqm)
            : (audit.appSqmOverride ?? 0.0);

        final erpBalance = audit.erpBalanceSqm;
        final appVsErp = liveAppSqm - erpBalance;
        final physicalSqmStr = audit.physicalSqm != null && audit.isCounted
            ? _fmt.format(audit.physicalSqm)
            : '';

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
            if (MediaQuery.sizeOf(context).width < 680) {
              final idx = audits.indexWhere((a) => a.materialId == audit.materialId);
              _openMobileDetailSheet(context, audit, audits, idx >= 0 ? idx : 0);
            } else {
              setState(() {
                _selectedAudit = audit;
              });
            }
          },
          cells: [
            // CodeText
            DataCell(Text(audit.codeText, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colors.textPrimary))),

            // ERP_Balance_sqm
            DataCell(Text(_fmt.format(erpBalance), style: TextStyle(color: colors.textPrimary))),

            // App_sqm
            DataCell(Text(_fmt.format(liveAppSqm), style: TextStyle(color: colors.textPrimary))),

            // Physical_sqm
            DataCell(Text(physicalSqmStr, style: TextStyle(color: colors.textPrimary))),

            // CheckStatus
            DataCell(Text(audit.checkStatus, style: TextStyle(color: colors.textPrimary))),

            // App_vs_ERP
            DataCell(Text(_fmt.format(appVsErp), style: TextStyle(color: colors.textPrimary))),

            // ERP_In_sqm
            DataCell(Text(_fmt.format(audit.erpInSqm), style: TextStyle(color: colors.textPrimary))),

            // ERP_Out_sqm
            DataCell(Text(_fmt.format(audit.erpOutSqm), style: TextStyle(color: colors.textPrimary))),

            // LastERPUpdate
            DataCell(Text(audit.lastErpUpdate, style: TextStyle(color: colors.textSecondary))),

            // Notes
            DataCell(Text(audit.notes, style: TextStyle(color: colors.textSecondary))),

            // LastCountDate
            DataCell(Text(audit.lastCountDate, style: TextStyle(color: colors.textSecondary))),

            // Trailing Chevron
            DataCell(
              InkWell(
                onTap: () {
                  if (MediaQuery.sizeOf(context).width < 680) {
                    final idx = audits.indexWhere((a) => a.materialId == audit.materialId);
                    _openMobileDetailSheet(context, audit, audits, idx >= 0 ? idx : 0);
                  } else {
                    setState(() {
                      _selectedAudit = audit;
                    });
                  }
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

  Future<void> _exportDataChek(BuildContext context, int categoryCode, List<MaterialAuditRecord> audits) async {
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

    final dataRows = audits.map((a) {
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
      defaultFileName: 'DataCheck_Category_$categoryCode',
      headers: headers,
      rows: dataRows,
    );
  }

  void _openMobileDetailSheet(
    BuildContext context,
    MaterialAuditRecord audit,
    List<MaterialAuditRecord> records,
    int idx,
  ) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final cur = records[idx.clamp(0, records.length - 1)];
          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.98,
            expand: false,
            builder: (c, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: DataCheckDetailPanel(
                audit: cur,
                allRecords: records,
                currentIndex: idx,
                isExpanded: true,
                onClose: () => Navigator.pop(ctx),
                onNavigate: (newAudit) {
                  final newIdx = records.indexWhere((a) => a.materialId == newAudit.materialId);
                  if (newIdx != -1) {
                    setModalState(() => idx = newIdx);
                  }
                },
                onToggleExpand: () {},
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryRowData {
  final int categoryCode;
  double erpSqm = 0.0;
  double appSqm = 0.0;

  _CategoryRowData({
    required this.categoryCode,
  });
}
