import 'package:flutter/material.dart';
import '../models/frame.dart';
import '../models/settings.dart';
import '../utils/path_engine.dart';

class PathPainter extends CustomPainter {
  final Frame? twoFramesAgo;
  final Frame? previousFrame;
  final Frame? currentFrame;
  final Size screenSize;
  final Settings settings;

  PathPainter({
    required this.twoFramesAgo,
    required this.previousFrame,
    required this.currentFrame,
    required this.screenSize,
    required this.settings,
  });

  Offset _boardCenter(Size size) {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 120;
    final usableHeight = size.height - appBarHeight - timelineHeight;
    final offsetTop = appBarHeight;
    final cx = size.width / 2;
    final cy = offsetTop + usableHeight / 2;
    return Offset(cx, cy);
  }

  Offset _toScreen(Offset cmPos) {
    final center = _boardCenter(screenSize);
    return center + Offset(
      settings.cmToLogical(cmPos.dx, screenSize),
      settings.cmToLogical(cmPos.dy, screenSize),
    );
  }

  // Local Catmull-Rom sampler (returns point in same coordinate space as inputs)
  Offset _catmullRomPoint(List<Offset> pts, int seg, double t) {
    final p0 = pts[seg + 0];
    final p1 = pts[seg + 1];
    final p2 = pts[seg + 2];
    final p3 = pts[seg + 3];
    final t2 = t * t;
    final t3 = t2 * t;
    final x = 0.5 *
        ((2 * p1.dx) +
            (-p0.dx + p2.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3);
    final y = 0.5 *
        ((2 * p1.dy) +
            (-p0.dy + p2.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3);
    return Offset(x, y);
  }

  void _drawSplinePath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;

    // If only start and end: straight line
    if (points.length == 2) {
      final p0 = _toScreen(points[0]);
      final p1 = _toScreen(points[1]);
      final path = Path()..moveTo(p0.dx, p0.dy)..lineTo(p1.dx, p1.dy);
      canvas.drawPath(path, paint);
      return;
    }

    // If exactly 3 points: use two-quadratic approximation via PathEngine
    if (points.length == 3) {
      final engine = PathEngine.fromTwoQuadratics(
        start: points[0],
        control: points[1],
        end: points[2],
        resolution: 400,
      );
      final path = Path();
      const int resolution = 400;
      if (resolution > 0) {
        final first = _toScreen(engine.sample(0.0));
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i <= resolution; i++) {
          final t = i / resolution;
          final s = _toScreen(engine.sample(t));
          path.lineTo(s.dx, s.dy);
        }
      }
      canvas.drawPath(path, paint);
      return;
    }

    // For 4+ points: Catmull-Rom spline (local implementation)
    final pts = points;
    final path = Path();
    const resolution = 400;
    final totalSegments = pts.length - 3;
    for (int seg = 0; seg < totalSegments; seg++) {
      for (int i = 0; i <= resolution; i++) {
        final t = i / resolution;
        final pt = _catmullRomPoint(pts, seg, t);
        final screenPt = _toScreen(pt);
        if (seg == 0 && i == 0) {
          path.moveTo(screenPt.dx, screenPt.dy);
        } else {
          path.lineTo(screenPt.dx, screenPt.dy);
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (previousFrame == null || currentFrame == null) return;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fadedPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // faded path: twoFramesAgo → previousFrame
    if (twoFramesAgo != null) {
      _drawSplinePath(
        canvas,
        [twoFramesAgo!.p1, ...previousFrame!.p1PathPoints, previousFrame!.p1],
        fadedPaint,
      );
      _drawSplinePath(
        canvas,
        [twoFramesAgo!.p2, ...previousFrame!.p2PathPoints, previousFrame!.p2],
        fadedPaint,
      );
      _drawSplinePath(
        canvas,
        [twoFramesAgo!.p3, ...previousFrame!.p3PathPoints, previousFrame!.p3],
        fadedPaint,
      );
      _drawSplinePath(
        canvas,
        [twoFramesAgo!.p4, ...previousFrame!.p4PathPoints, previousFrame!.p4],
        fadedPaint,
      );
      _drawSplinePath(
        canvas,
        [twoFramesAgo!.ball, ...previousFrame!.ballPathPoints, previousFrame!.ball],
        fadedPaint,
      );
    }

    // solid path: previousFrame → currentFrame
    _drawSplinePath(
      canvas,
      [previousFrame!.p1, ...currentFrame!.p1PathPoints, currentFrame!.p1],
      paint,
    );
    _drawSplinePath(
      canvas,
      [previousFrame!.p2, ...currentFrame!.p2PathPoints, currentFrame!.p2],
      paint,
    );
    _drawSplinePath(
      canvas,
      [previousFrame!.p3, ...currentFrame!.p3PathPoints, currentFrame!.p3],
      paint,
    );
    _drawSplinePath(
      canvas,
      [previousFrame!.p4, ...currentFrame!.p4PathPoints, currentFrame!.p4],
      paint,
    );
    _drawSplinePath(
      canvas,
      [previousFrame!.ball, ...currentFrame!.ballPathPoints, currentFrame!.ball],
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) {
    return oldDelegate.twoFramesAgo != twoFramesAgo ||
           oldDelegate.previousFrame != previousFrame ||
           oldDelegate.currentFrame != currentFrame ||
           oldDelegate.screenSize != screenSize ||
           oldDelegate.settings != settings;
  }
}