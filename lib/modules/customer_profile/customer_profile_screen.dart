import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/customer.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import 'customer_form_dialog.dart';
import '../../core/services/auth_service.dart';

/// Customer Profile Screen
/// Centralized management for all customer profiles, contact info, and records.
/// Provides real-time search, add, edit, and safe delete capabilities.
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAddCustomerDialog(BuildContext context) {
    CustomersFormDialog.show(context);
  }

  void _openEditCustomerDialog(BuildContext context, Customer customer) {
    CustomersFormDialog.show(context, customerToEdit: customer);
  }

  void _confirmDeleteCustomer(BuildContext context, Customer customer, AppColorsExtension colors) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colors.border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_forever_rounded, color: colors.error, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Delete Customer',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: colors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to remove the profile for:',
                style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: colors.textPrimary),
                    ),
                    if (customer.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Phone: ${customer.phone}',
                        style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                    if (customer.id.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Code: #${customer.id}',
                        style: GoogleFonts.inter(fontSize: 11, color: colors.textDisabled),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This will remove the customer record from local cache and cloud backend.',
                style: GoogleFonts.inter(fontSize: 12, color: colors.error),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              onPressed: () {
                final appState = AppStateScope.read(context);
                appState.deleteCustomer(customer.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Customer "${customer.fullName}" removed'),
                    backgroundColor: const Color(0xFF1E293B),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = context.isMobile;

    final allCustomers = appState.customers;

    // Filter by search query
    final filtered = allCustomers.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.fullName.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q) ||
          c.notes.toLowerCase().contains(q) ||
          c.company.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 12 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Header ───────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Profile',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Directory of client accounts, contact information & records',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 11.5 : 13,
                            color: colors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "+ Add Customer" Button
                  if (AuthService.instance.currentPermissions.canAddCustomer) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 18,
                          vertical: isMobile ? 10 : 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _openAddCustomerDialog(context),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: Text(
                        isMobile ? 'Add' : 'Add Customer',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── Controls: Search Bar & View Toggle ────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 19, color: colors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) => setState(() => _searchQuery = val.trim()),
                              style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Search by name, phone, email, address, or code...',
                                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: colors.textDisabled),
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
                              child: Icon(Icons.clear_rounded, size: 18, color: colors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Grid / List toggle
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.grid_view_rounded,
                            size: 18,
                            color: _isGridView ? colors.primary : colors.textSecondary,
                          ),
                          tooltip: 'Grid View',
                          splashRadius: 18,
                          onPressed: () => setState(() => _isGridView = true),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.view_list_rounded,
                            size: 19,
                            color: !_isGridView ? colors.primary : colors.textSecondary,
                          ),
                          tooltip: 'List View',
                          splashRadius: 18,
                          onPressed: () => setState(() => _isGridView = false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Customers List / Grid ────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(colors, isDark)
                    : _isGridView && !isMobile
                        ? _buildGridView(filtered, colors, isDark)
                        : _buildListView(filtered, colors, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors, bool isDark) {
    final hasSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Layered glowing icon container
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
                    colors.surface.withValues(alpha: 0.4),
                  ],
                ),
                border: Border.all(
                  color: colors.primary.withValues(alpha: isDark ? 0.28 : 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: isDark ? 0.09 : 0.05),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceVariant.withValues(alpha: isDark ? 0.6 : 0.8),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    hasSearch ? Icons.search_off_rounded : Icons.person_search_rounded,
                    size: 26,
                    color: colors.primary.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch ? 'No Customers Found' : 'No Customers Registered Yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'No results match "$_searchQuery". Try searching with a different name, phone number, or address.'
                  : 'Your customer directory is currently empty. Use the Add Customer button above to create a new profile.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: colors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasSearch) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Clear Search',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<Customer> list, AppColorsExtension colors, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 3 : 2;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.1,
          ),
          itemCount: list.length,
          itemBuilder: (ctx, idx) => _buildCustomerCard(list[idx], colors, isDark),
        );
      },
    );
  }

  Widget _buildListView(List<Customer> list, AppColorsExtension colors, bool isDark) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) => _buildCustomerCard(list[idx], colors, isDark),
    );
  }

  Widget _buildCustomerCard(Customer customer, AppColorsExtension colors, bool isDark) {
    final initials = customer.fullName.isNotEmpty
        ? customer.fullName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
        : 'C';

    final hasPhone = customer.phone.trim().isNotEmpty;
    final hasEmail = customer.email.trim().isNotEmpty;
    final hasAddress = customer.address.trim().isNotEmpty;
    final hasNotes = customer.notes.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Avatar, Name, Code, Actions ──
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: colors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.fullName,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(
                            customer.id,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (customer.company.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        customer.company,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons: Edit, Delete
              if (AuthService.instance.currentPermissions.canEditCustomer)
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
                  tooltip: 'Edit Profile',
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _openEditCustomerDialog(context, customer),
                ),
              if (AuthService.instance.currentPermissions.canDeleteCustomer)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.error),
                  tooltip: 'Delete Profile',
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _confirmDeleteCustomer(context, customer, colors),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 9),

          // ── Contact Info & Details ──
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (hasPhone)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: customer.phone));
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied "${customer.phone}" to clipboard'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_rounded, size: 13, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        customer.phone,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasEmail)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mail_outline_rounded, size: 13, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      customer.email,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              if (hasAddress)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      customer.address,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
            ],
          ),

          if (hasNotes) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Notes: ${customer.notes}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: colors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
