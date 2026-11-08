import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';

/// Modal dialog requiring user (specifically SuperAdmin on initial login or credentials reset)
/// to establish a new username and password with confirmation.
class ChangeCredentialsDialog extends StatefulWidget {
  final bool isMandatory;
  final VoidCallback onSuccess;

  const ChangeCredentialsDialog({
    super.key,
    this.isMandatory = true,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    bool isMandatory = true,
    required VoidCallback onSuccess,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (_) => ChangeCredentialsDialog(
        isMandatory: isMandatory,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<ChangeCredentialsDialog> createState() => _ChangeCredentialsDialogState();
}

class _ChangeCredentialsDialogState extends State<ChangeCredentialsDialog> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final current = AuthService.instance.currentUser;
    if (current != null) {
      _usernameCtrl.text = current.username;
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _usernameCtrl.text.trim();
    final newPassword = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match. Please re-enter.';
      });
      return;
    }

    if (newPassword == AuthService.defaultSuperAdminPassword &&
        newUsername == AuthService.defaultSuperAdminUsername) {
      setState(() {
        _errorMessage = 'Please choose credentials different from default factory settings.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthService.instance.updateCredentials(
      newUsername: newUsername,
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      widget.onSuccess();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Username "$newUsername" is already taken. Please choose another.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return PopScope(
      canPop: !widget.isMandatory,
      child: Dialog(
        backgroundColor: colors.surface,
        insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shield Icon & Title
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.primary.withAlpha(80)),
                          ),
                          child: Icon(Icons.security_rounded, color: colors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security Requirement',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Update default credentials to proceed',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(color: colors.border, height: 1),
                    const SizedBox(height: 18),

                    // Information Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.primary.withAlpha(45)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: colors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'For security governance, default SuperAdmin credentials must be changed upon first access.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: colors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: colors.error.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.error.withAlpha(70)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.inter(fontSize: 12, color: colors.error, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // New Username
                    Text(
                      'New Username',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _usernameCtrl,
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter new username',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Username is required';
                        if (val.trim().length < 3) return 'At least 3 characters required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // New Password
                    Text(
                      'New Password',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter new password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: colors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: colors.textSecondary),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Password is required';
                        if (val.length < 5) return 'At least 5 characters required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password
                    Text(
                      'Confirm New Password',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirm,
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Re-enter new password',
                        prefixIcon: Icon(Icons.check_circle_outline_rounded, size: 18, color: colors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18, color: colors.textSecondary),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Please confirm password';
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text(
                                'Save & Enter SuperAdmin Dashboard',
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
