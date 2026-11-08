import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../models/customer.dart';
import '../state/app_state_scope.dart';
import '../theme/responsive.dart';

/// Comprehensive Customer Registration Dialog
/// Provides full customer profile entry matching the design system.
void showCustomerRegistrationDialog(BuildContext context, ValueChanged<Customer> onAdded) {
  final nameCtrl = TextEditingController();
  final compCtrl = TextEditingController();
  final phCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final addrCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final colors = context.colors;

  AdaptiveDialog.show<void>(
    context: context,
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      final isMobile = ctx.isMobile;
      final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(260.0, 760.0);

      return Dialog(
        backgroundColor: colors.surface,
        insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 620, maxHeight: availableHeight),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person_add_rounded, color: colors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Registration',
                            style: GoogleFonts.inter(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                          Text(
                            'Register new customer account',
                            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: colors.border, height: 1),
                const SizedBox(height: 14),
                // ── Form Inputs ────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (isMobile) ...[
                          _buildRegField('Full Name', nameCtrl, colors, isRequired: true),
                          const SizedBox(height: 12),
                          _buildRegField('Company / Organization', compCtrl, colors),
                          const SizedBox(height: 12),
                          _buildRegField('Phone Number', phCtrl, colors, isRequired: true, keyboard: TextInputType.phone),
                          const SizedBox(height: 12),
                          _buildRegField('Email Address', emailCtrl, colors, keyboard: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _buildRegField('Street Address', addrCtrl, colors),
                          const SizedBox(height: 12),
                          _buildRegField('City / Region', cityCtrl, colors),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: _buildRegField('Full Name', nameCtrl, colors, isRequired: true)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildRegField('Company / Organization', compCtrl, colors)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildRegField('Phone Number', phCtrl, colors, isRequired: true, keyboard: TextInputType.phone)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildRegField('Email Address', emailCtrl, colors, keyboard: TextInputType.emailAddress)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(flex: 3, child: _buildRegField('Street Address', addrCtrl, colors)),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: _buildRegField('City / Region', cityCtrl, colors)),
                            ],
                          ),
                        ],
                      const SizedBox(height: 14),
                      _buildRegField('Customer Notes & Terms', notesCtrl, colors, maxLines: 3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 16),
              // ── Actions ────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty || phCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Please enter Full Name and Phone Number'),
                            backgroundColor: colors.warning,
                          ),
                        );
                        return;
                      }
                      final newC = AppStateScope.read(context).addCustomer(
                        fullName: nameCtrl.text.trim(),
                        company: compCtrl.text.trim(),
                        phone: phCtrl.text.trim(),
                        address: addrCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                      );
                      Navigator.pop(ctx);
                      onAdded(newC);
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.background,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  },
);
}

Widget _buildRegField(String label, TextEditingController ctrl, AppColorsExtension colors, {bool isRequired = false, TextInputType? keyboard, int maxLines = 1}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
          children: isRequired ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.blueAccent))] : null,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.primary, width: 1.5)),
        ),
      ),
    ],
  );
}
