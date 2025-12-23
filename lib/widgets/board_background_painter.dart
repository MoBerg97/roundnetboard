import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/app_theme.dart';
import '../models/settings.dart';
import '../models/court_element.dart';
import '../models/animation_project.dart';

class BoardBackgroundPainter extends CustomPainter {
  final Size screenSize;
  final Settings settings;
  final List<CourtElement>? customElements;
  final ProjectType? projectType; // null for play mode, training for training mode

  BoardBackgroundPainter({
    required this.screenSize,
    required this.settings,
    this.customElements,
    this.projectType,
  });

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

    // In training mode, skip drawing net and zones - only show background
    if (projectType == ProjectType.training) {
      return;
    }

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

    // --- Custom court elements (if any) ---
    if (customElements != null && customElements!.isNotEmpty) {
      _drawCustomElements(canvas, center, customElements!);
    }
  }

  void _drawCustomElements(Canvas canvas, Offset center, List<CourtElement> elements) {
    for (final element in elements) {
      if (!element.isVisible) continue;

      final paint = Paint()
        ..color = element.color
        ..strokeWidth = element.strokeWidth
        ..style = PaintingStyle.stroke;

      final scaledPos = center + (element.position - center);

      switch (element.type) {
        case CourtElementType.net:
          _drawNet(canvas, scaledPos, element.radius!, paint);
          break;
        case CourtElementType.innerCircle:
        case CourtElementType.outerCircle:
        case CourtElementType.customCircle:
          canvas.drawCircle(scaledPos, element.radius!, paint);
          break;
        case CourtElementType.customLine:
          if (element.endPosition != null) {
            final scaledEnd = center + (element.endPosition! - center);
            canvas.drawLine(scaledPos, scaledEnd, paint);
          }
          break;
        case CourtElementType.customRectangle:
          if (element.endPosition != null) {
            final scaledEnd = center + (element.endPosition! - center);
            final rect = Rect.fromPoints(scaledPos, scaledEnd);
            canvas.drawRect(rect, paint);
          }
          break;
      }
    }
  }

  void _drawNet(Canvas canvas, Offset center, double radius, Paint paint) {
    // Draw outer circle
    canvas.drawCircle(center, radius, paint);

    // Draw inner circle (rim)
    canvas.drawCircle(center, radius * 0.5, paint);

    // Draw hash pattern
    for (double angle = 0; angle < 360; angle += 15) {
      final radians = angle * 3.14159 / 180;
      final x1 = radius * 0.5 * (angle % 2 == 0 ? 0.6 : 0.4);
      final y1 = radius * 0.5 * (angle % 2 == 0 ? 0.6 : 0.4);
      
      final x = x1 * cos(radians);
      final y = y1 * sin(radians);
      
      canvas.drawLine(
        Offset(center.dx - x * 0.3, center.dy - y * 0.3),
        Offset(center.dx + x, center.dy + y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoardBackgroundPainter oldDelegate) {
    return oldDelegate.settings != settings || 
           oldDelegate.screenSize != screenSize ||
           oldDelegate.customElements != customElements ||
           oldDelegate.projectType != projectType;
  }
}

double cos(double angle) {
  angle = angle % (3.14159 * 2);
  if (angle < 0) angle += 3.14159 * 2;
  
  if (angle < 3.14159 / 2) return sin(3.14159 / 2 - angle);
  if (angle < 3.14159) return -sin(angle - 3.14159 / 2);
  if (angle < 3.14159 * 1.5) return -sin(3.14159 * 1.5 - angle);
  return sin(angle - 3.14159 * 1.5);
}

double sin(double angle) {
  angle = angle % (3.14159 * 2);
  if (angle < 0) angle += 3.14159 * 2;
  
  const lookup = [
    0.0, 0.052, 0.105, 0.156, 0.208, 0.259, 0.309, 0.358, 0.407, 0.454,
    0.5, 0.545, 0.588, 0.629, 0.669, 0.707, 0.743, 0.777, 0.809, 0.839,
    0.866, 0.891, 0.914, 0.934, 0.951, 0.966, 0.978, 0.988, 0.995, 0.999, 1.0
  ];
  
  final index = ((angle / (3.14159 / 2)) * 30).toInt().clamp(0, 30);
  
  if (angle <= 3.14159 / 2) return lookup[index];
  if (angle <= 3.14159) return lookup[60 - index];
  if (angle <= 3 * 3.14159 / 2) return -lookup[index - 30];
  return -lookup[90 - index];
}
