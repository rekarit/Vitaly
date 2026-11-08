import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/material_item.dart';
import '../theme/app_theme.dart';
import 'web_image_renderer.dart';

/// Universal stone image display widget that handles in-memory bytes, web HTML <img>
/// rendering to bypass CORS limitations, and fallbacks. Also supports interactive tap to preview!
class StoneImageWidget extends StatelessWidget {
  final MaterialItem? material;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool enablePreviewOnTap;

  const StoneImageWidget({
    super.key,
    this.material,
    this.imageUrl,
    this.imageBytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.enablePreviewOnTap = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = imageUrl ?? material?.imageUrl;
    final bytes = imageBytes ?? material?.imageBytes;

    Widget imageContent;

    if (bytes != null && bytes.isNotEmpty) {
      imageContent = Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _buildFallback(colors),
      );
    } else if (url != null && url.trim().isNotEmpty && url.startsWith('http')) {
      if (kIsWeb) {
        imageContent = SizedBox(
          width: width,
          height: height,
          child: renderWebImage(
            url: url.trim(),
            fit: fit,
            errorBuilder: (_) => _buildFallback(colors),
          ),
        );
      } else {
        imageContent = Image.network(
          url.trim(),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _buildFallback(colors),
        );
      }
    } else {
      imageContent = _buildFallback(colors);
    }

    if (borderRadius != null) {
      imageContent = ClipRRect(
        borderRadius: borderRadius!,
        child: imageContent,
      );
    }

    if (enablePreviewOnTap && (bytes != null || (url != null && url.startsWith('http')))) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => StoneImagePreviewDialog.show(
            context,
            material: material,
            imageUrl: url,
            imageBytes: bytes,
          ),
          child: imageContent,
        ),
      );
    }

    return imageContent;
  }

  Widget _buildFallback(AppColorsExtension colors) {
    return Container(
      width: width,
      height: height,
      color: colors.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.terrain_rounded,
          size: (height != null && height! < 50) ? 20 : 28,
          color: colors.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Full screen rich modal preview for stone textures and photographs.
class StoneImagePreviewDialog extends StatelessWidget {
  final MaterialItem? material;
  final String? imageUrl;
  final Uint8List? imageBytes;

  const StoneImagePreviewDialog({
    super.key,
    this.material,
    this.imageUrl,
    this.imageBytes,
  });

  static Future<void> show(
    BuildContext context, {
    MaterialItem? material,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => StoneImagePreviewDialog(
        material: material,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = imageUrl ?? material?.imageUrl;
    final bytes = imageBytes ?? material?.imageBytes;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 24 : 32,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image_outlined, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material?.name ?? 'Stone Texture Preview',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (material != null)
                          Text(
                            '${material!.materialCode} • ${material!.categoryId} • ${material!.finish}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: colors.border, height: 1),

            // High Resolution Image Viewer
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    minScale: 0.8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: bytes != null
                          ? Image.memory(bytes, fit: BoxFit.contain)
                          : (url != null && url.startsWith('http')
                              ? (kIsWeb
                                  ? renderWebImage(
                                      url: url,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_) => Icon(Icons.broken_image_rounded, size: 48, color: colors.textSecondary),
                                    )
                                  : Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, size: 48, color: colors.textSecondary),
                                    ))
                              : Icon(Icons.image_not_supported_rounded, size: 48, color: colors.textSecondary)),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom details bar
            if (material != null) ...[
              Divider(color: colors.border, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _detailChip('Stock Area', '${material!.totalAreaSqm.toStringAsFixed(2)} m²', colors),
                        const SizedBox(width: 8),
                        _detailChip('Slabs Count', '${material!.totalSlabs}', colors),
                        const SizedBox(width: 8),
                        _detailChip('Origin', material!.origin, colors),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value, AppColorsExtension colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
          children: [
            TextSpan(
              text: value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
