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
    // Draw the spline as sampled short segments. This allows us to vary
    // the paint opacity per-segment to produce gradient fades along the path.
    if (points.length < 2) return;

    final samples = <Offset>[];
    const int resolution = 400;

    if (points.length == 2) {
      samples.add(_toScreen(points[0]));
      samples.add(_toScreen(points[1]));
    } else if (points.length == 3) {
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
    } else {
      final pts = points;
      final totalSegments = pts.length - 3;
      for (int seg = 0; seg < totalSegments; seg++) {
        for (int i = 0; i <= resolution; i++) {
          final t = i / resolution;
          final pt = _catmullRomPoint(pts, seg, t);
          samples.add(_toScreen(pt));
        }
      }
    }

    if (samples.length < 2) return;

    // Draw each segment with the provided paint as a fallback for uniform stroke.
    final segmentPaint = paint;
    for (int i = 0; i < samples.length - 1; i++) {
      final a = samples[i];
      final b = samples[i + 1];
      canvas.drawLine(a, b, segmentPaint);
    }
  }

  void _drawFadedSegments(Canvas canvas, List<Offset> samples, Color baseColor, double startAlpha, double endAlpha, double strokeWidth) {
    if (samples.length < 2) return;
    final int n = samples.length - 1;
    for (int i = 0; i < n; i++) {
      final t = i / n; // 0..1 along path (start -> end)
      // Interpolate opacity from startAlpha at path start (t==0) to endAlpha at path end (t==1)
      final alpha = (startAlpha + (endAlpha - startAlpha) * t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = baseColor.withOpacity(alpha)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(samples[i], samples[i + 1], paint);
    }
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

    // faded path: twoFramesAgo → previousFrame (older path)
    if (twoFramesAgo != null) {
      final p1Samples = _sampleSplinePoints([twoFramesAgo!.p1, ...previousFrame!.p1PathPoints, previousFrame!.p1]);
      final p2Samples = _sampleSplinePoints([twoFramesAgo!.p2, ...previousFrame!.p2PathPoints, previousFrame!.p2]);
      final p3Samples = _sampleSplinePoints([twoFramesAgo!.p3, ...previousFrame!.p3PathPoints, previousFrame!.p3]);
      final p4Samples = _sampleSplinePoints([twoFramesAgo!.p4, ...previousFrame!.p4PathPoints, previousFrame!.p4]);
      final ballSamples = _sampleSplinePoints([twoFramesAgo!.ball, ...previousFrame!.ballPathPoints, previousFrame!.ball]);
      // Older path: fade from 30% at the oldest point to 10% at the newer point
      _drawFadedSegments(canvas, p1Samples, Colors.black, 0.3, 0.1, 2.0);
      _drawFadedSegments(canvas, p2Samples, Colors.black, 0.3, 0.1, 2.0);
      _drawFadedSegments(canvas, p3Samples, Colors.black, 0.3, 0.1, 2.0);
      _drawFadedSegments(canvas, p4Samples, Colors.black, 0.3, 0.1, 2.0);
      _drawFadedSegments(canvas, ballSamples, Colors.black, 0.3, 0.1, 2.0);
    }

    // solid path: previousFrame → currentFrame (preview)
    // Fade from 50% at the previous-frame end (start of this segment)
    // to 100% (fully visible) at the current-frame end (path endpoint).
    final s1 = _sampleSplinePoints([previousFrame!.p1, ...currentFrame!.p1PathPoints, currentFrame!.p1]);
    final s2 = _sampleSplinePoints([previousFrame!.p2, ...currentFrame!.p2PathPoints, currentFrame!.p2]);
    final s3 = _sampleSplinePoints([previousFrame!.p3, ...currentFrame!.p3PathPoints, currentFrame!.p3]);
    final s4 = _sampleSplinePoints([previousFrame!.p4, ...currentFrame!.p4PathPoints, currentFrame!.p4]);
    final sBall = _sampleSplinePoints([previousFrame!.ball, ...currentFrame!.ballPathPoints, currentFrame!.ball]);
    _drawFadedSegments(canvas, s1, Colors.black, 0.5, 1.0, 2.0);
    _drawFadedSegments(canvas, s2, Colors.black, 0.5, 1.0, 2.0);
    _drawFadedSegments(canvas, s3, Colors.black, 0.5, 1.0, 2.0);
    _drawFadedSegments(canvas, s4, Colors.black, 0.5, 1.0, 2.0);
    _drawFadedSegments(canvas, sBall, Colors.black, 0.5, 1.0, 2.0);
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