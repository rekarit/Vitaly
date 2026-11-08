import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class ExportUtils {
  /// Converts headers and string row cells into formatted CSV text.
  static String generateCsv({
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final buffer = StringBuffer();

    // Escape and format row
    String formatRow(List<dynamic> cells) {
      return cells.map((cell) {
        final str = cell?.toString() ?? '';
        if (str.contains(',') || str.contains('"') || str.contains('\n')) {
          return '"${str.replaceAll('"', '""')}"';
        }
        return str;
      }).join(',');
    }

    buffer.writeln(formatRow(headers));
    for (final row in rows) {
      buffer.writeln(formatRow(row));
    }
    return buffer.toString();
  }

  /// Copies CSV string to the system clipboard and displays a friendly toast.
  static Future<void> copyToClipboard(BuildContext context, String csvText, {String title = 'CSV Data'}) async {
    await Clipboard.setData(ClipboardData(text: csvText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('$title copied to clipboard!'),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Prompts user to save CSV to a file or copies it to clipboard if cancelled.
  static Future<void> exportCsv(
    BuildContext context, {
    required String defaultFileName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final csvText = generateCsv(headers: headers, rows: rows);

    try {
      final bytes = Uint8List.fromList(utf8.encode(csvText));
      final resultUri = await FilePicker.saveFile(
        dialogTitle: 'Save CSV Export',
        fileName: defaultFileName.endsWith('.csv') ? defaultFileName : '$defaultFileName.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (resultUri != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.file_download_done_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Successfully exported to ${resultUri.path.split('/').last}')),
              ],
            ),
            backgroundColor: const Color(0xFF1E88E5),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    } catch (_) {
      // Fallback to clipboard if file saving dialog fails or is cancelled
    }

    // Default or fallback: copy to clipboard
    if (context.mounted) {
      await copyToClipboard(context, csvText, title: defaultFileName);
    }
  }
}
