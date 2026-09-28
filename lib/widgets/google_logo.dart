import 'package:flutter/material.dart';

/// Custom widget rendering the authentic multi-color Google "G" logo
/// crisp at any resolution without requiring external image assets.
class GoogleLogoWidget extends StatelessWidget {
  final double size;

  const GoogleLogoWidget({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double center = width / 2;
    final double radius = width / 2;
    final double strokeWidth = width * 0.22;

    final rect = Rect.fromCircle(
      center: Offset(center, center),
      radius: radius - (strokeWidth / 2),
    );

    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Draw Google arcs
    // Red arc (Top)
    canvas.drawArc(rect, -0.75, 1.35, false, redPaint);
    // Yellow arc (Left)
    canvas.drawArc(rect, 0.6, 1.2, false, yellowPaint);
    // Green arc (Bottom)
    canvas.drawArc(rect, 1.8, 1.35, false, greenPaint);
    // Blue arc & bar (Right)
    canvas.drawArc(rect, 3.15, 0.9, false, bluePaint);

    // Blue horizontal crossbar
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTWH(
      center - strokeWidth * 0.1,
      center - strokeWidth / 2,
      radius,
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
