import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/material_audit_record.dart';
import '../../core/services/auth_service.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';

class DataCheckDetailPanel extends StatefulWidget {
  final MaterialAuditRecord audit;
  final List<MaterialAuditRecord> allRecords;
  final int currentIndex;
  final VoidCallback onClose;
  final ValueChanged<MaterialAuditRecord> onNavigate;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const DataCheckDetailPanel({
    super.key,
    required this.audit,
    required this.allRecords,
    required this.currentIndex,
    required this.onClose,
    required this.onNavigate,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  State<DataCheckDetailPanel> createState() => _DataCheckDetailPanelState();
}

class _DataCheckDetailPanelState extends State<DataCheckDetailPanel> {
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');
  late TextEditingController _physicalCtrl;
  late TextEditingController _notesCtrl;
  late bool _isCounted;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  @override
  void didUpdateWidget(covariant DataCheckDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.materialId != widget.audit.materialId) {
      _initValues();
    }
  }

  void _initValues() {
    _physicalCtrl = TextEditingController(
      text: widget.audit.physicalSqm != null
          ? widget.audit.physicalSqm!.toStringAsFixed(2)
          : '',
    );
    _notesCtrl = TextEditingController(text: widget.audit.notes);
    _isCounted = widget.audit.isCounted;
  }

  @override
  void dispose() {
    _physicalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (widget.currentIndex > 0) {
      widget.onNavigate(widget.allRecords[widget.currentIndex - 1]);
    }
  }

  void _goToNext() {
    if (widget.currentIndex < widget.allRecords.length - 1) {
      widget.onNavigate(widget.allRecords[widget.currentIndex + 1]);
    }
  }

  void _saveChanges(dynamic state, double liveAppSqm) {
    final parsedPhysical = double.tryParse(_physicalCtrl.text.trim());
    final nowStr = DateFormat('M/d/yyyy').format(DateTime.now());

    state.updateAudit(
      widget.audit.materialId,
      physicalSqm: parsedPhysical,
      isCounted: _isCounted,
      erpIn: widget.audit.erpInSqm,
      erpOut: widget.audit.erpOutSqm,
      erpBalanceOverride: widget.audit.erpBalanceOverride,
      appSqmOverride: liveAppSqm,
      notes: _notesCtrl.text.trim().isNotEmpty
          ? _notesCtrl.text.trim()
          : widget.audit.notes,
      lastCountDate: _isCounted
          ? (widget.audit.lastCountDate.isNotEmpty
              ? widget.audit.lastCountDate
              : nowStr)
          : '',
      materialName: widget.audit.materialName,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved audit changes for ${widget.audit.displayName}',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4A90E2),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final audit = widget.audit;

    // App Sqm: live slabs or override
    final slabs = state.slabsForMaterial(audit.materialId);
    final liveAppSqm = slabs.isNotEmpty
        ? slabs.fold(0.0, (s, sl) => s + (sl as dynamic).areaSqm)
        : (audit.appSqmOverride ?? 0.0);

    final erpBalance = audit.erpBalanceSqm;
    final appVsErp = liveAppSqm - erpBalance;

    final hasPrev = widget.currentIndex > 0;
    final hasNext = widget.currentIndex < widget.allRecords.length - 1;

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          left: BorderSide(color: colors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 25),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header Bar (Matching Screenshot 2) ──────────────────────────
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(color: colors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Left: Expand / Contract Toggle Icon
                IconButton(
                  icon: Icon(
                    widget.isExpanded
                        ? Icons.close_fullscreen_rounded
                        : Icons.open_in_full_rounded,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  tooltip: widget.isExpanded ? 'Restore' : 'Expand',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onToggleExpand,
                ),
                const SizedBox(width: 8),

                // Title: "1201 - CALACATTA GOLD"
                Expanded(
                  child: Text(
                    audit.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Navigation: < >
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: hasPrev ? colors.textPrimary : colors.textDisabled,
                  ),
                  tooltip: 'Previous',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: hasPrev ? _goToPrevious : null,
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: hasNext ? colors.textPrimary : colors.textDisabled,
                  ),
                  tooltip: 'Next',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: hasNext ? _goToNext : null,
                ),
                const SizedBox(width: 4),

                // Fullscreen toggle
                IconButton(
                  icon: Icon(
                    widget.isExpanded
                        ? Icons.close_fullscreen_rounded
                        : Icons.fullscreen_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  tooltip: 'Fullscreen',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onToggleExpand,
                ),

                // Close Button X
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  tooltip: 'Close',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // ── Scrollable Body with Left Scrollbar (Matching Screenshot 2) ──
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big Prominent Code (e.g. "1201")
                    Text(
                      audit.codeText,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle with warning icon: ⚠️ 1201 - CALACATTA GOLD
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.textPrimary.withAlpha(12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 22,
                            color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            audit.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: colors.border, height: 1),
                    const SizedBox(height: 20),

                    // ── Key Metrics Cards ─────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'ERP Balance',
                            value: '${_fmt.format(erpBalance)} m²',
                            color: const Color(0xFF4A90E2),
                            colors: colors,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'App Area',
                            value: '${_fmt.format(liveAppSqm)} m²',
                            color: const Color(0xFF00E676),
                            colors: colors,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'App vs ERP',
                            value:
                                '${appVsErp > 0 ? '+' : ''}${_fmt.format(appVsErp)} m²',
                            color: appVsErp.abs() > 0.01
                                ? const Color(0xFFFFB74D)
                                : const Color(0xFF00E676),
                            colors: colors,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Status',
                            value: _isCounted ? 'COUNTED' : 'NOT COUNTED',
                            color: _isCounted
                                ? const Color(0xFF00E676)
                                : const Color(0xFFE57373),
                            colors: colors,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Physical Count & Audit Status Form ─────────────────────
                    _buildSectionHeader('Physical Inventory Audit', colors),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Counted toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Audit Verification',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isCounted = !_isCounted;
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _isCounted
                                        ? const Color(0xFF00E676).withAlpha(isDark ? 30 : 40)
                                        : colors.textPrimary.withAlpha(isDark ? 15 : 10),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _isCounted
                                          ? const Color(0xFF00E676)
                                          : colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isCounted
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        size: 14,
                                        color: _isCounted
                                            ? const Color(0xFF00E676)
                                            : colors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isCounted ? 'COUNTED' : 'NOT COUNTED',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _isCounted
                                              ? const Color(0xFF00E676)
                                              : colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Physical Sqm input
                          Text(
                            'Physical_sqm (Counted Area)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _physicalCtrl,
                                  readOnly: !AuthService.instance.currentPermissions.canEditAuditRecord,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: GoogleFonts.inter(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter counted sqm...',
                                    hintStyle: GoogleFonts.inter(
                                        color: colors.textDisabled),
                                    filled: true,
                                    fillColor: colors.surface,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.textPrimary,
                                  side: BorderSide(color: colors.border),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _physicalCtrl.text =
                                        liveAppSqm.toStringAsFixed(2);
                                    _isCounted = true;
                                  });
                                },
                                child: Text('Use App',
                                    style: GoogleFonts.inter(fontSize: 11.5)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Notes input
                          Text(
                            'Notes',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _notesCtrl,
                            readOnly: !AuthService.instance.currentPermissions.canEditAuditRecord,
                            maxLines: 2,
                            style: GoogleFonts.inter(
                              color: colors.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add notes...',
                              hintStyle: GoogleFonts.inter(
                                  color: colors.textDisabled),
                              filled: true,
                              fillColor: colors.surface,
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── ERP Movement Details ──────────────────────────────────
                    _buildSectionHeader('ERP Movement Summary Details', colors),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('ERP_In_sqm',
                              '${_fmt.format(audit.erpInSqm)} m²', colors),
                          Divider(color: colors.border, height: 16),
                          _buildDetailRow('ERP_Out_sqm',
                              '${_fmt.format(audit.erpOutSqm)} m²', colors),
                          Divider(color: colors.border, height: 16),
                          _buildDetailRow('LastERPUpdate', audit.lastErpUpdate, colors),
                          Divider(color: colors.border, height: 16),
                          _buildDetailRow(
                            'LastCountDate',
                            audit.lastCountDate.isNotEmpty
                                ? audit.lastCountDate
                                : '—',
                            colors,
                          ),
                          Divider(color: colors.border, height: 16),
                          _buildDetailRow('CategoryCode', '${audit.categoryCode}', colors),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Save / Apply Button (Permission Guarded)
                    if (AuthService.instance.currentPermissions.canEditAuditRecord) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () => _saveChanges(state, liveAppSqm),
                          icon: const Icon(Icons.check_rounded,
                              size: 18, color: Colors.white),
                          label: Text(
                            'Save Changes',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColorsExtension colors) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required AppColorsExtension colors,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(isDark ? 40 : 80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppColorsExtension colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
