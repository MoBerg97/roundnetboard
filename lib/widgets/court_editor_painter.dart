import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/court_element.dart';
import '../models/settings.dart';
import '../config/app_theme.dart';

const String _textFontFamily = 'Roboto';

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
        if (_isOuterBoundaryZone(element)) {
          _drawCenterCrosshair(canvas, scaledPos);
        }
        break;
      case CourtElementType.customLine:
        if (element.endPosition != null) {
          final scaledEnd = _toScreenPosition(element.endPosition!, center);
          if ((element.text ?? '').startsWith('marker:')) {
            final marker = (element.text ?? '').substring('marker:'.length);
            _drawMarker(canvas, scaledPos, scaledEnd, paint, marker, isPreview: isPreview);
          } else {
            canvas.drawLine(scaledPos, scaledEnd, paint);
          }
        }
        break;
      case CourtElementType.customRectangle:
        if (element.endPosition != null) {
          final scaledEnd = _toScreenPosition(element.endPosition!, center);
          final rect = Rect.fromPoints(scaledPos, scaledEnd);
          canvas.drawRect(rect, paint);
        }
        break;
      case CourtElementType.sector:
        if (element.radius != null && element.startAngle != null && element.endAngle != null) {
          final radiusPx = settings.cmToLogical(element.radius!, screenSize);
          final rect = Rect.fromCircle(center: scaledPos, radius: radiusPx);
          final start = element.startAngle!;
          final sweep = element.endAngle! - start;
          final fillPaint = Paint()
            ..color = element.color.withValues(alpha: isPreview ? 0.3 : 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawArc(rect, start, sweep, true, fillPaint);
          canvas.drawArc(rect, start, sweep, true, paint);
        }
        break;
      case CourtElementType.text:
        final label = element.text ?? '';
        if (label.isEmpty) return;
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: element.color.withValues(alpha: isPreview ? 0.6 : 1.0),
              fontSize: element.fontSize ?? 20,
              fontFamily: _textFontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final paintOffset = scaledPos - Offset(textPainter.width / 2, textPainter.height / 2);
        textPainter.paint(canvas, paintOffset);
        break;
    }
  }

  bool _isOuterBoundaryZone(CourtElement element) {
    if (element.type != CourtElementType.outerCircle) return false;
    if (element.radius == null) return false;
    return (element.radius! - settings.outerBoundsRadiusCm).abs() < 0.5;
  }

  void _drawCenterCrosshair(Canvas canvas, Offset center) {
    final size = settings.cmToLogical(10.0, screenSize).abs();
    final half = size / 2;
    final paint = Paint()
      ..color = AppTheme.courtLine.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center + Offset(-half, 0), center + Offset(half, 0), paint);
    canvas.drawLine(center + Offset(0, -half), center + Offset(0, half), paint);
  }

  void _drawNet(Canvas canvas, Offset center, double radius, Paint strokePaint, bool isPreview) {
    // Outer filled donut to mimic board background net
    final bgPaint = Paint()
      ..color = settings.courtBackgroundColor
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

  void _drawMarker(Canvas canvas, Offset start, Offset end, Paint paint, String markerType, {required bool isPreview}) {
    final center = (end - start).distance > 0.001 ? end : start;
    final base = math.max(8.0, paint.strokeWidth * 3.0);

    if (markerType == 'dot') {
      final fill = Paint()
        ..color = paint.color.withValues(alpha: isPreview ? 0.6 : 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 2.5, fill);
      return;
    }

    if (markerType == 'pylon') {
      final radius = math.max(4.0, base * 0.55);
      final pylonPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.95,
          colors: [
            Colors.white.withValues(alpha: isPreview ? 0.45 : 0.82),
            paint.color.withValues(alpha: isPreview ? 0.42 : 0.88),
            paint.color.withValues(alpha: isPreview ? 0.22 : 0.56),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, pylonPaint);
      final border = Paint()
        ..color = paint.color.withValues(alpha: isPreview ? 0.5 : 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, paint.strokeWidth * 0.4);
      canvas.drawCircle(center, radius, border);
      return;
    }

    final arm = base * 0.65;
    canvas.drawLine(center + Offset(-arm, -arm), center + Offset(arm, arm), paint);
    canvas.drawLine(center + Offset(-arm, arm), center + Offset(arm, -arm), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Offset _boardCenter(Size screenSize) {
  final cx = screenSize.width / 2;
  final cy = screenSize.height / 2;
  return Offset(cx, cy);
}
