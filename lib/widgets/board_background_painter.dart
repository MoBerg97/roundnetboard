import 'package:flutter/material.dart';
import 'dart:math' as math;

class BoardBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Green background is already set by container color

    // --- 1. Net circle with hashed fill ---
    const netRadius = 46.0;
    final netPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // draw circle outline
    canvas.drawCircle(center, netRadius, netPaint);

    // draw hashed lines inside
    const step = 6.0; // spacing between lines
    for (double dx = -netRadius; dx <= netRadius; dx += step) {
      final dy = math.sqrt(netRadius * netRadius - dx * dx);
      canvas.drawLine(
        center + Offset(dx, -dy),
        center + Offset(dx, dy),
        netPaint,
      );
    }
    for (double dy = -netRadius; dy <= netRadius; dy += step) {
      final dx = math.sqrt(netRadius * netRadius - dy * dy);
      canvas.drawLine(
        center + Offset(-dx, dy),
        center + Offset(dx, dy),
        netPaint,
      );
    }

    // --- 2. White thin circle, radius 100 ---
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, 100, whitePaint);

    // --- 3. White thin circle, radius 260 ---
    canvas.drawCircle(center, 260, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
