import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../models/annotation.dart';
import '../models/settings.dart';

/// Widget to render frame annotations (lines, circles, etc.)
class AnnotationPainter extends StatelessWidget {
  final List<Annotation> annotations;
  final List<Annotation>? tempAnnotations;
  final bool tempAnnotationsShadow;
  final List<Annotation>? erasingAnnotations; // Annotations being erased (for preview)
  final Annotation? selectedAnnotation; // Selected annotation for highlighting
  final Settings settings;
  final Size screenSize;
  final List<Offset>? dragPreviewLine; // Live preview line during drag [start, end]
  final AnnotationLineStyle dragPreviewLineStyle;
  final double strokeWidthCm;

  const AnnotationPainter({
    super.key,
    required this.annotations,
    this.tempAnnotations,
    this.tempAnnotationsShadow = false,
    this.erasingAnnotations,
    this.selectedAnnotation,
    this.dragPreviewLine,
    this.dragPreviewLineStyle = AnnotationLineStyle.straight,
    required this.settings,
    required this.screenSize,
    required this.strokeWidthCm,
  });

  /// Calculate board center offset (must match _BoardScreenState._boardCenter)
  Offset _boardCenter() {
    final cx = screenSize.width / 2;
    final cy = screenSize.height / 2;
    return Offset(cx, cy);
  }

  /// Paint annotations with a dedicated custom painter
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AnnotationCanvasPainter(
        annotations: annotations,
        tempAnnotations: tempAnnotations,
        tempAnnotationsShadow: tempAnnotationsShadow,
        erasingAnnotations: erasingAnnotations,
        selectedAnnotation: selectedAnnotation,
        dragPreviewLine: dragPreviewLine,
        dragPreviewLineStyle: dragPreviewLineStyle,
        settings: settings,
        screenSize: screenSize,
        boardCenter: _boardCenter(),
        strokeWidthCm: strokeWidthCm,
      ),
      child: Container(),
    );
  }
}

class AnnotationCanvasPainter extends CustomPainter {
  final List<Annotation> annotations;
  final List<Annotation>? tempAnnotations;
  final bool tempAnnotationsShadow;
  final List<Annotation>? erasingAnnotations;
  final Annotation? selectedAnnotation;
  final List<Offset>? dragPreviewLine;
  final AnnotationLineStyle dragPreviewLineStyle;
  final Settings settings;
  final Size screenSize;
  final Offset boardCenter;
  final double strokeWidthCm;

  AnnotationCanvasPainter({
    required this.annotations,
    this.tempAnnotations,
    this.tempAnnotationsShadow = false,
    this.erasingAnnotations,
    this.selectedAnnotation,
    this.dragPreviewLine,
    this.dragPreviewLineStyle = AnnotationLineStyle.straight,
    required this.settings,
    required this.screenSize,
    required this.boardCenter,
    required this.strokeWidthCm,
  });

  /// Convert cm logical coordinates to screen pixels
  Offset _cmToScreen(Offset cmPos) {
    return boardCenter + Offset(settings.cmToLogical(cmPos.dx, screenSize), settings.cmToLogical(cmPos.dy, screenSize));
  }

  double _strokeWidthPx([double multiplier = 1.0]) =>
      (settings.cmToLogical(strokeWidthCm, screenSize) * multiplier).clamp(1.0, 20.0);

  double _strokeWidthPxFor(double cm, [double multiplier = 1.0]) =>
      (settings.cmToLogical(cm, screenSize) * multiplier).clamp(1.0, 20.0);

  bool get _shouldDrawTempShadow => tempAnnotationsShadow;

  void _drawTempShadow(Canvas canvas, VoidCallback draw) {
    if (!_shouldDrawTempShadow) return;
    canvas.save();
    canvas.translate(0, 1.5);
    draw();
    canvas.restore();
  }

  double _tempAlpha(double normal, double emphasized) {
    return _shouldDrawTempShadow ? emphasized : normal;
  }

