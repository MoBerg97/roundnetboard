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
  // Revision counter to force repaint when elements mutate in-place
  final int elementsRevision;

  BoardBackgroundPainter({
    required this.screenSize,
    required this.settings,
    this.customElements,
    this.projectType,
    this.elementsRevision = 0,
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
    // BUT still draw custom elements (user-created overlays)
    if (projectType == ProjectType.training) {
      // Draw custom elements even in training mode
      if (customElements != null && customElements!.isNotEmpty) {
        _drawCustomElements(canvas, center, customElements!);
      }
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

  void _drawNet(Canvas canvas, Offset center, double radius, Paint strokePaint) {
    // Outer filled donut to mimic board background net (same as CourtEditorPainter)
    final bgPaint = Paint()
      ..color = AppTheme.courtGreen
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = AppTheme.lightGrey
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius + 5, rimPaint);
    canvas.drawCircle(center, radius, bgPaint);

    // Grid hash pattern similar to board background
    final gridPaint = Paint()
      ..color = AppTheme.netBlack.withAlpha((0.4 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const step = 6.0;
    for (double dx = -radius; dx <= radius; dx += step) {
      final term = radius * radius - dx * dx;
      if (term < 0) continue;
      final dy = math.sqrt(term);
      canvas.drawLine(
        center + Offset(dx, -dy),
        center + Offset(dx, dy),
        gridPaint,
      );
    }
    for (double dy = -radius; dy <= radius; dy += step) {
      final term = radius * radius - dy * dy;
      if (term < 0) continue;
      final dx = math.sqrt(term);
      canvas.drawLine(
        center + Offset(-dx, dy),
        center + Offset(dx, dy),
        gridPaint,
      );
    }

    // Outer stroke highlight
    canvas.drawCircle(center, radius + 5, strokePaint);
  }

  @override
  bool shouldRepaint(covariant BoardBackgroundPainter oldDelegate) {
    // Repaint when:
    // - Settings or screen size or project type changed
    // - Elements revision changed (in-place mutations in editor)
    // - Elements list reference changed or length changed (BoardScreen rebuild after save)
    final listsDiffer = () {
      final a = oldDelegate.customElements;
      final b = customElements;
      if (a == null && b == null) return false;
      if (a == null || b == null) return true;
      if (!identical(a, b)) return true; // different list instance
      if (a.length != b.length) return true; // length change
      return false;
    }();

    return oldDelegate.settings != settings ||
        oldDelegate.screenSize != screenSize ||
        oldDelegate.projectType != projectType ||
        oldDelegate.elementsRevision != elementsRevision ||
        listsDiffer;
  }
}
