import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/theme/theme_scope.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../navigation/login_screen.dart';
import '../navigation/main_layout_screen.dart';
import 'user_form_dialog.dart';
import 'change_credentials_dialog.dart';
import '../../core/widgets/erase_data_dialog.dart';
import '../../core/widgets/user_profile_dialog.dart';

/// SuperAdmin Dedicated Control Center:
/// - User Accounts Management (Create, Edit, Delete, Granular Permissions)
/// - System Activity & Audit Logs (Tracking every action with filter & search)
/// - Security & SuperAdmin Credentials settings
/// - Direct switch to ERP workspace view
class SuperAdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToErp;

  const SuperAdminDashboardScreen({super.key, this.onSwitchToErp});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _activeNavIndex = 0; // 0: User Management, 1: Activity Logs, 2: Security & Profile
  String _searchQuery = '';
  String _selectedLogFilter = 'ALL';
  Timer? _realtimePollTimer;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
    // Instant sync on open + continuous 3-second live sync across devices
    AuthService.instance.syncFromCloud();
    _realtimePollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        AuthService.instance.syncFromCloud();
      }
    });
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _realtimePollTimer?.cancel();
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(colors, isDark, isMobile),
            Divider(color: colors.border, height: 1),

            // Main Body: Side Nav + Content
            Expanded(
              child: isMobile
                  ? Column(
                      children: [
                        _buildMobileNavigationPills(colors),
                        Divider(color: colors.border, height: 1),
                        Expanded(child: _buildCurrentSection(colors, isDark)),
                      ],
                    )
                  : Row(
                      children: [
                        _buildSideNav(colors, isDark),
                        Container(width: 1, color: colors.border),
                        Expanded(child: _buildCurrentSection(colors, isDark)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar(AppColorsExtension colors, bool isDark, bool isMobile) {
    final user = AuthService.instance.currentUser;

    return Container(
      height: isMobile ? 54 : 60,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 24),
      color: colors.surface,
      child: Row(
        children: [
          Container(
            width: isMobile ? 30 : 34,
            height: isMobile ? 30 : 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, const Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(80),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: isMobile ? 17 : 20),
          ),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isMobile ? 'Admin' : 'SuperAdmin Console',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 13.5 : 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isMobile)
                  Text(
                    'Governance & Security Management',
                    style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          OutlinedButton.icon(
            icon: Icon(Icons.dashboard_customize_rounded, size: isMobile ? 13 : 15),
            label: Text(
              isMobile ? 'ERP' : 'Switch to ERP Workspace',
              style: GoogleFonts.inter(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.primary.withAlpha(140)),
              foregroundColor: colors.primary,
              backgroundColor: colors.primary.withAlpha(15),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 14, vertical: isMobile ? 6 : 8),
              minimumSize: Size(isMobile ? 36 : 48, isMobile ? 32 : 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const MainLayoutScreen(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 200),
                ),
                (route) => false,
              );
            },
          ),
          SizedBox(width: isMobile ? 4 : 10),

          // Theme toggle
          InkWell(
            onTap: () => ThemeScope.read(context).toggleTheme(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 4 : 6),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: isMobile ? 14 : 16,
                color: colors.primary,
              ),
            ),
          ),
          SizedBox(width: isMobile ? 4 : 10),

          // User Profile badge (interactive)
          InkWell(
            onTap: () => UserProfileDialog.show(context),
            borderRadius: BorderRadius.circular(20),
            child: Tooltip(
              message: 'View Profile (${user?.username ?? "User"})',
              child: CircleAvatar(
                radius: isMobile ? 12 : 14,
                backgroundColor: colors.primary.withAlpha(45),
                child: Text(
                  (user?.username.isNotEmpty == true ? user!.username[0].toUpperCase() : 'A'),
                  style: GoogleFonts.inter(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.bold, color: colors.primary),
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 4 : 10),

          // Logout
          IconButton(
            icon: Icon(Icons.logout_rounded, size: isMobile ? 16 : 18, color: colors.error),
            tooltip: 'Logout',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isMobile ? 28 : 36, minHeight: isMobile ? 28 : 36),
            onPressed: () async {
              await AuthService.instance.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const LoginScreen(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Side Nav for Desktop ───────────────────────────────────────────────────
  Widget _buildSideNav(AppColorsExtension colors, bool isDark) {
    return Container(
      width: 220,
      color: colors.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          _navItem(0, Icons.people_alt_rounded, 'User Accounts', colors),
          const SizedBox(height: 6),
          _navItem(1, Icons.history_edu_rounded, 'Activity Logs', colors),
          const SizedBox(height: 6),
          _navItem(2, Icons.shield_rounded, 'Security & Profile', colors),
          const Spacer(),

          // Active session info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.instance.currentUser?.username ?? 'SuperAdmin',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Full Access Granted',
                        style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String title, AppColorsExtension colors) {
    final isSelected = _activeNavIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeNavIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? colors.primary.withAlpha(70) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? colors.primary : colors.textSecondary),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colors.primary : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile Navigation Pills ────────────────────────────────────────────────
  Widget _buildMobileNavigationPills(AppColorsExtension colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colors.surface,
      child: Row(
        children: [
          _pillItem(0, 'Users', Icons.people_alt_rounded, colors),
          const SizedBox(width: 8),
          _pillItem(1, 'Audit Logs', Icons.history_edu_rounded, colors),
          const SizedBox(width: 8),
          _pillItem(2, 'Security', Icons.shield_rounded, colors),
        ],
      ),
    );
  }

  Widget _pillItem(int index, String label, IconData icon, AppColorsExtension colors) {
    final isSelected = _activeNavIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeNavIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : colors.textSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSection(AppColorsExtension colors, bool isDark) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        switch (_activeNavIndex) {
          case 0:
            return _buildUsersSection(colors, isDark);
          case 1:
            return _buildActivityLogsSection(colors, isDark);
          case 2:
          default:
            return _buildSecuritySection(colors, isDark);
        }
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. USERS MANAGEMENT SECTION
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildUsersSection(AppColorsExtension colors, bool isDark) {
    final allUsers = AuthService.instance.users;
    final filtered = allUsers.where((u) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.username.toLowerCase().contains(q) || u.roleName.toLowerCase().contains(q);
    }).toList();

    final isMobile = context.isMobile;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Create User button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Accounts',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Total ${allUsers.length} system users with granular gates.',
                      style: GoogleFonts.inter(fontSize: isMobile ? 11 : 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Sync Users from Cloud',
                color: colors.primary,
                onPressed: () async {
                  await AuthService.instance.syncFromCloud();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cloud sync complete: All devices updated! ✓'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isMobile ? 'New' : 'Create User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  UserFormDialog.show(
                    context,
                    onSaved: () => setState(() {}),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Bar
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search user by username or role title...',
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
              filled: true,
              fillColor: colors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.border)),
            ),
          ),
          const SizedBox(height: 14),

          // Users Table or Cards
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No users match search criteria.', style: GoogleFonts.inter(color: colors.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final u = filtered[i];
                      return _buildUserCard(u, colors, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AppUser u, AppColorsExtension colors, bool isDark) {
    final isCurrent = u.id == AuthService.instance.currentUser?.id;
    final isMobile = context.isMobile;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isMobile ? 16 : 20,
            backgroundColor: u.isSuperAdmin ? colors.primary.withAlpha(40) : colors.surfaceVariant,
            child: Icon(
              u.isSuperAdmin ? Icons.shield_rounded : Icons.person_rounded,
              size: isMobile ? 16 : 20,
              color: u.isSuperAdmin ? colors.primary : colors.textSecondary,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      u.username,
                      style: GoogleFonts.inter(fontSize: isMobile ? 13.5 : 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: u.isSuperAdmin ? colors.primary.withAlpha(30) : colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: u.isSuperAdmin ? colors.primary.withAlpha(80) : colors.border),
                      ),
                      child: Text(
                        u.roleName,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: u.isSuperAdmin ? colors.primary : colors.textSecondary,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Active',
                          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Password: •••••••• · ${u.createdAt.toString().substring(0, 10)}',
                  style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_rounded, size: isMobile ? 16 : 18, color: colors.primary),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: isMobile ? 30 : 36, minHeight: isMobile ? 30 : 36),
                tooltip: 'Edit User & Permissions',
                onPressed: () {
                  UserFormDialog.show(
                    context,
                    existingUser: u,
                    onSaved: () => setState(() {}),
                  );
                },
              ),
              if (!u.isSuperAdmin || AuthService.instance.users.where((x) => x.isSuperAdmin).length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: isMobile ? 16 : 18, color: colors.error),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: isMobile ? 30 : 36, minHeight: isMobile ? 30 : 36),
                  tooltip: 'Delete User',
                  onPressed: () => _confirmDeleteUser(u),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(AppUser u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Delete User Account?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete user "${u.username}" (${u.roleName})?',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.deleteUser(u.id);
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. ACTIVITY & AUDIT LOGS SECTION
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildActivityLogsSection(AppColorsExtension colors, bool isDark) {
    final allLogs = AuthService.instance.logs;
    final filtered = allLogs.where((l) {
      if (_selectedLogFilter != 'ALL' && l.actionType != _selectedLogFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return l.username.toLowerCase().contains(q) ||
            l.details.toLowerCase().contains(q) ||
            l.section.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final isMobile = context.isMobile;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity & Audit Logs',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                Text(
                  'Tracks modifications, logins, and permissions in real-time.',
                  style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLogFilter,
                            isExpanded: true,
                            dropdownColor: colors.surface,
                            style: GoogleFonts.inter(fontSize: 11.5, color: colors.textPrimary, fontWeight: FontWeight.w600),
                            items: ['ALL', 'CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'SECURITY'].map((t) {
                              return DropdownMenuItem(value: t, child: Text('Filter: $t'));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedLogFilter = v);
                            },
                          ),
                        ),
                      ),
                    ),
                    if (allLogs.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: Icon(Icons.delete_sweep_rounded, size: 15, color: colors.error),
                        label: Text('Clear', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colors.error)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.error.withAlpha(120)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _confirmClearAllLogs(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User Activity & Security Audit Logs', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      Text('Tracks additions, modifications, deletions, logins, and permission activities in real-time.', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLogFilter,
                          dropdownColor: colors.surface,
                          style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w600),
                          items: ['ALL', 'CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'SECURITY'].map((t) {
                            return DropdownMenuItem(value: t, child: Text('Type: $t'));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedLogFilter = v);
                          },
                        ),
                      ),
                    ),
                    if (allLogs.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: Icon(Icons.delete_sweep_rounded, size: 16, color: colors.error),
                        label: Text('Clear All', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colors.error)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.error.withAlpha(120)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _confirmClearAllLogs(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Logs List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No activity logs recorded yet.', style: GoogleFonts.inter(color: colors.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final log = filtered[idx];
                      return _buildLogItem(log, colors);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Clear All Activity Logs?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete all ${AuthService.instance.logs.length} activity audit logs? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.clearAllLogs();
              setState(() {});
            },
            child: const Text('Clear All Logs'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSingleLog(UserActivityLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Delete Audit Log?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Delete log entry for "${log.username}" (${log.actionType} - ${log.section})?',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.deleteLog(log.id);
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(UserActivityLog log, AppColorsExtension colors) {
    Color typeColor;
    switch (log.actionType) {
      case 'CREATE':
        typeColor = const Color(0xFF10B981);
        break;
      case 'UPDATE':
        typeColor = const Color(0xFF3B82F6);
        break;
      case 'DELETE':
        typeColor = const Color(0xFFEF4444);
        break;
      case 'LOGIN':
        typeColor = const Color(0xFF8B5CF6);
        break;
      case 'SECURITY':
      default:
        typeColor = const Color(0xFFF59E0B);
        break;
    }

    final isMobile = context.isMobile;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              log.actionType,
              style: GoogleFonts.inter(fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.bold, color: typeColor),
            ),
          ),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      log.username,
                      style: GoogleFonts.inter(fontSize: isMobile ? 12 : 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    Text(
                      '(${log.roleName}) · ${log.section}',
                      style: GoogleFonts.inter(fontSize: isMobile ? 10.5 : 11, color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  log.details,
                  style: GoogleFonts.inter(fontSize: isMobile ? 11 : 12, color: colors.textPrimary),
                  maxLines: isMobile ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.robotoMono(fontSize: isMobile ? 10 : 11, color: colors.textDisabled),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: isMobile ? 15 : 16, color: colors.textDisabled),
            tooltip: 'Delete Log',
            hoverColor: colors.error.withAlpha(20),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isMobile ? 24 : 28, minHeight: isMobile ? 24 : 28),
            onPressed: () => _confirmDeleteSingleLog(log),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. SECURITY & CREDENTIALS SECTION
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSecuritySection(AppColorsExtension colors, bool isDark) {
    final user = AuthService.instance.currentUser;
    final isMobile = context.isMobile;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SuperAdmin Security & Credentials', style: GoogleFonts.inter(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            Text('Update your username and master password anytime.', style: GoogleFonts.inter(fontSize: isMobile ? 11 : 12, color: colors.textSecondary)),
            const SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_person_rounded, color: colors.primary, size: isMobile ? 20 : 24),
                      const SizedBox(width: 10),
                      Text('Master Account Details', style: GoogleFonts.inter(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: colors.border, height: 1),
                  const SizedBox(height: 12),

                  _securityDetailItem('Active Username', user?.username ?? 'SuperAdminVitaly', colors),
                  _securityDetailItem('Assigned Role', user?.roleName ?? 'Super Admin', colors),
                  _securityDetailItem('Security Status', 'Active & Protected', colors),
                  _securityDetailItem('Password Status', 'Encrypted local vault', colors),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.key_rounded, size: 16),
                      label: const Text('Change Username & Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        ChangeCredentialsDialog.show(
                          context,
                          isMandatory: false,
                          onSuccess: () {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SuperAdmin credentials successfully updated!'),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Danger Zone: Erase All Data (SuperAdmin Exclusive) ───────
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Danger Zone — Master Wipe',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Permanently purge all stone inventory, materials, customer profiles, sales, and audit check records from InsForge and client state. Only SuperAdmin can execute this action.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('Erase All Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => showEraseDataConfirmationDialog(context),
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

  Widget _securityDetailItem(String title, String value, AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 12.5, color: colors.textSecondary)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
