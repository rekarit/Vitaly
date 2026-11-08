import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/models/slab.dart';
import '../../core/models/material_item.dart';
import '../../core/models/customer.dart';
import '../../core/models/sale.dart';
import '../../core/models/reservation.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/widgets/customer_registration_dialog.dart';
import '../../core/services/auth_service.dart';

// ── SALES SCREEN ────────────────────────────────────────────────────────────
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All'; // 'All', 'Paid', 'Invoiced', 'Pending'
  bool _isGridView = false;
  bool _showReservedSection = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openSalesForm({Sale? existingSale, Reservation? fromReservation, List<Slab>? preselectedSlabs}) {
    SalesFormDialog.show(
      context,
      existingSale: existingSale,
      fromReservation: fromReservation,
      preselectedSlabs: preselectedSlabs,
    );
  }

  void _openPaymentsForm({Sale? preselectedSale}) {
    AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => _PaymentsFormDialog(
        preselectedSale: preselectedSale,
      ),
    );
  }

  void _showSalesDetailDialog(Sale sale, Customer? customer, List<Slab> slabs) {
    AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => _SalesDetailDialog(
        sale: sale,
        customer: customer,
        slabs: slabs,
        onEdit: () {
          Navigator.pop(ctx);
          _openSalesForm(existingSale: sale);
        },
        onPayment: () {
          Navigator.pop(ctx);
          _openPaymentsForm(preselectedSale: sale);
        },
      ),
    );
  }

  void _confirmDeleteSale(Sale sale) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Delete Sale Record', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
        content: Text('Are you sure you want to delete this sale record? Slabs will be returned to inventory.', style: GoogleFonts.inter(color: context.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: Colors.white),
            onPressed: () {
              AppStateScope.read(context).deleteSale(sale.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Sale deleted successfully'), backgroundColor: context.colors.error, behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalRev = state.sales.fold(0.0, (s, sale) => s + sale.total);
    final pending = state.sales.fold(0.0, (s, sale) => s + sale.balanceDue.clamp(0, double.infinity));
    final totalSlabsSold = state.sales.fold(0, (s, sale) => s + sale.lineItems.length);
    final totalAreaSold = state.sales.fold(0.0, (s, sale) => s + sale.totalSqm);
    final activeReservations = state.reservations.where((r) => r.status == ReservationStatus.active).toList();

    // Filter Sales
    final filteredSales = state.sales.reversed.where((sale) {
      final customer = state.customerById(sale.customerId);
      final slabIds = sale.lineItems.map((li) => li.slabId).toList();
      final slabs = state.slabsByIds(slabIds);
      final slabNumbers = slabs.map((s) => s.slabNo).join(' ');

      // Status Filter
      if (_selectedStatus != 'All') {
        if (_selectedStatus == 'Paid' && sale.status != SaleStatus.paid && sale.balanceDue > 0) return false;
        if (_selectedStatus == 'Pending' && sale.balanceDue <= 0) return false;
        if (_selectedStatus == 'Invoiced' && sale.status != SaleStatus.invoiced) return false;
      }

      // Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final cName = (customer?.fullName ?? '').toLowerCase();
        final inv = (sale.invoiceNumber ?? '').toLowerCase();
        final id = sale.id.toLowerCase();
        final slabMatch = slabNumbers.toLowerCase().contains(q);

        return cName.contains(q) || inv.contains(q) || id.contains(q) || slabMatch;
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
            context,
            state.sales.length,
            totalRev,
            pending,
            totalSlabsSold,
            totalAreaSold,
            () => _openSalesForm(),
          ),

          // ── Reserved Slabs Compact Bar ──────────────────────────────
          if (activeReservations.isNotEmpty && _showReservedSection)
            _buildReservedQuickBar(activeReservations, state, colors),

          // ── Search & Filter Bar ──────────────────────────────────────
          _buildSearchAndFilters(colors, isDark),

          // ── Sales Content (Grid / List) ─────────────────────────────
          Expanded(
            child: filteredSales.isEmpty
                ? _buildEmptyState(colors)
                : (_isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: context.responsiveValue(mobile: 500, tablet: 400, desktop: 390),
                          mainAxisExtent: 310,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredSales.length,
                        itemBuilder: (ctx, i) {
                          final sale = filteredSales[i];
                          final customer = state.customerById(sale.customerId);
                          final slabs = state.slabsByIds(sale.lineItems.map((li) => li.slabId).toList());
                          return _SaleGridCard(
                            sale: sale,
                            customer: customer,
                            slabs: slabs,
                            onDetail: () => _showSalesDetailDialog(sale, customer, slabs),
                            onEdit: () => _openSalesForm(existingSale: sale),
                            onDelete: () => _confirmDeleteSale(sale),
                            onPayment: () => _openPaymentsForm(preselectedSale: sale),
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                        itemCount: filteredSales.length,
                        itemBuilder: (ctx, i) {
                          final sale = filteredSales[i];
                          final customer = state.customerById(sale.customerId);
                          final slabs = state.slabsByIds(sale.lineItems.map((li) => li.slabId).toList());
                          return _SaleListCard(
                            sale: sale,
                            customer: customer,
                            slabs: slabs,
                            onDetail: () => _showSalesDetailDialog(sale, customer, slabs),
                            onEdit: () => _openSalesForm(existingSale: sale),
                            onDelete: () => _confirmDeleteSale(sale),
                            onPayment: () => _openPaymentsForm(preselectedSale: sale),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    int count,
    double totalRev,
    double pending,
    int totalSlabsSold,
    double totalAreaSold,
    VoidCallback onNewSale,
  ) {
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
              Text('Sales & Invoicing', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 2),
              Text('Direct sales · invoice generation', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RevBadge('$count Invoices', colors.info),
              _RevBadge('$totalSlabsSold Slabs Sold', colors.success),
              _RevBadge('${totalAreaSold.toStringAsFixed(1)} m² Sold', const Color(0xFFF59E0B)),
              _RevBadge('\$${_fmt(totalRev)} Revenue', colors.primary),
              _RevBadge('\$${_fmt(pending)} Due', pending > 0 ? colors.error : colors.success),
              if (AuthService.instance.currentPermissions.canProcessPayment) ...[
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: () => _openPaymentsForm(),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: Text('Payment', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withAlpha(140)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              if (AuthService.instance.currentPermissions.canCreateSale) ...[
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: onNewSale,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('New Sale', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.success,
                    foregroundColor: Colors.white,
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

  // ── Reserved Slabs Compact Quick Bar ─────────────────────────────────────────
  Widget _buildReservedQuickBar(List<Reservation> reservations, AppState state, AppColorsExtension colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: colors.warning.withAlpha(18),
        border: Border(bottom: BorderSide(color: colors.warning.withAlpha(60))),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_added_rounded, size: 18, color: colors.warning),
          const SizedBox(width: 8),
          Text(
            'Reserved Holds (${reservations.length}):',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: reservations.map((res) {
                  final customer = state.customerById(res.customerId);
                  final slabs = state.slabsByIds(res.slabIds);
                  final area = slabs.fold(0.0, (s, sl) => s + sl.areaSqm);

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.warning.withAlpha(90)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${customer?.fullName ?? "Cust"}: ${slabs.length} slabs (${area.toStringAsFixed(1)}m²)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            _openSalesForm(fromReservation: res, preselectedSlabs: slabs);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sell_rounded, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text('Sell', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: colors.textSecondary),
            onPressed: () => setState(() => _showReservedSection = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Search & Filter Bar ────────────────────────────────────────────────────
  Widget _buildSearchAndFilters(AppColorsExtension colors, bool isDark) {
    const statuses = ['All', 'Paid', 'Invoiced', 'Pending'];

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
                          hintText: 'Search by customer, invoice, slab #...',
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
          Icon(Icons.receipt_long_outlined, size: 56, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text('No sales records found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 6),
          Text('Create a new direct sale or convert from reserved holds.', style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary)),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ── REVENUE BADGE ────────────────────────────────────────────────────────────
class _RevBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RevBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withAlpha(75))),
        child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}

// ── SALE GRID CARD ───────────────────────────────────────────────────────────
class _SaleGridCard extends StatelessWidget {
  final Sale sale;
  final Customer? customer;
  final List<Slab> slabs;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPayment;

  const _SaleGridCard({
    required this.sale,
    required this.customer,
    required this.slabs,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fmt = DateFormat('MMM d, yyyy');
    final isPaid = sale.balanceDue <= 0;
    final statusColor = isPaid ? colors.success : colors.warning;
    final appState = AppStateScope.of(context);
    final matCodes = slabs.map((s) => s.materialId).toSet();
    final matNames = matCodes.map((c) {
      final m = appState.materials.where((it) => it.materialCode == c || it.id == c).firstOrNull;
      return m?.name ?? c;
    }).toList();
    final materialTitle = matNames.isNotEmpty ? matNames.join(', ') : '';
    final slabNos = slabs.map((s) => s.slabNo).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                  child: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 8),
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
                        '${materialTitle.isNotEmpty ? "$materialTitle · " : ""}${sale.invoiceNumber ?? sale.id}',
                        style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SOLD',
                        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withAlpha(80)),
                      ),
                      child: Text(
                        isPaid ? 'Paid' : '\$${sale.balanceDue.toStringAsFixed(0)} Due',
                        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
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
                          _MetricMini('Total', '\$${sale.total.toStringAsFixed(2)}', colors.primary),
                          _MetricMini('Paid', '\$${sale.amountPaid.toStringAsFixed(2)}', colors.textPrimary),
                          _MetricMini('Area', '${sale.totalSqm.toStringAsFixed(2)} m²', colors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (slabNos.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                          child: Text(
                            slabNos,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: colors.textDisabled),
                          const SizedBox(width: 4),
                          Text(fmt.format(sale.saleDate), style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                          const Spacer(),
                          Icon(sale.pickedUp ? Icons.check_circle_rounded : Icons.pending_actions_rounded, size: 12, color: sale.pickedUp ? colors.success : colors.warning),
                          const SizedBox(width: 4),
                          Text(sale.pickedUp ? 'Picked Up' : 'Not Picked', style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary)),
                        ],
                      ),
                    ],
                  ),

                  // Actions: [Trash] [Edit] [Payment] [Detail Button] (Permission Guarded)
                  Row(
                    children: [
                      if (AuthService.instance.currentPermissions.canCancelSale) ...[
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.error),
                          onPressed: onDelete,
                          tooltip: 'Delete Sale',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (AuthService.instance.currentPermissions.canCreateSale) ...[
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
                          onPressed: onEdit,
                          tooltip: 'Edit Sale',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (AuthService.instance.currentPermissions.canProcessPayment) ...[
                        IconButton(
                          icon: Icon(Icons.payments_outlined, size: 18, color: colors.success),
                          onPressed: onPayment,
                          tooltip: 'Payment Form',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onDetail,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: Text('Sale Details', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
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
    );
  }
}

// ── SALE LIST CARD (MATCHING SCREENSHOT 4 STYLE) ─────────────────────────────
class _SaleListCard extends StatelessWidget {
  final Sale sale;
  final Customer? customer;
  final List<Slab> slabs;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPayment;

  const _SaleListCard({
    required this.sale,
    required this.customer,
    required this.slabs,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fmt = DateFormat('MMM d, yyyy');
    final isPaid = sale.balanceDue <= 0;
    final statusColor = isPaid ? colors.success : colors.warning;
    final statusText = isPaid ? 'Paid' : '\$${sale.balanceDue.toStringAsFixed(0)} Due';
    final slabNos = slabs.map((s) => s.slabNo).join(', ');

    final appState = AppStateScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matCodes = slabs.map((s) => s.materialId).toSet();
    final matNames = matCodes.map((c) {
      final m = appState.materials.where((it) => it.materialCode == c || it.id == c).firstOrNull;
      return m?.name ?? c;
    }).toList();
    final materialTitle = matNames.isNotEmpty ? matNames.join(', ') : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Left Action Buttons as in screenshot 4: [Delete] [Edit] [Payment]
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: colors.textSecondary),
                  onPressed: onDelete,
                  tooltip: 'Delete Sale',
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary),
                  onPressed: onEdit,
                  tooltip: 'Edit Sale',
                ),
                IconButton(
                  icon: Icon(Icons.payments_outlined, size: 20, color: colors.success),
                  onPressed: onPayment,
                  tooltip: 'Payment Form',
                ),
              ],
            ),
            const SizedBox(width: 8),

            // Customer and Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        customer?.fullName ?? 'Unknown Customer',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      // Prominent SOLD Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF10B981)),
                            const SizedBox(width: 3),
                            Text(
                              'SOLD',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Payment status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          statusText,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                      if (sale.fromReservationId != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'From Hold',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${sale.invoiceNumber ?? sale.id} · ${fmt.format(sale.saleDate)}',
                        style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                      ),
                      if (materialTitle.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            materialTitle.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: colors.primary),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${slabs.length} slabs (${sale.totalSqm.toStringAsFixed(2)} m²)',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  if (slabNos.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Slabs Sold: $slabNos',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Price and Big Action Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${sale.total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                // Prominent Sale / Detail Button
                ElevatedButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: Text('Sale', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricMini(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: context.colors.textDisabled)),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ── SALES FORM DIALOG (MATCHING SCREENSHOTS 1, 2 & 3) ────────────────────────
class SalesFormDialog extends StatefulWidget {
  final Sale? existingSale;
  final Reservation? fromReservation;
  final List<Slab>? preselectedSlabs;

  const SalesFormDialog({
    super.key,
    this.existingSale,
    this.fromReservation,
    this.preselectedSlabs,
  });

  static Future<void> show(
    BuildContext context, {
    Sale? existingSale,
    Reservation? fromReservation,
    List<Slab>? preselectedSlabs,
  }) {
    return AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => SalesFormDialog(
        existingSale: existingSale,
        fromReservation: fromReservation,
        preselectedSlabs: preselectedSlabs,
      ),
    );
  }

  @override
  State<SalesFormDialog> createState() => _SalesFormDialogState();
}

class _SalesFormDialogState extends State<SalesFormDialog> {
  late String _saleId;
  DateTime _saleDate = DateTime.now();
  Customer? _selectedCustomer;
  MaterialItem? _selectedMaterial;
  double _priceSqm = 70.0;
  SaleStatus _status = SaleStatus.invoiced;
  final _notesCtrl = TextEditingController();
  String? _inventoryId;
  final _amountPaidCtrl = TextEditingController(text: '0.00');
  bool _pickedUp = false;
  DateTime _pickupDate = DateTime.now();
  final Set<String> _selectedSlabIds = {};

  String? _errorMsg;

  bool get _isEditing => widget.existingSale != null;

  @override
  void initState() {
    super.initState();
    final sale = widget.existingSale;
    if (sale != null) {
      _saleId = sale.id;
      _saleDate = sale.saleDate;
      _status = sale.status;
      _notesCtrl.text = sale.notes ?? '';
      _amountPaidCtrl.text = sale.amountPaid.toStringAsFixed(2);
      _pickedUp = sale.pickedUp;
      _pickupDate = sale.pickupDate ?? DateTime.now();
      _selectedSlabIds.addAll(sale.lineItems.map((li) => li.slabId));
      if (sale.lineItems.isNotEmpty) {
        _priceSqm = sale.lineItems.first.agreedPricePerSqm;
      }
    } else {
      _saleId = _generateSaleId();
      if (widget.preselectedSlabs != null) {
        _selectedSlabIds.addAll(widget.preselectedSlabs!.map((s) => s.id));
      }
      if (widget.fromReservation?.notes != null) {
        _notesCtrl.text = widget.fromReservation!.notes!;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppStateScope.read(context);

      if (sale != null) {
        setState(() {
          _selectedCustomer = state.customerById(sale.customerId);
        });
      } else if (widget.fromReservation != null) {
        setState(() {
          _selectedCustomer = state.customerById(widget.fromReservation!.customerId);
          if (widget.fromReservation!.depositAmount > 0) {
            _amountPaidCtrl.text = widget.fromReservation!.depositAmount.toStringAsFixed(2);
          }
        });
      }

      _syncMaterialAndInventory(state);
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  static String _generateSaleId() {
    final rand = Random();
    return List.generate(8, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  void _syncMaterialAndInventory(AppState appState) {
    if (_selectedSlabIds.isNotEmpty) {
      final firstSlab = appState.slabs.firstWhere(
        (s) => s.id == _selectedSlabIds.first,
        orElse: () => appState.slabs.first,
      );
      final mat = appState.materialById(firstSlab.materialId);
      setState(() {
        _selectedMaterial = mat;
        _inventoryId = firstSlab.inventoryId ?? firstSlab.warehouseLocation;
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
          _syncMaterialAndInventory(appState);
        },
      ),
    );
  }

  void _openAddCustomer() {
    AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => showCustomerRegistrationDialog(context, (newCust) {
        setState(() => _selectedCustomer = newCust);
      }) as Widget? ?? const SizedBox(),
    );
  }

  void _save() {
    if (_selectedCustomer == null) {
      setState(() => _errorMsg = 'Please select a CustomerID');
      return;
    }
    if (_selectedSlabIds.isEmpty) {
      setState(() => _errorMsg = 'Please select at least one slab in SlabsToSell');
      return;
    }

    final appState = AppStateScope.read(context);
    final selectedSlabs = appState.slabs.where((s) => _selectedSlabIds.contains(s.id)).toList();
    final lineItems = selectedSlabs.map((s) => SaleLineItem(slabId: s.id, agreedPricePerSqm: _priceSqm, areaSqm: s.areaSqm)).toList();
    final amountPaid = double.tryParse(_amountPaidCtrl.text) ?? 0.0;

    if (_isEditing) {
      appState.updateSale(
        saleId: _saleId,
        customerId: _selectedCustomer!.id,
        lineItems: lineItems,
        saleDate: _saleDate,
        status: _status,
        amountPaid: amountPaid,
        pickedUp: _pickedUp,
        pickupDate: _pickupDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Sale updated successfully ✓'), backgroundColor: context.colors.primary, behavior: SnackBarBehavior.floating),
      );
    } else {
      appState.createSale(
        customerId: _selectedCustomer!.id,
        lineItems: lineItems,
        paymentMethod: PaymentMethod.cash,
        amountPaid: amountPaid,
        pickedUp: _pickedUp,
        pickupDate: _pickupDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        fromReservationId: widget.fromReservation?.id,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Sale recorded successfully ✓'), backgroundColor: context.colors.success, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final colors = context.colors;
    final fmtDate = DateFormat('MM/dd/yyyy');

    // Calculations
    final selectedSlabs = state.slabs.where((s) => _selectedSlabIds.contains(s.id)).toList();
    final totalAreaSqm = selectedSlabs.fold(0.0, (s, sl) => s + sl.areaSqm);
    final totalAmount = totalAreaSqm * _priceSqm;
    final amountPaid = double.tryParse(_amountPaidCtrl.text) ?? 0.0;
    final balanceDue = (totalAmount - amountPaid).clamp(0.0, double.infinity);
    final slabNoDisplay = selectedSlabs.map((s) => s.slabNo).join(', ');

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(240.0, 840.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: [X] Sales Form       [Cancel] [Save]
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
                      'Sales Form',
                      style: GoogleFonts.inter(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w600, color: colors.textPrimary),
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
                  decoration: BoxDecoration(color: colors.error.withAlpha(25), borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.error.withAlpha(100))),
                  child: Text(_errorMsg!, style: GoogleFonts.inter(fontSize: 12, color: colors.error, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
              ],

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. SaleID*
                      _buildLabel('SaleID*'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        alignment: Alignment.centerLeft,
                        child: Text(_saleId, style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary)),
                      ),
                      const SizedBox(height: 14),

                      // 2. SaleDate
                      _buildLabel('SaleDate'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _saleDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                          if (picked != null) setState(() => _saleDate = picked);
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                          child: Row(
                            children: [
                              Expanded(child: Text(fmtDate.format(_saleDate), style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary))),
                              Icon(Icons.calendar_month_outlined, size: 18, color: colors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. CustomerID
                      _buildLabel('CustomerID'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Customer>(
                                  isExpanded: true,
                                  value: _selectedCustomer,
                                  dropdownColor: colors.surface,
                                  icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                                  hint: Text('Select customer...', style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled)),
                                  items: state.customers.map((c) {
                                    return DropdownMenuItem(value: c, child: Text('${c.id} - ${c.fullName}', style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)));
                                  }).toList(),
                                  onChanged: (c) => setState(() => _selectedCustomer = c),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.person_add_rounded),
                            color: colors.primary,
                            onPressed: _openAddCustomer,
                            tooltip: 'Add Customer',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4. MaterialCode
                      _buildLabel('MaterialCode'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MaterialItem>(
                            isExpanded: true,
                            value: _selectedMaterial,
                            dropdownColor: colors.surface,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            hint: Text('Select material...', style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled)),
                            items: state.materials.map((m) {
                              return DropdownMenuItem(value: m, child: Text('${m.materialCode} - ${m.name}', style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)));
                            }).toList(),
                            onChanged: (m) => setState(() => _selectedMaterial = m),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 5. Price_sqm with stepper buttons [-] [+]
                      _buildLabel('Price_sqm'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: Row(
                          children: [
                            Text('\$ ${_priceSqm.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              color: colors.textSecondary,
                              onPressed: () {
                                if (_priceSqm > 5) setState(() => _priceSqm -= 5);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 14),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              color: colors.textSecondary,
                              onPressed: () => setState(() => _priceSqm += 5),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 6. Status
                      _buildLabel('Status'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<SaleStatus>(
                            isExpanded: true,
                            value: _status,
                            dropdownColor: colors.surface,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            items: SaleStatus.values.map((st) {
                              return DropdownMenuItem(value: st, child: Text(st.name.toUpperCase(), style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)));
                            }).toList(),
                            onChanged: (st) {
                              if (st != null) setState(() => _status = st);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 7. Notes
                      _buildLabel('Notes'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _notesCtrl,
                          style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                          decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 8. InventoryID
                      _buildLabel('InventoryID'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _inventoryId,
                            dropdownColor: colors.surface,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            hint: Text(_inventoryId ?? 'Auto-populated from slabs', style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)),
                            items: ['Warehouse Main', 'Yard A', 'Rack Section', _inventoryId].whereType<String>().toSet().map((loc) {
                              return DropdownMenuItem(value: loc, child: Text(loc, style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)));
                            }).toList(),
                            onChanged: (loc) => setState(() => _inventoryId = loc),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 9. AmountPaid*
                      _buildLabel('AmountPaid*'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _amountPaidCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                          decoration: const InputDecoration(prefixText: '\$ ', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 10. BalanceDue (Read-Only Auto-calculated formula)
                      _buildLabel('BalanceDue'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$ ${balanceDue.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: balanceDue > 0 ? colors.error : colors.success),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 11. PickedUp [N] [Y] Toggle
                      _buildLabel('PickedUp'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _pickedUp = false),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: !_pickedUp ? colors.primary : colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: !_pickedUp ? colors.primary : colors.border),
                                ),
                                alignment: Alignment.center,
                                child: Text('N', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: !_pickedUp ? Colors.white : colors.textSecondary)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _pickedUp = true),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _pickedUp ? colors.success : colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _pickedUp ? colors.success : colors.border),
                                ),
                                alignment: Alignment.center,
                                child: Text('Y', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _pickedUp ? Colors.white : colors.textSecondary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 12. PickupDate
                      _buildLabel('PickupDate'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _pickupDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                          if (picked != null) setState(() => _pickupDate = picked);
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                          child: Row(
                            children: [
                              Expanded(child: Text(fmtDate.format(_pickupDate), style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary))),
                              Icon(Icons.calendar_month_outlined, size: 18, color: colors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 13. SlabsToSell with Search and '+' button
                      _buildLabel('SlabsToSell'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _openSlabSelector(state),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.primary.withAlpha(180))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedSlabIds.isEmpty ? 'Search' : '$slabNoDisplay (${totalAreaSqm.toStringAsFixed(2)} m²)',
                                  style: GoogleFonts.inter(fontSize: 13, color: _selectedSlabIds.isEmpty ? colors.textDisabled : colors.textPrimary, fontWeight: _selectedSlabIds.isEmpty ? FontWeight.normal : FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.add, size: 20, color: colors.primary),
                            ],
                          ),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: context.colors.textSecondary),
    );
  }
}

// ── SALES DETAIL DIALOG (MATCHING SCREENSHOT 3 & 4) ──────────────────────────
class _SalesDetailDialog extends StatelessWidget {
  final Sale sale;
  final Customer? customer;
  final List<Slab> slabs;
  final VoidCallback onEdit;
  final VoidCallback onPayment;

  const _SalesDetailDialog({
    required this.sale,
    required this.customer,
    required this.slabs,
    required this.onEdit,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final totalArea = sale.totalSqm;
    final unitPrice = sale.lineItems.isNotEmpty ? sale.lineItems.first.agreedPricePerSqm : 0.0;
    final state = AppStateScope.of(context);
    final firstSlab = slabs.isNotEmpty ? slabs.first : null;
    final mat = firstSlab != null ? state.materialById(firstSlab.materialId) : null;
    final slabNos = slabs.map((s) => s.slabNo).join(', ');
    final fmt = DateFormat('M/d/yyyy');

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(240.0, 720.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: availableHeight),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sales Detail', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prominent Circular Sell Icon matching Screenshot 3
                      Center(
                        child: Column(
                          children: [
                            InkWell(
                              onTap: onPayment,
                              borderRadius: BorderRadius.circular(32),
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF64B5F6),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF64B5F6).withAlpha(120), blurRadius: 14, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Sell', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: colors.border, height: 1),
                      const SizedBox(height: 14),

                      // Detail List exactly as in Screenshot 3:
                      _buildDetailItem('SaleID', sale.id, colors),
                      const SizedBox(height: 10),

                      _buildDetailItem('SaleDate', fmt.format(sale.saleDate), colors),
                      const SizedBox(height: 10),

                      _buildDetailItem('CustomerID', '${customer?.fullName ?? sale.customerId} (${sale.customerId})', colors),
                      const SizedBox(height: 10),

                      _buildDetailItem(
                        'MaterialCode',
                        '${mat?.materialCode ?? "1306"} - ${mat?.name ?? "ROYAL GREY"}',
                        colors,
                        leadingIcon: Icons.label_important_rounded,
                      ),
                      const SizedBox(height: 10),

                      _buildDetailItem('QuantitySold_sqm', totalArea.toStringAsFixed(2), colors),
                      const SizedBox(height: 10),

                      _buildDetailItem('LocationType', firstSlab?.warehouseLocation ?? 'Field', colors),
                      const SizedBox(height: 10),

                      _buildDetailItem('InventoryDeduct_sqm', totalArea.toStringAsFixed(2), colors),
                      const SizedBox(height: 10),

                      _buildDetailItem('Price_sqm', '\$${unitPrice.toStringAsFixed(2)}', colors),
                      const SizedBox(height: 10),

                      _buildDetailItem('TotalAmount', '\$${sale.total.toStringAsFixed(2)}', colors, isBold: true),
                      const SizedBox(height: 10),

                      _buildDetailItem('AmountPaid', '\$${sale.amountPaid.toStringAsFixed(2)} (Due: \$${sale.balanceDue.toStringAsFixed(2)})', colors),
                      const SizedBox(height: 10),

                      if (slabNos.isNotEmpty) ...[
                        _buildDetailItem('Slabs', slabNos, colors),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bottom Action Buttons: Payment & Accept Sale
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPayment,
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: Text('Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sale for ${customer?.fullName ?? sale.id} confirmed and accepted ✓', style: GoogleFonts.inter(color: Colors.white)),
                            backgroundColor: colors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: Text('Accept Sale', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildDetailItem(String label, String value, AppColorsExtension colors, {IconData? leadingIcon, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
        const SizedBox(height: 2),
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 16, color: colors.warning),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: isBold ? 16 : 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: isBold ? colors.primary : colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── SLAB PICKER DIALOG (FOR SELECTING SLABS IN SALES FORM) ───────────────────
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
      return s.slabNo.toLowerCase().contains(q) || s.warehouseLocation.toLowerCase().contains(q) || matName.contains(q);
    }).toList();

    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(240.0, 640.0);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
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
                  Text('Select Slabs To Sell', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.selectedSlabIds.length} slabs selected', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary)),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => widget.selectedSlabIds.addAll(filtered.map((s) => s.id)));
                          widget.onSelectionChanged();
                        },
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => widget.selectedSlabIds.clear());
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
                    ? Center(child: Text('No slabs available', style: GoogleFonts.inter(color: colors.textSecondary)))
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
                                  Icon(isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 20, color: isSelected ? colors.primary : colors.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.slabNo, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                                        Text('${mat?.name ?? "—"} · ${s.warehouseLocation}', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Text('${s.areaSqm.toStringAsFixed(2)} m²', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
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
                style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PAYMENTS FORM DIALOG (MATCHING SCREENSHOT 1 & 2) ─────────────────────────
class _PaymentsFormDialog extends StatefulWidget {
  final Sale? preselectedSale;
  const _PaymentsFormDialog({this.preselectedSale});

  @override
  State<_PaymentsFormDialog> createState() => _PaymentsFormDialogState();
}

class _PaymentsFormDialogState extends State<_PaymentsFormDialog> {
  late String _paymentId;
  late DateTime _paymentDate;
  String? _selectedCustomerId;
  String? _selectedSaleId;
  String? _selectedReservationId;
  late TextEditingController _amountPaidCtrl;
  String _paymentType = 'USD';
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paymentId = DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(8, '0').substring(0, 8);
    _paymentDate = DateTime.now();

    final sale = widget.preselectedSale;
    if (sale != null) {
      _selectedSaleId = sale.id;
      _selectedCustomerId = sale.customerId;
      _selectedReservationId = sale.fromReservationId;
      final due = sale.balanceDue > 0 ? sale.balanceDue : sale.total;
      _amountPaidCtrl = TextEditingController(text: due.toStringAsFixed(2));
    } else {
      _amountPaidCtrl = TextEditingController(text: '0.00');
    }
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _stepAmount(double delta) {
    final current = double.tryParse(_amountPaidCtrl.text.replaceAll(',', '')) ?? 0.0;
    final next = (current + delta).clamp(0.0, 999999999.0);
    setState(() {
      _amountPaidCtrl.text = _paymentType == 'IQD'
          ? next.toStringAsFixed(0)
          : next.toStringAsFixed(2);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  void _savePayment() {
    final amount = double.tryParse(_amountPaidCtrl.text.replaceAll(',', '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid amount paid', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final custId = _selectedCustomerId ?? (widget.preselectedSale?.customerId ?? 'WALK-IN');

    AppStateScope.read(context).addPayment(
      customerId: custId,
      amountPaid: amount,
      paymentType: _paymentType,
      relatedSaleId: _selectedSaleId,
      relatedReservationId: _selectedReservationId,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    Navigator.pop(context);

    final sym = _paymentType == 'IQD' ? 'IQD ' : '\$';
    final fmtAmount = _paymentType == 'IQD' ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment of $sym$fmtAmount recorded successfully ✓', style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: context.colors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldBg = isDark ? const Color(0xFF1E1E1E) : colors.surfaceVariant;
    final fieldBorder = isDark ? const Color(0xFF333333) : colors.border;
    final labelColor = isDark ? const Color(0xFFAAAAAA) : colors.textSecondary;
    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 24).clamp(240.0, 840.0);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF161616) : colors.surface,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: fieldBorder)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: availableHeight),
        child: Column(
          children: [
            // Top Bar: [X Payments Form] ... [Cancel] [Save]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: fieldBorder)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textPrimary, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payments Form',
                      style: GoogleFonts.inter(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _savePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF90CAF9),
                      foregroundColor: const Color(0xFF0D253F),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: Text('Save', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. PaymentID*
                    _buildFieldLabel('PaymentID*', labelColor),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: fieldBorder),
                      ),
                      child: Text(
                        _paymentId,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. PaymentDate
                    _buildFieldLabel('PaymentDate', labelColor),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: fieldBorder),
                        ),
                        child: Row(
                          children: [
                            Text(
                              DateFormat('MM/dd/yyyy').format(_paymentDate),
                              style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
                            ),
                            const Spacer(),
                            Icon(Icons.calendar_today_outlined, size: 18, color: colors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3. CustomerID
                    _buildFieldLabel('CustomerID', labelColor),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: fieldBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCustomerId,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF222222) : colors.surface,
                          hint: Text('Select Customer', style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled)),
                          icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                          items: state.customers.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.fullName} (${c.id})', style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedCustomerId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 4. RelatedSaleID
                    _buildFieldLabel('RelatedSaleID', labelColor),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: fieldBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSaleId,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF222222) : colors.surface,
                          hint: Row(
                            children: [
                              Icon(Icons.description_outlined, size: 16, color: colors.textDisabled),
                              const SizedBox(width: 8),
                              Text('Select Related Sale', style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled)),
                            ],
                          ),
                          icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                          items: state.sales.map((s) {
                            final c = state.customerById(s.customerId);
                            return DropdownMenuItem(
                              value: s.id,
                              child: Row(
                                children: [
                                  Icon(Icons.description_outlined, size: 16, color: colors.textSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${s.id}  (${c?.fullName ?? "Client"} - \$${s.total.toStringAsFixed(0)}, due \$${s.balanceDue.toStringAsFixed(0)})',
                                      style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedSaleId = v;
                              if (v != null) {
                                final s = state.sales.firstWhere((item) => item.id == v);
                                _selectedCustomerId = s.customerId;
                                _selectedReservationId = s.fromReservationId;
                                final due = s.balanceDue > 0 ? s.balanceDue : s.total;
                                _amountPaidCtrl.text = due.toStringAsFixed(2);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 5. RelatedReservationID
                    _buildFieldLabel('RelatedReservationID', labelColor),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: fieldBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedReservationId,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF222222) : colors.surface,
                          hint: Text('Select Related Reservation (optional)', style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled)),
                          icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('None', style: TextStyle(color: Colors.grey)),
                            ),
                            ...state.reservations.map((r) {
                              final c = state.customerById(r.customerId);
                              return DropdownMenuItem<String>(
                                value: r.id,
                                child: Text('${r.id} (${c?.fullName ?? "Customer"})', style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)),
                              );
                            }),
                          ],
                          onChanged: (v) => setState(() => _selectedReservationId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 6. AmountPaid* with - and + Steppers
                    _buildFieldLabel('AmountPaid*', labelColor),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: fieldBorder),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _paymentType == 'IQD' ? 'IQD ' : '\$ ',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _paymentType == 'IQD' ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _amountPaidCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                            ),
                          ),
                          // Steppers - and + matching screenshot
                          InkWell(
                            onTap: () => _stepAmount(_paymentType == 'IQD' ? -25000 : -50),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.remove, size: 18, color: colors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _stepAmount(_paymentType == 'IQD' ? 25000 : 50),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.add, size: 18, color: colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 7. PaymentType
                    _buildFieldLabel('PaymentType', labelColor),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentTypeOption(
                            code: 'USD',
                            title: 'US Dollar',
                            symbol: '\$',
                            icon: Icons.attach_money_rounded,
                            accentColor: const Color(0xFF10B981),
                            isSelected: _paymentType == 'USD',
                            onTap: () {
                              if (_paymentType != 'USD') {
                                setState(() => _paymentType = 'USD');
                              }
                            },
                            fieldBg: fieldBg,
                            fieldBorder: fieldBorder,
                            isDark: isDark,
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentTypeOption(
                            code: 'IQD',
                            title: 'Iraqi Dinar',
                            symbol: 'د.ع',
                            icon: Icons.payments_rounded,
                            accentColor: const Color(0xFFF59E0B),
                            isSelected: _paymentType == 'IQD',
                            onTap: () {
                              if (_paymentType != 'IQD') {
                                setState(() => _paymentType = 'IQD');
                              }
                            },
                            fieldBg: fieldBg,
                            fieldBorder: fieldBorder,
                            isDark: isDark,
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 8. Notes
                    _buildFieldLabel('Notes', labelColor),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: fieldBorder),
                      ),
                      child: TextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        minLines: 2,
                        style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTypeOption({
    required String code,
    required String title,
    required String symbol,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
    required Color fieldBg,
    required Color fieldBorder,
    required bool isDark,
    required dynamic colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
              : fieldBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accentColor : fieldBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: isDark ? 0.28 : 0.2)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? accentColor : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        code,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? colors.textPrimary : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($symbol)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? accentColor : colors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isSelected ? colors.textSecondary : colors.textDisabled,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? accentColor : colors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Text(
      label,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: color),
    );
  }
}

