import 'package:flutter/material.dart';
import '../models/frame.dart';
import '../models/settings.dart';

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
      _drawPathWithControlPoints(canvas, twoFramesAgo!.p1, previousFrame!.p1, previousFrame!.p1PathPoints, fadedPaint);
      _drawPathWithControlPoints(canvas, twoFramesAgo!.p2, previousFrame!.p2, previousFrame!.p2PathPoints, fadedPaint);
      _drawPathWithControlPoints(canvas, twoFramesAgo!.p3, previousFrame!.p3, previousFrame!.p3PathPoints, fadedPaint);
      _drawPathWithControlPoints(canvas, twoFramesAgo!.p4, previousFrame!.p4, previousFrame!.p4PathPoints, fadedPaint);
      _drawPathWithControlPoints(canvas, twoFramesAgo!.ball, previousFrame!.ball, previousFrame!.ballPathPoints, fadedPaint);
    }

    // solid path: previousFrame → currentFrame
    _drawPathWithControlPoints(canvas, previousFrame!.p1, currentFrame!.p1, currentFrame!.p1PathPoints, paint);
    _drawPathWithControlPoints(canvas, previousFrame!.p2, currentFrame!.p2, currentFrame!.p2PathPoints, paint);
    _drawPathWithControlPoints(canvas, previousFrame!.p3, currentFrame!.p3, currentFrame!.p3PathPoints, paint);
    _drawPathWithControlPoints(canvas, previousFrame!.p4, currentFrame!.p4, currentFrame!.p4PathPoints, paint);
    _drawPathWithControlPoints(canvas, previousFrame!.ball, currentFrame!.ball, currentFrame!.ballPathPoints, paint);
  }

  void _drawPathWithControlPoints(
    Canvas canvas,
    Offset start,
    Offset end,
    List<Offset> controlPoints,
    Paint paint,
  ) {
    final path = Path()..moveTo(_toScreen(start).dx, _toScreen(start).dy);

    if (controlPoints.isNotEmpty) {
      if (controlPoints.length == 1) {
        final cp = _toScreen(controlPoints[0]);
        final e = _toScreen(end);
        path.quadraticBezierTo(cp.dx, cp.dy, e.dx, e.dy);
      } else {
        final points = [...controlPoints, end];
        var current = _toScreen(start);
        for (int i = 0; i < points.length - 1; i++) {
          final cp1 = (_toScreen(points[i]) + current) / 2;
          final cp2 = (_toScreen(points[i + 1]) + _toScreen(points[i])) / 2;
          final e = _toScreen(points[i + 1]);
          path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, e.dx, e.dy);
          current = e;
        }
      }
    } else {
      path.lineTo(_toScreen(end).dx, _toScreen(end).dy);
    }

    canvas.drawPath(path, paint);
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