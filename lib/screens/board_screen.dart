import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;
import '../models/animation_project.dart';
import '../models/frame.dart';
import '../widgets/path_painter.dart';
import '../widgets/board_background_painter.dart';
import '../models/settings.dart';
import '../utils/path_engine.dart';
import 'settings_screen.dart';
import '../utils/history.dart';

class BoardScreen extends StatefulWidget {
  final AnimationProject project;
  const BoardScreen({super.key, required this.project});
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> with TickerProviderStateMixin {
  late Frame currentFrame;
  late Settings _settings;
  late HistoryManager _history;

  bool _isPlaying = false;
  bool _endedAtLastFrame = false;
  late Ticker _ticker;
  double _playbackT = 0.0;
  double _playbackSpeed = 1.0;
  int _playbackFrameIndex = 0;

  String? _pendingBallMark; // 'hit' | 'set'
  bool _showModifierMenu = false;
  

  final Map<String, Offset> _dragStartLogical = {};
  final Map<String, Offset> _dragStartScreen = {};
  // Key for the board render box to compute coordinates reliably
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.project.settings == null) {
      widget.project.settings = Settings();
      widget.project.save();
    }
    _settings = widget.project.settings!;
    _playbackSpeed = _settings.playbackSpeed;

    if (widget.project.frames.isEmpty) {
      final r = _settings.outerCircleRadiusCm;
      final defaultFrame = Frame(
        p1: Offset(0, -r),
        p2: Offset(r, 0),
        p3: Offset(0, r),
        p4: Offset(-r, 0),
        ball: Offset.zero,
        p1Rotation: 0,
        p2Rotation: 0,
        p3Rotation: 0,
        p4Rotation: 0,
        p1PathPoints: [],
        p2PathPoints: [],
        p3PathPoints: [],
        p4PathPoints: [],
        ballPathPoints: [],
      );
      widget.project.frames.add(defaultFrame);
      currentFrame = defaultFrame;
      _saveProject();
    } else {
      currentFrame = widget.project.frames.first;
    }
    _ticker = createTicker(_onTick);
    _history = HistoryManager(widget.project);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Offset _boardCenter(Size size) {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 120;
    final usableHeight = size.height - appBarHeight - timelineHeight;
    final cx = size.width / 2;
    final cy = appBarHeight + usableHeight / 2;
    return Offset(cx, cy);
  }

  Offset _toScreenPosition(Offset cmPos, Size size) {
    final center = _boardCenter(size);
    return center +
        Offset(
          _settings.cmToLogical(cmPos.dx, size),
          _settings.cmToLogical(cmPos.dy, size),
        );
  }

