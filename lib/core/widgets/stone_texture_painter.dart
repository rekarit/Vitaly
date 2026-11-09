import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Stone texture palette definitions for authentic procedural rendering
class StonePalette {
  final Color baseColor;
  final Color secondaryColor;
  final Color veinPrimary;
  final Color veinSecondary;
  final Color highlightColor;
  final Color speckleColor;

  const StonePalette({
    required this.baseColor,
    required this.secondaryColor,
    required this.veinPrimary,
    required this.veinSecondary,
    required this.highlightColor,
    required this.speckleColor,
  });

  static StonePalette resolve({
    required String? categoryName,
    required String? stoneType,
    required String? materialName,
  }) {
    final name = (materialName ?? '').toUpperCase();
    final cat = (categoryName ?? '').toUpperCase();
    final type = (stoneType ?? '').toUpperCase();

    // 1. Specific Color Schemes based on Stone Name
    if (name.contains('CALACATTA') || name.contains('STATUARIO') || name.contains('WHITE') || name.contains('BIANKO')) {
      if (name.contains('GOLD') || name.contains('LUX')) {
        // Calacatta Gold
        return const StonePalette(
          baseColor: Color(0xFFF7F4EB),
          secondaryColor: Color(0xFFEBE4D5),
          veinPrimary: Color(0xFFBFA15F),
          veinSecondary: Color(0xFF8C7D68),
          highlightColor: Color(0xFFFFFDF5),
          speckleColor: Color(0xFFDFD1B5),
        );
      }
      // Pure White / Grey Veins
      return const StonePalette(
        baseColor: Color(0xFFF8FAFC),
        secondaryColor: Color(0xFFE2E8F0),
        veinPrimary: Color(0xFF64748B),
        veinSecondary: Color(0xFF94A3B8),
        highlightColor: Color(0xFFFFFFFF),
        speckleColor: Color(0xFFCBD5E1),
      );
    }

    if (name.contains('BLACK') || name.contains('NIGHT') || name.contains('CASPIAN') || name.contains('FOREST')) {
      if (name.contains('FUSION') || name.contains('GOLD')) {
        // Black Fusion (Black with bright gold river veins)
        return const StonePalette(
          baseColor: Color(0xFF121417),
          secondaryColor: Color(0xFF1E2228),
          veinPrimary: Color(0xFFD97706),
          veinSecondary: Color(0xFFF59E0B),
          highlightColor: Color(0xFFFEF3C7),
          speckleColor: Color(0xFF78716C),
        );
      }
      // Obsidian Black with silver specks
      return const StonePalette(
        baseColor: Color(0xFF0F1115),
        secondaryColor: Color(0xFF1A1D24),
        veinPrimary: Color(0xFF475569),
        veinSecondary: Color(0xFF64748B),
        highlightColor: Color(0xFFE2E8F0),
        speckleColor: Color(0xFF94A3B8),
      );
    }

    if (name.contains('GREEN') || name.contains('JAGUAR') || name.contains('VERDE') || name.contains('AMAZONIA')) {
      // Emerald / Verde Amazonia
      return const StonePalette(
        baseColor: Color(0xFF0B2418),
        secondaryColor: Color(0xFF123827),
        veinPrimary: Color(0xFF22C55E),
        veinSecondary: Color(0xFFCA8A04),
        highlightColor: Color(0xFF86EFAC),
        speckleColor: Color(0xFF15803D),
      );
    }

    if (name.contains('BLUE') || name.contains('VOLGA') || name.contains('AQUA')) {
      // Volga Blue / Crystal Blue
      return const StonePalette(
        baseColor: Color(0xFF0C1929),
        secondaryColor: Color(0xFF152A45),
        veinPrimary: Color(0xFF0284C7),
        veinSecondary: Color(0xFF38BDF8),
        highlightColor: Color(0xFFBAE6FD),
        speckleColor: Color(0xFF0369A1),
      );
    }

    if (name.contains('EMPERADOR') || name.contains('BROWN') || name.contains('TORANJ') || name.contains('ARMANI')) {
      // Dark / Silk Emperador Chocolate
      return const StonePalette(
        baseColor: Color(0xFF261810),
        secondaryColor: Color(0xFF3B261A),
        veinPrimary: Color(0xFFD97706),
        veinSecondary: Color(0xFFE5C390),
        highlightColor: Color(0xFFFEF3C7),
        speckleColor: Color(0xFF784B2E),
      );
    }

    if (name.contains('AMETHYST') || name.contains('PURPLE') || name.contains('VIOLET')) {
      // Amethyst Gemstone
      return const StonePalette(
        baseColor: Color(0xFF2A103D),
        secondaryColor: Color(0xFF3F195C),
        veinPrimary: Color(0xFFA855F7),
        veinSecondary: Color(0xFFC084FC),
        highlightColor: Color(0xFFF3E8FF),
        speckleColor: Color(0xFF7E22CE),
      );
    }

    if (name.contains('BEIGE') || name.contains('CREAM') || name.contains('TITANIUM') || name.contains('ZEBRINO')) {
      // Warm Travertine Beige
      return const StonePalette(
        baseColor: Color(0xFFEFE8DA),
        secondaryColor: Color(0xFFDFD4BE),
        veinPrimary: Color(0xFFB09F82),
        veinSecondary: Color(0xFF8C7B61),
        highlightColor: Color(0xFFFCFBF7),
        speckleColor: Color(0xFFC7B79B),
      );
    }

    // 2. Category Default Palettes
    if (cat.contains('ONYX') || type.contains('ONYX')) {
      return const StonePalette(
        baseColor: Color(0xFFD97706),
        secondaryColor: Color(0xFFB45309),
        veinPrimary: Color(0xFFFEF08A),
        veinSecondary: Color(0xFFFDE047),
        highlightColor: Color(0xFFFFFBEB),
        speckleColor: Color(0xFF78350F),
      );
    }

    if (cat.contains('TRAVERTINE') || type.contains('TRAVERTINE')) {
      return const StonePalette(
        baseColor: Color(0xFFE8DECA),
        secondaryColor: Color(0xFFD8C9AE),
        veinPrimary: Color(0xFF9E8B6E),
        veinSecondary: Color(0xFF7D6C52),
        highlightColor: Color(0xFFFBF8F2),
        speckleColor: Color(0xFFB8A587),
      );
    }

    if (cat.contains('GRANITE') || type.contains('GRANITE')) {
      return const StonePalette(
        baseColor: Color(0xFF1E242B),
        secondaryColor: Color(0xFF2B333C),
        veinPrimary: Color(0xFF64748B),
        veinSecondary: Color(0xFF94A3B8),
        highlightColor: Color(0xFFF1F5F9),
        speckleColor: Color(0xFFCBD5E1),
      );
    }

    if (cat.contains('MARBLE') || type.contains('MARBLE')) {
      return const StonePalette(
        baseColor: Color(0xFFF3EFE6),
        secondaryColor: Color(0xFFE2D9C8),
        veinPrimary: Color(0xFF786A59),
        veinSecondary: Color(0xFFA3937F),
        highlightColor: Color(0xFFFFFFFF),
        speckleColor: Color(0xFFC7B9A5),
      );
    }

    if (cat.contains('CRYSTAL') || cat.contains('SEMI') || type.contains('CRYSTAL')) {
      return const StonePalette(
        baseColor: Color(0xFF1E293B),
        secondaryColor: Color(0xFF334155),
        veinPrimary: Color(0xFF38BDF8),
        veinSecondary: Color(0xFF818CF8),
        highlightColor: Color(0xFFE0E7FF),
        speckleColor: Color(0xFF6366F1),
      );
    }

    // Standard Quartzite fallback
    return const StonePalette(
      baseColor: Color(0xFFF5F2EB),
      secondaryColor: Color(0xFFE7DEC9),
      veinPrimary: Color(0xFFB89F6B),
      veinSecondary: Color(0xFF8C7752),
      highlightColor: Color(0xFFFFFDF8),
      speckleColor: Color(0xFFD4C4A3),
    );
  }
}

