import 'package:flutter/material.dart';
import '../models/frame.dart';

class PathPainter extends CustomPainter {
  final Frame? twoFramesAgo;
  final Frame? previousFrame;
  final Frame? currentFrame;

  PathPainter({
    required this.twoFramesAgo,
    required this.previousFrame,
    required this.currentFrame,
  });

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

    // 🔹 Faded path: twoFramesAgo → previousFrame
    if (twoFramesAgo != null) {
      _drawPathWithControlPoints(
        canvas,
        twoFramesAgo!.p1,
        previousFrame!.p1,
        previousFrame!.p1PathPoints,
        fadedPaint,
      );
      _drawPathWithControlPoints(
        canvas,
        twoFramesAgo!.p2,
        previousFrame!.p2,
        previousFrame!.p2PathPoints,
        fadedPaint,
      );
      _drawPathWithControlPoints(
        canvas,
        twoFramesAgo!.p3,
        previousFrame!.p3,
        previousFrame!.p3PathPoints,
        fadedPaint,
      );
      _drawPathWithControlPoints(
        canvas,
        twoFramesAgo!.p4,
        previousFrame!.p4,
        previousFrame!.p4PathPoints,
        fadedPaint,
      );
      _drawPathWithControlPoints(
        canvas,
        twoFramesAgo!.ball,
        previousFrame!.ball,
        previousFrame!.ballPathPoints,
        fadedPaint,
      );
    }

    // 🔹 Solid path: previousFrame → currentFrame
    _drawPathWithControlPoints(
      canvas,
      previousFrame!.p1,
      currentFrame!.p1,
      currentFrame!.p1PathPoints,
      paint,
    );
    _drawPathWithControlPoints(
      canvas,
      previousFrame!.p2,
      currentFrame!.p2,
      currentFrame!.p2PathPoints,
      paint,
    );
    _drawPathWithControlPoints(
      canvas,
      previousFrame!.p3,
      currentFrame!.p3,
      currentFrame!.p3PathPoints,
      paint,
    );
    _drawPathWithControlPoints(
      canvas,
      previousFrame!.p4,
      currentFrame!.p4,
      currentFrame!.p4PathPoints,
      paint,
    );
    _drawPathWithControlPoints(
      canvas,
      previousFrame!.ball,
      currentFrame!.ball,
      currentFrame!.ballPathPoints,
      paint,
    );
  }

  void _drawPathWithControlPoints(
    Canvas canvas,
    Offset start,
    Offset end,
    List<Offset> controlPoints,
    Paint paint,
  ) {
    final path = Path()..moveTo(start.dx, start.dy);

    if (controlPoints.isNotEmpty) {
      // 🔹 If only 1 control point → quadratic bezier
      if (controlPoints.length == 1) {
        path.quadraticBezierTo(
          controlPoints[0].dx,
          controlPoints[0].dy,
          end.dx,
          end.dy,
        );
      } else {
        // 🔹 Multiple control points → piecewise cubic
        final points = [...controlPoints, end];
        var current = start;
        for (int i = 0; i < points.length - 1; i++) {
          final cp1 = Offset(
            (current.dx + points[i].dx) / 2,
            (current.dy + points[i].dy) / 2,
          );
          final cp2 = Offset(
            (points[i].dx + points[i + 1].dx) / 2,
            (points[i].dy + points[i + 1].dy) / 2,
          );
          path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
          current = points[i + 1];
        }
      }
    } else {
      // 🔹 No control points → straight line
      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
