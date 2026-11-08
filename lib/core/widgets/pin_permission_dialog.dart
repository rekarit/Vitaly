import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PIN PERMISSION DIALOG
/// Prompts the user for a 4-digit security PIN before executing protected actions.
/// Current static PIN for test phase: "0101"
/// ─────────────────────────────────────────────────────────────────────────────
class PinPermissionDialog extends StatefulWidget {
  final String actionTitle;
  final String? title;
  final String? subtitle;
  final String? confirmText;
  final String? cancelText;
  final String? incorrectPinMessage;
  final String? showCodeText;
  final String? hideCodeText;

  static const String staticPin = '0101';

  const PinPermissionDialog({
    super.key,
    this.actionTitle = '',
    this.title,
    this.subtitle,
    this.confirmText,
    this.cancelText,
    this.incorrectPinMessage,
    this.showCodeText,
    this.hideCodeText,
  });

  /// Static helper to show the dialog and return true if authorized.
  static Future<bool> request(
    BuildContext context, {
    String actionTitle = '',
    String? title,
    String? subtitle,
    String? confirmText,
    String? cancelText,
    String? incorrectPinMessage,
    String? showCodeText,
    String? hideCodeText,
  }) async {
    final result = await AdaptiveDialog.show<bool>(
      context: context,
      isDismissible: true,
      builder: (ctx) => PinPermissionDialog(
        actionTitle: actionTitle,
        title: title,
        subtitle: subtitle,
        confirmText: confirmText,
        cancelText: cancelText,
        incorrectPinMessage: incorrectPinMessage,
        showCodeText: showCodeText,
        hideCodeText: hideCodeText,
      ),
    );
    return result ?? false;
  }

  @override
  State<PinPermissionDialog> createState() => _PinPermissionDialogState();
}

class _PinPermissionDialogState extends State<PinPermissionDialog> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _errorMessage = '';
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyPin(String input) {
    if (input.length < 4) return;

    if (input == PinPermissionDialog.staticPin) {
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = widget.incorrectPinMessage ?? 'Incorrect PIN entered, please try again';
        _pinController.clear();
      });
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = context.isMobile;

    final currentPin = _pinController.text;

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Icon Header
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(25),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary.withAlpha(80), width: 1.5),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                widget.title ?? 'Permission Required',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Prompt description as requested
              Text(
                widget.subtitle ?? 'You need permission for this action. Please enter the 4-digit PIN.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
              ),

              if (widget.actionTitle.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      widget.actionTitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Off-stage or overlay hidden text field to capture keyboard input
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.0,
                    child: TextField(
                      controller: _pinController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      autofocus: true,
                      onChanged: (val) {
                        setState(() {
                          _errorMessage = '';
                        });
                        if (val.length == 4) {
                          _verifyPin(val);
                        }
                      },
                      onSubmitted: (val) => _verifyPin(val),
                    ),
                  ),

                  // Interactive 4 PIN digit boxes
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _focusNode.requestFocus(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final hasValue = index < currentPin.length;
                        final isFocusedBox = index == currentPin.length;
                        final char = hasValue
                            ? (_obscurePin ? '•' : currentPin[index])
                            : '';

                        return Container(
                          width: isMobile ? 50 : 58,
                          height: isMobile ? 54 : 62,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _errorMessage.isNotEmpty
                                  ? colors.error
                                  : isFocusedBox
                                      ? colors.primary
                                      : hasValue
                                          ? colors.primary.withAlpha(160)
                                          : colors.border,
                              width: isFocusedBox || hasValue ? 2 : 1.2,
                            ),
                            boxShadow: isFocusedBox
                                ? [
                                    BoxShadow(
                                      color: colors.primary.withAlpha(40),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            char,
                            style: GoogleFonts.robotoMono(
                              fontSize: _obscurePin && hasValue ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),

              // Visibility toggle button
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  icon: Icon(
                    _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  label: Text(
                    _obscurePin
                        ? (widget.showCodeText ?? 'Show PIN')
                        : (widget.hideCodeText ?? 'Hide PIN'),
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),

              // Error feedback
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 15, color: colors.error),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons: Cancel & Confirm
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        widget.cancelText ?? 'Cancel',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: isDark ? const Color(0xFF111418) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: currentPin.length == 4
                          ? () => _verifyPin(currentPin)
                          : null,
                      child: Text(
                        widget.confirmText ?? 'Confirm',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
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
