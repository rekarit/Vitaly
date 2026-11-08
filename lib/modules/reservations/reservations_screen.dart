import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/models/slab.dart';
import '../../core/models/customer.dart';
import '../../core/models/material_item.dart';
import '../../core/models/reservation.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../sales/sales_screen.dart';
import '../../core/services/auth_service.dart';

// ── RESERVATIONS SCREEN (RESERVATION LIST) ──────────────────────────────────
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All'; // 'All', 'Active', 'Expired', 'Converted', 'Cancelled'
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppStateScope.read(context).sweepExpiredReservations();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openReservationForm({Reservation? existingReservation, List<Slab>? preselectedSlabs}) {
    ReservationsFormDialog.show(
      context,
      existingReservation: existingReservation,
      preselectedSlabs: preselectedSlabs,
    );
  }

  void _openSalesForm({Reservation? fromReservation, List<Slab>? preselectedSlabs}) {
    SalesFormDialog.show(
      context,
      fromReservation: fromReservation,
      preselectedSlabs: preselectedSlabs,
    );
  }

  void _openCustomerForm([ValueChanged<Customer>? onSaved]) {
    AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => _CustomersFormDialog(onSaved: onSaved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeCount = state.reservations.where((r) => r.status == ReservationStatus.active).length;
    final expiredCount = state.reservations.where((r) => r.status == ReservationStatus.expired).length;

    // Calculate total reserved area
    double totalReservedArea = 0.0;
    for (final res in state.reservations) {
      if (res.status == ReservationStatus.active) {
        final slabs = state.slabsByIds(res.slabIds);
        totalReservedArea += slabs.fold(0.0, (sum, s) => sum + s.areaSqm);
      }
    }

    // Filter reservations
    final filtered = state.reservations.reversed.where((res) {
      final customer = state.customerById(res.customerId);
      final slabs = state.slabsByIds(res.slabIds);
      final slabNumbers = slabs.map((s) => s.slabNo).join(' ');

      // Status filter
      if (_selectedStatus != 'All') {
        final match = switch (_selectedStatus) {
          'Active' => res.status == ReservationStatus.active,
          'Expired' => res.status == ReservationStatus.expired,
          'Converted' => res.status == ReservationStatus.converted,
          'Cancelled' => res.status == ReservationStatus.cancelled,
          _ => true,
        };
        if (!match) return false;
      }

      // Query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final cName = (customer?.fullName ?? '').toLowerCase();
        final cCompany = (customer?.company ?? '').toLowerCase();
        final cPhone = (customer?.phone ?? '').toLowerCase();
        final notes = (res.notes ?? '').toLowerCase();
        final resId = res.id.toLowerCase();
        final slabMatch = slabNumbers.toLowerCase().contains(q);

        return cName.contains(q) ||
            cCompany.contains(q) ||
            cPhone.contains(q) ||
            notes.contains(q) ||
            resId.contains(q) ||
            slabMatch;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar ──────────────────────────────────────────────
          _buildHeader(
            context: context,
            activeCount: activeCount,
            expiredCount: expiredCount,
            totalArea: totalReservedArea,
            onNewReservation: () => _openReservationForm(),
            onNewCustomer: () => _openCustomerForm(),
          ),

          // ── Search & Filter Bar ──────────────────────────────────────
          _buildSearchAndFilters(colors, isDark),

          // ── Reservation Content (Grid / List) ────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(colors)
                : (_isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: context.responsiveValue(mobile: 500, tablet: 400, desktop: 390),
                          mainAxisExtent: 295,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final res = filtered[i];
                          final customer = state.customerById(res.customerId);
                          final slabs = state.slabsByIds(res.slabIds);
                          return _ReservationGridCard(
                            res: res,
                            customer: customer,
                            slabs: slabs,
                            onSell: () => _openSalesForm(fromReservation: res, preselectedSlabs: slabs),
                            onEdit: () => _openReservationForm(existingReservation: res),
                            onCancel: () => state.cancelReservation(res.id),
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final res = filtered[i];
                          final customer = state.customerById(res.customerId);
                          final slabs = state.slabsByIds(res.slabIds);
                          return _ReservationListCard(
                            res: res,
                            customer: customer,
                            slabs: slabs,
                            onSell: () => _openSalesForm(fromReservation: res, preselectedSlabs: slabs),
                            onEdit: () => _openReservationForm(existingReservation: res),
                            onCancel: () => state.cancelReservation(res.id),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildHeader({
    required BuildContext context,
    required int activeCount,
    required int expiredCount,
    required double totalArea,
    required VoidCallback onNewReservation,
    required VoidCallback onNewCustomer,
  }) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reservation List',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Customer hold management · inventory reservations',
                style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeaderBadge(
                label: 'Active Holds',
                value: '$activeCount',
                color: colors.success,
              ),
              _HeaderBadge(
                label: 'Expired',
                value: '$expiredCount',
                color: expiredCount > 0 ? colors.error : colors.textDisabled,
              ),
              _HeaderBadge(
                label: 'Reserved Area',
                value: '${totalArea.toStringAsFixed(2)} m²',
                color: colors.primary,
              ),
              if (AuthService.instance.currentPermissions.canAddCustomer) ...[
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: onNewCustomer,
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: Text('Customer', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              if (AuthService.instance.currentPermissions.canCreateReservation) ...[
                ElevatedButton.icon(
                  onPressed: onNewReservation,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('New Reservation', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Search & Filter Bar ────────────────────────────────────────────────────
  Widget _buildSearchAndFilters(AppColorsExtension colors, bool isDark) {
    const statuses = ['All', 'Active', 'Expired', 'Converted', 'Cancelled'];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Input
              Container(
                height: 40,
                width: context.isMobile ? double.infinity : (context.screenWidth > 600 ? 320 : double.infinity),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceVariant : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by customer, slab #, notes...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.cancel_rounded, size: 16, color: colors.textSecondary),
                      ),
                  ],
                ),
              ),

              // View Mode Toggle (Grid vs List)
              _buildViewModeToggle(colors, isDark),
            ],
          ),
          const SizedBox(height: 10),

          // Status Filter Chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final st = statuses[i];
                final isSelected = _selectedStatus == st;
                return InkWell(
                  onTap: () => setState(() => _selectedStatus = st),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : (isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? colors.primary : colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      st,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? (isDark ? const Color(0xFF111418) : Colors.white) : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(AppColorsExtension colors, bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // List View
          InkWell(
            onTap: () => setState(() => _isGridView = false),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: !_isGridView ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.view_list_rounded,
                    size: 16,
                    color: !_isGridView ? (isDark ? const Color(0xFF111418) : Colors.white) : colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'List',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: !_isGridView ? FontWeight.bold : FontWeight.w500,
                      color: !_isGridView ? (isDark ? const Color(0xFF111418) : Colors.white) : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Grid View
          InkWell(
            onTap: () => setState(() => _isGridView = true),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isGridView ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: _isGridView ? (isDark ? const Color(0xFF111418) : Colors.white) : colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Grid',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: _isGridView ? FontWeight.bold : FontWeight.w500,
                      color: _isGridView ? (isDark ? const Color(0xFF111418) : Colors.white) : colors.textSecondary,
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

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 56, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'No reservations found',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a new reservation to reserve stone slabs for customers.',
            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openReservationForm(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('New Reservation', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.warning,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ── HEADER BADGE ─────────────────────────────────────────────────────────────
class _HeaderBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: colors.textSecondary),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ── RESERVATION GRID CARD ────────────────────────────────────────────────────
class _ReservationGridCard extends StatelessWidget {
  final Reservation res;
  final Customer? customer;
  final List<Slab> slabs;
  final VoidCallback onSell;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _ReservationGridCard({
    required this.res,
    required this.customer,
    required this.slabs,
    required this.onSell,
    required this.onEdit,
    required this.onCancel,
  });

  Color _statusColor(BuildContext context) => switch (res.status) {
        ReservationStatus.active => context.colors.success,
        ReservationStatus.expired => context.colors.error,
        ReservationStatus.converted => context.colors.primary,
        ReservationStatus.cancelled => context.colors.textDisabled,
      };

  String get _statusLabel => switch (res.status) {
        ReservationStatus.active => 'Active',
        ReservationStatus.expired => 'Expired',
        ReservationStatus.converted => 'Converted',
        ReservationStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final totalSqm = slabs.fold(0.0, (s, sl) => s + sl.areaSqm);
    final color = _statusColor(context);
    final colors = context.colors;
    final slabNos = slabs.map((s) => s.slabNo).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withAlpha(40),
                  child: Icon(Icons.person_rounded, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?.fullName ?? 'Unknown Customer',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        customer?.phone.isNotEmpty == true ? customer!.phone : (customer?.company ?? 'No phone'),
                        style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withAlpha(90)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),

          // Card Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MiniMetric(
                            label: 'Slabs',
                            value: '${slabs.length} slabs',
                            icon: Icons.layers_rounded,
                            colors: colors,
                          ),
                          _MiniMetric(
                            label: 'Total Area',
                            value: '${totalSqm.toStringAsFixed(2)} m²',
                            icon: Icons.square_foot_rounded,
                            colors: colors,
                            isBold: true,
                          ),
                          _MiniMetric(
                            label: 'Deposit',
                            value: '\$${res.depositAmount.toStringAsFixed(0)}',
                            icon: Icons.payments_outlined,
                            colors: colors,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (slabNos.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.tag_rounded, size: 12, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  slabNos,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: colors.textDisabled),
                          const SizedBox(width: 4),
                          Text(
                            'Res: ${fmt.format(res.reservedAt)}',
                            style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                          ),
                          const Spacer(),
                          Icon(Icons.event_outlined, size: 12, color: colors.textDisabled),
                          const SizedBox(width: 4),
                          Text(
                            'Exp: ${fmt.format(res.expiresAt)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: res.isExpired && res.status == ReservationStatus.active ? colors.error : colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (res.notes != null && res.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          res.notes!,
                          style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),

                  // Actions: Sell, Edit and Cancel
                  Row(
                    children: [
                      if (res.status == ReservationStatus.active) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onSell,
                            icon: const Icon(Icons.point_of_sale_rounded, size: 14),
                            label: Text('Sell', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary.withAlpha(120)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                      if (res.status == ReservationStatus.active) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                            side: BorderSide(color: colors.error.withAlpha(120)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text('Cancel', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── RESERVATION LIST CARD ────────────────────────────────────────────────────
class _ReservationListCard extends StatelessWidget {
  final Reservation res;
  final Customer? customer;
  final List<Slab> slabs;
  final VoidCallback onSell;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _ReservationListCard({
    required this.res,
    required this.customer,
    required this.slabs,
    required this.onSell,
    required this.onEdit,
    required this.onCancel,
  });

  Color _statusColor(BuildContext context) => switch (res.status) {
        ReservationStatus.active => context.colors.success,
        ReservationStatus.expired => context.colors.error,
        ReservationStatus.converted => context.colors.primary,
        ReservationStatus.cancelled => context.colors.textDisabled,
      };

  String get _statusLabel => switch (res.status) {
        ReservationStatus.active => 'Active',
        ReservationStatus.expired => 'Expired',
        ReservationStatus.converted => 'Converted',
        ReservationStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final totalSqm = slabs.fold(0.0, (s, sl) => s + sl.areaSqm);
    final color = _statusColor(context);
    final colors = context.colors;
    final slabNos = slabs.map((s) => s.slabNo).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: res.status == ReservationStatus.active ? onSell : onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withAlpha(75)),
                  ),
                  child: Icon(Icons.person_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?.fullName ?? 'Unknown Customer',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      Text(
                        '${customer?.company.isNotEmpty == true ? "${customer!.company} · " : ""}${customer?.phone ?? ""}',
                        style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withAlpha(90)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: colors.border, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ListMetric(Icons.calendar_today_outlined, 'Reserved', fmt.format(res.reservedAt), colors),
                _ListMetric(Icons.event_outlined, 'Expires', fmt.format(res.expiresAt), colors),
                _ListMetric(Icons.layers_rounded, 'Slabs', '${res.slabIds.length} slabs (${totalSqm.toStringAsFixed(2)} m²)', colors),
                _ListMetric(Icons.payments_outlined, 'Deposit', '\$${res.depositAmount.toStringAsFixed(0)}', colors),
              ],
            ),
            if (slabNos.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Slab Numbers: ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                  Expanded(
                    child: Text(
                      slabNos,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (res.notes != null && res.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  res.notes!,
                  style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (res.status == ReservationStatus.active) ...[
                  ElevatedButton.icon(
                    onPressed: onSell,
                    icon: const Icon(Icons.point_of_sale_rounded, size: 15),
                    label: Text(
                      'Sell / Convert to Sale',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withAlpha(120)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                if (res.status == ReservationStatus.active) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error.withAlpha(120)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final AppColorsExtension colors;
  final bool isBold;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: colors.textDisabled),
            const SizedBox(width: 3),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? colors.primary : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ListMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppColorsExtension colors;

  const _ListMetric(this.icon, this.label, this.value, this.colors);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textDisabled),
        const SizedBox(width: 5),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
      ],
    );
  }
}

// ── CUSTOMERS FORM DIALOG (MATCHING SCREENSHOTS 1 & 2) ────────────────────────
class _CustomersFormDialog extends StatefulWidget {
  final ValueChanged<Customer>? onSaved;
  const _CustomersFormDialog({this.onSaved});

  @override
  State<_CustomersFormDialog> createState() => _CustomersFormDialogState();
}

class _CustomersFormDialogState extends State<_CustomersFormDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _errorMsg;

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
    if (name.isEmpty) {
      setState(() => _errorMsg = 'CustomerName is required');
      return;
    }

    final appState = AppStateScope.read(context);
    final cust = appState.addCustomer(
      fullName: name,
      phone: phone,
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );

    widget.onSaved?.call(cust);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Customer "$name" saved successfully ✓', style: GoogleFonts.inter(color: Colors.white)),
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
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(240.0, 720.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: [X] Customers Form       [Cancel] [Save]
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
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
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF72B4F8),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    onPressed: _save,
                    child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 16),

              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.error.withAlpha(100)),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: GoogleFonts.inter(fontSize: 12, color: colors.error, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Form Body
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
                        autoFocus: true,
                      ),
                      const SizedBox(height: 14),
                      _buildFormField(
                        label: 'Phone',
                        controller: _phoneCtrl,
                        colors: colors,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _buildFormField(
                        label: 'Email',
                        controller: _emailCtrl,
                        colors: colors,
                        isDark: isDark,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _buildFormField(
                        label: 'Address',
                        controller: _addressCtrl,
                        colors: colors,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _buildFormField(
                        label: 'Notes',
                        controller: _notesCtrl,
                        colors: colors,
                        isDark: isDark,
                        maxLines: 3,
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

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required AppColorsExtension colors,
    required bool isDark,
    bool autoFocus = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: maxLines > 1 ? null : 44,
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            autofocus: autoFocus,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

// ── RESERVATIONS FORM DIALOG (MATCHING SCREENSHOTS 3 & 4 + EDIT & AUTO MATERIAL IMAGE) ──
class ReservationsFormDialog extends StatefulWidget {
  final Reservation? existingReservation;
  final List<Slab>? preselectedSlabs;

  const ReservationsFormDialog({
    super.key,
    this.existingReservation,
    this.preselectedSlabs,
  });

  static Future<void> show(BuildContext context, {Reservation? existingReservation, List<Slab>? preselectedSlabs}) {
    return AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => ReservationsFormDialog(
        existingReservation: existingReservation,
        preselectedSlabs: preselectedSlabs,
      ),
    );
  }

  @override
  State<ReservationsFormDialog> createState() => _ReservationsFormDialogState();
}

class _ReservationsFormDialogState extends State<ReservationsFormDialog> {
  Customer? _selectedCustomer;
  final Set<String> _selectedSlabIds = {};

  final _notesCtrl = TextEditingController();
  final _materialImageCtrl = TextEditingController();

  DateTime _reservationDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 14));
  ReservationStatus _status = ReservationStatus.active;

  MaterialItem? _detectedMaterial;
  String? _errorMsg;

  bool get _isEditing => widget.existingReservation != null;

  @override
  void initState() {
    super.initState();
    final res = widget.existingReservation;
    if (res != null) {
      _selectedSlabIds.addAll(res.slabIds);
      _reservationDate = res.reservedAt;
      _expiryDate = res.expiresAt;
      _status = res.status;
      _notesCtrl.text = res.notes ?? '';
    } else if (widget.preselectedSlabs != null) {
      _selectedSlabIds.addAll(widget.preselectedSlabs!.map((s) => s.id));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppStateScope.read(context);
      if (res != null) {
        setState(() {
          _selectedCustomer = state.customerById(res.customerId);
        });
      }
      _syncMaterialDetails(state);
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _materialImageCtrl.dispose();
    super.dispose();
  }

  void _syncMaterialDetails(AppState appState) {
    if (_selectedSlabIds.isNotEmpty) {
      final firstSlab = appState.slabs.firstWhere(
        (s) => s.id == _selectedSlabIds.first,
        orElse: () => appState.slabs.first,
      );
      final mat = appState.materialById(firstSlab.materialId);
      setState(() {
        _detectedMaterial = mat;
        if (mat?.imageUrl != null && mat!.imageUrl!.isNotEmpty) {
          _materialImageCtrl.text = mat.imageUrl!;
        } else if (mat != null) {
          _materialImageCtrl.text = mat.name;
        }
      });
    } else {
      setState(() {
        _detectedMaterial = null;
        _materialImageCtrl.clear();
      });
    }
  }

  void _openSlabSelector(AppState appState) {
    showDialog<void>(
      context: context,
      builder: (_) => _SlabPickerDialog(
        availableSlabs: appState.slabs.where((s) => s.status == SlabStatus.available || _selectedSlabIds.contains(s.id)).toList(),
        selectedSlabIds: _selectedSlabIds,
        onSelectionChanged: () {
          _syncMaterialDetails(appState);
        },
      ),
    );
  }

  void _openCustomerRegistration() {
    AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => _CustomersFormDialog(
        onSaved: (newCust) {
          setState(() {
            _selectedCustomer = newCust;
          });
        },
      ),
    );
  }

  void _save() {
    if (_selectedCustomer == null) {
      setState(() => _errorMsg = 'Please select a CustomerID');
      return;
    }
    if (_selectedSlabIds.isEmpty) {
      setState(() => _errorMsg = 'Please select at least one slab to reserve in SlabsToReserve');
      return;
    }

    final appState = AppStateScope.read(context);

    if (_isEditing) {
      appState.updateReservation(
        resId: widget.existingReservation!.id,
        customerId: _selectedCustomer!.id,
        slabIds: _selectedSlabIds.toList(),
        expiresAt: _expiryDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        status: _status,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation updated successfully ✓', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: context.colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      appState.createReservation(
        customerId: _selectedCustomer!.id,
        slabIds: _selectedSlabIds.toList(),
        expiresAt: _expiryDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation created for ${_selectedCustomer!.fullName} ✓', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: context.colors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final colors = context.colors;
    final fmtDate = DateFormat('MM/dd/yyyy');

    // Calculate selected slabs metrics
    final selectedSlabs = state.slabs.where((s) => _selectedSlabIds.contains(s.id)).toList();
    final totalAreaSqm = selectedSlabs.fold(0.0, (sum, s) => sum + s.areaSqm);
    final slabNoDisplay = selectedSlabs.map((s) => s.slabNo).join(', ');

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(240.0, 840.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: [X] Reservations Form       [Cancel] [Save]
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Reservation' : 'Reservations Form',
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
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF72B4F8),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    onPressed: _save,
                    child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 16),

              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.error.withAlpha(100)),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: GoogleFonts.inter(fontSize: 12, color: colors.error, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status (when editing)
                      if (_isEditing) ...[
                        _buildLabel('Status'),
                        const SizedBox(height: 6),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ReservationStatus>(
                              isExpanded: true,
                              value: _status,
                              dropdownColor: colors.surface,
                              items: ReservationStatus.values.map((st) {
                                return DropdownMenuItem(
                                  value: st,
                                  child: Text(
                                    st.name.toUpperCase(),
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                  ),
                                );
                              }).toList(),
                              onChanged: (st) {
                                if (st != null) setState(() => _status = st);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 1. CustomerID (Dropdown with Add Customer option)
                      _buildLabel('CustomerID'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Customer>(
                                  isExpanded: true,
                                  value: _selectedCustomer,
                                  dropdownColor: colors.surface,
                                  icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                                  hint: Text(
                                    'Select customer...',
                                    style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled),
                                  ),
                                  items: state.customers.map((c) {
                                    return DropdownMenuItem<Customer>(
                                      value: c,
                                      child: Text(
                                        '${c.id} - ${c.fullName}${c.company.isNotEmpty ? " (${c.company})" : ""}',
                                        style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (c) {
                                    setState(() {
                                      _selectedCustomer = c;
                                      _errorMsg = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Add New Customer',
                            child: InkWell(
                              onTap: _openCustomerRegistration,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: colors.primary.withAlpha(90)),
                                ),
                                child: Icon(Icons.person_add_rounded, size: 20, color: colors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 2. SlabsToReserve (Display with '+' button on right)
                      _buildLabel('SlabsToReserve'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _openSlabSelector(state),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedSlabIds.isEmpty
                                      ? 'Tap + to select slabs to reserve...'
                                      : '${_selectedSlabIds.length} slab(s) selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _selectedSlabIds.isEmpty ? colors.textDisabled : colors.textPrimary,
                                    fontWeight: _selectedSlabIds.isEmpty ? FontWeight.normal : FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(Icons.add, color: colors.textSecondary, size: 22),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. SelectedTotal_sqm (Read-only total sqm calculated)
                      _buildLabel('SelectedTotal_sqm'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          totalAreaSqm.toStringAsFixed(2),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: totalAreaSqm > 0 ? colors.primary : colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. ReservationDate (Date picker with calendar icon)
                      _buildLabel('ReservationDate'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _reservationDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _reservationDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fmtDate.format(_reservationDate),
                                  style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                                ),
                              ),
                              Icon(Icons.calendar_month_outlined, size: 18, color: colors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 5. Notes
                      _buildLabel('Notes'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _notesCtrl,
                          style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 6. ExpiryDate (Date picker with calendar icon)
                      _buildLabel('ExpiryDate'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expiryDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _expiryDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fmtDate.format(_expiryDate),
                                  style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                                ),
                              ),
                              Icon(Icons.calendar_month_outlined, size: 18, color: colors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 7. SlabNo
                      _buildLabel('SlabNo'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          slabNoDisplay.isNotEmpty ? slabNoDisplay : 'None selected',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: slabNoDisplay.isNotEmpty ? colors.textPrimary : colors.textDisabled,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 8. MaterialImage (Automatic preview + name)
                      _buildLabel('MaterialImage'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            // Material Thumbnail
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildMaterialThumbnail(_detectedMaterial, colors),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _detectedMaterial?.name ?? 'Auto-detect from selected slabs',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _detectedMaterial != null ? colors.textPrimary : colors.textDisabled,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _detectedMaterial != null
                                        ? '${_detectedMaterial!.materialCode} · ${_detectedMaterial!.origin}'
                                        : 'Select slabs above to link stone image',
                                    style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildMaterialThumbnail(MaterialItem? mat, AppColorsExtension colors) {
    if (mat == null) {
      return Icon(Icons.image_outlined, color: colors.textDisabled, size: 24);
    }
    if (mat.imageBytes != null) {
      return Image.memory(mat.imageBytes!, fit: BoxFit.cover);
    }
    if (mat.imageUrl != null && mat.imageUrl!.isNotEmpty) {
      return Image.network(
        mat.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.texture_rounded, color: colors.primary, size: 24),
      );
    }
    return Icon(Icons.texture_rounded, color: colors.primary, size: 24);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.colors.textSecondary,
      ),
    );
  }
}

// ── SLAB PICKER DIALOG (FOR SELECTING SLABS IN RESERVATIONS FORM) ─────────────
class _SlabPickerDialog extends StatefulWidget {
  final List<Slab> availableSlabs;
  final Set<String> selectedSlabIds;
  final VoidCallback onSelectionChanged;

  const _SlabPickerDialog({
    required this.availableSlabs,
    required this.selectedSlabIds,
    required this.onSelectionChanged,
  });

  @override
  State<_SlabPickerDialog> createState() => _SlabPickerDialogState();
}

class _SlabPickerDialogState extends State<_SlabPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final colors = context.colors;

    final filtered = widget.availableSlabs.where((s) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final mat = appState.materialById(s.materialId);
      final matName = (mat?.name ?? '').toLowerCase();
      return s.slabNo.toLowerCase().contains(q) ||
          s.warehouseLocation.toLowerCase().contains(q) ||
          matName.contains(q);
    }).toList();

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(240.0, 640.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Slabs To Reserve',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search input
              TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search slab number, material, location...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: colors.textDisabled),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              // Quick action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.selectedSlabIds.length} slabs selected',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            widget.selectedSlabIds.addAll(filtered.map((s) => s.id));
                          });
                          widget.onSelectionChanged();
                        },
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            widget.selectedSlabIds.clear();
                          });
                          widget.onSelectionChanged();
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No slabs available', style: GoogleFonts.inter(color: colors.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final s = filtered[i];
                          final mat = appState.materialById(s.materialId);
                          final isSelected = widget.selectedSlabIds.contains(s.id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  widget.selectedSlabIds.remove(s.id);
                                } else {
                                  widget.selectedSlabIds.add(s.id);
                                }
                              });
                              widget.onSelectionChanged();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? colors.primary.withAlpha(30) : colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isSelected ? colors.primary : colors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    size: 20,
                                    color: isSelected ? colors.primary : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.slabNo,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                        ),
                                        Text(
                                          '${mat?.name ?? "—"} · ${s.warehouseLocation}',
                                          style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${s.areaSqm.toStringAsFixed(2)} m²',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