/// Custom painter that renders authentic natural stone slabs with veins, strata, and crystals.
class StoneTexturePainter extends CustomPainter {
  final StonePalette palette;
  final String stoneType;
  final String finish;
  final int seed;

  StoneTexturePainter({
    required this.palette,
    required this.stoneType,
    required this.finish,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final w = size.width;
    final h = size.height;

    // 1. Base Gradient Background (Mottling)
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.baseColor,
          palette.secondaryColor,
          palette.baseColor.withValues(alpha: 0.9),
          palette.secondaryColor,
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final typeLower = stoneType.toLowerCase();

    // 2. Texture Specific Patterns
    if (typeLower.contains('travertine')) {
      _paintTravertineStrata(canvas, size, rand);
    } else if (typeLower.contains('granite')) {
      _paintGraniteSpeckles(canvas, size, rand);
    } else if (typeLower.contains('onyx')) {
      _paintOnyxWaves(canvas, size, rand);
    } else if (typeLower.contains('crystal') || typeLower.contains('semi')) {
      _paintCrystalFacets(canvas, size, rand);
    } else {
      // Marble & Quartzite: Organic Breccia Veining
      _paintMarbleVeins(canvas, size, rand);
    }

    // 3. Surface Finish Sheen Overlay
    _paintFinishEffect(canvas, size);

    // 4. Subtle Perimeter Slab Edge Vignette
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black.withValues(alpha: 0.15);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), borderPaint);
  }

  void _paintMarbleVeins(Canvas canvas, Size size, math.Random rand) {
    final w = size.width;
    final h = size.height;

    // Primary Deep Veins
    for (int i = 0; i < 3; i++) {
      final veinPath = Path();
      double startX = rand.nextDouble() * (w * 0.4);
      double startY = 0;
      double endX = w * 0.6 + rand.nextDouble() * (w * 0.4);

      veinPath.moveTo(startX, startY);

      int segments = 5;
      double curX = startX;
      double curY = startY;
      for (int s = 1; s <= segments; s++) {
        double targetY = (h / segments) * s;
        double targetX = startX + ((endX - startX) / segments) * s + (rand.nextDouble() - 0.5) * (w * 0.25);
        double ctrlX = (curX + targetX) / 2 + (rand.nextDouble() - 0.5) * (w * 0.2);
        double ctrlY = (curY + targetY) / 2;
        veinPath.quadraticBezierTo(ctrlX, ctrlY, targetX, targetY);
        curX = targetX;
        curY = targetY;
      }

      final veinPaint = Paint()
        ..color = (i == 0 ? palette.veinPrimary : palette.veinSecondary).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, w * 0.015)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawPath(veinPath, veinPaint);

      // Highlight Core
      final corePaint = Paint()
        ..color = palette.highlightColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.006)
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(veinPath, corePaint);
    }

    // Branching Micro-Veins
    for (int b = 0; b < 6; b++) {
      final bPath = Path();
      double bx = rand.nextDouble() * w;
      double by = rand.nextDouble() * h;
      bPath.moveTo(bx, by);
      bPath.lineTo(bx + (rand.nextDouble() - 0.5) * (w * 0.35), by + (rand.nextDouble() - 0.5) * (h * 0.35));

      final bPaint = Paint()
        ..color = palette.veinSecondary.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(bPath, bPaint);
    }
  }

  void _paintGraniteSpeckles(Canvas canvas, Size size, math.Random rand) {
    final w = size.width;
    final h = size.height;
    final numDots = (w * h / 35).clamp(80, 800).toInt();

    final specklePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < numDots; i++) {
      final x = rand.nextDouble() * w;
      final y = rand.nextDouble() * h;
      final radius = 0.8 + rand.nextDouble() * 2.2;

      final choice = rand.nextInt(3);
      if (choice == 0) {
        specklePaint.color = palette.speckleColor.withValues(alpha: 0.65);
      } else if (choice == 1) {
        specklePaint.color = palette.highlightColor.withValues(alpha: 0.75);
      } else {
        specklePaint.color = palette.veinPrimary.withValues(alpha: 0.55);
      }

      canvas.drawCircle(Offset(x, y), radius, specklePaint);
    }
  }

  void _paintTravertineStrata(Canvas canvas, Size size, math.Random rand) {
    final w = size.width;
    final h = size.height;
    const bands = 12;

    for (int i = 0; i < bands; i++) {
      final y = (h / bands) * i;
      final thickness = (h / bands) * (0.6 + rand.nextDouble() * 0.8);

      final bandPaint = Paint()
        ..color = (i % 2 == 0 ? palette.veinPrimary : palette.veinSecondary).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(0, y);
      path.quadraticBezierTo(w * 0.5, y + (rand.nextDouble() - 0.5) * 8, w, y);
      path.lineTo(w, y + thickness);
      path.quadraticBezierTo(w * 0.5, y + thickness + (rand.nextDouble() - 0.5) * 8, 0, y + thickness);
      path.close();

      canvas.drawPath(path, bandPaint);
    }
  }

  void _paintOnyxWaves(Canvas canvas, Size size, math.Random rand) {
    final w = size.width;
    final h = size.height;
    const count = 7;

    for (int i = 0; i < count; i++) {
      final wavePath = Path();
      final cy = (h / count) * i;

      wavePath.moveTo(0, cy);
      wavePath.cubicTo(
        w * 0.25, cy - 25 + rand.nextDouble() * 50,
        w * 0.75, cy + 25 - rand.nextDouble() * 50,
        w, cy,
      );

      final wavePaint = Paint()
        ..color = (i % 2 == 0 ? palette.highlightColor : palette.veinPrimary).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.0, w * 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawPath(wavePath, wavePaint);
    }
  }

  void _paintCrystalFacets(Canvas canvas, Size size, math.Random rand) {
    final w = size.width;
    final h = size.height;

    for (int i = 0; i < 8; i++) {
      final poly = Path();
      double cx = rand.nextDouble() * w;
      double cy = rand.nextDouble() * h;
      double r = 18 + rand.nextDouble() * 35;

      poly.moveTo(cx + r * math.cos(0), cy + r * math.sin(0));
      for (int a = 1; a < 6; a++) {
        double angle = a * (math.pi / 3);
        poly.lineTo(cx + r * math.cos(angle), cy + r * math.sin(angle));
      }
      poly.close();

      final polyPaint = Paint()
        ..color = palette.highlightColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawPath(poly, polyPaint);

      final linePaint = Paint()
        ..color = palette.veinPrimary.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawPath(poly, linePaint);
    }
  }

  void _paintFinishEffect(Canvas canvas, Size size) {
    final f = finish.toLowerCase();
    if (f.contains('polish')) {
      // Polished mirror diagonal glare
      final sheenPaint = Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1.2, -1.2),
          end: const Alignment(1.2, 1.2),
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.35, 0.5, 0.65],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sheenPaint);
    } else if (f.contains('honed') || f.contains('matte')) {
      // Soft matte diffused film
      final mattePaint = Paint()..color = Colors.black.withValues(alpha: 0.05);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), mattePaint);
    }
  }

  @override
  bool shouldRepaint(covariant StoneTexturePainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.finish != finish ||
        oldDelegate.stoneType != stoneType ||
        oldDelegate.palette != palette;
  }
}

/// Standalone Flutter widget that renders an authentic, fully responsive stone texture slab.
class StoneTextureWidget extends StatelessWidget {
  final String? categoryName;
  final String? stoneType;
  final String? materialName;
  final String? materialCode;
  final String finish;
  final double? width;
  final double? height;
  final bool showBadge;

  const StoneTextureWidget({
    super.key,
    this.categoryName,
    this.stoneType,
    this.materialName,
    this.materialCode,
    this.finish = 'Polish',
    this.width,
    this.height,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StonePalette.resolve(
      categoryName: categoryName,
      stoneType: stoneType,
      materialName: materialName,
    );

    final seed = (materialCode ?? materialName ?? 'stone').hashCode.abs();

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: StoneTexturePainter(
          palette: palette,
          stoneType: stoneType ?? categoryName ?? 'Marble',
          finish: finish,
          seed: seed,
        ),
      ),
    );
  }
}
