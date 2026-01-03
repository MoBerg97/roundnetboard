import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/court_element.dart';
import '../models/settings.dart';
import '../config/app_theme.dart';

class CourtEditorPainter extends CustomPainter {
  final List<CourtElement> elements;
  final Offset? eraserPos;
  final double eraserRadius;
  final Size screenSize;
  final CourtElement? previewElement;
  final Settings settings;

  CourtEditorPainter({
    required this.elements,
    this.eraserPos,
    required this.eraserRadius,
    required this.screenSize,
    this.previewElement,
    required this.settings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = _boardCenter(screenSize);

    // Sort elements so NET elements are drawn last (on top)
    final sortedElements = [...elements];
    sortedElements.sort((a, b) {
      // NET elements should always be last (topmost)
      if (a.type == CourtElementType.net && b.type != CourtElementType.net) return 1;
      if (a.type != CourtElementType.net && b.type == CourtElementType.net) return -1;
      return 0;
    });

    // Draw all elements
    for (final element in sortedElements) {
      _drawElement(canvas, element, center);
    }

    // Draw live preview (e.g., circle while dragging)
    if (previewElement != null) {
      _drawElement(canvas, previewElement!, center, isPreview: true);
      if (previewElement!.type == CourtElementType.innerCircle ||
          previewElement!.type == CourtElementType.outerCircle ||
          previewElement!.type == CourtElementType.customCircle) {
        final r = settings.cmToLogical(previewElement!.radius ?? 0, screenSize);
        final pos = _toScreenPosition(previewElement!.position, center);
        final diameterPaint = Paint()
          ..color = previewElement!.color.withValues(alpha: 0.6)
          ..strokeWidth = 1.5;
        canvas.drawLine(pos + Offset(-r, 0), pos + Offset(r, 0), diameterPaint);
      } else if (previewElement!.type == CourtElementType.customLine && previewElement!.endPosition != null) {
        // Show start and end points as circles for line preview
        final startPos = _toScreenPosition(previewElement!.position, center);
        final endPos = _toScreenPosition(previewElement!.endPosition!, center);
        final pointRadius = 4.0;
        final pointPaint = Paint()
          ..color = previewElement!.color.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(startPos, pointRadius, pointPaint);
        canvas.drawCircle(endPos, pointRadius, pointPaint);
      }
    }

    // Draw eraser preview
    if (eraserPos != null) {
      final eraserPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(eraserPos!, eraserRadius, eraserPaint);

      final eraserStroke = Paint()
        ..color = Colors.red
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(eraserPos!, eraserRadius, eraserStroke);
    }
  }

  /// Convert cm logical position to screen pixel position
  Offset _toScreenPosition(Offset cmPos, Offset center) {
    return center + Offset(settings.cmToLogical(cmPos.dx, screenSize), settings.cmToLogical(cmPos.dy, screenSize));
  }

  void _drawElement(Canvas canvas, CourtElement element, Offset center, {bool isPreview = false}) {
    final scaledPos = _toScreenPosition(element.position, center);
    final paint = Paint()
      ..color = element.color.withValues(alpha: isPreview ? 0.6 : 1.0)
      ..strokeWidth = element.strokeWidth
      ..style = PaintingStyle.stroke;

    switch (element.type) {
      case CourtElementType.net:
        _drawNet(canvas, scaledPos, settings.cmToLogical(element.radius!, screenSize), paint, isPreview);
        break;
      case CourtElementType.innerCircle:
      case CourtElementType.outerCircle:
      case CourtElementType.customCircle:
        canvas.drawCircle(scaledPos, settings.cmToLogical(element.radius!, screenSize), paint);
        break;
      case CourtElementType.customLine:
        if (element.endPosition != null) {
          final scaledEnd = _toScreenPosition(element.endPosition!, center);
          canvas.drawLine(scaledPos, scaledEnd, paint);
        }
        break;
      case CourtElementType.customRectangle:
        if (element.endPosition != null) {
          final scaledEnd = _toScreenPosition(element.endPosition!, center);
          final rect = Rect.fromPoints(scaledPos, scaledEnd);
          canvas.drawRect(rect, paint);
        }
        break;
    }
  }

  void _drawNet(Canvas canvas, Offset center, double radius, Paint strokePaint, bool isPreview) {
    // Outer filled donut to mimic board background net
    final bgPaint = Paint()
      ..color = AppTheme.courtGreen
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = AppTheme.lightGrey.withValues(alpha: isPreview ? 0.5 : 1.0)
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
      canvas.drawLine(center + Offset(dx, -dy), center + Offset(dx, dy), gridPaint);
    }
    for (double dy = -radius; dy <= radius; dy += step) {
      final term = radius * radius - dy * dy;
      if (term < 0) continue;
      final dx = math.sqrt(term);
      canvas.drawLine(center + Offset(-dx, dy), center + Offset(dx, dy), gridPaint);
    }

    // Outer stroke highlight
    canvas.drawCircle(center, radius + 5, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Offset _boardCenter(Size screenSize) {
  const double appBarHeight = kToolbarHeight;
  const double timelineHeight = 140;
  final usableHeight = screenSize.height - appBarHeight - timelineHeight;
  final offsetTop = appBarHeight;
  final cx = screenSize.width / 2;
  final cy = offsetTop + usableHeight / 2;
  return Offset(cx, cy);
}
