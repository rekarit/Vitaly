import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../../modules/admin/change_credentials_dialog.dart';
import '../../modules/navigation/login_screen.dart';

/// Modal dialog displaying user details, role, status, and account actions.
class UserProfileDialog extends StatelessWidget {
  const UserProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const UserProfileDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = AuthService.instance.currentUser;
    final isSuperAdmin = AuthService.instance.isSuperAdmin;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Profile Avatar & Info ────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSuperAdmin
                            ? [colors.primary, const Color(0xFFD97706)]
                            : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isSuperAdmin ? colors.primary : const Color(0xFF3B82F6)).withAlpha(60),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user?.username.isNotEmpty == true ? user!.username[0].toUpperCase() : 'U',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.username ?? 'User',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isSuperAdmin ? colors.primary : const Color(0xFF3B82F6)).withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (isSuperAdmin ? colors.primary : const Color(0xFF3B82F6)).withAlpha(80),
                                ),
                              ),
                              child: Text(
                                user?.roleName ?? (isSuperAdmin ? 'Super Admin' : 'User'),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSuperAdmin ? colors.primary : const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSuperAdmin ? 'Full System & Security Privileges' : 'Standard ERP Workspace Member',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 18),

              // ── Account Details Card ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withAlpha(120),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      colors,
                      icon: Icons.account_circle_outlined,
                      label: 'Account Username',
                      value: user?.username ?? '—',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      colors,
                      icon: Icons.security_rounded,
                      label: 'Role Status',
                      value: isSuperAdmin ? 'SuperAdmin (Master)' : user?.roleName ?? 'User',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      colors,
                      icon: Icons.schedule_rounded,
                      label: 'Session Access',
                      value: 'Active Session',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Action Buttons ──────────────────────────────────────────────
              if (isSuperAdmin) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.key_rounded, size: 16),
                  label: const Text('Change Credentials'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withAlpha(120)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ChangeCredentialsDialog.show(
                      context,
                      isMandatory: false,
                      onSuccess: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Credentials updated successfully!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],

              ElevatedButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error.withAlpha(25),
                  foregroundColor: colors.error,
                  elevation: 0,
                  side: BorderSide(color: colors.error.withAlpha(60)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await AuthService.instance.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const LoginScreen(),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    AppColorsExtension colors, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
