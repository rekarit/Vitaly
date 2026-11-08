import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/models/customer.dart';
import '../../core/models/material_item.dart';
import '../../core/models/sale.dart';
import '../../core/models/return_item.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/services/auth_service.dart';

// ── RETURNS SCREEN ──────────────────────────────────────────────────────────
class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All'; // 'All', 'Completed', 'Pending', 'Approved', 'Rejected'
  bool _isGridView = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openReturnForm({ReturnItem? existingReturn}) {
    AdaptiveDialog.show<void>(
      context: context,
      builder: (ctx) => _ReturnsFormDialog(existingReturn: existingReturn),
    );
  }

  void _confirmDeleteReturn(ReturnItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Delete Return', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
        content: Text('Are you sure you want to delete this return record?', style: GoogleFonts.inter(color: context.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: Colors.white),
            onPressed: () {
              AppStateScope.read(context).deleteReturn(item.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Return record deleted ✓'), backgroundColor: context.colors.error, behavior: SnackBarBehavior.floating),
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

    final totalReturnedArea = state.returns.fold(0.0, (sum, r) => sum + r.quantityReturnedSqm);
    final pendingCount = state.returns.where((r) => r.status == ReturnStatus.pending).length;

    // Filter returns
    final filtered = state.returns.reversed.where((r) {
      final customer = state.customerById(r.customerId);

      // Status filter
      if (_selectedStatus != 'All') {
        final match = switch (_selectedStatus) {
          'Completed' => r.status == ReturnStatus.completed,
          'Pending' => r.status == ReturnStatus.pending,
          'Approved' => r.status == ReturnStatus.approved,
          'Rejected' => r.status == ReturnStatus.rejected,
          _ => true,
        };
        if (!match) return false;
      }

      // Query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final cName = (customer?.fullName ?? '').toLowerCase();
        final id = r.id.toLowerCase();
        final saleId = (r.originalSaleId ?? '').toLowerCase();
        final mat = (r.materialCode ?? '').toLowerCase();
        final notes = (r.notes ?? '').toLowerCase();

        return cName.contains(q) || id.contains(q) || saleId.contains(q) || mat.contains(q) || notes.contains(q);
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Preserved screen UI (all buttons, headers, filters, list/grid intact)
          AbsorbPointer(
            absorbing: true,
            child: Opacity(
              opacity: 0.30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Bar ──────────────────────────────────────────────
                  _buildHeader(context, state.returns.length, totalReturnedArea, pendingCount, () => _openReturnForm()),

                  // ── Search & Filter Bar ──────────────────────────────────────
                  _buildSearchAndFilters(colors, isDark),

                  // ── Content (Grid / List) ────────────────────────────────────
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmptyState(colors)
                        : (_isGridView
                            ? GridView.builder(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: context.responsiveValue(mobile: 500, tablet: 400, desktop: 390),
                                  mainAxisExtent: 290,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) {
                                  final item = filtered[i];
                                  final customer = state.customerById(item.customerId);
                                  return _ReturnGridCard(
                                    item: item,
                                    customer: customer,
                                    onEdit: () => _openReturnForm(existingReturn: item),
                                    onDelete: () => _confirmDeleteReturn(item),
                                  );
                                },
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) {
                                  final item = filtered[i];
                                  final customer = state.customerById(item.customerId);
                                  return _ReturnListCard(
                                    item: item,
                                    customer: customer,
                                    onEdit: () => _openReturnForm(existingReturn: item),
                                    onDelete: () => _confirmDeleteReturn(item),
                                  );
                                },
                              )),
                  ),
                ],
              ),
            ),
          ),

          // ── Darkening tint overlay
          Container(
            color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.45),
          ),

          // ── Center Unavailable & Lock Card
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161C24).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Lock Icon
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF9800).withValues(alpha: 0.25),
                          const Color(0xFFE65100).withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.28),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 38,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Unavailable Right now title
                  Text(
                    'Unavailable Right now',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'This section is currently unavailable',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: Color(0xFFFF9800),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Temporarily Locked',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                      ],
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

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, int count, double totalArea, int pendingCount, VoidCallback onNewReturn) {
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
              Text('Returns', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 2),
              Text('Manage customer returns, restocked slabs & credit', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeaderBadge(label: 'Total Returns', value: '$count', color: colors.info),
              _HeaderBadge(label: 'Restocked Area', value: '${totalArea.toStringAsFixed(2)} m²', color: const Color(0xFFFF9800)),
              _HeaderBadge(label: 'Pending', value: '$pendingCount', color: pendingCount > 0 ? colors.warning : colors.success),
              if (AuthService.instance.currentPermissions.canCreateReturn) ...[
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: onNewReturn,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('New Return', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
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

  // ── Search & Filter Bar ────────────────────────────────────────────────────
  Widget _buildSearchAndFilters(AppColorsExtension colors, bool isDark) {
    const statuses = ['All', 'Completed', 'Pending', 'Approved', 'Rejected'];

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
                          hintText: 'Search by return ID, customer, sale ID...',
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
                      color: isSelected ? const Color(0xFFFF9800) : (isDark ? colors.surfaceVariant : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? const Color(0xFFFF9800) : colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      st,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : colors.textSecondary,
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
                color: !_isGridView ? const Color(0xFFFF9800) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_list_rounded, size: 16, color: !_isGridView ? Colors.white : colors.textSecondary),
                  const SizedBox(width: 5),
                  Text('List', style: GoogleFonts.inter(fontSize: 12, fontWeight: !_isGridView ? FontWeight.bold : FontWeight.w500, color: !_isGridView ? Colors.white : colors.textSecondary)),
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
                color: _isGridView ? const Color(0xFFFF9800) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, size: 16, color: _isGridView ? Colors.white : colors.textSecondary),
                  const SizedBox(width: 5),
                  Text('Grid', style: GoogleFonts.inter(fontSize: 12, fontWeight: _isGridView ? FontWeight.bold : FontWeight.w500, color: _isGridView ? Colors.white : colors.textSecondary)),
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
          Icon(Icons.assignment_return_outlined, size: 56, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text('No return records found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 6),
          Text('Process sales returns, exchange slabs, or restock inventory.', style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openReturnForm(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Record Return', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withAlpha(75))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: context.colors.textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── RETURN GRID CARD ─────────────────────────────────────────────────────────
class _ReturnGridCard extends StatelessWidget {
  final ReturnItem item;
  final Customer? customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReturnGridCard({
    required this.item,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fmt = DateFormat('MMM d, yyyy');
    final statusColor = item.status == ReturnStatus.completed
        ? colors.success
        : (item.status == ReturnStatus.rejected ? colors.error : colors.warning);

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
                  backgroundColor: statusColor.withAlpha(35),
                  child: Icon(Icons.assignment_return_rounded, size: 16, color: statusColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer?.fullName ?? 'Unknown Customer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Return #${item.id}', style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withAlpha(30), borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withAlpha(80))),
                  child: Text(item.status.name.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
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
                          _MiniReturnInfo('Qty Returned', '${item.quantityReturnedSqm.toStringAsFixed(2)} m²', colors.primary),
                          _MiniReturnInfo('Condition', item.condition, colors.textPrimary),
                          _MiniReturnInfo('Restocked', item.restockToInventory ? 'YES' : 'NO', item.restockToInventory ? colors.success : colors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (item.materialCode != null && item.materialCode!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                          child: Text(
                            'Material: ${item.materialCode}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.receipt_outlined, size: 12, color: colors.textDisabled),
                          const SizedBox(width: 4),
                          Text('Sale: ${item.originalSaleId ?? "Direct"}', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                          const Spacer(),
                          Icon(Icons.calendar_today_outlined, size: 11, color: colors.textDisabled),
                          const SizedBox(width: 4),
                          Text(fmt.format(item.returnDate), style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                        ],
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.notes!, style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),

                  // Actions: [Delete] [Edit]
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.error),
                        onPressed: onDelete,
                        tooltip: 'Delete Return',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: Text('Edit Return', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary.withAlpha(120)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

// ── RETURN LIST CARD ─────────────────────────────────────────────────────────
class _ReturnListCard extends StatelessWidget {
  final ReturnItem item;
  final Customer? customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReturnListCard({
    required this.item,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fmt = DateFormat('MMM d, yyyy');
    final statusColor = item.status == ReturnStatus.completed
        ? colors.success
        : (item.status == ReturnStatus.rejected ? colors.error : colors.warning);

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
            // Actions
            IconButton(icon: Icon(Icons.delete_outline_rounded, size: 20, color: colors.textSecondary), onPressed: onDelete),
            IconButton(icon: Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary), onPressed: onEdit),
            const SizedBox(width: 8),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(customer?.fullName ?? 'Unknown Customer', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                        child: Text(item.status.name.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Return #${item.id} · Sale: ${item.originalSaleId ?? "—"} · ${fmt.format(item.returnDate)} · Reason: ${item.returnReason}',
                    style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                  ),
                  if (item.materialCode != null && item.materialCode!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Material: ${item.materialCode} · Condition: ${item.condition}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary)),
                  ],
                ],
              ),
            ),

            // Quantity & Restock Tag
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${item.quantityReturnedSqm.toStringAsFixed(2)} m²', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: item.restockToInventory ? colors.success.withAlpha(25) : colors.textDisabled.withAlpha(25), borderRadius: BorderRadius.circular(4)),
                  child: Text(item.restockToInventory ? 'Restocked' : 'No Restock', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: item.restockToInventory ? colors.success : colors.textDisabled)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniReturnInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniReturnInfo(this.label, this.value, this.color);

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

// ── RETURNS FORM DIALOG (MATCHING SCREENSHOTS 1 & 2) ─────────────────────────
class _ReturnsFormDialog extends StatefulWidget {
  final ReturnItem? existingReturn;
  const _ReturnsFormDialog({this.existingReturn});

  @override
  State<_ReturnsFormDialog> createState() => _ReturnsFormDialogState();
}

class _ReturnsFormDialogState extends State<_ReturnsFormDialog> {
  late String _returnId;
  DateTime _returnDate = DateTime.now();
  Sale? _selectedSale;
  Customer? _selectedCustomer;
  MaterialItem? _selectedMaterial;
  String? _inventoryId;
  double _quantityReturned = 0.0;
  String _returnReason = 'Defective / Damaged';
  String _condition = 'Good';
  bool _restockToInventory = true;
  ReturnStatus _status = ReturnStatus.completed;
  final _notesCtrl = TextEditingController();

  String? _errorMsg;

  bool get _isEditing => widget.existingReturn != null;

  final List<String> _reasons = [
    'Defective / Damaged',
    'Customer Changed Mind',
    'Wrong Item / Dimension',
    'Vein / Color Mismatch',
    'Job Cancelled',
  ];

  final List<String> _conditions = [
    'Flawless',
    'Good',
    'Minor Scratch',
    'Cracked',
    'Damaged',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.existingReturn;
    if (item != null) {
      _returnId = item.id;
      _returnDate = item.returnDate;
      _quantityReturned = item.quantityReturnedSqm;
      _returnReason = item.returnReason;
      _condition = item.condition;
      _restockToInventory = item.restockToInventory;
      _status = item.status;
      _inventoryId = item.inventoryId;
      _notesCtrl.text = item.notes ?? '';
    } else {
      _returnId = _generateReturnId();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppStateScope.read(context);

      if (item != null) {
        setState(() {
          _selectedCustomer = state.customerById(item.customerId);
          if (item.originalSaleId != null) {
            _selectedSale = state.sales.where((s) => s.id == item.originalSaleId).firstOrNull;
          }
          if (item.materialCode != null) {
            _selectedMaterial = state.materials.where((m) => m.materialCode == item.materialCode).firstOrNull;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  static String _generateReturnId() {
    final rand = Random();
    return List.generate(8, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  void _onSaleSelected(Sale? sale, AppState state) {
    setState(() {
      _selectedSale = sale;
      if (sale != null) {
        _selectedCustomer = state.customerById(sale.customerId);
        _quantityReturned = sale.totalSqm;

        final slabs = state.slabsByIds(sale.lineItems.map((li) => li.slabId).toList());
        if (slabs.isNotEmpty) {
          _selectedMaterial = state.materialById(slabs.first.materialId);
          _inventoryId = slabs.first.warehouseLocation;
        }
      }
    });
  }

  void _save() {
    if (_selectedCustomer == null) {
      setState(() => _errorMsg = 'Please select a CustomerID');
      return;
    }

    final appState = AppStateScope.read(context);

    if (_isEditing) {
      appState.updateReturn(
        returnId: _returnId,
        customerId: _selectedCustomer!.id,
        originalSaleId: _selectedSale?.id,
        materialCode: _selectedMaterial?.materialCode,
        inventoryId: _inventoryId,
        quantityReturnedSqm: _quantityReturned,
        returnReason: _returnReason,
        condition: _condition,
        restockToInventory: _restockToInventory,
        status: _status,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Return updated successfully ✓'), backgroundColor: context.colors.primary, behavior: SnackBarBehavior.floating),
      );
    } else {
      appState.createReturn(
        customerId: _selectedCustomer!.id,
        originalSaleId: _selectedSale?.id,
        materialCode: _selectedMaterial?.materialCode,
        inventoryId: _inventoryId,
        quantityReturnedSqm: _quantityReturned,
        returnReason: _returnReason,
        condition: _condition,
        restockToInventory: _restockToInventory,
        status: _status,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return registered successfully ✓'), backgroundColor: Color(0xFFFF9800), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final colors = context.colors;
    final fmtDate = DateFormat('MM/dd/yyyy');

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
              // Top Bar: [X] Returns Form       [Cancel] [Save]
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
                      'Returns Form',
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
                      // 1. ReturnID*
                      _buildLabel('ReturnID*'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        alignment: Alignment.centerLeft,
                        child: Text(_returnId, style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary)),
                      ),
                      const SizedBox(height: 14),

                      // 2. ReturnDate
                      _buildLabel('ReturnDate'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _returnDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                          if (picked != null) setState(() => _returnDate = picked);
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                          child: Row(
                            children: [
                              Expanded(child: Text(fmtDate.format(_returnDate), style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary))),
                              Icon(Icons.calendar_month_outlined, size: 18, color: colors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. OriginalSaleID
                      _buildLabel('OriginalSaleID'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Sale>(
                            isExpanded: true,
                            value: _selectedSale,
                            dropdownColor: colors.surface,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            hint: Text('Select original sale (optional)...', style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled)),
                            items: state.sales.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_rounded, size: 16, color: colors.textSecondary),
                                    const SizedBox(width: 8),
                                    Text('${s.id} · \$${s.total.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (s) => _onSaleSelected(s, state),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. CustomerID
                      _buildLabel('CustomerID'),
                      const SizedBox(height: 6),
                      Container(
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
                      const SizedBox(height: 14),

                      // 5. MaterialCode
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
                            hint: Text('Select material code...', style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled)),
                            items: state.materials.map((m) {
                              return DropdownMenuItem(value: m, child: Text('${m.materialCode} - ${m.name}', style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)));
                            }).toList(),
                            onChanged: (m) => setState(() => _selectedMaterial = m),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 6. InventoryID
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
                            hint: Text(_inventoryId ?? 'Select warehouse location...', style: GoogleFonts.inter(fontSize: 13, color: colors.textDisabled)),
                            items: ['Warehouse', 'Yard A', 'Yard B', 'Showroom', 'Field', _inventoryId].whereType<String>().toSet().map((loc) {
                              return DropdownMenuItem(value: loc, child: Text(loc, style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)));
                            }).toList(),
                            onChanged: (loc) => setState(() => _inventoryId = loc),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 7. QuantityReturned_sqm with stepper buttons [-] [+]
                      _buildLabel('QuantityReturned_sqm'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: Row(
                          children: [
                            Text('${_quantityReturned.toStringAsFixed(2)} m²', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              color: colors.textSecondary,
                              onPressed: () {
                                if (_quantityReturned >= 0.5) setState(() => _quantityReturned -= 0.5);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 14),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              color: colors.textSecondary,
                              onPressed: () => setState(() => _quantityReturned += 0.5),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 8. ReturnReason
                      _buildLabel('ReturnReason'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _returnReason,
                            dropdownColor: colors.surface,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)))).toList(),
                            onChanged: (r) => setState(() => _returnReason = r!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 9. Condition
                      _buildLabel('Condition'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _condition,
                            dropdownColor: colors.surface,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)))).toList(),
                            onChanged: (c) => setState(() => _condition = c!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 10. RestockToInventory [N] [Y] Toggle
                      _buildLabel('RestockToInventory'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _restockToInventory = false),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: !_restockToInventory ? colors.primary : colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: !_restockToInventory ? colors.primary : colors.border),
                                ),
                                alignment: Alignment.center,
                                child: Text('N', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: !_restockToInventory ? Colors.white : colors.textSecondary)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _restockToInventory = true),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _restockToInventory ? colors.success : colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _restockToInventory ? colors.success : colors.border),
                                ),
                                alignment: Alignment.center,
                                child: Text('Y', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _restockToInventory ? Colors.white : colors.textSecondary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 11. Status
                      _buildLabel('Status'),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ReturnStatus>(
                            isExpanded: true,
                            value: _status,
                            dropdownColor: colors.surface,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            items: ReturnStatus.values.map((st) {
                              return DropdownMenuItem(value: st, child: Text(st.name.toUpperCase(), style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary)));
                            }).toList(),
                            onChanged: (st) {
                              if (st != null) setState(() => _status = st);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 12. Notes
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
