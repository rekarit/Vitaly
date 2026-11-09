import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/slab.dart';
import '../state/app_state.dart';
import 'file_download_helper.dart';

class PdfLabelService {
  /// Generates a real printable PDF document for the given slabs with barcodes and formatting.
  static Future<Uint8List> generateLabelsPdf({
    required List<Slab> slabs,
    required AppState appState,
    String labelFormat = '100mm × 75mm (Standard Thermal)',
    int copies = 1,
  }) async {
    final pdf = pw.Document(
      title: 'Vitaly Stone Labels',
      author: 'Vitaly Natural Stone ERP',
    );

    final cleanCopies = copies.clamp(1, 50);
    final isA4 = labelFormat.toLowerCase().contains('a4');
    final isLarge = labelFormat.toLowerCase().contains('150mm') || labelFormat.toLowerCase().contains('large');

    final List<Slab> allSlabsToPrint = [];
    for (final s in slabs) {
      for (int c = 0; c < cleanCopies; c++) {
        allSlabsToPrint.add(s);
      }
    }

    if (isA4) {
      // 4 labels per A4 page (2x2 grid)
      const labelsPerPage = 4;
      for (int i = 0; i < allSlabsToPrint.length; i += labelsPerPage) {
        final pageSlabs = allSlabsToPrint.skip(i).take(labelsPerPage).toList();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
            build: (pw.Context ctx) {
              return pw.GridView(
                crossAxisCount: 2,
                childAspectRatio: 1.35,
                crossAxisSpacing: 10 * PdfPageFormat.mm,
                mainAxisSpacing: 10 * PdfPageFormat.mm,
                children: pageSlabs.map((slab) {
                  return _buildLabelCard(slab, appState, isCompact: false);
                }).toList(),
              );
            },
          ),
        );
      }
    } else {
      // Single label per page for Thermal Printer (100x75mm or 100x150mm)
      final pageFormat = isLarge
          ? const PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm)
          : const PdfPageFormat(100 * PdfPageFormat.mm, 75 * PdfPageFormat.mm);

      final margin = isLarge
          ? const pw.EdgeInsets.all(6 * PdfPageFormat.mm)
          : const pw.EdgeInsets.all(4 * PdfPageFormat.mm);

      for (final slab in allSlabsToPrint) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: margin,
            build: (pw.Context ctx) {
              return _buildLabelCard(slab, appState, isCompact: !isLarge);
            },
          ),
        );
      }
    }

    return await pdf.save();
  }

  /// Builds a single stylized label sticker card
  static pw.Widget _buildLabelCard(Slab slab, AppState appState, {required bool isCompact}) {
    final mat = appState.materialById(slab.materialId);
    final lenMm = (slab.lengthMm > 0 ? slab.lengthMm : slab.lengthCm * 10).round();
    final widMm = (slab.widthMm > 0 ? slab.widthMm : slab.widthCm * 10).round();
    final lenCm = (lenMm / 10.0).toStringAsFixed(lenMm % 10 == 0 ? 0 : 1);
    final widCm = (widMm / 10.0).toStringAsFixed(widMm % 10 == 0 ? 0 : 1);
    final thickMm = slab.thicknessMm > 0 ? slab.thicknessMm.round() : 20;

    final slabNoStr = slab.slabNo.isNotEmpty
        ? slab.slabNo.toUpperCase()
        : 'SLAB ${slab.bundleNumber}-${slab.slabNumber.toString().padLeft(2, "0")}';

    final qrData = slab.qrCode.isNotEmpty ? slab.qrCode : slab.slabNo;
    final shortQr = qrData.length > 10 ? qrData.substring(qrData.length - 10) : qrData;
    final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: pw.EdgeInsets.all(isCompact ? 6 : 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Top Brand Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: const pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VITALY NATURAL STONE',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: isCompact ? 8.5 : 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  mat?.stoneType.toUpperCase() ?? 'WAREHOUSE ERP',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: isCompact ? 7.5 : 9,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: isCompact ? 4 : 8),

          // Main Content Row: Info Left, Barcode Right
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Info Section
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Large Slab Number
                          pw.Text(
                            slabNoStr,
                            style: pw.TextStyle(
                              fontSize: isCompact ? 16 : 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),

                          // Material Name
                          pw.Text(
                            (mat?.name ?? 'NATURAL STONE').toUpperCase(),
                            maxLines: 1,
                            style: pw.TextStyle(
                              fontSize: isCompact ? 10.5 : 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey900,
                            ),
                          ),
                          pw.SizedBox(height: 2),

                          // Finish and Category
                          pw.Text(
                            '${mat?.finish ?? "Polish"} · ${mat?.categoryId ?? "Natural Stone"}',
                            style: pw.TextStyle(
                              fontSize: isCompact ? 8 : 9.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),

                      // Dimensions and Area Box
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '$lenCm × $widCm cm (${thickMm}mm)',
                              style: pw.TextStyle(
                                fontSize: isCompact ? 9 : 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'AREA: ${slab.areaSqm.toStringAsFixed(2)} SQM ($lenMm×$widMm mm)',
                              style: pw.TextStyle(
                                fontSize: isCompact ? 8 : 9.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Warehouse Location & Rack
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.black, width: 0.8),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                            ),
                            child: pw.Text(
                              slab.warehouseLocation.isNotEmpty ? slab.warehouseLocation : 'RACK STOCK',
                              style: pw.TextStyle(
                                fontSize: isCompact ? 7.5 : 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          if (slab.rackCode.isNotEmpty && slab.rackCode != slab.warehouseLocation) ...[
                            pw.SizedBox(width: 4),
                            pw.Text(
                              'Rack: ${slab.rackCode}',
                              style: pw.TextStyle(fontSize: isCompact ? 7 : 8.5, color: PdfColors.grey700),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),

                // Right QR Code & Verification
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: isCompact ? 58 : 78,
                        height: isCompact ? 58 : 78,
                        padding: const pw.EdgeInsets.all(3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        shortQr.toLowerCase(),
                        style: pw.TextStyle(
                          fontSize: isCompact ? 6.5 : 8,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 3),

          // Bottom Footer Meta
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Label ID: ${slab.id}',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
              ),
              pw.Text(
                'Generated: $timestamp · Vitaly ERP',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Downloads the PDF file directly to the user's browser/system downloads folder.
  static Future<void> downloadPdf({
    required List<Slab> slabs,
    required AppState appState,
    String labelFormat = '100mm × 75mm (Standard Thermal)',
    int copies = 1,
  }) async {
    final bytes = await generateLabelsPdf(
      slabs: slabs,
      appState: appState,
      labelFormat: labelFormat,
      copies: copies,
    );

    final slabName = slabs.length == 1
        ? (slabs.first.slabNo.isNotEmpty ? slabs.first.slabNo : slabs.first.id)
        : '${slabs.length}_slabs';

    final safeName = slabName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final fileName = 'vitaly_labels_$safeName.pdf';

    downloadFileBytes(bytes, fileName);
  }

  /// Opens the PDF document directly in a new browser tab so the user can inspect every page.
  static Future<void> previewPdfInNewTab({
    required List<Slab> slabs,
    required AppState appState,
    String labelFormat = '100mm × 75mm (Standard Thermal)',
    int copies = 1,
  }) async {
    final bytes = await generateLabelsPdf(
      slabs: slabs,
      appState: appState,
      labelFormat: labelFormat,
      copies: copies,
    );

    openPdfInNewTab(bytes);
  }

  /// Triggers the system print dialog or browser print layout.
  static Future<void> printPdfDocument({
    required List<Slab> slabs,
    required AppState appState,
    String labelFormat = '100mm × 75mm (Standard Thermal)',
    int copies = 1,
  }) async {
    final bytes = await generateLabelsPdf(
      slabs: slabs,
      appState: appState,
      labelFormat: labelFormat,
      copies: copies,
    );

    final slabName = slabs.length == 1
        ? (slabs.first.slabNo.isNotEmpty ? slabs.first.slabNo : slabs.first.id)
        : '${slabs.length}_slabs';

    await Printing.layoutPdf(
      name: 'vitaly_labels_$slabName.pdf',
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }
}