  Offset _toLogicalPosition(Offset screenPos, Size size) {
    final center = _boardCenter(size);
    final scalePerCm = _settings.cmToLogical(1.0, size);
    return Offset(
      (screenPos.dx - center.dx) / scalePerCm,
      (screenPos.dy - center.dy) / scalePerCm,
    );
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) {
      setState(() {
        _endedAtLastFrame = true;
        _isPlaying = false;
      });
      _ticker.stop();
      return;
    }
    setState(() {
      _playbackT += 0.02 * _playbackSpeed;
      if (_playbackT >= 1.0) {
        _playbackT = 0.0;
        _playbackFrameIndex++;
        if (_playbackFrameIndex >= frames.length - 1) {
          _endedAtLastFrame = true;
        }
      }
    });
  }

  void _startPlayback() {
    if (widget.project.frames.length < 2) return;
    setState(() {
      _isPlaying = true;
      _endedAtLastFrame = false;
      _playbackFrameIndex = 0;
      _playbackT = 0.0;
    });
    _ticker.start();
  }

  void _stopPlayback() {
    setState(() {
      _isPlaying = false;
      _endedAtLastFrame = false;
      _playbackFrameIndex = 0;
      _playbackT = 0.0;
    });
    _ticker.stop();
  }

  Frame? get _animatedFrame {
    if (!_isPlaying) return null;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return null;
    final fA = frames[_playbackFrameIndex];
    final fB = frames[_playbackFrameIndex + 1];
    final t = _playbackT;

    Offset getPathOrLinear(String entity, Offset start, Offset end, List<Offset> pathPoints) {
      if (pathPoints.isNotEmpty) {
        // Create PathEngine for the current frame transition
        final engine = PathEngine.fromTwoQuadratics(
          start: start,
          control: pathPoints.first,
          end: end,
          resolution: 400,  // Use higher resolution for smoother animation
        );
        return engine.sample(t);
      } else {
        return Offset.lerp(start, end, t)!;
      }
    }

    return Frame(
      p1: getPathOrLinear('P1', fA.p1, fB.p1, fB.p1PathPoints),
      p2: getPathOrLinear('P2', fA.p2, fB.p2, fB.p2PathPoints),
      p3: getPathOrLinear('P3', fA.p3, fB.p3, fB.p3PathPoints),
      p4: getPathOrLinear('P4', fA.p4, fB.p4, fB.p4PathPoints),
      ball: getPathOrLinear('BALL', fA.ball, fB.ball, fB.ballPathPoints),
      p1Rotation: _interpolateRotation(fA.p1Rotation, fB.p1Rotation, t),
      p2Rotation: _interpolateRotation(fA.p2Rotation, fB.p2Rotation, t),
      p3Rotation: _interpolateRotation(fA.p3Rotation, fB.p3Rotation, t),
      p4Rotation: _interpolateRotation(fA.p4Rotation, fB.p4Rotation, t),
      p1PathPoints: [],
      p2PathPoints: [],
      p3PathPoints: [],
      p4PathPoints: [],
      ballPathPoints: [],
    );
  }

  // Compute scale and star opacity for ball effects during playback
  double _ballScaleAt(double t) {
    const double base = 1.0;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return base;
    final fB = frames[_playbackFrameIndex + 1];
    // Set modifier: quadratic peak at t=0.5, from 1.0 -> 2.0 -> 1.0
    if ((fB.ballSet ?? false) && fB.ballHitT == null) {
      final quad = 1.0 + (1.0 - 4.0 * (t - 0.5) * (t - 0.5));
      return quad.clamp(0.5, 2.0);
    }
    // Hit modifier: linear piecewise reaching 0.5 at tHit
    if (fB.ballHitT != null && !(fB.ballSet ?? false)) {
      final th = fB.ballHitT!.clamp(0.0001, 0.9999);
      const window = 0.15; // duration around hit where scale animates
      final d = (t - th).abs();
      if (d > window) return 1.0;
      // peak at 1.3x size at d==0, linear falloff to 1.0 at window boundary
      final factor = 1.0 + 0.3 * (1.0 - (d / window));
      return factor.clamp(1.0, 1.3);
    }
    return base;
  }

  double _starOpacityAt(double t) {
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return 0;
    final fB = frames[_playbackFrameIndex + 1];
    if (fB.ballHitT == null) return 0;
    final d = (t - fB.ballHitT!.clamp(0.0, 1.0)).abs();
    const double window = 0.1;
    if (d > window) return 0;
    return (1 - d / window).clamp(0.0, 1.0);
  }

  double _gauss(double x, double sigma) {
    return math.exp(-(x * x) / (2 * sigma * sigma));
  }

  double _interpolateRotation(double a, double b, double t) => a + (b - a) * t;

  Frame? _getPreviousFrame() {
    final index = widget.project.frames.indexOf(currentFrame);
    if (index > 0) return widget.project.frames[index - 1];
    return null;
  }

  Frame? _getTwoFramesAgo() {
    final index = widget.project.frames.indexOf(currentFrame);
    if (index >= 2) return widget.project.frames[index - 2];
    return null;
  }

  // Undo/Redo handled via HistoryManager

  void _updateFramePosition(String label, Offset newPos) {
    if (_isPlaying) return;
    setState(() {
      switch (label) {
        case "P1":
          currentFrame.p1 = newPos;
          break;
        case "P2":
          currentFrame.p2 = newPos;
          break;
        case "P3":
          currentFrame.p3 = newPos;
          break;
        case "P4":
          currentFrame.p4 = newPos;
          break;
        case "BALL":
          currentFrame.ball = newPos;
          break;
      }
      final idx = widget.project.frames.indexOf(currentFrame);
      if (idx >= 0) widget.project.frames[idx] = currentFrame;
    });
  }

  void _updateRotation(String label, double newRotation) {
    if (_isPlaying) return;
    setState(() {
      switch (label) {
        case "P1":
          currentFrame.p1Rotation = newRotation;
          break;
        case "P2":
          currentFrame.p2Rotation = newRotation;
          break;
        case "P3":
          currentFrame.p3Rotation = newRotation;
          break;
        case "P4":
          currentFrame.p4Rotation = newRotation;
          break;
      }
    });
    _saveProject();
  }

  void _insertFrameAfterCurrent() {
    final index = widget.project.frames.indexOf(currentFrame);
    final newFrame = Frame(
      p1: currentFrame.p1,
      p2: currentFrame.p2,
      p3: currentFrame.p3,
      p4: currentFrame.p4,
      ball: currentFrame.ball,
      p1Rotation: currentFrame.p1Rotation,
      p2Rotation: currentFrame.p2Rotation,
      p3Rotation: currentFrame.p3Rotation,
      p4Rotation: currentFrame.p4Rotation,
      p1PathPoints: [],
      p2PathPoints: [],
      p3PathPoints: [],
      p4PathPoints: [],
      ballPathPoints: [],
    );
    final newIdx = _history.push(InsertFrameAction(frameIndex: index, inserted: newFrame));
    setState(() {
      currentFrame = widget.project.frames[newIdx + 1];
    });
  }

  void _confirmDeleteFrame(Frame frame) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Frame"),
        content: const Text("Are you sure you want to delete this frame?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      final index = widget.project.frames.indexOf(frame);
      final newIdx = _history.push(DeleteFrameAction(frameIndex: index));
      setState(() {
        if (widget.project.frames.isEmpty) {
          final r = _settings.outerCircleRadiusCm;
          final defaultFrame = Frame(
            p1: Offset(0, -r),
            p2: Offset(r, 0),
            p3: Offset(0, r),
            p4: Offset(-r, 0),
            ball: Offset.zero,
            p1Rotation: 0,
            p2Rotation: 0,
            p3Rotation: 0,
            p4Rotation: 0,
            p1PathPoints: [],
            p2PathPoints: [],
            p3PathPoints: [],
            p4PathPoints: [],
            ballPathPoints: [],
          );
          widget.project.frames.add(defaultFrame);
          currentFrame = defaultFrame;
          _saveProject();
        } else {
          final safeIdx = index > 0 ? index - 1 : 0;
          currentFrame = widget.project.frames[math.min(safeIdx, widget.project.frames.length - 1)];
        }
      });
    }
  }

  void _saveProject() {
    widget.project.save();
    debugPrint("Project saved with ${widget.project.frames.length} frames");
  }

  void _handleBoardTap(Offset tapPos, Size size) {
    if (_isPlaying) return;
    final prev = _getPreviousFrame();
    if (prev == null) return;
    if (_pendingBallMark == 'hit') {
      _placeBallHitAt(tapPos, size);
      return;
    }
    bool tryAdd(String label, Offset startCm, Offset endCm, List<Offset> points) {
      if (points.isNotEmpty) return false;
      final pathLengthCm = (endCm - startCm).distance;
      if (pathLengthCm <= 50) return false;
      final midCm = (startCm + endCm) / 2;
      final midScreen = _toScreenPosition(midCm, size);
      if ((tapPos - midScreen).distance < 24) {
        setState(() => points.add(midCm));
        final idx = widget.project.frames.indexOf(currentFrame);
        PathEngine.invalidateCacheFor(idx, label);
        _saveProject();
        return true;
      }
      return false;
    }
    if (tryAdd("P1", prev.p1, currentFrame.p1, currentFrame.p1PathPoints)) return;
    if (tryAdd("P2", prev.p2, currentFrame.p2, currentFrame.p2PathPoints)) return;
    if (tryAdd("P3", prev.p3, currentFrame.p3, currentFrame.p3PathPoints)) return;
    if (tryAdd("P4", prev.p4, currentFrame.p4, currentFrame.p4PathPoints)) return;
    if (tryAdd("BALL", prev.ball, currentFrame.ball, currentFrame.ballPathPoints)) return;
  }

  void _placeBallHitAt(Offset tapPos, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return;
    // Build samples along path from prev.ball to currentFrame.ball
    final hasCtrl = currentFrame.ballPathPoints.isNotEmpty;
    final engine = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: prev.ball,
            control: currentFrame.ballPathPoints.first,
            end: currentFrame.ball,
            resolution: 200,
          )
        : null;
    double bestT = 0.5;
    double bestD = double.infinity;
    const int res = 200;
    for (int i = 0; i <= res; i++) {
      final t = i / res;
      final posCm = hasCtrl
          ? engine!.sample(t)
          : Offset.lerp(prev.ball, currentFrame.ball, t)!;
      final posScreen = _toScreenPosition(posCm, size);
      final d = (tapPos - posScreen).distance;
      if (d < bestD) {
        bestD = d;
        bestT = t;
      }
    }
    if (bestD < 40) {
      setState(() {
        currentFrame.ballHitT = bestT;
        _pendingBallMark = null;
      });
      _saveProject();
    } else {
      // ignore if too far from path
    }
  }

  

  double _nearestTOnBallPath(Offset tapPos, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return 0.5;
    final hasCtrl = currentFrame.ballPathPoints.isNotEmpty;
    final engine = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: prev.ball,
            control: currentFrame.ballPathPoints.first,
            end: currentFrame.ball,
            resolution: 400)
        : null;
    const int res = 400;
    double bestT = 0.5;
    double bestD = double.infinity;
    for (int i = 0; i <= res; i++) {
      final t = i / res;
      final posCm = hasCtrl ? engine!.sample(t) : Offset.lerp(prev.ball, currentFrame.ball, t)!;
      final posScreen = _toScreenPosition(posCm, size);
      final d = (tapPos - posScreen).distance;
      if (d < bestD) {
        bestD = d;
        bestT = t;
      }
    }
    return bestT;
  }

  double _avoidControlPointOverlap(Frame prev, double t) {
    if (currentFrame.ballPathPoints.isEmpty) return t;
    final ctrl = currentFrame.ballPathPoints.first;
    final ctrlT = 0.5; // control is midpoint in our 2-quad approx
    final cmOffset = 150.0;
    if ((t - ctrlT).abs() < 0.02) {
      // approximate mapping: shift t by distance in cm over estimated path length
      final pathLen = (currentFrame.ball - prev.ball).distance;
      final frac = (pathLen > 0) ? (cmOffset / pathLen) : 0.1;
      return (t + frac).clamp(0.0, 1.0);
    }
    return t;
  }

  Widget _buildHitMarker(double t, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return const SizedBox.shrink();
    final hasCtrl = currentFrame.ballPathPoints.isNotEmpty;
    final posCm = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: prev.ball,
            control: currentFrame.ballPathPoints.first,
            end: currentFrame.ball,
            resolution: 400)
            .sample(t)
        : Offset.lerp(prev.ball, currentFrame.ball, t)!;
    final pos = _toScreenPosition(posCm, size);
    return Positioned(
      left: pos.dx - 16,
      top: pos.dy - 16,
      child: GestureDetector(
        onPanStart: (details) {
          // Start dragging the hit marker immediately when the user pans on it
          setState(() => _pendingBallMark = 'hit');
        },
            onPanUpdate: (details) {
          if (_pendingBallMark == 'hit') {
            // Convert global coordinates to local coordinates relative to the board
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            final localPos = box.globalToLocal(details.globalPosition);
            final newT = _nearestTOnBallPath(localPos, size);
            setState(() => currentFrame.ballHitT = newT);
            _saveProject();
          }
        },
        onPanEnd: (_) => setState(() => _pendingBallMark = null),
        child: CustomPaint(
          size: const Size(32, 32),
          painter: _StarPainter(),
        ),
      ),
    );
  }

  Widget _buildSetPreview(Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return const SizedBox.shrink();
    final hasCtrl = currentFrame.ballPathPoints.isNotEmpty;
    final midCm = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: prev.ball,
            control: currentFrame.ballPathPoints.first,
            end: currentFrame.ball,
            resolution: 200).sample(0.5)
        : (prev.ball + currentFrame.ball) / 2;
    final pos = _toScreenPosition(midCm, size);
    final double scale = 2.0; // max size for set
    return Positioned(
      left: pos.dx - 15 * scale,
      top: pos.dy - 15 * scale,
      child: Opacity(
        opacity: 0.35,
        child: Container(
          width: 30 * scale,
          height: 30 * scale,
          decoration: BoxDecoration(
            color: Colors.orange.shade200,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

// (moved painter classes to top-level after the widget class)

  List<Widget> _buildPathControlPoints(
    List<Offset> points,
    Offset startCm,
    Offset endCm,
    Size size,
    String label,
  ) {
    final widgets = <Widget>[];
    for (int i = 0; i < points.length; i++) {
      final screenPos = _toScreenPosition(points[i], size);
      widgets.add(
        Positioned(
          left: screenPos.dx - 8,
          top: screenPos.dy - 8,
          child: GestureDetector(
            onDoubleTap: () {
              _removeControlPoint(points, i, startCm, endCm, size);
              _saveProject();
            },
            onPanStart: (details) {
              _dragStartLogical["$label-$i"] = points[i];
              // store screen position relative to board
              final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
              _dragStartScreen["$label-$i"] = box.globalToLocal(details.globalPosition);
            },
            onPanUpdate: (details) {
              setState(() {
                final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
                final localPos = box.globalToLocal(details.globalPosition);
                final deltaScreen = localPos - (_dragStartScreen["$label-$i"] ?? localPos);
                final scalePerCm = _settings.cmToLogical(1.0, size);
                points[i] = (_dragStartLogical["$label-$i"] ?? points[i]) + deltaScreen / scalePerCm;
              });
            },
            onPanEnd: (_) {
              _dragStartLogical.remove("$label-$i");
              _dragStartScreen.remove("$label-$i");
              _saveProject();
            },
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(97, 0, 0, 0),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  void _removeControlPoint(
    List<Offset> points,
    int index,
    Offset startCm,
    Offset endCm,
    Size size,
  ) {
    if (index < 0 || index >= points.length) return;
    final removedPoint = points[index];
    final target = (startCm + endCm) / 2;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    late final Animation<Offset> animation;
    animation = Tween<Offset>(begin: removedPoint, end: target).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() {
          if (index < points.length) points[index] = animation.value;
        });
      });
    controller.forward().then((_) {
      setState(() {
        points.removeAt(index);
        controller.dispose();
        final idx = widget.project.frames.indexOf(currentFrame);
        if (idx >= 0) widget.project.frames[idx] = currentFrame;
        _saveProject();
      });
    });
  }

  Widget _buildPlayer(
    Offset posCm,
    double rotation,
    Color color,
    String label,
    Size size,
  ) {
    final screenPos = _toScreenPosition(posCm, size);
    return Positioned(
      left: screenPos.dx - 20,
      top: screenPos.dy - 20,
      child: GestureDetector(
        onPanStart: (details) {
          _dragStartLogical[label] = posCm;
          final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
          _dragStartScreen[label] = box.globalToLocal(details.globalPosition);
        },
        onPanUpdate: (details) {
          setState(() {
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            final localPos = box.globalToLocal(details.globalPosition);
            final deltaScreen = localPos - (_dragStartScreen[label] ?? localPos);
            final scalePerCm = _settings.cmToLogical(1.0, size);
            _updateFramePosition(
              label,
              (_dragStartLogical[label] ?? posCm) + deltaScreen / scalePerCm,
            );
          });
        },
        onPanEnd: (_) {
          final from = _dragStartLogical[label] ?? posCm;
          final to = switch (label) {
            "P1" => currentFrame.p1,
            "P2" => currentFrame.p2,
            "P3" => currentFrame.p3,
            "P4" => currentFrame.p4,
            _ => currentFrame.ball,
          };
          final idx = widget.project.frames.indexOf(currentFrame);
          final newIdx = _history.push(MoveEntityAction(frameIndex: idx, label: label, from: from, to: to));
          setState(() {
            currentFrame = widget.project.frames[newIdx];
          });
          _dragStartLogical.remove(label);
          _dragStartScreen.remove(label);
        },
        child: Transform.rotate(
          angle: rotation,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            // Arrow hidden by default for now
          ),
        ),
      ),
    );
  }

  Widget _buildBall(Offset posCm, Size size, {double scale = 1.0, double starOpacity = 0.0}) {
    final screenPos = _toScreenPosition(posCm, size);
    return Positioned(
      left: screenPos.dx - 15 * scale,
      top: screenPos.dy - 15 * scale,
      child: GestureDetector(
        onTap: () {
          if (!_isPlaying && !_endedAtLastFrame) {
            setState(() {
              _showModifierMenu = true;
            });
          }
        },
        onPanStart: (details) {
          _dragStartLogical["BALL"] = posCm;
          final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
          _dragStartScreen["BALL"] = box.globalToLocal(details.globalPosition);
        },
        onPanUpdate: (details) {
          setState(() {
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            final localPos = box.globalToLocal(details.globalPosition);
            final deltaScreen = localPos - (_dragStartScreen["BALL"] ?? localPos);
            final scalePerCm = _settings.cmToLogical(1.0, size);
            _updateFramePosition(
              "BALL",
              (_dragStartLogical["BALL"] ?? posCm) + deltaScreen / scalePerCm,
            );
          });
        },
        onPanEnd: (_) {
          final from = _dragStartLogical["BALL"] ?? posCm;
          final to = currentFrame.ball;
          final idx = widget.project.frames.indexOf(currentFrame);
          final newIdx = _history.push(MoveEntityAction(frameIndex: idx, label: "BALL", from: from, to: to));
          setState(() {
            currentFrame = widget.project.frames[newIdx];
          });
          _dragStartLogical.remove("BALL");
          _dragStartScreen.remove("BALL");
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 30 * scale,
              height: 30 * scale,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            if (starOpacity > 0)
              Transform.translate(
                offset: Offset(0, 16 * scale), // draw below the ball
                child: Opacity(
                  opacity: starOpacity,
                  child: CustomPaint(
                    size: Size(24 * scale, 24 * scale),
                    painter: _StarPainter(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _drawControlHandles(Canvas canvas, List<Offset> pathPoints, Paint handlePaint, Size size) {
    for (final point in pathPoints) {
      final screenPoint = _toScreenPosition(point, size);
      canvas.drawCircle(screenPoint, 6, handlePaint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    Settings.setScreenSize(screenSize);
    final isPlayback = _isPlaying && _animatedFrame != null;
    final frameToShow = _endedAtLastFrame
        ? widget.project.frames.last
        : (isPlayback ? _animatedFrame! : currentFrame);
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.project.name),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(project: widget.project)),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_showModifierMenu)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Enable Set',
                      onPressed: () {
                        if (_isPlaying || _endedAtLastFrame) return;
                        setState(() {
                          currentFrame.ballSet = true;
                          currentFrame.ballHitT = null; // mutually exclusive
                          _pendingBallMark = null;
                        });
                        _saveProject();
                      },
                      icon: SizedBox(
                        width: 40,
                        height: 28,
                        child: CustomPaint(
                          painter: _SetIconPainter(active: (currentFrame.ballSet ?? false)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      tooltip: 'Enable Hit',
                      onPressed: () {
                        if (_isPlaying || _endedAtLastFrame) return;
                        // default to midpoint; avoid control point collision
                        final prev = _getPreviousFrame();
                        if (prev != null) {
                          final tMid = 0.5;
                          final tAdjusted = _avoidControlPointOverlap(prev, tMid);
                          setState(() {
                            currentFrame.ballHitT = tAdjusted;
                            currentFrame.ballSet = false; // mutually exclusive
                            _pendingBallMark = 'hit';
                          });
                          _saveProject();
                        }
                      },
                      icon: SizedBox(
                        width: 40,
                        height: 28,
                        child: CustomPaint(
                          painter: _HitIconPainter(active: (currentFrame.ballHitT != null)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showModifierMenu = false;
                          _pendingBallMark = null;
                        });
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AbsorbPointer(
                absorbing: _isPlaying || _endedAtLastFrame,
                child: Container(
                  key: _boardKey,
                  color: Colors.green[400],
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: screenSize,
                        painter: BoardBackgroundPainter(
                          screenSize: screenSize,
                          settings: _settings,
                        ),
                      ),
                      if (!(_isPlaying || _endedAtLastFrame))
                        CustomPaint(
                          size: screenSize,
                          painter: PathPainter(
                            currentFrame: frameToShow,
                            previousFrame: _getPreviousFrame(),
                            twoFramesAgo: _getTwoFramesAgo(),
                            screenSize: screenSize,
                            settings: _settings,
                          ),
                        ),
                      // Full-board tap handler placed below interactive entities so that
                      // entity GestureDetectors (players, ball, control points) receive
                      // gestures first. If they don't handle the gesture, this fills in.
                      Positioned.fill(
                        child: GestureDetector(
                          onTapUp: (details) {
                            if (!(_isPlaying || _endedAtLastFrame)) {
                              if (_pendingBallMark == 'hit') {
                                _placeBallHitAt(details.localPosition, screenSize);
                              } else {
                                // Defer to next frame to avoid setState during build
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _handleBoardTap(details.localPosition, screenSize);
                                });
                              }
                            }
                          },
                          behavior: HitTestBehavior.translucent,
                          child: Container(),
                        ),
                      ),
                      _buildPlayer(frameToShow.p1, frameToShow.p1Rotation, Colors.blue, "P1", screenSize),
                      _buildPlayer(frameToShow.p2, frameToShow.p2Rotation, Colors.blue, "P2", screenSize),
                      _buildPlayer(frameToShow.p3, frameToShow.p3Rotation, Colors.red, "P3", screenSize),
                      _buildPlayer(frameToShow.p4, frameToShow.p4Rotation, Colors.red, "P4", screenSize),
                      _buildBall(
                        frameToShow.ball,
                        screenSize,
                        scale: isPlayback ? _ballScaleAt(_playbackT) : 1.0,
                        starOpacity: isPlayback ? _starOpacityAt(_playbackT) : 0.0,
                      ),
                      // Set preview: slightly transparent max-size ball at midpoint when editing
                      if (!isPlayback && (currentFrame.ballSet ?? false))
                        _buildSetPreview(screenSize),
                      if (!(_isPlaying || _endedAtLastFrame)) ...[
                        if (currentFrame.p1PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(currentFrame.p1PathPoints, currentFrame.p1, currentFrame.p1PathPoints.last, screenSize, "P1"),
                        if (currentFrame.p2PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(currentFrame.p2PathPoints, currentFrame.p2, currentFrame.p2PathPoints.last, screenSize, "P2"),
                        if (currentFrame.p3PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(currentFrame.p3PathPoints, currentFrame.p3, currentFrame.p3PathPoints.last, screenSize, "P3"),
                        if (currentFrame.p4PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(currentFrame.p4PathPoints, currentFrame.p4, currentFrame.p4PathPoints.last, screenSize, "P4"),
                        if (currentFrame.ballPathPoints.isNotEmpty)
                          ..._buildPathControlPoints(currentFrame.ballPathPoints, currentFrame.ball, currentFrame.ballPathPoints.last, screenSize, "BALL"),
                      ],
                      
                      if (currentFrame.ballHitT != null && !(_isPlaying || _endedAtLastFrame))
                        _buildHitMarker(currentFrame.ballHitT!, screenSize),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: 120,
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  if (_isPlaying)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text("Speed", style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: _playbackSpeed,
                              min: 0.1,
                              max: 3.0,
                              divisions: 29,
                              label: "${_playbackSpeed.toStringAsFixed(1)}x",
                              onChanged: (v) => setState(() => _playbackSpeed = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: _isPlaying || _endedAtLastFrame,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.project.frames.length,
                        itemBuilder: (context, index) {
                          final frame = widget.project.frames[index];
                          final isSelected = frame == currentFrame;
                          return GestureDetector(
                            onTap: () {
                              if (!(_isPlaying || _endedAtLastFrame)) setState(() => currentFrame = frame);
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 60,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blueAccent : Colors.grey[400],
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: Colors.yellow, width: 3) : null,
                                  ),
                                  child: Center(child: Text("${index + 1}")),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => _confirmDeleteFrame(frame),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: (_isPlaying || _endedAtLastFrame) ? _stopPlayback : _startPlayback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isPlaying || _endedAtLastFrame) ? Colors.red : Colors.green,
                        ),
                        child: Icon((_isPlaying || _endedAtLastFrame) ? Icons.stop : Icons.play_arrow),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: "Previous frame",
                        onPressed: (_isPlaying || _endedAtLastFrame)
                            ? null
                            : () {
                                final idx = widget.project.frames.indexOf(currentFrame);
                                if (idx > 0) setState(() => currentFrame = widget.project.frames[idx - 1]);
                              },
                        icon: const Icon(Icons.skip_previous),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: "Next frame",
                        onPressed: (_isPlaying || _endedAtLastFrame)
                            ? null
                            : () {
                                final idx = widget.project.frames.indexOf(currentFrame);
                                if (idx < widget.project.frames.length - 1) {
                                  setState(() => currentFrame = widget.project.frames[idx + 1]);
                                }
                              },
                        icon: const Icon(Icons.skip_next),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: (_isPlaying || _endedAtLastFrame) ? null : _insertFrameAfterCurrent,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.undo),
                        tooltip: "Undo",
                        onPressed: (_isPlaying || _endedAtLastFrame)
                            ? null
                            : (_history.canUndo
                            ? () {
                                final idx = _history.undo();
                                if (idx != null && idx >= 0 && idx < widget.project.frames.length) {
                                  setState(() => currentFrame = widget.project.frames[idx]);
                                } else {
                                  setState(() {});
                                }
                              }
                            : null),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.redo),
                        tooltip: "Redo",
                        onPressed: (_isPlaying || _endedAtLastFrame)
                            ? null
                            : (_history.canRedo
                            ? () {
                                final idx = _history.redo();
                                if (idx != null && idx >= 0 && idx < widget.project.frames.length) {
                                  setState(() => currentFrame = widget.project.frames[idx]);
                                } else {
                                  setState(() {});
                                }
                              }
                            : null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final innerR = outerR * 0.5;
    const points = 8;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final isOuter = i % 2 == 0;
      final r = isOuter ? outerR : innerR;
      final angle = (math.pi / points) * i - math.pi / 2;
      final p = center + Offset(r * math.cos(angle), r * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    final fill = Paint()..color = Colors.yellow;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.redAccent;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Set icon painter (arc + endpoint circle)
class _SetIconPainter extends CustomPainter {
  final bool active;
  _SetIconPainter({required this.active});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = active ? Colors.orange : Colors.grey;
    final path = Path();
    path.moveTo(size.width * 0.05, size.height * 0.9);
    path.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.05,
      size.width * 0.75,
      size.height * 0.85,
    );
    canvas.drawPath(path, paint);
    final c = Offset(size.width * 0.85, size.height * 0.85);
    canvas.drawCircle(c, size.height * 0.12, paint);
  }
  @override
  bool shouldRepaint(covariant _SetIconPainter oldDelegate) => oldDelegate.active != active;
}

// Hit icon painter (V shape + endpoint circle)
class _HitIconPainter extends CustomPainter {
  final bool active;
  _HitIconPainter({required this.active});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = active ? Colors.yellow[700]! : Colors.grey;
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.2);
    path.lineTo(size.width * 0.5, size.height * 0.8);
    path.lineTo(size.width * 0.85, size.height * 0.3);
    canvas.drawPath(path, paint);
    final c = Offset(size.width * 0.9, size.height * 0.28);
    canvas.drawCircle(c, size.height * 0.12, paint);
  }
  @override
  bool shouldRepaint(covariant _HitIconPainter oldDelegate) => oldDelegate.active != active;
}
