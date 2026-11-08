import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/theme/theme_scope.dart';
import '../data_entry/data_entry_screen.dart';
import '../available_stone/available_stone_screen.dart';
import '../reservations/reservations_screen.dart';
import '../sales/sales_screen.dart';
import '../returns/returns_screen.dart';
import '../category_check/category_check_screen.dart';
import '../data_check/data_check_screen.dart';
import '../print_labels/print_labels_screen.dart';
import '../scan/scan_screen.dart';
import '../customer_profile/customer_profile_screen.dart';
import 'login_screen.dart';
import '../../core/widgets/erase_data_dialog.dart';

import '../../core/services/auth_service.dart';
import '../admin/super_admin_dashboard_screen.dart';
import '../../core/widgets/user_profile_dialog.dart';

// ── Nav item descriptor ──────────────────────────────────────────────────────
class _NavItem {
  final int      originalIndex;
  final String   label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({
    required this.originalIndex,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// ── Main Layout ──────────────────────────────────────────────────────────────
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});
  static final GlobalKey<MainLayoutScreenState> globalKey =
      GlobalKey<MainLayoutScreenState>();
  static void navigateToTab(int index) =>
      globalKey.currentState?.switchTab(index);

  @override
  State<MainLayoutScreen> createState() => MainLayoutScreenState();
}

class MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  final ScrollController _bottomNavScrollController = ScrollController();

  // Track which screens have been built at least once (lazy init).
  final Set<int> _built = {0};

  static const List<_NavItem> _allPossibleItems = [
    _NavItem(originalIndex: 0, label: 'Data Entry',        icon: Icons.add_box_outlined,           activeIcon: Icons.add_box_rounded),
    _NavItem(originalIndex: 1, label: 'Stone Types',       icon: Icons.grid_view_outlined,         activeIcon: Icons.grid_view_rounded),
    _NavItem(originalIndex: 2, label: 'Customer Profile',  icon: Icons.badge_outlined,             activeIcon: Icons.badge_rounded),
    _NavItem(originalIndex: 3, label: 'Reservations',      icon: Icons.bookmark_add_outlined,      activeIcon: Icons.bookmark_added_rounded),
    _NavItem(originalIndex: 4, label: 'Sales',           icon: Icons.point_of_sale_outlined,    activeIcon: Icons.point_of_sale_rounded),
    _NavItem(originalIndex: 5, label: 'Returns',         icon: Icons.assignment_return_outlined, activeIcon: Icons.assignment_return_rounded),
    _NavItem(originalIndex: 6, label: 'Category Check',  icon: Icons.pie_chart_outline_rounded, activeIcon: Icons.pie_chart_rounded),
    _NavItem(originalIndex: 7, label: 'Data Check',      icon: Icons.fact_check_outlined,       activeIcon: Icons.fact_check_rounded),
    _NavItem(originalIndex: 8, label: 'Print Labels',    icon: Icons.print_outlined,            activeIcon: Icons.print_rounded),
    _NavItem(originalIndex: 9, label: 'Scan',            icon: Icons.qr_code_scanner_outlined,  activeIcon: Icons.qr_code_scanner_rounded),
  ];

  List<_NavItem> get _items {
    final perms = AuthService.instance.currentPermissions;
    return _allPossibleItems.where((item) {
      switch (item.originalIndex) {
        case 0: return perms.canViewDataEntry;
        case 1: return perms.canViewStoneTypes;
        case 2: return perms.canViewCustomerProfile;
        case 3: return perms.canViewReservations;
        case 4: return perms.canViewSales;
        case 5: return perms.canViewReturns;
        case 6: return perms.canViewCategoryCheck;
        case 7: return perms.canViewDataCheck;
        case 8: return perms.canViewPrintLabels;
        case 9: return perms.canViewScan;
        default: return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final allowed = _items;
    if (allowed.isNotEmpty) {
      _currentIndex = 0;
      _built.add(allowed[0].originalIndex);
    }
  }

  @override
  void dispose() {
    _bottomNavScrollController.dispose();
    super.dispose();
  }

  void switchTab(int index) {
    if (_currentIndex == index) return;
    final allowed = _items;
    if (index >= allowed.length) return;
    final origIdx = allowed[index].originalIndex;

    setState(() {
      _currentIndex = index;
      _built.add(origIdx);
    });
    if (origIdx == 1) {
      AvailableStoneScreen.globalKey.currentState?.resetFilterToAll();
    }
    _scrollToActiveTab(index);
  }

  void _scrollToActiveTab(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_bottomNavScrollController.hasClients) return;
      final targetOffset = (index * 84.0 - 100.0).clamp(
        0.0,
        _bottomNavScrollController.position.maxScrollExtent,
      );
      _bottomNavScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _showAllModulesSheet(BuildContext context, AppColorsExtension c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: c.textDisabled.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.primaryLight, c.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.apps_rounded, color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All System Modules',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            'Tap any module for instant one-click access',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: c.border, height: 1),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.05,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, idx) {
                    final item = _items[idx];
                    final isSelected = _currentIndex == idx;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        switchTab(idx);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? c.primary.withAlpha(35)
                              : (isDark ? const Color(0xFF1B1D22) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? c.primary : c.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 24,
                              color: isSelected ? c.primary : c.textSecondary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? c.primary : c.textPrimary,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:  return DataEntryScreen(key: DataEntryScreen.globalKey);
      case 1:  return AvailableStoneScreen(key: AvailableStoneScreen.globalKey);
      case 2:  return const CustomerProfileScreen();
      case 3:  return const ReservationsScreen();
      case 4:  return const SalesScreen();
      case 5:  return const ReturnsScreen();
      case 6:  return const CategoryCheckScreen();
      case 7:  return const DataCheckScreen();
      case 8:  return const PrintLabelsScreen();
      case 9:  return const ScanScreen();
      default: return DataEntryScreen(key: DataEntryScreen.globalKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _TopHeader(
              colors: c,
              onOpenModules: () => _showAllModulesSheet(context, c),
            ),
            Expanded(
              child: ResponsiveLayout(
                mobile: _buildMobileLayout(c),
                tablet: _buildTabletLayout(c),
                desktop: _buildDesktopLayout(c),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: (context.isMobile && !isKeyboardOpen) ? _buildBottomNav(c) : null,
    );
  }

  Widget _buildMobileLayout(AppColorsExtension c) {
    return _buildMainContent();
  }

  Widget _buildTabletLayout(AppColorsExtension c) {
    return Row(
      children: [
        _NavigationRailNav(
          items: _items,
          currentIndex: _currentIndex,
          colors: c,
          onTap: switchTab,
        ),
        Container(width: 1, color: c.border),
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  Widget _buildDesktopLayout(AppColorsExtension c) {
    return Row(
      children: [
        _SideNav(
          items: _items,
          currentIndex: _currentIndex,
          colors: c,
          onTap: switchTab,
        ),
        Container(width: 1, color: c.border),
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  Widget _buildMainContent() {
    final allowed = _items;
    if (allowed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_person_rounded, size: 48, color: context.colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              'No Accessible Modules',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Your account role does not have permission to view ERP modules.\nPlease contact SuperAdmin for access.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return IndexedStack(
      index: _currentIndex.clamp(0, allowed.length - 1),
      children: List.generate(allowed.length, (i) {
        final origIdx = allowed[i].originalIndex;
        if (!_built.contains(origIdx)) {
          return const SizedBox.shrink();
        }
        return RepaintBoundary(child: _buildScreen(origIdx));
      }),
    );
  }

  Widget _buildBottomNav(AppColorsExtension c) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _bottomNavScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: List.generate(_items.length, (i) {
                    final item = _items[i];
                    final sel = _currentIndex == i;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => switchTab(i),
                          borderRadius: BorderRadius.circular(12),
                          splashColor: c.primary.withAlpha(40),
                          highlightColor: c.primary.withAlpha(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            constraints: const BoxConstraints(minWidth: 74),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: sel ? c.primary.withAlpha(30) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? c.primary.withAlpha(80) : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  sel ? item.activeIcon : item.icon,
                                  size: 22,
                                  color: sel ? c.primary : c.textSecondary,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                    color: sel ? c.primary : c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            // "All Modules" menu button pinned at the right edge
            Container(
              height: 48,
              padding: const EdgeInsets.only(right: 8, left: 2),
              child: Tooltip(
                message: 'All Modules',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showAllModulesSheet(context, c),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(Icons.apps_rounded, size: 22, color: c.primary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Header — separated to avoid full-layout rebuild on theme toggle ──────
class _TopHeader extends StatelessWidget {
  final AppColorsExtension colors;
  final VoidCallback? onOpenModules;
  const _TopHeader({required this.colors, this.onOpenModules});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c      = colors;
    final isMobile = context.isMobile;

    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color:  c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (AuthService.instance.isSuperAdmin) {
                  VitalyTapDetector.onTap(context);
                }
              },
              onLongPress: () {
                if (AuthService.instance.isSuperAdmin) {
                  showEraseDataConfirmationDialog(context);
                }
              },
              borderRadius: BorderRadius.circular(10),
              splashColor: c.primary.withAlpha(40),
              highlightColor: c.primary.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.diamond_rounded, color: c.primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vitaly ERP',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),

          // Modules Grid button on mobile
          if (isMobile && onOpenModules != null) ...[
            InkWell(
              onTap: onOpenModules,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Icon(Icons.apps_rounded, size: 17, color: c.primary),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Theme toggle
          InkWell(
            onTap: () => ThemeScope.read(context).toggleTheme(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 3 : 5),
              decoration: BoxDecoration(
                color:        c.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThemeIcon(icon: Icons.light_mode_rounded, active: !isDark, activeColor: c.primary, inactiveColor: c.textDisabled),
                  const SizedBox(width: 2),
                  _ThemeIcon(icon: Icons.dark_mode_rounded,  active: isDark,  activeColor: c.primary, inactiveColor: c.textDisabled),
                ],
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 16),
          // SuperAdmin Dashboard shortcut button if user is SuperAdmin
          if (AuthService.instance.isSuperAdmin) ...[
            InkWell(
              onTap: () {
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const SuperAdminDashboardScreen(),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 200),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary, const Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withAlpha(50),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_rounded, size: 15, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      isMobile ? 'Admin' : 'Super Admin',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // User Avatar with user initials (Opens Profile Dialog)
          InkWell(
            onTap: () => UserProfileDialog.show(context),
            borderRadius: BorderRadius.circular(20),
            child: Tooltip(
              message: 'View Profile (${AuthService.instance.currentUser?.username ?? "User"})',
              child: CircleAvatar(
                radius: isMobile ? 13 : 15,
                backgroundColor: c.primary.withAlpha(45),
                child: Text(
                  (AuthService.instance.currentUser?.username.isNotEmpty == true
                      ? AuthService.instance.currentUser!.username.substring(0, 2).toUpperCase()
                      : 'VA'),
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: c.primary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 12),
          // Logout Button
          InkWell(
            onTap: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const LoginScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 200),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: isMobile ? 5 : 6),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout_rounded, size: isMobile ? 15 : 16, color: c.error),
                  if (!isMobile) ...[
                    const SizedBox(width: 6),
                    Text(
                      'Logout',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation Rail (Tablet Layout) ──────────────────────────────────────────
class _NavigationRailNav extends StatelessWidget {
  final List<_NavItem>       items;
  final int                  currentIndex;
  final AppColorsExtension   colors;
  final ValueChanged<int>    onTap;
  const _NavigationRailNav({required this.items, required this.currentIndex, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: ColoredBox(
        color: colors.surface,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: List.generate(items.length, (idx) {
              final sel = currentIndex == idx;
              final item = items[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tooltip(
                  message: item.label,
                  preferBelow: false,
                  child: InkWell(
                    onTap: () => onTap(idx),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: sel ? colors.primary.withAlpha(30) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? colors.primary.withAlpha(70) : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        sel ? item.activeIcon : item.icon,
                        size: 22,
                        color: sel ? colors.primary : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Side Nav — extracted so its rebuild is independent ───────────────────────
class _SideNav extends StatelessWidget {
  final List<_NavItem>       items;
  final int                  currentIndex;
  final AppColorsExtension   colors;
  final ValueChanged<int>    onTap;
  const _SideNav({required this.items, required this.currentIndex, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: ColoredBox(
        color: colors.surface,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(items.length, (idx) => _NavTile(
              item:       items[idx],
              isSelected: currentIndex == idx,
              colors:     colors,
              onTap:      () => onTap(idx),
            )),
          ),
        ),
      ),
    );
  }
}

// ── Nav Tile — lightweight, single AnimatedContainer, no AnimationController ─
class _NavTile extends StatelessWidget {
  final _NavItem             item;
  final bool                 isSelected;
  final AppColorsExtension   colors;
  final VoidCallback         onTap;
  const _NavTile({required this.item, required this.isSelected, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c   = colors;
    final sel = isSelected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? c.primary.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? c.primary.withAlpha(70) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: sel ? c.primary.withAlpha(40) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    sel ? item.activeIcon : item.icon,
                    size: 18,
                    color: sel ? c.primary : c.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? c.primary : c.textSecondary,
                          ),
                        ),
                      ),
                      if (item.label == 'Returns') ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: sel ? c.primary : c.textSecondary.withAlpha(180),
                        ),
                      ],
                    ],
                  ),
                ),
                if (sel)
                  Container(
                    width: 3, height: 14,
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Theme icon ───────────────────────────────────────────────────────────────
class _ThemeIcon extends StatelessWidget {
  final IconData icon;
  final bool     active;
  final Color    activeColor;
  final Color    inactiveColor;
  const _ThemeIcon({required this.icon, required this.active, required this.activeColor, required this.inactiveColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:  const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:        active ? activeColor.withAlpha(38) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 16, color: active ? activeColor : inactiveColor),
    );
  }
}
