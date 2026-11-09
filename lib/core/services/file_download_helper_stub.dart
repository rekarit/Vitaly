import 'dart:typed_data';
import 'package:printing/printing.dart';

void downloadFileBytes(Uint8List bytes, String fileName, {String mimeType = 'application/pdf'}) {
  Printing.sharePdf(bytes: bytes, filename: fileName);
}

void openPdfInNewTab(Uint8List bytes) {
  Printing.layoutPdf(onLayout: (_) async => bytes);
}
