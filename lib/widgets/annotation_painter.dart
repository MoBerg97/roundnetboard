import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final bool handDrawnStyle;
  final bool showCurvedControlHandles;

  const AnnotationPainter({
    super.key,
    required this.annotations,
    this.tempAnnotations,
    this.tempAnnotationsShadow = false,
    this.erasingAnnotations,
    this.selectedAnnotation,
    this.dragPreviewLine,
    this.dragPreviewLineStyle = AnnotationLineStyle.straight,
    this.handDrawnStyle = false,
    this.showCurvedControlHandles = false,
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
        handDrawnStyle: handDrawnStyle,
        showCurvedControlHandles: showCurvedControlHandles,
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
  final bool handDrawnStyle;
  final bool showCurvedControlHandles;
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
    this.handDrawnStyle = false,
    this.showCurvedControlHandles = false,
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

  Color _alphaScaled(Color color, double factor) {
    return color.withValues(alpha: (color.a * factor).clamp(0.0, 1.0));
  }

  bool get _useHandDrawnStyle => handDrawnStyle;

  int _annotationSeed(Annotation annotation) {
    var seed = annotation.id?.hashCode ?? annotation.type.index * 997;
    for (final point in annotation.points) {
      seed = 31 * seed + point.dx.toStringAsFixed(3).hashCode;
      seed = 31 * seed + point.dy.toStringAsFixed(3).hashCode;
    }
    return seed.abs();
  }

  double _seedUnit(int seed, int step) {
    final value = math.sin((seed + (step * 37)).toDouble() * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  List<Offset> _curvedLineScreenPoints(Annotation annotation) {
    if (annotation.points.length < 2) return const <Offset>[];
    return annotation.points.map(_cmToScreen).toList(growable: false);
  }

  List<Offset> _buildSquiggleLinePoints(Offset start, Offset end, int seed, double strokeWidth) {
    final delta = end - start;
    final length = delta.distance;
    if (length <= 0.001) return [start, end];

    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);

    final curveSegments = length < 55
        ? 1
        : length < 170
        ? 2
        : length < 330
        ? 3
        : 4;

    final baseAmplitude = math.min(1.3, math.max(0.22, strokeWidth * 0.2));
    final points = <Offset>[start];

    for (var segment = 0; segment < curveSegments; segment++) {
      final t0 = segment / curveSegments;
      final t1 = (segment + 1) / curveSegments;
      final p0 = start + direction * (length * t0);
      final p2 = start + direction * (length * t1);
      final mid = start + direction * (length * ((t0 + t1) / 2));

      final sign = ((segment + (seed % 2)) % 2 == 0) ? 1.0 : -1.0;
      final variation = 0.8 + _seedUnit(seed, 40 + segment) * 0.4;
      final control = mid + normal * (baseAmplitude * variation * sign);

      const samplesPerCurve = 8;
      for (var sample = 1; sample <= samplesPerCurve; sample++) {
        final t = sample / samplesPerCurve;
        final mt = 1.0 - t;
        points.add(
          Offset(
            mt * mt * p0.dx + 2 * mt * t * control.dx + t * t * p2.dx,
            mt * mt * p0.dy + 2 * mt * t * control.dy + t * t * p2.dy,
          ),
        );
      }
    }

    return points;
  }

  List<Offset> _buildGentlePolyline(List<Offset> points, int seed, double strokeWidth) {
    if (points.length < 2) return points;
    if (points.length == 2) {
      return _buildSquiggleLinePoints(points[0], points[1], seed + 23, math.max(strokeWidth, 1.0));
    }

    double totalLength = 0;
    for (var i = 0; i < points.length - 1; i++) {
      totalLength += (points[i + 1] - points[i]).distance;
    }
    if (totalLength <= 0.001) return points;

    final curveSegments = totalLength < 55
        ? 1
        : totalLength < 170
        ? 2
        : totalLength < 330
        ? 3
        : 4;
    final sampleCount = math.max(14, curveSegments * 10);
    final amplitude = math.min(1.55, math.max(0.26, strokeWidth * 0.24));
    final phase = _seedUnit(seed, 7) * math.pi * 2;

    final result = <Offset>[];
    for (var i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount;
      final base = _pointAlongPolyline(points, t);
      final before = _pointAlongPolyline(points, (t - 0.015).clamp(0.0, 1.0));
      final after = _pointAlongPolyline(points, (t + 0.015).clamp(0.0, 1.0));
      final tangent = after - before;
      final tangentLength = tangent.distance;
      final direction = tangentLength > 0.001 ? tangent / tangentLength : const Offset(1, 0);
      final normal = Offset(-direction.dy, direction.dx);
      final envelope = math.sin(math.pi * t);
      final wiggle = math.sin((t * math.pi * 2 * curveSegments) + phase);
      final noise = (_seedUnit(seed, 300 + i) - 0.5) * 0.08;
      result.add(base + normal * ((wiggle + noise) * amplitude * envelope));
    }
    return result;
  }

  Path _pathFromPoints(List<Offset> points) {
    if (points.isEmpty) return Path();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  Offset _pointAlongPolyline(List<Offset> points, double t) {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1) return points.first;
    final target = t.clamp(0.0, 1.0);

    double totalLength = 0;
    for (var i = 0; i < points.length - 1; i++) {
      totalLength += (points[i + 1] - points[i]).distance;
    }
    if (totalLength <= 0.001) return points.last;

    final targetDistance = totalLength * target;
    double traveled = 0;
    for (var i = 0; i < points.length - 1; i++) {
      final segmentLength = (points[i + 1] - points[i]).distance;
      if (traveled + segmentLength >= targetDistance) {
        final local = (targetDistance - traveled) / math.max(0.001, segmentLength);
        return Offset.lerp(points[i], points[i + 1], local)!;
      }
      traveled += segmentLength;
    }
    return points.last;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final dashLength = math.max(6.0, paint.strokeWidth * 2.8);
    final gapLength = math.max(4.0, paint.strokeWidth * 1.6);

    for (final metric in path.computeMetrics()) {
      double traveled = 0;
      while (traveled < metric.length) {
        final next = math.min(traveled + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(traveled, next), paint);
        traveled += dashLength + gapLength;
      }
    }
  }

  void _paintStyledPolyline(Canvas canvas, List<Offset> points, Paint paint, AnnotationLineStyle style) {
    if (points.length < 2) return;
    final path = _pathFromPoints(points);
    switch (style) {
      case AnnotationLineStyle.straight:
        canvas.drawPath(path, paint);
        break;
      case AnnotationLineStyle.arrow:
        canvas.drawPath(path, paint);
        _drawArrowHead(canvas, points[points.length - 2], points.last, paint);
        break;
      case AnnotationLineStyle.arrowStart:
        canvas.drawPath(path, paint);
        _drawArrowHead(canvas, points[1], points.first, paint);
        break;
      case AnnotationLineStyle.dashed:
        _drawDashedPath(canvas, path, paint);
        break;
      case AnnotationLineStyle.markerX:
      case AnnotationLineStyle.markerPylon:
      case AnnotationLineStyle.markerDot:
        _drawMarkerSymbol(canvas, points[points.length - 2], points.last, paint, style);
        break;
    }
  }

  void _paintStyledLineMaybeHandDrawn(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    AnnotationLineStyle style,
    int seed,
  ) {
    if (!_useHandDrawnStyle) {
      _paintStyledPolyline(canvas, [start, end], paint, style);
      return;
    }

    final mechanicPoints = _buildSquiggleLinePoints(start, end, seed + 19, paint.strokeWidth);
    _paintStyledPolylineMaybeHandDrawn(canvas, mechanicPoints, paint, style, seed + 103);
  }

  void _paintStyledPolylineMaybeHandDrawn(
    Canvas canvas,
    List<Offset> points,
    Paint paint,
    AnnotationLineStyle style,
    int seed,
  ) {
    if (points.length < 2) return;
    if (!_useHandDrawnStyle) {
      _paintStyledPolyline(canvas, points, paint, style);
      return;
    }

    final primaryPoints = _buildGentlePolyline(points, seed, paint.strokeWidth);
    _paintStyledPolyline(canvas, primaryPoints, paint, style);

    final secondaryPaint = Paint()
      ..color = paint.color.withValues(alpha: (paint.color.a * 0.44).clamp(0.0, 1.0))
      ..strokeWidth = math.max(1.0, paint.strokeWidth * 0.9)
      ..strokeCap = paint.strokeCap
      ..strokeJoin = paint.strokeJoin
      ..style = paint.style;
    final secondaryPoints = _buildGentlePolyline(points, seed + 7919, secondaryPaint.strokeWidth);
    _paintStyledPolyline(canvas, secondaryPoints, secondaryPaint, style);
  }

  List<Offset> _buildJitteredOutlineNodes(Path clipPath, int seed, double spacingPx) {
    final nodes = <Offset>[];
    final metrics = clipPath.computeMetrics().toList();
    var nodeIndex = 0;

    for (final metric in metrics) {
      if (metric.length <= 0.001) continue;
      final count = math.max(12, (metric.length / math.max(1.0, spacingPx)).round());
      for (var i = 0; i < count; i++) {
        final t = i / count;
        final tangent = metric.getTangentForOffset(metric.length * t);
        if (tangent == null) continue;

        final vector = tangent.vector;
        final vectorLength = vector.distance;
        final tangentDir = vectorLength > 0.001 ? vector / vectorLength : const Offset(1, 0);
        final normal = Offset(-tangentDir.dy, tangentDir.dx);

        final normalJitter = (_seedUnit(seed, 1200 + nodeIndex) - 0.5) * spacingPx * 0.46;
        final tangentJitter = (_seedUnit(seed, 2200 + nodeIndex) - 0.5) * spacingPx * 0.34;
        nodes.add(tangent.position + normal * normalJitter + tangentDir * tangentJitter);
        nodeIndex++;
      }
    }

    return nodes;
  }

  List<Offset> _sortedByAngleAround(List<Offset> points, Offset center) {
    final sorted = List<Offset>.from(points);
    sorted.sort((a, b) {
      final aa = math.atan2(a.dy - center.dy, a.dx - center.dx);
      final bb = math.atan2(b.dy - center.dy, b.dx - center.dx);
      return aa.compareTo(bb);
    });
    return sorted;
  }

  List<Offset> _dedupeOrderedNodes(List<Offset> points, double minDistance) {
    if (points.isEmpty) return const <Offset>[];
    final filtered = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      if ((points[i] - filtered.last).distance >= minDistance) {
        filtered.add(points[i]);
      }
    }
    return filtered;
  }

  double _normalizedAngle(Offset point, Offset center) {
    final angle = math.atan2(point.dy - center.dy, point.dx - center.dx);
    return angle < 0 ? angle + (math.pi * 2) : angle;
  }

  double _circularDistance(double a, double b) {
    final d = (a - b).abs();
    return math.min(d, (math.pi * 2) - d);
  }

  bool _isDenseCircleSegment(double angle) {
    const topRight = 7 * math.pi / 4; // 315°
    const bottomLeft = 3 * math.pi / 4; // 135°
    const band = math.pi / 4; // 45°
    return _circularDistance(angle, topRight) <= band || _circularDistance(angle, bottomLeft) <= band;
  }

  int _indexClosestToAngle(List<Offset> ordered, Offset center, double targetAngle) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < ordered.length; i++) {
      final nodeAngle = _normalizedAngle(ordered[i], center);
      final distance = _circularDistance(nodeAngle, targetAngle);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  int _circleStepForIndex(List<Offset> ordered, int index, int baseStep, Offset center) {
    final angle = _normalizedAngle(ordered[index], center);
    if (_isDenseCircleSegment(angle)) {
      return math.max(1, (baseStep * 0.3).round());
    }
    return baseStep;
  }

  void _drawIrregularHatchFill(
    Canvas canvas,
    Path clipPath,
    Color color,
    int seed, {
    double alpha = 0.24,
    double strokeWidth = 1.0,
    bool circularMode = false,
  }) {
    final bounds = clipPath.getBounds();
    if (bounds.isEmpty || bounds.width < 1 || bounds.height < 1) return;

    final hatchStrokeWidth = (strokeWidth * 1.5).clamp(0.9, 20.0);
    final nodeSpacing = (hatchStrokeWidth * 3.1).clamp(5.0, 16.0);
    final nodes = _buildJitteredOutlineNodes(clipPath, seed + 31, nodeSpacing);
    if (nodes.length < 8) {
      return;
    }

    canvas.save();
    final bleedPadding = math.max(hatchStrokeWidth * 1.4, nodeSpacing * 1.0);
    canvas.clipRect(bounds.inflate(bleedPadding));

    final paint = Paint()
      ..color = _alphaScaled(color, alpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = hatchStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (circularMode) {
      final ordered = _sortedByAngleAround(nodes, bounds.center);
      if (ordered.length >= 6) {
        final stride = math.max(1, (ordered.length / 96).round());
        const fixedStartAngle = 5 * math.pi / 4;
        final startIndex = _indexClosestToAngle(ordered, bounds.center, fixedStartAngle);
        final path = Path()..moveTo(ordered[startIndex].dx, ordered[startIndex].dy);

        var forwardIndex = startIndex;
        var backwardIndex = startIndex;
        final visited = List<bool>.filled(ordered.length, false);
        visited[startIndex] = true;
        var visitedCount = 1;
        var iter = 0;
        final maxIterations = ordered.length * 3;

        while (visitedCount < ordered.length && iter < maxIterations) {
          final stepForward = _circleStepForIndex(ordered, forwardIndex, stride, bounds.center);
          forwardIndex = (forwardIndex + stepForward) % ordered.length;
          path.lineTo(ordered[forwardIndex].dx, ordered[forwardIndex].dy);
          if (!visited[forwardIndex]) {
            visited[forwardIndex] = true;
            visitedCount++;
          }

          final stepBackward = _circleStepForIndex(ordered, backwardIndex, stride, bounds.center);
          backwardIndex = (backwardIndex - stepBackward + ordered.length * 4) % ordered.length;
          path.lineTo(ordered[backwardIndex].dx, ordered[backwardIndex].dy);
          if (!visited[backwardIndex]) {
            visited[backwardIndex] = true;
            visitedCount++;
          }

          iter++;
        }

        canvas.drawPath(path, paint);
      }

      canvas.restore();
      return;
    }

    final edgeTolerance = math.max(hatchStrokeWidth * 1.8, nodeSpacing * 0.9);

    List<Offset> left = nodes.where((point) => (point.dx - bounds.left).abs() <= edgeTolerance).toList();
    List<Offset> top = nodes.where((point) => (point.dy - bounds.top).abs() <= edgeTolerance).toList();
    List<Offset> bottom = nodes.where((point) => (point.dy - bounds.bottom).abs() <= edgeTolerance).toList();
    List<Offset> right = nodes.where((point) => (point.dx - bounds.right).abs() <= edgeTolerance).toList();

    if (left.length < 3 || top.length < 3 || bottom.length < 3 || right.length < 3) {
      final takeCount = math.max(6, nodes.length ~/ 8);

      final byX = List<Offset>.from(nodes)..sort((a, b) => a.dx.compareTo(b.dx));
      final byY = List<Offset>.from(nodes)..sort((a, b) => a.dy.compareTo(b.dy));

      left = byX.take(takeCount).toList();
      right = byX.reversed.take(takeCount).toList();
      top = byY.take(takeCount).toList();
      bottom = byY.reversed.take(takeCount).toList();
    }

    left.sort((a, b) => a.dy.compareTo(b.dy));
    top.sort((a, b) => a.dx.compareTo(b.dx));
    bottom.sort((a, b) => a.dx.compareTo(b.dx));
    right.sort((a, b) => a.dy.compareTo(b.dy));

    final minEdgeSpacing = math.max(1.0, nodeSpacing * 0.42);
    left = _dedupeOrderedNodes(left, minEdgeSpacing);
    top = _dedupeOrderedNodes(top, minEdgeSpacing);
    bottom = _dedupeOrderedNodes(bottom, minEdgeSpacing);
    right = _dedupeOrderedNodes(right, minEdgeSpacing);

    if (left.isEmpty || top.isEmpty || bottom.isEmpty || right.isEmpty) {
      canvas.restore();
      return;
    }

    final streamA = <Offset>[...left, ...bottom]; // left edge first, then lower edge
    final streamB = <Offset>[...top, ...right]; // upper edge first, then right edge
    final maxCount = math.max(streamA.length, streamB.length);

    if (maxCount > 0) {
      final path = Path()..moveTo(streamA.first.dx, streamA.first.dy);
      path.lineTo(streamB.first.dx, streamB.first.dy);

      for (var i = 1; i < maxCount; i++) {
        final a = i < streamA.length ? streamA[i] : streamA.last;
        final b = i < streamB.length ? streamB[i] : streamB.last;
        path.lineTo(a.dx, a.dy);
        path.lineTo(b.dx, b.dy);
      }

      canvas.drawPath(path, paint);
    }

    canvas.restore();
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
        case AnnotationType.curvedLine:
          _paintCurvedLine(canvas, annotation);
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
          case AnnotationType.curvedLine:
            _paintTempCurvedLine(canvas, annotation);
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
          case AnnotationType.curvedLine:
            _paintErasingCurvedLine(canvas, annotation);
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

    if (showCurvedControlHandles) {
      for (final annotation in annotations) {
        if (annotation.type == AnnotationType.curvedLine) {
          _paintCurvedControlHandle(canvas, annotation, isSelected: identical(annotation, selectedAnnotation));
        }
      }
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
    final seed = _annotationSeed(annotation);
    if (annotation.filled) {
      if (_useHandDrawnStyle) {
        _drawIrregularHatchFill(
          canvas,
          Path()..addRect(rect),
          annotation.color,
          seed,
          alpha: 0.24,
          strokeWidth: _strokeWidthPxFor(annotation.strokeWidthCm, 1.2),
        );
      } else {
        final fill = Paint()
          ..color = _alphaScaled(annotation.color, 0.5)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, fill);
      }
    }
    final outline = Paint()
      ..color = _alphaScaled(annotation.color, 0.9)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.2)
      ..style = PaintingStyle.stroke;
    if (_useHandDrawnStyle) {
      final points = _buildSquiggleLinePoints(rect.topLeft, rect.topRight, seed + 1, outline.strokeWidth);
      final right = _buildSquiggleLinePoints(rect.topRight, rect.bottomRight, seed + 2, outline.strokeWidth);
      final bottom = _buildSquiggleLinePoints(rect.bottomRight, rect.bottomLeft, seed + 3, outline.strokeWidth);
      final left = _buildSquiggleLinePoints(rect.bottomLeft, rect.topLeft, seed + 4, outline.strokeWidth);
      _paintStyledPolyline(canvas, points, outline, AnnotationLineStyle.straight);
      _paintStyledPolyline(canvas, right, outline, AnnotationLineStyle.straight);
      _paintStyledPolyline(canvas, bottom, outline, AnnotationLineStyle.straight);
      _paintStyledPolyline(canvas, left, outline, AnnotationLineStyle.straight);
    } else {
      canvas.drawRect(rect, outline);
    }
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
    final seed = _annotationSeed(annotation);
    _drawTempShadow(canvas, () {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
        ..style = annotation.filled ? PaintingStyle.fill : PaintingStyle.stroke;
      canvas.drawRect(rect, shadowPaint);
    });
    if (annotation.filled) {
      if (_useHandDrawnStyle) {
        _drawIrregularHatchFill(
          canvas,
          Path()..addRect(rect),
          annotation.color,
          seed,
          alpha: _tempAlpha(0.21, 0.32),
          strokeWidth: _strokeWidthPxFor(annotation.strokeWidthCm),
        );
      } else {
        final fill = Paint()
          ..color = _alphaScaled(annotation.color, _tempAlpha(0.28, 0.5))
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, fill);
      }
    }
    final paint = Paint()
      ..color = _alphaScaled(annotation.color, _tempAlpha(0.56, 0.78))
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..style = PaintingStyle.stroke;
    if (_useHandDrawnStyle) {
      _paintStyledPolyline(
        canvas,
        _buildSquiggleLinePoints(rect.topLeft, rect.topRight, seed + 21, paint.strokeWidth),
        paint,
        AnnotationLineStyle.straight,
      );
      _paintStyledPolyline(
        canvas,
        _buildSquiggleLinePoints(rect.topRight, rect.bottomRight, seed + 22, paint.strokeWidth),
        paint,
        AnnotationLineStyle.straight,
      );
      _paintStyledPolyline(
        canvas,
        _buildSquiggleLinePoints(rect.bottomRight, rect.bottomLeft, seed + 23, paint.strokeWidth),
        paint,
        AnnotationLineStyle.straight,
      );
      _paintStyledPolyline(
        canvas,
        _buildSquiggleLinePoints(rect.bottomLeft, rect.topLeft, seed + 24, paint.strokeWidth),
        paint,
        AnnotationLineStyle.straight,
      );
    } else {
      canvas.drawRect(rect, paint);
    }
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
        ..color = _alphaScaled(annotation.color, 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fill);
    }
    final fade = Paint()
      ..color = _alphaScaled(annotation.color, 0.2)
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
        ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.05)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      _paintStyledLineMaybeHandDrawn(
        canvas,
        startScreen,
        endScreen,
        shadowPaint,
        annotation.lineStyle,
        _annotationSeed(annotation) + 501,
      );
    });
    final paint = Paint()
      ..color = _alphaScaled(annotation.color, _tempAlpha(0.6, 0.82))
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.05)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _paintStyledLineMaybeHandDrawn(
      canvas,
      startScreen,
      endScreen,
      paint,
      annotation.lineStyle,
      _annotationSeed(annotation) + 11,
    );
  }

  void _paintCurvedLine(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final points = _curvedLineScreenPoints(annotation);
    if (points.length < 2) return;
    final paint = Paint()
      ..color = _alphaScaled(annotation.color, 0.8)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.65)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _paintStyledPolylineMaybeHandDrawn(canvas, points, paint, annotation.lineStyle, _annotationSeed(annotation) + 31);
  }

  void _paintTempCurvedLine(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final points = _curvedLineScreenPoints(annotation);
    if (points.length < 2) return;
    final seed = _annotationSeed(annotation);

    _drawTempShadow(canvas, () {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.26)
        ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.05)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      _paintStyledPolylineMaybeHandDrawn(canvas, points, shadowPaint, annotation.lineStyle, seed + 401);
    });

    final paint = Paint()
      ..color = _alphaScaled(annotation.color, _tempAlpha(0.6, 0.82))
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.05)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _paintStyledPolylineMaybeHandDrawn(canvas, points, paint, annotation.lineStyle, seed + 21);
  }

  void _paintErasingCurvedLine(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;
    final points = _curvedLineScreenPoints(annotation);
    if (points.length < 2) return;

    final fadePaint = Paint()
      ..color = _alphaScaled(annotation.color, 0.2)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.65)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _paintStyledPolylineMaybeHandDrawn(
      canvas,
      points,
      fadePaint,
      annotation.lineStyle,
      _annotationSeed(annotation) + 1201,
    );

    final midpoint = _pointAlongPolyline(points, 0.5);
    final tangent = _pointAlongPolyline(points, 0.56) - _pointAlongPolyline(points, 0.44);
    final tangentLen = tangent.distance;
    final normal = tangentLen > 0.001 ? Offset(-tangent.dy / tangentLen, tangent.dx / tangentLen) : const Offset(0, 1);

    final strikePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(midpoint - normal * 15, midpoint + normal * 15, strikePaint);
  }

  void _paintCurvedControlHandle(Canvas canvas, Annotation annotation, {required bool isSelected}) {
    if (annotation.points.length < 2) return;
    final points = _curvedLineScreenPoints(annotation);
    if (points.length < 2) return;
    final handle = _pointAlongPolyline(points, 0.5);

    const handleRadius = 5.5;
    final handleFill = Paint()
      ..color = Colors.amber.withValues(alpha: isSelected ? 0.95 : 0.8)
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(handle, handleRadius, handleFill);
    canvas.drawCircle(handle, handleRadius, handleBorder);
  }

  void _paintDragPreviewLine(Canvas canvas, Offset startCm, Offset endCm) {
    final startScreen = _cmToScreen(startCm);
    final endScreen = _cmToScreen(endCm);
    final paint = Paint()
      ..color =
          const Color.fromARGB(200, 255, 200, 100) // Semi-transparent orange preview
      ..strokeWidth = _strokeWidthPx(1.7)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _paintStyledLineMaybeHandDrawn(canvas, startScreen, endScreen, paint, dragPreviewLineStyle, 12345);

    final isMarkerPreview =
        dragPreviewLineStyle == AnnotationLineStyle.markerX ||
        dragPreviewLineStyle == AnnotationLineStyle.markerPylon ||
        dragPreviewLineStyle == AnnotationLineStyle.markerDot;
    if (isMarkerPreview) {
      return;
    }

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
      case AnnotationType.curvedLine:
        if (annotation.points.length >= 2) {
          final points = annotation.points.map(_cmToScreen).toList();
          _paintStyledPolyline(canvas, points, highlightPaint, annotation.lineStyle);
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
          canvas.drawArc(
            rect,
            annotation.startAngle!,
            annotation.endAngle! - annotation.startAngle!,
            false,
            highlightPaint,
          );
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
    final seed = _annotationSeed(annotation);
    _drawTempShadow(canvas, () {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
        ..style = annotation.filled ? PaintingStyle.fill : PaintingStyle.stroke;
      canvas.drawCircle(centerScreen, radiusScreen, shadowPaint);
    });
    if (annotation.filled) {
      if (_useHandDrawnStyle) {
        _drawIrregularHatchFill(
          canvas,
          Path()..addOval(Rect.fromCircle(center: centerScreen, radius: radiusScreen)),
          annotation.color,
          seed,
          alpha: _tempAlpha(0.21, 0.32),
          strokeWidth: _strokeWidthPxFor(annotation.strokeWidthCm),
          circularMode: true,
        );
      } else {
        final fill = Paint()
          ..color = _alphaScaled(annotation.color, _tempAlpha(0.28, 0.5))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(centerScreen, radiusScreen, fill);
      }
    }
    final paint = Paint()
      ..color = _alphaScaled(annotation.color, _tempAlpha(0.56, 0.78))
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..style = PaintingStyle.stroke;
    _paintCircleOutlineMaybeHandDrawn(canvas, centerScreen, radiusScreen, paint, seed + 1);
  }

  List<Offset> _buildGentleCirclePoints(Offset center, double radius, int seed, double strokeWidth) {
    final clampedRadius = math.max(1.0, radius);
    final samples = clampedRadius < 22
        ? 20
        : clampedRadius < 70
        ? 28
        : 36;
    final jitterAmplitude = math.min(clampedRadius * 0.03, math.max(0.18, strokeWidth * 0.12));
    final phaseA = _seedUnit(seed, 1001) * math.pi * 2;
    final phaseB = _seedUnit(seed, 1002) * math.pi * 2;

    final points = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final angle = t * math.pi * 2;
      final waveA = math.sin((angle * 2) + phaseA) * 0.55;
      final waveB = math.sin((angle * 3) + phaseB) * 0.45;
      final radial = clampedRadius + (waveA + waveB) * jitterAmplitude;
      points.add(center + Offset(math.cos(angle) * radial, math.sin(angle) * radial));
    }
    return points;
  }

  void _paintCircleOutlineMaybeHandDrawn(Canvas canvas, Offset center, double radius, Paint paint, int seed) {
    if (!_useHandDrawnStyle) {
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final primary = _buildGentleCirclePoints(center, radius, seed, paint.strokeWidth);
    _paintStyledPolyline(canvas, primary, paint, AnnotationLineStyle.straight);

    final secondPaint = Paint()
      ..color = paint.color.withValues(alpha: (paint.color.a * 0.42).clamp(0.0, 1.0))
      ..strokeWidth = math.max(1.0, paint.strokeWidth * 0.92)
      ..strokeCap = paint.strokeCap
      ..strokeJoin = paint.strokeJoin
      ..style = paint.style;
    final secondary = _buildGentleCirclePoints(center, radius, seed + 2221, secondPaint.strokeWidth);
    _paintStyledPolyline(canvas, secondary, secondPaint, AnnotationLineStyle.straight);
  }

  void _paintLine(Canvas canvas, Annotation annotation) {
    if (annotation.points.length < 2) return;

    final start = annotation.points[0];
    final end = annotation.points[1];

    // Convert logical coordinates to screen coordinates
    final startScreen = _cmToScreen(start);
    final endScreen = _cmToScreen(end);

    final paint = Paint()
      ..color = _alphaScaled(annotation.color, 0.8)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.65)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _paintStyledLineMaybeHandDrawn(
      canvas,
      startScreen,
      endScreen,
      paint,
      annotation.lineStyle,
      _annotationSeed(annotation),
    );
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
    final seed = _annotationSeed(annotation);
    if (annotation.filled) {
      if (_useHandDrawnStyle) {
        _drawIrregularHatchFill(
          canvas,
          Path()..addOval(Rect.fromCircle(center: centerScreen, radius: radiusScreen)),
          annotation.color,
          seed,
          alpha: 0.24,
          strokeWidth: _strokeWidthPxFor(annotation.strokeWidthCm, 1.2),
          circularMode: true,
        );
      } else {
        final fill = Paint()
          ..color = _alphaScaled(annotation.color, 0.5)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(centerScreen, radiusScreen, fill);
      }
    }
    final outline = Paint()
      ..color = _alphaScaled(annotation.color, 0.9)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.2)
      ..style = PaintingStyle.stroke;
    _paintCircleOutlineMaybeHandDrawn(canvas, centerScreen, radiusScreen, outline, seed + 11);
  }

  static const double _defaultTextSize = 20.0;
  static const String _textFontFamily = 'Roboto';

  TextStyle _textStyleFor(Annotation annotation, {required double alpha}) {
    final color = _alphaScaled(annotation.color, alpha);
    final fontSize = annotation.fontSize ?? _defaultTextSize;
    if (_useHandDrawnStyle) {
      return GoogleFonts.walterTurncoat(color: color, fontSize: fontSize, fontWeight: FontWeight.w600);
    }
    return TextStyle(color: color, fontSize: fontSize, fontFamily: _textFontFamily, fontWeight: FontWeight.w600);
  }

  TextPainter _textPainterFor(Annotation annotation, {double alpha = 0.9}) {
    return TextPainter(
      text: TextSpan(
        text: annotation.text ?? '',
        style: _textStyleFor(annotation, alpha: alpha),
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
          style: (_useHandDrawnStyle
              ? GoogleFonts.walterTurncoat(
                  color: Colors.black.withValues(alpha: _tempAlpha(0.35, 0.42)),
                  fontSize: annotation.fontSize ?? _defaultTextSize,
                  fontWeight: FontWeight.w600,
                )
              : TextStyle(
                  color: Colors.black.withValues(alpha: _tempAlpha(0.35, 0.42)),
                  fontSize: annotation.fontSize ?? _defaultTextSize,
                  fontFamily: _textFontFamily,
                  fontWeight: FontWeight.w600,
                )),
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
      ..color = _alphaScaled(annotation.color, 0.2)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm, 1.65)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _paintStyledLineMaybeHandDrawn(
      canvas,
      startScreen,
      endScreen,
      fadePaint,
      annotation.lineStyle,
      _annotationSeed(annotation) + 700,
    );

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

  void _paintStyledLine(Canvas canvas, Offset start, Offset end, Paint paint, AnnotationLineStyle style) {
    switch (style) {
      case AnnotationLineStyle.straight:
        canvas.drawLine(start, end, paint);
        break;
      case AnnotationLineStyle.arrow:
        canvas.drawLine(start, end, paint);
        _drawArrowHead(canvas, start, end, paint);
        break;
      case AnnotationLineStyle.arrowStart:
        canvas.drawLine(start, end, paint);
        _drawArrowHead(canvas, end, start, paint);
        break;
      case AnnotationLineStyle.dashed:
        _drawDashedLine(canvas, start, end, paint);
        break;
      case AnnotationLineStyle.markerX:
      case AnnotationLineStyle.markerPylon:
      case AnnotationLineStyle.markerDot:
        _drawMarkerSymbol(canvas, start, end, paint, style);
        break;
    }
  }

  void _drawMarkerSymbol(Canvas canvas, Offset start, Offset end, Paint paint, AnnotationLineStyle style) {
    final vector = end - start;
    final dist = vector.distance;
    final center = dist > 0.001 ? end : start;
    final baseSize = math.max(8.0, paint.strokeWidth * 3.0);

    switch (style) {
      case AnnotationLineStyle.markerX:
        final arm = baseSize * 0.65;
        canvas.drawLine(center + Offset(-arm, -arm), center + Offset(arm, arm), paint);
        canvas.drawLine(center + Offset(-arm, arm), center + Offset(arm, -arm), paint);
        break;
      case AnnotationLineStyle.markerPylon:
        final radius = math.max(4.0, baseSize * 0.55);
        final pylonPaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.35),
            radius: 0.95,
            colors: [
              Colors.white.withValues(alpha: (paint.color.a * 0.9).clamp(0.0, 1.0)),
              paint.color.withValues(alpha: (paint.color.a * 0.9).clamp(0.0, 1.0)),
              paint.color.withValues(alpha: (paint.color.a * 0.55).clamp(0.0, 1.0)),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius, pylonPaint);
        final border = Paint()
          ..color = paint.color.withValues(alpha: (paint.color.a * 0.9).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, paint.strokeWidth * 0.4);
        canvas.drawCircle(center, radius, border);
        break;
      case AnnotationLineStyle.markerDot:
        final dotPaint = Paint()
          ..color = paint.color.withValues(alpha: (paint.color.a * 0.95).clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        final dotRadius = math.max(4.0, baseSize * 0.45);
        canvas.drawCircle(center, dotRadius, dotPaint);
        break;
      case AnnotationLineStyle.straight:
      case AnnotationLineStyle.arrow:
      case AnnotationLineStyle.arrowStart:
      case AnnotationLineStyle.dashed:
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
        ..color = _alphaScaled(annotation.color, 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(centerScreen, radiusScreen, fill);
    }

    // Draw faded circle
    final fadePaint = Paint()
      ..color = _alphaScaled(annotation.color, 0.2)
      ..strokeWidth = _strokeWidthPxFor(annotation.strokeWidthCm)
      ..style = PaintingStyle.stroke;
    _paintCircleOutlineMaybeHandDrawn(
      canvas,
      centerScreen,
      radiusScreen,
      fadePaint,
      _annotationSeed(annotation) + 4401,
    );

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
    final sweep = annotation.endAngle! - annotation.startAngle!;
    final seed = _annotationSeed(annotation);

    final rect = Rect.fromCircle(center: centerScreen, radius: radiusScreen);
    if (_useHandDrawnStyle) {
      final sectorPath = Path()
        ..moveTo(centerScreen.dx, centerScreen.dy)
        ..arcTo(rect, annotation.startAngle!, sweep, false)
        ..close();
      _drawIrregularHatchFill(
        canvas,
        sectorPath,
        annotation.color,
        seed,
        alpha: 0.24,
        strokeWidth: _strokeWidthPxFor(annotation.strokeWidthCm),
      );
    } else {
      final fill = Paint()
        ..color = _alphaScaled(annotation.color, 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, annotation.startAngle!, sweep, true, fill);
    }
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
    final sweep = annotation.endAngle! - annotation.startAngle!;
    final seed = _annotationSeed(annotation);

    _drawTempShadow(canvas, () {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..style = PaintingStyle.fill;
      final shadowRect = Rect.fromCircle(center: centerScreen, radius: radiusScreen);
      canvas.drawArc(shadowRect, annotation.startAngle!, sweep, true, shadowPaint);
    });

    final rect = Rect.fromCircle(center: centerScreen, radius: radiusScreen);
    if (_useHandDrawnStyle) {
      final sectorPath = Path()
        ..moveTo(centerScreen.dx, centerScreen.dy)
        ..arcTo(rect, annotation.startAngle!, sweep, false)
        ..close();
      _drawIrregularHatchFill(
        canvas,
        sectorPath,
        annotation.color,
        seed,
        alpha: _tempAlpha(0.21, 0.32),
        strokeWidth: _strokeWidthPxFor(annotation.strokeWidthCm),
      );
    } else {
      final fill = Paint()
        ..color = _alphaScaled(annotation.color, _tempAlpha(0.3, 0.56))
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, annotation.startAngle!, sweep, true, fill);
    }
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
      ..color = _alphaScaled(annotation.color, 0.1)
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
      strokeWidthCm != oldDelegate.strokeWidthCm ||
      handDrawnStyle != oldDelegate.handDrawnStyle ||
      showCurvedControlHandles != oldDelegate.showCurvedControlHandles;
}
