import 'package:flutter/material.dart';
import '../models/settings.dart';
import 'dart:math' as math;

class BoardBackgroundPainter extends CustomPainter {
  final Size screenSize;
  final Settings settings;

  BoardBackgroundPainter({required this.screenSize, required this.settings});

  Offset _boardCenter() => Offset(screenSize.width / 2, screenSize.height / 2);

double _boardScale() {
  // Scale so that outer circle fits within screen with some padding
  final maxRadius = math.min(screenSize.width, screenSize.height) / 2 - 16; // padding
  final outerRadius = settings.outerCircleRadius.clamp(1.0, double.infinity);
  return maxRadius / outerRadius;
}


  Offset _toScreen(Offset logicalPos) {
    // Convert logical board coordinates to screen coordinates
    final center = _boardCenter();
    final scale = _boardScale();
    return center + (logicalPos * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the board background elements based on settings
    final center = _boardCenter();
    final scale = _boardScale();

    // --- 1. Net circle with hashed fill ---
    final netRadius = settings.netCircleRadius * scale;

    final netPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, netRadius, netPaint);

    final step = 6.0 * scale;

    // Draw hashed lines inside the net circle
    for (double dx = -netRadius; dx <= netRadius; dx += step) {
      final dy = math.sqrt(netRadius * netRadius - dx * dx);
      canvas.drawLine(center + Offset(dx, -dy), center + Offset(dx, dy), netPaint);
    }
    for (double dy = -netRadius; dy <= netRadius; dy += step) {
      final dx = math.sqrt(netRadius * netRadius - dy * dy);
      canvas.drawLine(center + Offset(-dx, dy), center + Offset(dx, dy), netPaint);
    }

    // --- 2. White thin circles (inner and outer) ---
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, settings.innerCircleRadius * scale, whitePaint);
    canvas.drawCircle(center, settings.outerCircleRadius * scale, whitePaint);
  }

  @override
  bool shouldRepaint(covariant BoardBackgroundPainter oldDelegate) {
    return oldDelegate.settings != settings || oldDelegate.screenSize != screenSize;
  }
}