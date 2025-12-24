import 'package:flutter/material.dart';
import 'dart:ui' as ui;
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
    const double timelineHeight = 140; // Match timeline height in board_screen.dart
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

  // helper removed: path drawing is handled by _drawFadedSegments and
  // _sampleSplinePoints which generate a Path and shader-based fades.

  void _drawFadedSegments(Canvas canvas, List<Offset> samples, Color baseColor, double startAlpha, double endAlpha, double strokeWidth) {
    if (samples.length < 2) return;
    // Build a path from sampled points
    final path = Path();
    path.moveTo(samples.first.dx, samples.first.dy);
    for (var i = 1; i < samples.length; i++) {
      path.lineTo(samples[i].dx, samples[i].dy);
    }

    // Use a linear gradient shader along the path from start->end to avoid
    // overlapping-segment additive alpha. The shader maps startAlpha at
    // samples.first to endAlpha at samples.last.
    final shader = ui.Gradient.linear(
      samples.first,
      samples.last,
      [
        baseColor.withAlpha((startAlpha.clamp(0.0, 1.0) * 255).round()),
        baseColor.withAlpha((endAlpha.clamp(0.0, 1.0) * 255).round()),
      ],
    );
    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  List<Offset> _sampleSplinePoints(List<Offset> points) {
    final samples = <Offset>[];
    const int resolution = 400;
    if (points.length < 2) return samples;

    if (points.length == 2) {
      // Sample a straight line into many segments so fade can be applied
      for (var i = 0; i <= resolution; i++) {
        final t = i / resolution;
        final p = Offset.lerp(points[0], points[1], t)!;
        samples.add(_toScreen(p));
      }
      return samples;
    }

    if (points.length == 3) {
      final engine = PathEngine.fromTwoQuadratics(
        start: points[0],
        control: points[1],
        end: points[2],
        resolution: resolution,
      );
      for (var i = 0; i <= resolution; i++) {
        final t = i / resolution;
        samples.add(_toScreen(engine.sample(t)));
      }
      return samples;
    }

    final pts = points;
    final totalSegments = pts.length - 3;
    for (int seg = 0; seg < totalSegments; seg++) {
      for (int i = 0; i <= resolution; i++) {
        final t = i / resolution;
        final pt = _catmullRomPoint(pts, seg, t);
        samples.add(_toScreen(pt));
      }
    }
    return samples;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (previousFrame == null || currentFrame == null) return;

    // Paint objects are created per-segment in _drawFadedSegments so no
    // uniform paint is required here.

    // faded path: twoFramesAgo → previousFrame (older path) - only render if setting enabled
    if (settings.showPreviousFrameLines && twoFramesAgo != null) {
      final p1Samples = _sampleSplinePoints([twoFramesAgo!.p1, ...previousFrame!.p1PathPoints, previousFrame!.p1]);
      final p2Samples = _sampleSplinePoints([twoFramesAgo!.p2, ...previousFrame!.p2PathPoints, previousFrame!.p2]);
      final p3Samples = _sampleSplinePoints([twoFramesAgo!.p3, ...previousFrame!.p3PathPoints, previousFrame!.p3]);
      final p4Samples = _sampleSplinePoints([twoFramesAgo!.p4, ...previousFrame!.p4PathPoints, previousFrame!.p4]);
      _drawFadedSegments(canvas, p1Samples, Colors.black, 0.05, 0.30, 2.0);
      _drawFadedSegments(canvas, p2Samples, Colors.black, 0.05, 0.30, 2.0);
      _drawFadedSegments(canvas, p3Samples, Colors.black, 0.05, 0.30, 2.0);
      _drawFadedSegments(canvas, p4Samples, Colors.black, 0.05, 0.30, 2.0);
      
      // Draw paths for all balls in twoFramesAgo
      for (int i = 0; i < twoFramesAgo!.balls.length && i < previousFrame!.balls.length; i++) {
        final prevBall = twoFramesAgo!.balls[i];
        final currBall = previousFrame!.balls[i];
        final ballSamples = _sampleSplinePoints([prevBall.position, ...currBall.pathPoints, currBall.position]);
        _drawFadedSegments(canvas, ballSamples, Colors.black, 0.05, 0.30, 2.0);
      }
    }

    // solid path: previousFrame -> currentFrame (preview)
    // Preview path: fade from fully visible at the previous-frame end to 30% at the current-frame end.
    final s1 = _sampleSplinePoints([previousFrame!.p1, ...currentFrame!.p1PathPoints, currentFrame!.p1]);
    final s2 = _sampleSplinePoints([previousFrame!.p2, ...currentFrame!.p2PathPoints, currentFrame!.p2]);
    final s3 = _sampleSplinePoints([previousFrame!.p3, ...currentFrame!.p3PathPoints, currentFrame!.p3]);
    final s4 = _sampleSplinePoints([previousFrame!.p4, ...currentFrame!.p4PathPoints, currentFrame!.p4]);
    _drawFadedSegments(canvas, s1, Colors.black, 0.30, 1.0, 2.0);
    _drawFadedSegments(canvas, s2, Colors.black, 0.30, 1.0, 2.0);
    _drawFadedSegments(canvas, s3, Colors.black, 0.30, 1.0, 2.0);
    _drawFadedSegments(canvas, s4, Colors.black, 0.30, 1.0, 2.0);
    
    // Draw paths for all balls from previousFrame to currentFrame
    for (int i = 0; i < previousFrame!.balls.length && i < currentFrame!.balls.length; i++) {
      final prevBall = previousFrame!.balls[i];
      final currBall = currentFrame!.balls[i];
      final ballSamples = _sampleSplinePoints([prevBall.position, ...currBall.pathPoints, currBall.position]);
      _drawFadedSegments(canvas, ballSamples, Colors.black, 0.30, 1.0, 2.0);
    }
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