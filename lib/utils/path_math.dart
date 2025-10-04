import 'dart:ui';

Offset positionAlongPath(List<Offset> points, double t) {
  if (points.isEmpty) return Offset.zero;
  if (t <= 0) return points.first;
  if (t >= 1) return points.last;

  final double totalSegments = (points.length -1).toDouble();
  final double floatIndex = t * totalSegments;
  final int idx = floatIndex.floor();
  final double frac = floatIndex - idx;

  if (idx >= points.length - 1) return points.last;

  final Offset a = points[idx];
  final Offset b = points[idx + 1];
  return Offset(lerpDouble(a.dx, b.dx, frac)!, lerpDouble(a.dy, b.dy, frac)!);
}

double tForClosestPointOnPath(List<Offset> points, Offset p) {
  if (points.length == 1) return 0.0;
  if (points.length == 2) {
    final segT = _closestTOnSegment(points[0], points[1], p);
    return segT;
  }

  double bestT = 0.0;
  double bestDist2 = double.infinity;

  for (int i = 0;  i < points.length - 1; i++) {
    final Offset a = points[i];
    final Offset b = points[i+1];

    final double local = _projFraction(a, b, p);

    final double px = a.dx + (b.dx - a.dx) * local;
    final double py = a.dy + (b.dy - a.dy) * local;
    final double dx = p.dx - px;
    final double dy = p.dy - py;
    final double dist2 = dx * dx + dy * dy;

    final double segmentStartT = i / (points.length - 1);
    final double segmentTLength = 1.0 / (points.length - 1);
    final double t = segmentStartT + local * segmentTLength;

    if (dist2 < bestDist2) {
      bestDist2 = dist2;
      bestT = t;
    }
  }

  return bestT.clamp(0.0, 1.0);
}

double _projFraction(Offset a, Offset b, Offset p) {
  final double vx = b.dx - a.dx;
  final double vy = b.dy - a.dy;
  final double wx = p.dx - a.dx;
  final double wy = p.dy - a.dy;
  final double v2 = vx * vx + vy * vy;
  if (v2 == 0) return 0.0;
  final double dot = vx * wx + vy * wy;
  return (dot / v2).clamp(0.0, 1.0);
}

double _closestTOnSegment(Offset a, Offset b, Offset p) {
  final local = _projFraction(a, b, p);
  return local;
}
