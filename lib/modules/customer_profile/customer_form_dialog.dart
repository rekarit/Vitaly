import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/customer.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';

/// Customers Form Dialog matching Screenshot 1 exactly
/// Supports both creating a new customer and editing an existing customer.
class CustomersFormDialog extends StatefulWidget {
  final Customer? customerToEdit;
  final ValueChanged<Customer>? onSaved;

  const CustomersFormDialog({
    super.key,
    this.customerToEdit,
    this.onSaved,
  });

  static Future<Customer?> show(
    BuildContext context, {
    Customer? customerToEdit,
    ValueChanged<Customer>? onSaved,
  }) {
    return AdaptiveDialog.show<Customer?>(
      context: context,
      isDismissible: true,
      builder: (ctx) => CustomersFormDialog(
        customerToEdit: customerToEdit,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<CustomersFormDialog> createState() => _CustomersFormDialogState();
}

class _CustomersFormDialogState extends State<CustomersFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;
  String? _errorMsg;

  bool get isEditing => widget.customerToEdit != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customerToEdit;
    _nameCtrl = TextEditingController(text: c?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _addressCtrl = TextEditingController(text: c?.address.isNotEmpty == true ? c!.address : (c?.city ?? ''));
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMsg = 'CustomerName is required');
      return;
    }

    final appState = AppStateScope.read(context);
    Customer savedCustomer;

    if (isEditing) {
      final existing = widget.customerToEdit!;
      appState.updateCustomer(
        id: existing.id,
        fullName: name,
        phone: phone,
        email: email,
        address: address,
        city: address,
        notes: notes,
      );
      savedCustomer = existing.copyWith(
        fullName: name,
        phone: phone,
        email: email,
        address: address,
        city: address,
        notes: notes,
      );
    } else {
      savedCustomer = appState.addCustomer(
        fullName: name,
        phone: phone,
        email: email,
        address: address,
        city: address,
        notes: notes,
      );
    }

    widget.onSaved?.call(savedCustomer);
    Navigator.of(context).pop(savedCustomer);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEditing
                    ? 'Customer "$name" updated successfully'
                    : 'Customer "$name" created successfully',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: context.colors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(320.0, 780.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Bar: [X] Customers Form       [Cancel] [Save] ──
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Customers Form',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.border),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF72B4F8),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: _save,
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 14),

              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: GoogleFonts.inter(fontSize: 12.5, color: colors.error, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Inputs Matching Screenshot 1 ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormField(
                        label: 'CustomerName',
                        controller: _nameCtrl,
                        colors: colors,
                        isDark: isDark,
                        hintText: 'Enter customer or company name',
                        isRequired: true,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 14),

                      _buildFormField(
                        label: 'Phone',
                        controller: _phoneCtrl,
                        colors: colors,
                        isDark: isDark,
                        hintText: 'e.g. +964 750 123 4567',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),

                      _buildFormField(
                        label: 'Email',
                        controller: _emailCtrl,
                        colors: colors,
                        isDark: isDark,
                        hintText: 'e.g. client@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      _buildFormField(
                        label: 'Address',
                        controller: _addressCtrl,
                        colors: colors,
                        isDark: isDark,
                        hintText: 'Street, District, City',
                        keyboardType: TextInputType.streetAddress,
                      ),
                      const SizedBox(height: 14),

                      _buildFormField(
                        label: 'Notes',
                        controller: _notesCtrl,
                        colors: colors,
                        isDark: isDark,
                        hintText: 'Additional customer specifications, payment terms...',
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 10),
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

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required AppColorsExtension colors,
    required bool isDark,
    String? hintText,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 3),
              const Text('*', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.inter(
                fontSize: 12.5,
                color: colors.textDisabled,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
