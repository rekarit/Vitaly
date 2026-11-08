import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/rack.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// Rack Details and Edit Dialogs
/// Exact replication of AppSheet Screenshots 4 & 5
/// Screenshot 4: Rack Details View (Header with Delete, Edit button, Navigation)
/// Screenshot 5: Rack Edit Form (RackCode*, RackName, Warehouse, Active*, LocationType)
/// ──────────────────────────────────────────────────────────────────────────

class RackDetailDialog extends StatelessWidget {
  final Rack rack;

  const RackDetailDialog({super.key, required this.rack});

  static Future<void> show(BuildContext context, Rack rack) {
    return AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => RackDetailDialog(rack: rack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final colors = context.colors;
    final currentRack = appState.rackByCode(rack.rackCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B1D21) : colors.surface;
    final dividerColor = isDark ? Colors.white12 : colors.border;
    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - (isMobile ? 16 : 48)).clamp(220.0, 750.0);

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: availableHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header Bar (Matching Screenshot 4) ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    currentRack.rackName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Delete Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: dividerColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.delete_outline, size: 18, color: colors.textSecondary),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: dialogBg,
                          title: Text('Delete Rack', style: TextStyle(color: colors.textPrimary)),
                          content: Text(
                            'Are you sure you want to delete rack "${currentRack.rackCode}"?',
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
                      if (confirm == true && context.mounted) {
                        appState.deleteRack(currentRack.rackCode);
                        Navigator.pop(context);
                      }
                    },
                    tooltip: 'Delete',
                  ),
                  const SizedBox(width: 8),
                  // Edit Button (Blue highlighted button matching Screenshot 4)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF86B9E0),
                      foregroundColor: const Color(0xFF111418),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _showRackEditDialog(context, currentRack);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Close IconButton
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: dividerColor, height: 1),

            // ── Body Fields (Matching Screenshot 4) ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItem('RackName', currentRack.rackName, colors),
                  const SizedBox(height: 18),
                  _buildDetailItem('RackCode', currentRack.rackCode, colors),
                  const SizedBox(height: 18),
                  _buildDetailItem('Warehouse', currentRack.warehouse, colors),
                  const SizedBox(height: 18),
                  _buildDetailItem('Active', currentRack.active, colors),
                  const SizedBox(height: 18),
                  _buildDetailItem('LocationType', currentRack.locationType, colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  static void _showRackEditDialog(BuildContext context, Rack rack) {
    AdaptiveDialog.show(
      context: context,
      isDismissible: false,
      builder: (ctx) => RackEditDialog(rack: rack),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────
/// Rack Edit Form (Matching Screenshot 5)
/// Fields: RackCode*, RackName, Warehouse, Active* (toggle), LocationType (Yard | Field)
/// ──────────────────────────────────────────────────────────────────────────
class RackEditDialog extends StatefulWidget {
  final Rack rack;

  const RackEditDialog({super.key, required this.rack});

  @override
  State<RackEditDialog> createState() => _RackEditDialogState();
}

class _RackEditDialogState extends State<RackEditDialog> {
  late TextEditingController _rackCodeCtrl;
  late TextEditingController _rackNameCtrl;
  late TextEditingController _warehouseCtrl;
  late String _active;
  late String _locationType;

  @override
  void initState() {
    super.initState();
    _rackCodeCtrl = TextEditingController(text: widget.rack.rackCode);
    _rackNameCtrl = TextEditingController(text: widget.rack.rackName);
    _warehouseCtrl = TextEditingController(text: widget.rack.warehouse);
    _active = widget.rack.active;
    _locationType = widget.rack.locationType;
  }

  @override
  void dispose() {
    _rackCodeCtrl.dispose();
    _rackNameCtrl.dispose();
    _warehouseCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final code = _rackCodeCtrl.text.trim();
    if (code.isEmpty) return;

    final updated = widget.rack.copyWith(
      rackCode: code,
      rackName: _rackNameCtrl.text.trim().isNotEmpty ? _rackNameCtrl.text.trim() : code,
      warehouse: _warehouseCtrl.text.trim().isNotEmpty ? _warehouseCtrl.text.trim() : 'Warehouse',
      active: _active,
      locationType: _locationType,
    );

    final appState = AppStateScope.read(context);
    appState.updateRack(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1B1D21) : colors.surface;
    final closeIconColor = isDark ? Colors.white : colors.textPrimary;
    final inputBg = isDark ? const Color(0xFF1F2228) : colors.surfaceVariant;
    final inputBorder = isDark ? const Color(0xFF3B4048) : colors.border;
    final inactiveToggleBg = isDark ? const Color(0xFF1F2228) : colors.surfaceVariant;
    final inactiveTextColor = isDark ? Colors.white70 : colors.textSecondary;

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - (isMobile ? 16 : 48)).clamp(220.0, 750.0);

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header (Matching Screenshot 5: ✕ [Title] [Cancel] [Save]) ──
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: closeIconColor),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.rack.rackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cancel Button
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF86B9E0),
                      side: const BorderSide(color: Color(0xFF86B9E0)),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF86B9E0),
                      foregroundColor: const Color(0xFF111418),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    onPressed: _save,
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Input Fields in Scrollable Body ───────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // RackCode*
              _buildLabel('RackCode', colors, isRequired: true),
              const SizedBox(height: 6),
              _buildInputContainer(
                inputBg: inputBg,
                inputBorder: inputBorder,
                child: TextField(
                  controller: _rackCodeCtrl,
                  style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // RackName
              _buildLabel('RackName', colors),
              const SizedBox(height: 6),
              _buildInputContainer(
                inputBg: inputBg,
                inputBorder: inputBorder,
                child: TextField(
                  controller: _rackNameCtrl,
                  style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Warehouse
              _buildLabel('Warehouse', colors),
              const SizedBox(height: 6),
              _buildInputContainer(
                inputBg: inputBg,
                inputBorder: inputBorder,
                child: TextField(
                  controller: _warehouseCtrl,
                  style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Active* (Blue button toggle matching Screenshot 5)
              _buildLabel('Active', colors, isRequired: true),
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  setState(() {
                    _active = _active == 'Y' ? 'N' : 'Y';
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: double.infinity,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _active == 'Y' ? const Color(0xFF86B9E0) : inactiveToggleBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: inputBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _active,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _active == 'Y' ? const Color(0xFF111418) : inactiveTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // LocationType (Yard | Field toggle buttons matching Screenshot 5)
              _buildLabel('LocationType', colors),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _locationType = 'Yard'),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: _locationType == 'Yard' ? const Color(0xFF86B9E0) : inactiveToggleBg,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                          border: Border.all(color: inputBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Yard',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _locationType == 'Yard' ? const Color(0xFF111418) : inactiveTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _locationType = 'Field'),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: _locationType == 'Field' ? const Color(0xFF86B9E0) : inactiveToggleBg,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                          border: Border.all(color: inputBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Field',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _locationType == 'Field' ? const Color(0xFF111418) : inactiveTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
),
);
  }

  Widget _buildLabel(String label, AppColorsExtension colors, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFF86B9E0), fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildInputContainer({
    required Widget child,
    required Color inputBg,
    required Color inputBorder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: inputBorder),
      ),
      child: child,
    );
  }
}
