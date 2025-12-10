import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/app_theme.dart';
import '../models/settings.dart';

class BoardBackgroundPainter extends CustomPainter {
  final Size screenSize;
  final Settings settings;

  BoardBackgroundPainter({required this.screenSize, required this.settings});

  Offset _boardCenter() {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 140; // Match timeline height in board_screen.dart
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
    final bgPaint = Paint()..color = AppTheme.courtGreen;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // --- Net donut (annulus) ---
    final netRadius = settings.netCircleRadiusPx;
    final RimOuterRadius = netRadius + 5;

    // Draw outer filled circle (light grey)
    final RimPaint = Paint()
      ..color = AppTheme.lightGrey
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, RimOuterRadius, RimPaint);

    // Draw inner filled circle (court background color) to "cut out" center
    canvas.drawCircle(center, netRadius, bgPaint);

    // Define netPaint for grid lines (if you still want them)
    final netPaint = Paint()
      ..color = AppTheme.netBlack.withAlpha((0.4*255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final step = 6.0;
    for (double dx = -netRadius; dx <= netRadius; dx += step) {
      final dy = (netRadius * netRadius - dx * dx) > 0 ? math.sqrt(netRadius * netRadius - dx * dx) : 0;
      canvas.drawLine(
        center + Offset(dx.toDouble(), -dy.toDouble()),
        center + Offset(dx.toDouble(), dy.toDouble()),
        netPaint,
      );
    }
    for (double dy = -netRadius; dy <= netRadius; dy += step) {
      final dx = (netRadius * netRadius - dy * dy) > 0 ? math.sqrt(netRadius * netRadius - dy * dy) : 0;
      canvas.drawLine(
        center + Offset(-dx.toDouble(), dy.toDouble()),
        center + Offset(dx.toDouble(), dy.toDouble()),
        netPaint,
      );
    }

    // --- Inner + Outer circles ---
    final whitePaint = Paint()
      ..color = AppTheme.courtLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final innerRadius = settings.innerCircleRadiusPx;
    final outerRadius = settings.outerCircleRadiusPx;

    // Existing circles
    canvas.drawCircle(center, innerRadius, whitePaint);
    canvas.drawCircle(center, outerRadius, whitePaint);

    // --- Additional outer bounds circle ---
    final outerBoundsRadius = settings.outerBoundsRadiusPx; // Define this in your Settings model

    canvas.drawCircle(center, outerBoundsRadius, whitePaint);
  }

  @override
  bool shouldRepaint(covariant BoardBackgroundPainter oldDelegate) {
    return oldDelegate.settings != settings || oldDelegate.screenSize != screenSize;
  }
}
