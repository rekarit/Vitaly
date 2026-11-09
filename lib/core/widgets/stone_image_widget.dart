import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/material_item.dart';
import '../theme/app_theme.dart';
import 'stone_texture_painter.dart';
import 'web_image_renderer.dart';

/// Universal stone image display widget that renders authentic procedural stone slabs,
/// handles uploaded photos, and provides interactive tap-to-preview modals.
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

  /// High-resolution verified texture photo for each stone category when material image is empty
  static String getDefaultImageUrlForCategory(String? categoryName) {
    if (categoryName == null) {
      return 'https://vitalygroup.co/wp-content/uploads/2026/02/CALACATTA-GOLD-Quartize-polish-copy.jpg';
    }
    final lower = categoryName.toLowerCase();
    if (lower.contains('quartzite') || lower.contains('quartz')) {
      return 'https://vitalygroup.co/wp-content/uploads/2026/02/CALACATTA-GOLD-Quartize-polish-copy.jpg';
    } else if (lower.contains('marble')) {
      return 'https://vitalygroup.co/wp-content/uploads/2026/02/SILK-EMPERADOR-Marble-Polish-copy.jpg';
    } else if (lower.contains('granite')) {
      return 'https://vitalygroup.co/wp-content/uploads/2026/02/BLACK-FOREST-Granite-Polish-copy.jpg';
    } else if (lower.contains('onyx')) {
      return 'https://vitalygroup.co/wp-content/uploads/2026/06/Onyx-Vitaly-12-scaled-e1782737433318-2048x1205.png';
    } else if (lower.contains('travertine')) {
      return 'https://vitalygroup.co/wp-content/uploads/2026/02/CLASSIC-BEIGE-Travertine-polish-copy.jpg';
    } else if (lower.contains('crystal') || lower.contains('semi precious')) {
      return 'https://vitalygroup.co/wp-content/uploads/2026/06/IMG_0333.jpeg';
    }
    return 'https://vitalygroup.co/wp-content/uploads/2026/02/CALACATTA-GOLD-Quartize-polish-copy.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes ?? material?.imageBytes;
    
    // Resolve URL
    String? url = imageUrl ?? material?.imageUrl;
    if (url != null && (!url.startsWith('http') || url.contains('vitalygroup.co'))) {
      // vitalygroup.co blocks requests with 403 StackProtect anti-bot barrier
      // Use the native, high-performance StoneTextureWidget instead
      url = null;
    }

    Widget imageContent;

    if (bytes != null && bytes.isNotEmpty) {
      imageContent = Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _buildTextureSlab(),
      );
    } else if (url != null && url.isNotEmpty) {
      if (kIsWeb) {
        imageContent = SizedBox(
          width: width,
          height: height,
          child: renderWebImage(
            url: url.trim(),
            fit: fit,
            errorBuilder: (_) => _buildTextureSlab(),
          ),
        );
      } else {
        imageContent = Image.network(
          url.trim(),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _buildTextureSlab(),
        );
      }
    } else {
      imageContent = _buildTextureSlab();
    }

    if (borderRadius != null) {
      imageContent = ClipRRect(
        borderRadius: borderRadius!,
        child: imageContent,
      );
    }

    if (enablePreviewOnTap) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => StoneImagePreviewDialog.show(
            context,
            material: material,
            imageUrl: url,
            imageBytes: bytes,
          ),
          child: Stack(
            fit: (width != null && height != null) ? StackFit.loose : StackFit.passthrough,
            children: [
              imageContent,
              // Subtle zoom indicator overlay on hover
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return imageContent;
  }

  Widget _buildTextureSlab() {
    return StoneTextureWidget(
      categoryName: material?.categoryId,
      stoneType: material?.stoneType,
      materialName: material?.name,
      materialCode: material?.materialCode,
      finish: material?.finish ?? 'Polish',
      width: width,
      height: height,
    );
  }
}

/// Full screen rich modal preview for stone textures and photographs with interactive zoom & pan.
class StoneImagePreviewDialog extends StatefulWidget {
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
  State<StoneImagePreviewDialog> createState() => _StoneImagePreviewDialogState();
}

