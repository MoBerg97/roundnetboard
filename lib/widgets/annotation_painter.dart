import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/annotation.dart';
import '../models/settings.dart';

/// Widget to render frame annotations (lines, circles, etc.)
class AnnotationPainter extends StatelessWidget {
  final List<Annotation> annotations;
  final List<Annotation>? tempAnnotations;
  final List<Annotation>? erasingAnnotations; // Annotations being erased (for preview)
  final Settings settings;
  final Size screenSize;
  final List<Offset>? dragPreviewLine; // Live preview line during drag [start, end]

  const AnnotationPainter({
    super.key,
    required this.annotations,
    this.tempAnnotations,
    this.erasingAnnotations,
    this.dragPreviewLine,
    required this.settings,
    required this.screenSize,
  });

  /// Calculate board center offset (must match _BoardScreenState._boardCenter)
  Offset _boardCenter() {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 140; // Match timeline height in board_screen.dart
    final usableHeight = screenSize.height - appBarHeight - timelineHeight;
    final cx = screenSize.width / 2;
    final cy = appBarHeight + usableHeight / 2;
    return Offset(cx, cy);
  }

  /// Paint annotations with a dedicated custom painter
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AnnotationCustomPainter(
        annotations: annotations,
        tempAnnotations: tempAnnotations,
        erasingAnnotations: erasingAnnotations,
        dragPreviewLine: dragPreviewLine,
        settings: settings,
        screenSize: screenSize,
        boardCenter: _boardCenter(),
      ),
      child: Container(),
    );
  }
}

class _AnnotationCustomPainter extends CustomPainter {
  final List<Annotation> annotations;
  final List<Annotation>? tempAnnotations;
  final List<Annotation>? erasingAnnotations;
  final List<Offset>? dragPreviewLine;
  final Settings settings;
  final Size screenSize;
  final Offset boardCenter;

  _AnnotationCustomPainter({
    required this.annotations,
    this.tempAnnotations,
    this.erasingAnnotations,
    this.dragPreviewLine,
    required this.settings,
    required this.screenSize,
    required this.boardCenter,
  });

  /// Convert cm logical coordinates to screen pixels
  Offset _cmToScreen(Offset cmPos) {
    return boardCenter + Offset(settings.cmToLogical(cmPos.dx, screenSize), settings.cmToLogical(cmPos.dy, screenSize));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      switch (annotation.type) {
        case AnnotationType.line:
          _paintLine(canvas, annotation);
        case AnnotationType.circle:
          _paintCircle(canvas, annotation);
        case AnnotationType.rectangle:
          _paintRectangle(canvas, annotation);
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
    final paint = Paint()
      ..color = annotation.color.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, paint);
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
    final paint = Paint()
      ..color = annotation.color.withValues(alpha: 0.35)
      ..strokeWidth = 2.0
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
    final fade = Paint()
      ..color = annotation.color.withValues(alpha: 0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, fade);
    // draw X across rectangle
    final strike = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
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
    final paint = Paint()
      ..color = annotation.color.withValues(alpha: 0.45)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(startScreen, endScreen, paint);
  }

  void _paintDragPreviewLine(Canvas canvas, Offset startCm, Offset endCm) {
    final startScreen = _cmToScreen(startCm);
    final endScreen = _cmToScreen(endCm);
    final paint = Paint()
      ..color =
          const Color.fromARGB(200, 255, 200, 100) // Semi-transparent orange preview
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(startScreen, endScreen, paint);

    // Draw endpoint markers
    final endpointPaint = Paint()
      ..color = const Color.fromARGB(220, 255, 200, 100)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startScreen, 5, endpointPaint);
    canvas.drawCircle(endScreen, 5, endpointPaint);
  }

  void _paintTempCircle(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final center = annotation.points[0];
    final radiusPoint = annotation.points[1];
    final radius = (radiusPoint - center).distance;
    final centerScreen = _cmToScreen(center);
    final scalePerCm = settings.cmToLogical(1.0, screenSize);
    final radiusScreen = radius * scalePerCm;
    final paint = Paint()
      ..color = annotation.color.withValues(alpha: 0.35)
      ..strokeWidth = 2.0
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
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(startScreen, endScreen, paint);

    // Draw endpoints as small circles for clarity
    final endpointPaint = Paint()
      ..color = annotation.color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(startScreen, 4, endpointPaint);
    canvas.drawCircle(endScreen, 4, endpointPaint);
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

    final paint = Paint()
      ..color = annotation.color.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(centerScreen, radiusScreen, paint);

    // Draw center point
    final centerPaint = Paint()
      ..color = annotation.color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(centerScreen, 4, centerPaint);
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
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(startScreen, endScreen, fadePaint);

    // Draw strikethrough (perpendicular lines across the erasing line)
    final center = (startScreen + endScreen) / 2;
    final direction = (endScreen - startScreen).direction;
    final perpendicular = Offset(-math.sin(direction), math.cos(direction));
    const strokeLength = 15.0;

    final strikePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center - perpendicular * strokeLength, center + perpendicular * strokeLength, strikePaint);

    // Draw faded endpoints
    final endpointPaint = Paint()
      ..color = annotation.color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startScreen, 4, endpointPaint);
    canvas.drawCircle(endScreen, 4, endpointPaint);
  }

  void _paintErasingCircle(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;

    final center = annotation.points[0];
    final radiusPoint = annotation.points[1];
    final radius = (radiusPoint - center).distance;
    final centerScreen = _cmToScreen(center);
    final scalePerCm = settings.cmToLogical(1.0, screenSize);
    final radiusScreen = radius * scalePerCm;

    // Draw faded circle
    final fadePaint = Paint()
      ..color = annotation.color.withValues(alpha: 0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(centerScreen, radiusScreen, fadePaint);

    // Draw X through center as strikethrough
    final xRadius = radiusScreen * 0.3;
    final xPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(centerScreen - Offset(xRadius, xRadius), centerScreen + Offset(xRadius, xRadius), xPaint);
    canvas.drawLine(centerScreen - Offset(xRadius, -xRadius), centerScreen + Offset(xRadius, -xRadius), xPaint);

    // Draw faded center point
    final centerPaint = Paint()
      ..color = annotation.color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerScreen, 4, centerPaint);
  }

  @override
  bool shouldRepaint(_AnnotationCustomPainter oldDelegate) =>
      annotations != oldDelegate.annotations ||
      tempAnnotations != oldDelegate.tempAnnotations ||
      erasingAnnotations != oldDelegate.erasingAnnotations ||
      dragPreviewLine != oldDelegate.dragPreviewLine ||
      boardCenter != oldDelegate.boardCenter;
}
