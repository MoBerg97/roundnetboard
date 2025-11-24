import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/settings.dart';

class BoardBackgroundPainter extends CustomPainter {
  final Size screenSize;
  final Settings settings;

  BoardBackgroundPainter({required this.screenSize, required this.settings});

  Offset _boardCenter() {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 120;
    final usableHeight = screenSize.height - appBarHeight - timelineHeight;
    final offsetTop = appBarHeight;
    final cx = screenSize.width / 2;
    final cy = offsetTop + usableHeight / 2;
    return Offset(cx, cy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = _boardCenter();

    // --- Background ---
    final bgPaint = Paint()..color = Colors.green[400]!;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // --- Net circle ---
    final netRadius = settings.netCircleRadiusPx;
    final netPaint = Paint()
      ..color = Colors.black.withAlpha((0.4 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, netRadius, netPaint);

    final step = 6.0;
    for (double dx = -netRadius; dx <= netRadius; dx += step) {
      final dy = (netRadius * netRadius - dx * dx) > 0
          ? math.sqrt(netRadius * netRadius - dx * dx)
          : 0;
      canvas.drawLine(center + Offset(dx.toDouble(), -dy.toDouble()), center + Offset(dx.toDouble(), dy.toDouble()), netPaint);
    }
    for (double dy = -netRadius; dy <= netRadius; dy += step) {
      final dx = (netRadius * netRadius - dy * dy) > 0
          ? math.sqrt(netRadius * netRadius - dy * dy)
          : 0;
      canvas.drawLine(center + Offset(-dx.toDouble(), dy.toDouble()), center + Offset(dx.toDouble(), dy.toDouble()), netPaint);
    }

    // --- Inner + Outer circles ---
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final innerRadius = settings.innerCircleRadiusPx;
    final outerRadius = settings.outerCircleRadiusPx;

    canvas.drawCircle(center, innerRadius, whitePaint);
    canvas.drawCircle(center, outerRadius, whitePaint);
  }

  @override
  bool shouldRepaint(covariant BoardBackgroundPainter oldDelegate) {
    return oldDelegate.settings != settings || oldDelegate.screenSize != screenSize;
  }
}