class _StoneImagePreviewDialogState extends State<StoneImagePreviewDialog> {
  final TransformationController _transformCtrl = TransformationController();
  double _currentScale = 1.0;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale * 1.3).clamp(1.0, 4.0);
      _transformCtrl.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale / 1.3).clamp(1.0, 4.0);
      _transformCtrl.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformCtrl.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bytes = widget.imageBytes ?? widget.material?.imageBytes;
    
    String? url = widget.imageUrl ?? widget.material?.imageUrl;
    if (url != null && (!url.startsWith('http') || url.contains('vitalygroup.co'))) {
      url = null;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 28,
        vertical: isMobile ? 16 : 28,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.photo_library_rounded, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.material?.name.toUpperCase() ?? 'Stone Preview',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.material != null)
                          Text(
                            '${widget.material!.materialCode} • ${widget.material!.categoryId} • ${widget.material!.finish} • ${widget.material!.stoneType}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Zoom control buttons
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out_rounded, size: 18),
                          tooltip: 'Zoom Out',
                          onPressed: _zoomOut,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        Text(
                          '${(_currentScale * 100).round()}%',
                          style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in_rounded, size: 18),
                          tooltip: 'Zoom In',
                          onPressed: _zoomIn,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        if (_currentScale != 1.0)
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            tooltip: 'Reset Zoom',
                            onPressed: _resetZoom,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: colors.border, height: 1),

            // High Resolution Image Viewer Area with Definite Sizing
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF1F5F9),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final viewW = constraints.maxWidth;
                    final viewH = constraints.maxHeight;

                    Widget displayImage;
                    if (bytes != null && bytes.isNotEmpty) {
                      displayImage = Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        width: viewW,
                        height: viewH,
                      );
                    } else if (url != null && url.startsWith('http')) {
                      if (kIsWeb) {
                        displayImage = SizedBox(
                          width: viewW,
                          height: viewH,
                          child: renderWebImage(
                            url: url,
                            fit: BoxFit.contain,
                            errorBuilder: (_) => _buildTexturePreview(viewW, viewH),
                          ),
                        );
                      } else {
                        displayImage = Image.network(
                          url,
                          fit: BoxFit.contain,
                          width: viewW,
                          height: viewH,
                          errorBuilder: (_, __, ___) => _buildTexturePreview(viewW, viewH),
                        );
                      }
                    } else {
                      displayImage = _buildTexturePreview(viewW, viewH);
                    }

                    return InteractiveViewer(
                      transformationController: _transformCtrl,
                      maxScale: 4.0,
                      minScale: 1.0,
                      boundaryMargin: const EdgeInsets.all(40),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: viewW,
                            height: viewH,
                            child: displayImage,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bottom details bar
            if (widget.material != null) ...[
              Divider(color: colors.border, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _detailChip('Stock Area', '${widget.material!.totalAreaSqm.toStringAsFixed(2)} m²', colors),
                        const SizedBox(width: 8),
                        _detailChip('Slabs Count', '${widget.material!.totalSlabs}', colors),
                        const SizedBox(width: 8),
                        _detailChip('Origin', widget.material!.origin, colors),
                        if (widget.material!.referenceCode.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _detailChip('Ref', widget.material!.referenceCode, colors),
                        ],
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: isDark ? const Color(0xFF111418) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 16),
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

  Widget _buildTexturePreview(double width, double height) {
    return Stack(
      fit: StackFit.expand,
      children: [
        StoneTextureWidget(
          categoryName: widget.material?.categoryId,
          stoneType: widget.material?.stoneType,
          materialName: widget.material?.name,
          materialCode: widget.material?.materialCode,
          finish: widget.material?.finish ?? 'Polish',
          width: width,
          height: height,
        ),
        // Natural Stone Slab Watermark Specimen Badge in bottom corner
        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Text(
                  '${widget.material?.stoneType ?? "NATURAL"} • ${widget.material?.finish ?? "POLISH"} SLAB',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