  bool _annotationListsDiffer(List<Annotation> a, List<Annotation> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.type != y.type || x.colorValue != y.colorValue || x.filled != y.filled) return true;
      if (x.lineStyleIndex != y.lineStyleIndex) return true;
      if (x.sectorAttachmentType != y.sectorAttachmentType || x.sectorAttachmentId != y.sectorAttachmentId) {
        return true;
      }
      if (x.strokeWidthCm != y.strokeWidthCm) return true;
      if (x.startAngle != y.startAngle || x.endAngle != y.endAngle) return true;
      if ((x.fontSize ?? 0) != (y.fontSize ?? 0)) return true;
      if ((x.text ?? '') != (y.text ?? '')) return true;
      if (x.points.length != y.points.length) return true;
      for (var j = 0; j < x.points.length; j++) {
        if (x.points[j] != y.points[j]) return true;
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      // Draw highlight if this is the selected annotation
      final isSelected = selectedAnnotation != null && identical(annotation, selectedAnnotation);
      if (isSelected) {
        _paintAnnotationHighlight(canvas, annotation);
      }
      
      switch (annotation.type) {
        case AnnotationType.line:
          _paintLine(canvas, annotation);
        case AnnotationType.circle:
          _paintCircle(canvas, annotation);
        case AnnotationType.rectangle:
          _paintRectangle(canvas, annotation);
        case AnnotationType.sector:
          _paintSector(canvas, annotation);
        case AnnotationType.text:
          _paintText(canvas, annotation);
      }
    }
    // draw temporary/staged annotations (if any) with lighter style
    if (tempAnnotations != null) {
      for (final annotation in tempAnnotations!) {
        switch (annotation.type) {
          case AnnotationType.line:
            _paintTempLine(canvas, annotation);
          case AnnotationType.circle:
            _paintTempCircle(canvas, annotation);
          case AnnotationType.rectangle:
            _paintTempRectangle(canvas, annotation);
          case AnnotationType.sector:
            _paintTempSector(canvas, annotation);
          case AnnotationType.text:
            _paintTempText(canvas, annotation);
        }
      }
    }
    // Draw erasing annotations with faded + strikethrough effect
    if (erasingAnnotations != null) {
      for (final annotation in erasingAnnotations!) {
        switch (annotation.type) {
          case AnnotationType.line:
            _paintErasingLine(canvas, annotation);
          case AnnotationType.circle:
            _paintErasingCircle(canvas, annotation);
          case AnnotationType.rectangle:
            _paintErasingRectangle(canvas, annotation);
          case AnnotationType.sector:
            _paintErasingSector(canvas, annotation);
          case AnnotationType.text:
            _paintErasingText(canvas, annotation);
        }
      }
    }
    // Draw live preview line during drag
    if (dragPreviewLine != null && dragPreviewLine!.length >= 2) {
      _paintDragPreviewLine(canvas, dragPreviewLine![0], dragPreviewLine![1]);
    }
  }

  void _paintRectangle(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final a = annotation.points[0];
    final b = annotation.points[1];
    final topLeft = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
    final bottomRight = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
    final tl = _cmToScreen(topLeft);
    final br = _cmToScreen(bottomRight);
    final rect = Rect.fromPoints(tl, br);
    if (annotation.filled) {
      final fill = Paint()
        ..color = annotation.color.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fill);
    }
    final outline = Paint()
      ..color = annotation.color.withValues(alpha: 0.9)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.2)
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, outline);
  }

  void _paintTempRectangle(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final a = annotation.points[0];
    final b = annotation.points[1];
    final topLeft = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
    final bottomRight = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
    final tl = _cmToScreen(topLeft);
    final br = _cmToScreen(bottomRight);
    final rect = Rect.fromPoints(tl, br);
    _drawTempShadow(canvas, () {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
        ..style = annotation.filled ? PaintingStyle.fill : PaintingStyle.stroke;
      canvas.drawRect(rect, shadowPaint);
    });
    if (annotation.filled) {
      final fill = Paint()
        ..color = annotation.color.withValues(alpha: _tempAlpha(0.28, 0.5))
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fill);
    }
    final paint = Paint()
      ..color = annotation.color.withValues(alpha: _tempAlpha(0.56, 0.78))
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, paint);
  }

  void _paintErasingRectangle(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final a = annotation.points[0];
    final b = annotation.points[1];
    final topLeft = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
    final bottomRight = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
    final tl = _cmToScreen(topLeft);
    final br = _cmToScreen(bottomRight);
    final rect = Rect.fromPoints(tl, br);
    if (annotation.filled) {
      final fill = Paint()
        ..color = annotation.color.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fill);
    }
    final fade = Paint()
      ..color = annotation.color.withValues(alpha: 0.2)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, fade);
    // draw X across rectangle
    final strike = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..style = PaintingStyle.stroke;
    canvas.drawLine(tl, br, strike);
    canvas.drawLine(Offset(br.dx, tl.dy), Offset(tl.dx, br.dy), strike);
  }

  void _paintTempLine(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final start = annotation.points[0];
    final end = annotation.points[1];
    final startScreen = _cmToScreen(start);
    final endScreen = _cmToScreen(end);
    _drawTempShadow(canvas, () {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.26)
        ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _paintStyledLine(canvas, startScreen, endScreen, shadowPaint, annotation.lineStyle);
    });
    final paint = Paint()
      ..color = annotation.color.withValues(alpha: _tempAlpha(0.6, 0.82))
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _paintStyledLine(canvas, startScreen, endScreen, paint, annotation.lineStyle);
  }

  void _paintDragPreviewLine(Canvas canvas, Offset startCm, Offset endCm) {
    final startScreen = _cmToScreen(startCm);
    final endScreen = _cmToScreen(endCm);
    final paint = Paint()
      ..color =
          const Color.fromARGB(200, 255, 200, 100) // Semi-transparent orange preview
      ..strokeWidth = _strokeWidthPx(1.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _paintStyledLine(canvas, startScreen, endScreen, paint, dragPreviewLineStyle);

    // Draw endpoint markers
    final endpointPaint = Paint()
      ..color = const Color.fromARGB(220, 255, 200, 100)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startScreen, 5, endpointPaint);
    canvas.drawCircle(endScreen, 5, endpointPaint);
  }

  /// Draw highlight for selected annotation (cyan glow)
  void _paintAnnotationHighlight(Canvas canvas, Annotation annotation) {
    final highlightPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.4)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 2.5)
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    switch (annotation.type) {
      case AnnotationType.line:
        if (annotation.points.length >= 2) {
          final start = _cmToScreen(annotation.points[0]);
          final end = _cmToScreen(annotation.points[1]);
          _paintStyledLine(canvas, start, end, highlightPaint, annotation.lineStyle);
        }
      case AnnotationType.circle:
        if (annotation.points.length >= 2) {
          final center = _cmToScreen(annotation.points[0]);
          final radiusPoint = annotation.points[1];
          final radius = (radiusPoint - annotation.points[0]).distance;
          final scalePerCm = settings.cmToLogical(1.0, screenSize);
          final radiusScreen = radius * scalePerCm;
          canvas.drawCircle(center, radiusScreen, highlightPaint);
        }
      case AnnotationType.rectangle:
        if (annotation.points.length >= 2) {
          final a = annotation.points[0];
          final b = annotation.points[1];
          final topLeft = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
          final bottomRight = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
          final tl = _cmToScreen(topLeft);
          final br = _cmToScreen(bottomRight);
          final rect = Rect.fromPoints(tl, br);
          canvas.drawRect(rect, highlightPaint);
        }
      case AnnotationType.sector:
        if (annotation.points.length >= 2 && annotation.startAngle != null && annotation.endAngle != null) {
          final center = _cmToScreen(annotation.points[0]);
          final radiusPoint = annotation.points[1];
          final radius = (radiusPoint - annotation.points[0]).distance;
          final scalePerCm = settings.cmToLogical(1.0, screenSize);
          final radiusScreen = radius * scalePerCm;
          final rect = Rect.fromCircle(center: center, radius: radiusScreen);
          canvas.drawArc(rect, annotation.startAngle!, annotation.endAngle! - annotation.startAngle!, false, highlightPaint);
        }
      case AnnotationType.text:
        if (annotation.points.isNotEmpty) {
          final center = _cmToScreen(annotation.points.first);
          final painter = _textPainterFor(annotation);
          final rect = Rect.fromCenter(center: center, width: painter.width + 16, height: painter.height + 8);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), highlightPaint);
        }
    }
  }

  void _paintTempCircle(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final center = annotation.points[0];
    final radiusPoint = annotation.points[1];
    final radius = (radiusPoint - center).distance;
    final centerScreen = _cmToScreen(center);
    final scalePerCm = settings.cmToLogical(1.0, screenSize);
    final radiusScreen = radius * scalePerCm;
    _drawTempShadow(canvas, () {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
        ..style = annotation.filled ? PaintingStyle.fill : PaintingStyle.stroke;
      canvas.drawCircle(centerScreen, radiusScreen, shadowPaint);
    });
    if (annotation.filled) {
      final fill = Paint()
        ..color = annotation.color.withValues(alpha: _tempAlpha(0.28, 0.5))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(centerScreen, radiusScreen, fill);
    }
    final paint = Paint()
      ..color = annotation.color.withValues(alpha: _tempAlpha(0.56, 0.78))
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(centerScreen, radiusScreen, paint);
  }

  void _paintLine(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;

    final start = annotation.points[0];
    final end = annotation.points[1];

    // Convert logical coordinates to screen coordinates
    final startScreen = _cmToScreen(start);
    final endScreen = _cmToScreen(end);

    final paint = Paint()
      ..color = annotation.color.withValues(alpha: 0.8)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _paintStyledLine(canvas, startScreen, endScreen, paint, annotation.lineStyle);
    // Endpoints are no longer drawn as circles for cleaner annotation lines
  }

  void _paintCircle(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;

    final center = annotation.points[0];
    final radiusPoint = annotation.points[1];
    final radius = (radiusPoint - center).distance;

    // Convert logical coordinates to screen coordinates
    final centerScreen = _cmToScreen(center);

    // Convert radius (in cm) to screen pixels
    // Calculate scale factor by converting 1.0 cm
    final scalePerCm = settings.cmToLogical(1.0, screenSize);
    final radiusScreen = radius * scalePerCm;
    if (annotation.filled) {
      final fill = Paint()
        ..color = annotation.color.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(centerScreen, radiusScreen, fill);
    }
    final outline = Paint()
      ..color = annotation.color.withValues(alpha: 0.9)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.2)
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(centerScreen, radiusScreen, outline);
  }

  static const double _defaultTextSize = 20.0;
  static const String _textFontFamily = 'Roboto';

  TextPainter _textPainterFor(Annotation annotation, {double alpha = 0.9}) {
    return TextPainter(
      text: TextSpan(
        text: annotation.text ?? '',
        style: TextStyle(
          color: annotation.color.withValues(alpha: alpha),
          fontSize: annotation.fontSize ?? _defaultTextSize,
          fontFamily: _textFontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _paintText(Canvas canvas, Annotation annotation) {
    if (annotation.points.isEmpty) return;
    final text = annotation.text ?? '';
    if (text.isEmpty) return;
    final center = _cmToScreen(annotation.points.first);
    final painter = _textPainterFor(annotation, alpha: 0.95);
    final topLeft = center - Offset(painter.width / 2, painter.height / 2);
    painter.paint(canvas, topLeft);
  }

  void _paintTempText(Canvas canvas, Annotation annotation) {
    if (annotation.points.isEmpty) return;
    final text = annotation.text ?? '';
    if (text.isEmpty) return;
    final center = _cmToScreen(annotation.points.first);
    _drawTempShadow(canvas, () {
      final shadowPainter = _textPainterFor(annotation, alpha: 0.35)
        ..text = TextSpan(
          text: annotation.text ?? '',
          style: TextStyle(
            color: Colors.black.withValues(alpha: _tempAlpha(0.35, 0.42)),
            fontSize: annotation.fontSize ?? _defaultTextSize,
            fontFamily: _textFontFamily,
            fontWeight: FontWeight.w600,
          ),
        )
        ..layout();
      final shadowTopLeft = center - Offset(shadowPainter.width / 2, shadowPainter.height / 2);
      shadowPainter.paint(canvas, shadowTopLeft);
    });
    final painter = _textPainterFor(annotation, alpha: _tempAlpha(0.66, 0.86));
    final topLeft = center - Offset(painter.width / 2, painter.height / 2);
    painter.paint(canvas, topLeft);
  }

  void _paintErasingText(Canvas canvas, Annotation annotation) {
    if (annotation.points.isEmpty) return;
    final text = annotation.text ?? '';
    if (text.isEmpty) return;
    final center = _cmToScreen(annotation.points.first);
    final painter = _textPainterFor(annotation, alpha: 0.25);
    final topLeft = center - Offset(painter.width / 2, painter.height / 2);
    painter.paint(canvas, topLeft);

    final strikePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, painter.width, painter.height);
    canvas.drawLine(rect.topLeft, rect.bottomRight, strikePaint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, strikePaint);
  }

  // Rendering for annotations being erased (faded + strikethrough effect)
  void _paintErasingLine(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;

    final start = annotation.points[0];
    final end = annotation.points[1];
    final startScreen = _cmToScreen(start);
    final endScreen = _cmToScreen(end);

    // Draw faded line
    final fadePaint = Paint()
      ..color = annotation.color.withValues(alpha: 0.2)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _paintStyledLine(canvas, startScreen, endScreen, fadePaint, annotation.lineStyle);

    // Draw strikethrough (perpendicular lines across the erasing line)
    final center = (startScreen + endScreen) / 2;
    final direction = (endScreen - startScreen).direction;
    final perpendicular = Offset(-math.sin(direction), math.cos(direction));
    const strokeLength = 15.0;

    final strikePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center - perpendicular * strokeLength, center + perpendicular * strokeLength, strikePaint);
    // Endpoints no longer drawn for erasing lines
  }

  void _paintStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    AnnotationLineStyle style,
  ) {
    switch (style) {
      case AnnotationLineStyle.straight:
        canvas.drawLine(start, end, paint);
        break;
      case AnnotationLineStyle.arrow:
        canvas.drawLine(start, end, paint);
        _drawArrowHead(canvas, start, end, paint);
        break;
      case AnnotationLineStyle.dashed:
        _drawDashedLine(canvas, start, end, paint);
        break;
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final length = delta.distance;
    if (length <= 0.0001) return;

    final dir = delta / length;
    final dashLength = math.max(6.0, paint.strokeWidth * 2.8);
    final gapLength = math.max(4.0, paint.strokeWidth * 1.6);

    double traveled = 0;
    while (traveled < length) {
      final dashStart = start + (dir * traveled);
      final dashEnd = start + (dir * math.min(traveled + dashLength, length));
      canvas.drawLine(dashStart, dashEnd, paint);
      traveled += dashLength + gapLength;
    }
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final length = delta.distance;
    if (length <= 0.0001) return;

    final angle = math.atan2(delta.dy, delta.dx);
    final headLength = math.max(8.0, paint.strokeWidth * 3.2);
    const spread = math.pi / 6;

    final left = end - Offset(math.cos(angle - spread), math.sin(angle - spread)) * headLength;
    final right = end - Offset(math.cos(angle + spread), math.sin(angle + spread)) * headLength;
    canvas.drawLine(end, left, paint);
    canvas.drawLine(end, right, paint);
  }

  void _paintErasingCircle(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;

    final center = annotation.points[0];
    final radiusPoint = annotation.points[1];
    final radius = (radiusPoint - center).distance;
    final centerScreen = _cmToScreen(center);
    final scalePerCm = settings.cmToLogical(1.0, screenSize);
    final radiusScreen = radius * scalePerCm;

    if (annotation.filled) {
      final fill = Paint()
        ..color = annotation.color.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(centerScreen, radiusScreen, fill);
    }

    // Draw faded circle
    final fadePaint = Paint()
      ..color = annotation.color.withValues(alpha: 0.2)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(centerScreen, radiusScreen, fadePaint);

    // Draw X through center as strikethrough
    final xRadius = radiusScreen * 0.3;
    final xPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(centerScreen - Offset(xRadius, xRadius), centerScreen + Offset(xRadius, xRadius), xPaint);
    canvas.drawLine(centerScreen - Offset(xRadius, -xRadius), centerScreen + Offset(xRadius, -xRadius), xPaint);

    // Center marker removed for cleaner circles
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CIRCLE SECTOR PAINTING METHODS
  // ════════════════════════════════════════════════════════════════════════════

  void _paintSector(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    if (annotation.startAngle == null || annotation.endAngle == null) return;

    final center = annotation.points[0];
    final radiusPoint = annotation.points[1];
    final radius = (radiusPoint - center).distance;

    final centerScreen = _cmToScreen(center);
    final scalePerCm = settings.cmToLogical(1.0, screenSize);
    final radiusScreen = radius * scalePerCm;

    // Sector is always filled (per requirement)
    final fill = Paint()
      ..color = annotation.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: centerScreen, radius: radiusScreen);
    canvas.drawArc(rect, annotation.startAngle!, annotation.endAngle! - annotation.startAngle!, true, fill);
  }

  void _paintTempSector(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    if (annotation.startAngle == null || annotation.endAngle == null) return;

    final center = annotation.points[0];
    final radiusPoint = annotation.points[1];
    final radius = (radiusPoint - center).distance;

    final centerScreen = _cmToScreen(center);
    final scalePerCm = settings.cmToLogical(1.0, screenSize);
    final radiusScreen = radius * scalePerCm;

    _drawTempShadow(canvas, () {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..style = PaintingStyle.fill;
      final shadowRect = Rect.fromCircle(center: centerScreen, radius: radiusScreen);
      canvas.drawArc(
        shadowRect,
        annotation.startAngle!,
        annotation.endAngle! - annotation.startAngle!,
        true,
        shadowPaint,
      );
    });

    // Temporary sector with lighter opacity
    final fill = Paint()
      ..color = annotation.color.withValues(alpha: _tempAlpha(0.3, 0.56))
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: centerScreen, radius: radiusScreen);
    canvas.drawArc(rect, annotation.startAngle!, annotation.endAngle! - annotation.startAngle!, true, fill);
  }

  void _paintErasingSector(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    if (annotation.startAngle == null || annotation.endAngle == null) return;

    final center = annotation.points[0];
    final radiusPoint = annotation.points[1];
    final radius = (radiusPoint - center).distance;

    final centerScreen = _cmToScreen(center);
    final scalePerCm = settings.cmToLogical(1.0, screenSize);
    final radiusScreen = radius * scalePerCm;

    // Faded sector
    final fadePaint = Paint()
      ..color = annotation.color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: centerScreen, radius: radiusScreen);
    canvas.drawArc(rect, annotation.startAngle!, annotation.endAngle! - annotation.startAngle!, true, fadePaint);

    // Draw X through center as strikethrough
    final xRadius = radiusScreen * 0.3;
    final xPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(centerScreen - Offset(xRadius, xRadius), centerScreen + Offset(xRadius, xRadius), xPaint);
    canvas.drawLine(centerScreen - Offset(xRadius, -xRadius), centerScreen + Offset(xRadius, -xRadius), xPaint);
  }

  @override
  bool shouldRepaint(covariant AnnotationCanvasPainter oldDelegate) =>
      _annotationListsDiffer(annotations, oldDelegate.annotations) ||
      (tempAnnotations != null && oldDelegate.tempAnnotations != null
          ? _annotationListsDiffer(tempAnnotations!, oldDelegate.tempAnnotations!)
          : tempAnnotations != oldDelegate.tempAnnotations) ||
      (erasingAnnotations != null && oldDelegate.erasingAnnotations != null
          ? _annotationListsDiffer(erasingAnnotations!, oldDelegate.erasingAnnotations!)
          : erasingAnnotations != oldDelegate.erasingAnnotations) ||
      !listEquals(dragPreviewLine, oldDelegate.dragPreviewLine) ||
      dragPreviewLineStyle != oldDelegate.dragPreviewLineStyle ||
      selectedAnnotation != oldDelegate.selectedAnnotation ||
        tempAnnotationsShadow != oldDelegate.tempAnnotationsShadow ||
      boardCenter != oldDelegate.boardCenter ||
      strokeWidthCm != oldDelegate.strokeWidthCm;
}
