import 'dart:ui';
import 'dart:math';

class PathEngine {
  static final Map<String, PathEngine> _cache = {};

  final List<Offset> _samples;

  PathEngine._(this._samples);

  static PathEngine fromTwoQuadratics({
    required Offset start,
    required Offset control,
    required Offset end,
    int resolution = 48,
    Offset? handleIn,
    Offset? handleOut,
  }) {
    // Calculate vectors and their magnitudes
    final vIn = (control - start);
    final vOut = (end - control);
    final dIn = vIn.distance;
    final dOut = vOut.distance;
    
    // Normalize vectors and scale them by the average distance
    final avgDist = (dIn + dOut) / 2;
    final normIn = vIn / dIn;
    final normOut = vOut / dOut;
    
    // Calculate handle points with interpolated direction
    // and scaled distance for smooth transition
    final handleDir = (normIn + normOut) / 2;
    handleIn = control - handleDir * (avgDist / 3);
    handleOut = control + handleDir * (avgDist / 3);

    final seg1Count = (resolution / 2).ceil();
    final seg2Count = resolution - seg1Count;
    final List<Offset> samples = [];

    // First quadratic segment
    for (int i = 0; i < seg1Count; i++) {
      final t = i / (seg1Count - 1);
      samples.add(_sampleQuadratic(start, handleIn, control, t));
    }
    
    // Second quadratic segment
    for (int j = 1; j < seg2Count; j++) {
      final t = j / (seg2Count - 1);
      samples.add(_sampleQuadratic(control, handleOut, end, t));
    }
    
    return PathEngine._(samples);
  }

  Offset sample(double t) {
    if (_samples.isEmpty) return Offset.zero;
    final clamped = t.clamp(0.0, 1.0);
    final idxF = clamped * (_samples.length - 1);
    final idx = idxF.floor();
    final next = min(idx + 1, _samples.length - 1);
    final localT = idxF - idx;
    return Offset.lerp(_samples[idx], _samples[next], localT)!;
  }

  Path toPath() {
    final p = Path();
    if (_samples.isEmpty) return p;
    p.moveTo(_samples.first.dx, _samples.first.dy);
    for (var i = 1; i < _samples.length; i++) {
      p.lineTo(_samples[i].dx, _samples[i].dy);
    }
    return p;
  }

  static Offset _sampleQuadratic(Offset a, Offset c, Offset b, double t) {
    final omt = 1 - t;
    final x = omt * omt * a.dx + 2 * omt * t * c.dx + t * t * b.dx;
    final y = omt * omt * a.dy + 2 * omt * t * c.dy + t * t * b.dy;
    return Offset(x, y);
  }

  static String _cacheKey(int frameIndex, String entity) => '$frameIndex-$entity';

  static PathEngine cachedForFrameEntity({
    required int frameIndex,
    required String entity,
    required Offset start,
    required Offset control,
    required Offset end,
    int resolution = 48,
  }) {
    final key = _cacheKey(frameIndex, entity);
    final existing = _cache[key];
    if (existing != null) return existing;
    final engine = PathEngine.fromTwoQuadratics(
      start: start,
      control: control,
      end: end,
      resolution: resolution,
    );
    _cache[key] = engine;
    return engine;
  }

  static void invalidateCacheFor(int frameIndex, String entity) {
    _cache.remove(_cacheKey(frameIndex, entity));
  }

  static void invalidateAll() => _cache.clear();
}
