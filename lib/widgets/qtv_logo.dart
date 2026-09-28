import 'package:flutter/material.dart';

/// QTV Brand Logo + HD LIVE Badge Widget
class QtvLogoWidget extends StatelessWidget {
  final double fontSize;

  const QtvLogoWidget({
    super.key,
    this.fontSize = 44.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'QTV',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            height: 1.0,
            fontFamily: 'sans-serif',
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: const Text(
            'HD LIVE',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
