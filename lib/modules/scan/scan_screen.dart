import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/state/app_state.dart';
import '../../core/state/app_state_scope.dart';
import '../../core/models/slab.dart';
import '../../core/utils/export_utils.dart';
import '../../core/theme/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../navigation/main_layout_screen.dart';
import '../data_entry/data_entry_screen.dart';
import '../../core/services/auth_service.dart';

/// Complete, AppSheet-faithful Scan module that seamlessly displays
/// the comprehensive data table with all columns, paired with an
/// ultra-fast live QR/Barcode Scanner Modal.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_ScanRowData> _getFilteredRows(AppState appState) {
    final List<_ScanRowData> all = [];
    for (final s in appState.slabs) {
      final mat = appState.materialById(s.materialId);
      final matName = mat?.name.isNotEmpty == true ? mat!.name : s.materialId;
      final stoneType = mat?.stoneType ?? '-';
      final finish = mat?.finish ?? '-';
      final statusLabel = s.status == SlabStatus.available
          ? 'In Stock'
          : (s.status == SlabStatus.reserved
              ? 'Reserved'
              : (s.status == SlabStatus.damaged ? 'Damaged' : 'Sold'));
      all.add(_ScanRowData(
        slabDisplay: '${matName.toUpperCase()} - ${s.slabNo} - ${s.areaSqm.round()}m²',
        inventoryId: s.inventoryId ?? s.id,
        materialCode: '${s.materialId} - ${matName.toUpperCase()}',
        slabNo: s.slabNo,
        lengthMm: s.lengthMm.round(),
        widthMm: s.widthMm.round(),
        thicknessMm: s.thicknessMm.round(),
        areaSqm: s.areaSqm,
        rackCode: s.warehouseLocation,
          status: statusLabel,
          photoName: s.photoBytes != null ? 'IMG' : '',
          receivedDate: '${s.receivedDate.month}/${s.receivedDate.day}/${s.receivedDate.year}',
          notes: s.defectNotes ?? '',
          categoryCode: mat?.categoryCode ?? 12,
          stoneType: stoneType,
          materialName: matName.toUpperCase(),
          finish: finish,
          referenceCode: mat?.referenceCode ?? s.materialId,
          reservedFor: '',
          reservedFrom: '',
          reservedUntil: '',
          reservationExpired: 'Yes',
          batchId: s.batchId ?? '',
          pickupDate: '${s.receivedDate.month}/${s.receivedDate.day}/${s.receivedDate.year}',
          signatureNote: '',
          locationType: 'Yard',
          visible: 'Y',
          sourceReturnId: '',
          quantity: '',
          relatedReservationsCount: 0,
          relatedReturnsCount: 0,
          relatedSalesCount: 0,
          labelText: '${s.slabNo} · ${(s.lengthMm / 1000).toStringAsFixed(2)}x${(s.widthMm / 1000).toStringAsFixed(2)}m = ${s.areaSqm.toStringAsFixed(2)} sqm',
          materialStockSummary: 'This slab: ${s.slabNo} · ${s.areaSqm.round()} m² · $statusLabel',
          slabDisplayImage: '',
          printLabelText: '${s.slabNo} · $stoneType / $matName',
          dimensionsSummary: '${s.lengthMm.round()}×${s.widthMm.round()}×${s.thicknessMm.round()}mm · ${s.areaSqm.toStringAsFixed(2)} sqm',
        ));
    }

    return all.where((r) {
      if (_selectedStatus != 'All' && r.status.toLowerCase() != _selectedStatus.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return r.slabDisplay.toLowerCase().contains(q) ||
            r.inventoryId.toLowerCase().contains(q) ||
            r.materialCode.toLowerCase().contains(q) ||
            r.slabNo.toLowerCase().contains(q) ||
            r.rackCode.toLowerCase().contains(q) ||
            r.notes.toLowerCase().contains(q) ||
            r.status.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  void _openCameraScannerModal(AppState appState) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CameraScannerDialog(
        onScanned: (code) {
          Navigator.of(ctx).pop();
          _onCodeScanned(code, appState);
        },
      ),
    );
  }

  void _onCodeScanned(String rawCode, AppState appState) {
    final code = rawCode.trim();
    String? targetMaterialCode;
    String? targetSlabNo;

    // 1. Check if scanned code is a URL (e.g. from generated QR code)
    if (code.contains('?')) {
      final uri = Uri.tryParse(code.startsWith('http') ? code : 'https://$code');
      if (uri != null) {
        targetMaterialCode = uri.queryParameters['material'] ?? uri.queryParameters['mat'];
        targetSlabNo = uri.queryParameters['slab'] ?? uri.queryParameters['slabNo'];
      }
    }

    // 2. If not a URL or missing material parameter, search slabs and materials in state
    if (targetMaterialCode == null || targetMaterialCode.isEmpty) {
      final query = code.toLowerCase();
      final slab = appState.slabs.where((s) =>
          s.slabNo.toLowerCase() == query ||
          (s.inventoryId != null && s.inventoryId!.toLowerCase() == query) ||
          (s.customQrData != null && s.customQrData!.toLowerCase() == query) ||
          s.qrCode.toLowerCase() == query ||
          s.id.toLowerCase() == query).firstOrNull;

      if (slab != null) {
        targetMaterialCode = slab.materialId;
        targetSlabNo = slab.slabNo;
      } else {
        final mat = appState.materialById(code);
        if (mat != null) {
          targetMaterialCode = mat.materialCode;
        } else if (query.contains('-')) {
          final prefix = query.split('-').first.trim();
          final prefixMat = appState.materialById(prefix);
          if (prefixMat != null) {
            targetMaterialCode = prefixMat.materialCode;
            targetSlabNo = code;
          } else {
            targetMaterialCode = prefix;
            targetSlabNo = code;
          }
        } else {
          targetMaterialCode = code;
        }
      }
    }

    // Set search bar to code as well for reference
    setState(() {
      _searchCtrl.text = code;
      _searchQuery = code;
    });

    // 3. Directly navigate to Data Entry -> Material Tab
    if (targetMaterialCode.isNotEmpty) {
      MainLayoutScreen.navigateToTab(0);
      DataEntryScreen.openMaterialDetail(materialCode: targetMaterialCode, slabNo: targetSlabNo);

      final mat = appState.materialById(targetMaterialCode);
      final matName = mat != null ? mat.name.toUpperCase() : targetMaterialCode;
      final matSlabs = appState.slabsForMaterial(targetMaterialCode);
      final matAvail = matSlabs.where((s) => s.status == SlabStatus.available).length;
      final matSoldUnavail = matSlabs.where((s) => s.status == SlabStatus.unavailable || s.status == SlabStatus.sold || s.status == SlabStatus.reserved).length;
      final matDamaged = matSlabs.where((s) => s.status == SlabStatus.damaged).length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Material $matName ($targetMaterialCode) • Stock: $matAvail Available • $matSoldUnavail Sold • $matDamaged Damaged',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No matching Slab or Material found for: $code',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRowDetails(_ScanRowData row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.slabDisplay,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // QR code card
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: QrImageView(
                    data: 'https://rekarit.github.io/vitaly-app/?material=${row.materialCode}&slab=${row.slabNo}',
                    version: QrVersions.auto,
                    size: 140,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Material Stock Availability Ribbon
              Builder(
                builder: (context) {
                  final state = AppStateScope.read(context);
                  final mSlabs = state.slabsForMaterial(row.materialCode);
                  final av = mSlabs.where((s) => s.status == SlabStatus.available).length;
                  final un = mSlabs.where((s) => s.status == SlabStatus.unavailable || s.status == SlabStatus.sold || s.status == SlabStatus.reserved).length;
                  final dm = mSlabs.where((s) => s.status == SlabStatus.damaged).length;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock Availability for Material ${row.materialCode}:', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text('Available: $av', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(color: const Color(0xFF64748B).withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
                              child: Text('Sold / Unavailable: $un', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(color: const Color(0xFFEA580C).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text('Damaged: $dm', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildDetailItem('InventoryID', row.inventoryId),
              _buildDetailItem('MaterialCode', row.materialCode),
              _buildDetailItem('SlabNo', row.slabNo),
              _buildDetailItem('Dimensions', '${row.lengthMm} × ${row.widthMm} × ${row.thicknessMm} mm'),
              _buildDetailItem('Area_sqm', '${row.areaSqm.toStringAsFixed(2)} m²'),
              _buildDetailItem('RackCode', row.rackCode.isNotEmpty ? row.rackCode : '—'),
              _buildDetailItem('Status', row.status),
              _buildDetailItem('ReceivedDate', row.receivedDate),
              _buildDetailItem('Notes', row.notes.isNotEmpty ? row.notes : '—'),
              _buildDetailItem('StoneType', row.stoneType),
              _buildDetailItem('Finish', row.finish),
              _buildDetailItem('ReservedFor', row.reservedFor.isNotEmpty ? row.reservedFor : '—'),
              _buildDetailItem('PickupDate', row.pickupDate),
              _buildDetailItem('LocationType', row.locationType),
              _buildDetailItem('LabelText', row.labelText),
              _buildDetailItem('PrintLabelText', row.printLabelText),
              _buildDetailItem('DimensionsSummary', row.dimensionsSummary),
              const SizedBox(height: 20),

              // Button to directly view Material & All Slabs tab in Data Entry
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 16),
                  label: Text(
                    'View Material & Slabs (Data Entry)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF86B9E0),
                    foregroundColor: const Color(0xFF111418),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    MainLayoutScreen.navigateToTab(0);
                    final matId = row.referenceCode.isNotEmpty
                        ? row.referenceCode
                        : (row.materialCode.contains('-') ? row.materialCode.split('-').first.trim() : row.materialCode);
                    DataEntryScreen.openMaterialDetail(materialCode: matId, slabNo: row.slabNo);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Direct Mark Damaged button for warehouse tablet / mobile users (Permission Guarded)
              if (row.status.toLowerCase() != 'damaged' && AuthService.instance.currentPermissions.canDirectMarkDamagedInScan)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.broken_image_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Mark Slab Damaged Directly',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      final appState = AppStateScope.of(context);
                      final slab = appState.slabs.where((s) =>
                          s.inventoryId == row.inventoryId ||
                          s.slabNo == row.slabNo).firstOrNull;
                      if (slab != null) {
                        appState.markDamaged(slab.id, defectNotes: 'Marked damaged directly from Scan details');
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Slab #${row.slabNo} marked as damaged.',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: const Color(0xFF1E293B),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(title, style: GoogleFonts.inter(fontSize: 13, color: Colors.white54))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))),
        ],
      ),
    );
  }

  Future<void> _exportScanData(BuildContext context, List<_ScanRowData> data) async {
    final exportRows = data.map((r) => [
      r.slabDisplay,
      r.inventoryId,
      r.materialCode,
      r.slabNo,
      r.lengthMm,
      r.widthMm,
      r.thicknessMm,
      r.areaSqm,
      r.rackCode,
      r.status,
      r.receivedDate,
      r.notes,
      r.categoryCode,
      r.stoneType,
      r.materialName,
      r.finish,
      r.referenceCode,
      r.reservedFor,
      r.reservationExpired,
      r.batchId,
      r.pickupDate,
      r.locationType,
      r.visible,
      r.labelText,
      r.materialStockSummary,
      r.printLabelText,
      r.dimensionsSummary,
    ]).toList();

    await ExportUtils.exportCsv(
      context,
      defaultFileName: 'Scan_Inventory_Export',
      headers: [
        'SlabDisplay', 'InventoryID', 'MaterialCode', 'SlabNo', 'Length_mm', 'Width_mm', 'Thickness_mm', 'Area_sqm',
        'RackCode', 'Status', 'ReceivedDate', 'Notes', 'CategoryCode', 'StoneType', 'MaterialName', 'Finish',
        'ReferenceCode', 'ReservedFor', 'ReservationExpired', 'BatchID', 'PickupDate', 'LocationType', 'Visible',
        'LabelText', 'MaterialStockSummary', 'PrintLabelText', 'DimensionsSummary'
      ],
      rows: exportRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final records = _getFilteredRows(appState);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 768;

        return Scaffold(
          backgroundColor: colors.background,
          floatingActionButton: null,
          body: SafeArea(
            child: Column(
              children: [
                // Top Bar with standout "Open Camera" action
                _buildTopBar(context, records, appState, colors, isDark, isNarrow, constraints.maxWidth),
                Divider(color: colors.border, height: 1, thickness: 1),

                // Filter Bar with search & camera quick trigger
                _buildFilterBar(context, appState, colors, isDark, isNarrow),
                Divider(color: colors.border, height: 1, thickness: 1),

                // Mobile-Friendly Cards (< 768px) OR 27-Column Table for Desktop
                Expanded(
                  child: records.isEmpty
                      ? _buildEmptyState(context, appState, colors, isDark)
                      : isNarrow
                          ? _buildMobileList(context, records, colors, isDark)
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: _buildTable(context, records, colors, isDark),
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildMobileList(BuildContext context, List<_ScanRowData> records, AppColorsExtension colors, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final r = records[idx];
        return Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _showRowDetails(r),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  // QR preview badge
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: QrImageView(
                      data: r.inventoryId,
                      version: QrVersions.auto,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.slabDisplay,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildStatusBadge(r.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'ID: ',
                              style: GoogleFonts.inter(fontSize: 11, color: colors.textDisabled),
                            ),
                            Text(
                              r.inventoryId,
                              style: GoogleFonts.robotoMono(fontSize: 11.5, color: colors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            if (r.rackCode.isNotEmpty) ...[
                              Icon(Icons.location_on_outlined, size: 12, color: colors.textDisabled),
                              const SizedBox(width: 2),
                              Text(
                                r.rackCode,
                                style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 20, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    List<_ScanRowData> records,
    AppState appState,
    AppColorsExtension colors,
    bool isDark,
    bool isNarrow,
    double totalWidth,
  ) {
    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Scan',
          style: GoogleFonts.inter(
            fontSize: isNarrow ? 16 : 19,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withAlpha(isDark ? 25 : 15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
          ),
          child: Text(
            '${records.length} slabs',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFFF59E0B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final openCameraBtn = InkWell(
      onTap: () => _openCameraScannerModal(appState),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 9 : 18, vertical: isNarrow ? 6 : 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withAlpha(isDark ? 130 : 90),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFFDE68A).withAlpha(150),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_rounded,
              size: 15,
              color: Color(0xFF0F172A),
            ),
            const SizedBox(width: 5),
            Text(
              'Open Camera',
              style: GoogleFonts.inter(
                fontSize: isNarrow ? 11.5 : 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withAlpha(35),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'FAST',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final exportBtn = InkWell(
      onTap: () => _exportScanData(context, records),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 9 : 14, vertical: isNarrow ? 6 : 9),
        decoration: BoxDecoration(
          color: const Color(0xFF4A90E2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 20),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Export Lab...',
              style: GoogleFonts.inter(
                fontSize: isNarrow ? 11 : 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    final isVeryNarrow = totalWidth < 410;

    final canCamera = AuthService.instance.currentPermissions.canOpenCameraScanner;
    final canExport = AuthService.instance.currentPermissions.canExportScanData;

    return Container(
      color: colors.surface,
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 20, vertical: isNarrow ? 7 : 12),
      child: isVeryNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    titleRow,
                    if (canExport) exportBtn,
                  ],
                ),
                if (canCamera) ...[
                  const SizedBox(height: 6),
                  openCameraBtn,
                ],
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                titleRow,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canCamera) openCameraBtn,
                    if (canCamera && canExport) const SizedBox(width: 6),
                    if (canExport) exportBtn,
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar(BuildContext context, AppState appState, AppColorsExtension colors, bool isDark, bool isNarrow) {
    final searchField = TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: GoogleFonts.inter(fontSize: isNarrow ? 12 : 13, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: isNarrow ? 'Search slabs, ID, code...' : 'Search by SlabDisplay, InventoryID, MaterialCode, SlabNo...',
        hintStyle: GoogleFonts.inter(fontSize: isNarrow ? 11.5 : 13, color: colors.textDisabled),
        prefixIcon: Icon(Icons.search_rounded, size: 17, color: colors.textSecondary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 15),
                tooltip: 'Clear search',
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: colors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: isNarrow ? 5 : 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );

    final statusDropdown = Container(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          dropdownColor: colors.surface,
          style: GoogleFonts.inter(fontSize: isNarrow ? 11.5 : 13, color: colors.textPrimary, fontWeight: FontWeight.w500),
          items: ['All', 'In Stock', 'Reserved', 'Sold', 'Damaged'].map<DropdownMenuItem<String>>((val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val == 'All' ? 'All Statuses' : val),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedStatus = val);
            }
          },
        ),
      ),
    );

    return Container(
      color: colors.surfaceVariant,
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 20, vertical: isNarrow ? 6 : 9),
      child: Row(
        children: [
          Expanded(child: searchField),
          SizedBox(width: isNarrow ? 6 : 14),
          statusDropdown,
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState appState, AppColorsExtension colors, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 38),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : colors.border,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Scanner Viewfinder Illustration
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFF59E0B).withAlpha(45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withAlpha(25),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withAlpha(140),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 46,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Title
                Text(
                  'Live Camera & Barcode Scanner',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Scan stone slab QR code stickers or barcode labels with ultra-fast camera recognition.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Feature Badges
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFeatureBadge('⚡ 60 FPS Auto-Detect', colors, isDark),
                    _buildFeatureBadge('🔦 Flashlight Ready', colors, isDark),
                    _buildFeatureBadge('🏷️ Slabs, Bundles & Racks', colors, isDark),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(String text, AppColorsExtension colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'in stock':
        bg = const Color(0xFF10B981).withAlpha(30);
        fg = const Color(0xFF10B981);
        break;
      case 'reserved':
        bg = const Color(0xFFF59E0B).withAlpha(30);
        fg = const Color(0xFFF59E0B);
        break;
      case 'damaged':
        bg = const Color(0xFFEF4444).withAlpha(30);
        fg = const Color(0xFFEF4444);
        break;
      case 'sold':
      default:
        bg = const Color(0xFF8B5CF6).withAlpha(30);
        fg = const Color(0xFF8B5CF6);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: fg)),
          const SizedBox(width: 6),
          Text(status, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<_ScanRowData> records, AppColorsExtension colors, bool isDark) {
    final columns = [
      'SlabDisplay',
      'InventoryID',
      'MaterialCode',
      'SlabNo',
      'Length_mm',
      'Width_mm',
      'Thickness_mm',
      'Area_sqm',
      'RackCode',
      'Status',
      'Photo',
      'ReceivedDate',
      'Notes',
      'CategoryCode',
      'StoneType',
      'MaterialName',
      'Finish',
      'ReferenceCode',
      'MaterialImage',
      'ReservedFor',
      'ReservedFrom',
      'ReservedUntil',
      'ReservationExpired',
      'BatchID',
      'PickupDate',
      'SignatureNote',
      'LocationType',
      'Visible',
      'SourceReturnID',
      'Quantity',
      'Related Reservations',
      'Related Returns',
      'Related Sales',
      'QRCodeImage',
      'LabelText',
      'MaterialStockSummary',
      'SlabDisplayImage',
      'PrintLabelText',
      'DimensionsSummary',
      '',
    ];

    final NumberFormat numFmt = NumberFormat('#,###');

    return DataTable(
      headingRowHeight: 46,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 52,
      columnSpacing: 22,
      horizontalMargin: 20,
      headingRowColor: WidgetStateProperty.all(colors.surfaceVariant.withAlpha(isDark ? 70 : 120)),
      border: TableBorder(bottom: BorderSide(color: colors.border, width: 1)),
      headingTextStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
      dataTextStyle: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
      columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
      rows: records.map((r) {
        return DataRow(
          cells: [
            DataCell(Text(r.slabDisplay, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(r.inventoryId, style: GoogleFonts.robotoMono(color: colors.textSecondary))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: colors.textDisabled),
                const SizedBox(width: 6),
                Text(r.materialCode, style: TextStyle(color: colors.textPrimary)),
              ],
            )),
            DataCell(Text(r.slabNo, style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(numFmt.format(r.lengthMm), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(numFmt.format(r.widthMm), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text('${r.thicknessMm}', style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(r.areaSqm.toStringAsFixed(2), style: TextStyle(color: colors.textPrimary))),
            DataCell(Text(r.rackCode, style: TextStyle(color: colors.textPrimary))),
            DataCell(_buildStatusBadge(r.status)),
            DataCell(
              r.photoName.isNotEmpty
                  ? Container(
                      width: 28,
                      height: 28,
                      color: isDark ? Colors.black : Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: Text(r.photoName, style: TextStyle(fontSize: 10, color: isDark ? Colors.white : Colors.black87)),
                    )
                  : const SizedBox.shrink(),
            ),
            DataCell(Text(r.receivedDate, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.notes, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text('${r.categoryCode}', style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.stoneType, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.materialName, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.finish, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.referenceCode, style: TextStyle(color: colors.textSecondary))),
            DataCell(Icon(Icons.warning_amber_rounded, size: 16, color: colors.textDisabled)),
            DataCell(Text(r.reservedFor, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.reservedFrom, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.reservedUntil, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.reservationExpired, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.batchId, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.pickupDate, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.signatureNote, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.locationType, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.visible, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.sourceReturnId, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.quantity, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text('Related Reservations (${r.relatedReservationsCount})', style: TextStyle(color: colors.textSecondary))),
            DataCell(Text('Related Returns (${r.relatedReturnsCount})', style: TextStyle(color: colors.textSecondary))),
            DataCell(Text('Related Sales (${r.relatedSalesCount})', style: TextStyle(color: colors.textSecondary))),
            // QR Code cell
            DataCell(
              Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(1),
                color: Colors.white,
                child: QrImageView(
                  data: r.inventoryId,
                  version: QrVersions.auto,
                  size: 30,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            DataCell(Text(r.labelText, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.materialStockSummary, style: TextStyle(color: colors.textSecondary))),
            DataCell(
              r.slabDisplayImage.isNotEmpty
                  ? Container(
                      width: 28,
                      height: 28,
                      color: isDark ? Colors.black : Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: Text(r.slabDisplayImage, style: TextStyle(fontSize: 10, color: isDark ? Colors.white : Colors.black87)),
                    )
                  : Icon(Icons.warning_amber_rounded, size: 16, color: colors.textDisabled),
            ),
            DataCell(Text(r.printLabelText, style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(r.dimensionsSummary, style: TextStyle(color: colors.textSecondary))),
            DataCell(
              InkWell(
                onTap: () => _showRowDetails(r),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 20),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ScanRowData {
  final String slabDisplay;
  final String inventoryId;
  final String materialCode;
  final String slabNo;
  final int lengthMm;
  final int widthMm;
  final int thicknessMm;
  final double areaSqm;
  final String rackCode;
  final String status;
  final String photoName;
  final String receivedDate;
  final String notes;
  final int categoryCode;
  final String stoneType;
  final String materialName;
  final String finish;
  final String referenceCode;
  final String reservedFor;
  final String reservedFrom;
  final String reservedUntil;
  final String reservationExpired;
  final String batchId;
  final String pickupDate;
  final String signatureNote;
  final String locationType;
  final String visible;
  final String sourceReturnId;
  final String quantity;
  final int relatedReservationsCount;
  final int relatedReturnsCount;
  final int relatedSalesCount;
  final String labelText;
  final String materialStockSummary;
  final String slabDisplayImage;
  final String printLabelText;
  final String dimensionsSummary;

  _ScanRowData({
    required this.slabDisplay,
    required this.inventoryId,
    required this.materialCode,
    required this.slabNo,
    required this.lengthMm,
    required this.widthMm,
    required this.thicknessMm,
    required this.areaSqm,
    required this.rackCode,
    required this.status,
    required this.photoName,
    required this.receivedDate,
    required this.notes,
    required this.categoryCode,
    required this.stoneType,
    required this.materialName,
    required this.finish,
    required this.referenceCode,
    required this.reservedFor,
    required this.reservedFrom,
    required this.reservedUntil,
    required this.reservationExpired,
    required this.batchId,
    required this.pickupDate,
    required this.signatureNote,
    required this.locationType,
    required this.visible,
    required this.sourceReturnId,
    required this.quantity,
    required this.relatedReservationsCount,
    required this.relatedReturnsCount,
    required this.relatedSalesCount,
    required this.labelText,
    required this.materialStockSummary,
    required this.slabDisplayImage,
    required this.printLabelText,
    required this.dimensionsSummary,
  });
}

/// High-Speed Live Camera & Barcode Lookup Dialog
class _CameraScannerDialog extends StatefulWidget {
  final ValueChanged<String> onScanned;
  const _CameraScannerDialog({required this.onScanned});

  @override
  State<_CameraScannerDialog> createState() => _CameraScannerDialogState();
}

class _CameraScannerDialogState extends State<_CameraScannerDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _manualCtrl = TextEditingController();
  MobileScannerController? _cameraCtrl;
  late final AnimationController _animCtrl;
  late final Animation<double> _laserAnim;

  bool _hasScanned = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _startCamera();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _laserAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  void _startCamera() {
    _cameraCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _cameraCtrl?.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        _hasScanned = true;
        HapticFeedback.mediumImpact();
        widget.onScanned(code);
        break;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _cameraCtrl?.toggleTorch();
      setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      await _cameraCtrl?.switchCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isMobile = context.isMobile;
    final availableHeight = (mq.size.height - mq.viewInsets.bottom - mq.viewPadding.vertical - 32).clamp(320.0, 640.0);

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF334155), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: availableHeight),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 20,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Camera Scanner',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '60 FPS Ultra-Fast Mode Active',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),

            // Live Camera View with Viewfinder & Sweeping Laser
            Expanded(
              child: ClipRRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_cameraCtrl != null)
                      MobileScanner(
                        controller: _cameraCtrl!,
                        onDetect: _onDetect,
                        errorBuilder: (context, error, child) {
                          return Container(
                            color: const Color(0xFF0B1120),
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.videocam_off_rounded,
                                      size: 40,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Camera Unavailable',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Check webcam permissions or enter the code manually below.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Translucent dark vignette around scanner box
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final boxSize = (constraints.maxWidth * 0.65).clamp(180.0, 240.0);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Viewfinder Reticle Box with corner brackets
                            SizedBox(
                              width: boxSize,
                              height: boxSize,
                              child: CustomPaint(
                                painter: _ReticleCornersPainter(
                                  color: _hasScanned ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                                child: AnimatedBuilder(
                                  animation: _laserAnim,
                                  builder: (context, _) {
                                    return Stack(
                                      children: [
                                        Positioned(
                                          top: _laserAnim.value * (boxSize - 12) + 6,
                                          left: 12,
                                          right: 12,
                                          child: Container(
                                            height: 2.5,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Color(0xFFF59E0B),
                                                  Color(0xFFFDE68A),
                                                  Color(0xFFF59E0B),
                                                  Colors.transparent,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFF59E0B).withAlpha(220),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Floating Camera Controls (Flashlight & Camera Flip)
                            Positioned(
                              top: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(140),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: _toggleTorch,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _torchOn ? const Color(0xFFF59E0B) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                                              size: 16,
                                              color: _torchOn ? const Color(0xFF0F172A) : Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _torchOn ? 'Flash ON' : 'Flash',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _torchOn ? const Color(0xFF0F172A) : Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(width: 1, height: 16, color: Colors.white24),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: _switchCamera,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.flip_camera_ios_rounded, size: 15, color: Colors.white),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Flip',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Subtitle prompt below the viewfinder box
                            Positioned(
                              bottom: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(160),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _hasScanned ? '✓ QR Code Recognized!' : 'Align QR code or Barcode inside the box',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _hasScanned ? const Color(0xFF10B981) : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: Color(0xFF1E293B), height: 1),

            // Manual Barcode / InventoryID entry
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualCtrl,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Or enter InventoryID / Slab No manually...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        prefixIcon: const Icon(Icons.keyboard_alt_rounded, size: 18, color: Colors.white38),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) widget.onScanned(v.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (_manualCtrl.text.trim().isNotEmpty) {
                        widget.onScanned(_manualCtrl.text.trim());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    child: Text('Find', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter to draw sharp glowing corner reticles around viewfinder
class _ReticleCornersPainter extends CustomPainter {
  final Color color;
  const _ReticleCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ReticleCornersPainter oldDelegate) => oldDelegate.color != color;
}
