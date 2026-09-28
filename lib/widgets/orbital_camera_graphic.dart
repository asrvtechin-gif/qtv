import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated Concentric Orbital Camera Graphic
/// Draws the orbital rings, glowing cyan & purple orbital dots,
/// and the central camera badge with smooth subtle animations.
class OrbitalCameraGraphic extends StatefulWidget {
  final double size;

  const OrbitalCameraGraphic({
    super.key,
    this.size = 240.0,
  });

  @override
  State<OrbitalCameraGraphic> createState() => _OrbitalCameraGraphicState();
}

class _OrbitalCameraGraphicState extends State<OrbitalCameraGraphic>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _OrbitalPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  final double progress;

  _OrbitalPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 0. Ambient background radial glow (Purple + Cyan)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6B21A8).withValues(alpha: 0.35), // Deep glowing purple
          const Color(0xFF00E5FF).withValues(alpha: 0.15), // Cyan tint
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 1.1));

    canvas.drawCircle(center, maxRadius * 1.05, glowPaint);

    // Radii for concentric rings
    final r3 = maxRadius * 0.92; // Outer ring
    final r2 = maxRadius * 0.72; // Mid-outer ring
    final r1 = maxRadius * 0.52; // Mid-inner ring
    final rCore = maxRadius * 0.34; // Core camera circle

    // 1. Outer Ring (Dark purple/blue thin stroke)
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: const [
          Color(0xFF3B1578),
          Color(0xFF1E1B4B),
          Color(0xFF0284C7),
          Color(0xFF3B1578),
        ],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: r3));

    canvas.drawCircle(center, r3, outerRingPaint);

    // 2. Mid-outer Ring
    final midRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: const [
          Color(0xFF00E5FF),
          Color(0xFF8B5CF6),
          Color(0xFF1E1B4B),
          Color(0xFF00E5FF),
        ],
        transform: GradientRotation(-progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: r2));

    canvas.drawCircle(center, r2, midRingPaint);

    // 3. Mid-inner Ring
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = SweepGradient(
        colors: const [
          Color(0xFF9333EA),
          Color(0xFF00E5FF),
          Color(0xFF4C1D95),
          Color(0xFF9333EA),
        ],
        transform: GradientRotation(progress * 2 * math.pi * 0.5),
      ).createShader(Rect.fromCircle(center: center, radius: r1));

    canvas.drawCircle(center, r1, innerRingPaint);

    // 4. Orbital Dots
    // Outer Cyan Dot (at ~10 o'clock in original design, with smooth slow orbit)
    final cyanAngle = -2.2 + (progress * 2 * math.pi * 0.2);
    final cyanDotCenter = Offset(
      center.dx + r3 * math.cos(cyanAngle),
      center.dy + r3 * math.sin(cyanAngle),
    );

    // Glowing aura for Cyan Dot
    final cyanGlowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(cyanDotCenter, 5.5, cyanGlowPaint);

    final cyanDotPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(cyanDotCenter, 3.8, cyanDotPaint);

    // Mid Purple Dot (at ~4 o'clock in original design, orbiting slowly in reverse)
    final purpleAngle = 0.85 - (progress * 2 * math.pi * 0.15);
    final purpleDotCenter = Offset(
      center.dx + r2 * math.cos(purpleAngle),
      center.dy + r2 * math.sin(purpleAngle),
    );

    // Glowing aura for Purple Dot
    final purpleGlowPaint = Paint()
      ..color = const Color(0xFFA855F7).withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(purpleDotCenter, 6.5, purpleGlowPaint);

    final purpleDotPaint = Paint()
      ..color = const Color(0xFFC084FC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(purpleDotCenter, 4.5, purpleDotPaint);

    // 5. Central Camera Circle Core
    // Dark core fill
    final coreFillPaint = Paint()
      ..color = const Color(0xFF080B18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, rCore, coreFillPaint);

    // Glowing cyan stroke around core
    final coreGlowStroke = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, rCore, coreGlowStroke);

    final coreBorderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, rCore, coreBorderPaint);

    // 6. Draw Center Video Camera Icon
    _drawCameraIcon(canvas, center, rCore * 0.85);
  }

  void _drawCameraIcon(Canvas canvas, Offset center, double iconSize) {
    final Paint iconPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double w = iconSize * 0.8;
    final double h = iconSize * 0.55;

    // Body rectangle (rounded)
    final RRect bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx - w * 0.1, center.dy), width: w * 0.62, height: h),
      const Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, iconPaint);

    // Lens triangle / trapezoid on the right
    final Path lensPath = Path();
    final double lensLeft = center.dx + w * 0.22;
    final double lensRight = center.dx + w * 0.48;
    final double lensTop = center.dy - h * 0.42;
    final double lensBottom = center.dy + h * 0.42;

    lensPath.moveTo(lensLeft, center.dy - h * 0.18);
    lensPath.lineTo(lensRight, lensTop);
    lensPath.lineTo(lensRight, lensBottom);
    lensPath.lineTo(lensLeft, center.dy + h * 0.18);
    lensPath.close();

    canvas.drawPath(lensPath, iconPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
