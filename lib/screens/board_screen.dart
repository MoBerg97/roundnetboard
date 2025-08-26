import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/animation_project.dart';
import '../models/frame.dart';
import '../widgets/path_painter.dart';

class BoardScreen extends StatefulWidget {
  final AnimationProject project;

  const BoardScreen({super.key, required this.project});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late Frame _currentFrame;

  // Animation
  late AnimationController _controller;
  bool _isPlaying = false;
  double _speed = 1.0; // 1.0x default
  static const int _baseMsPerSegment = 1200;

  @override
  void initState() {
    super.initState();

    if (widget.project.frames.isEmpty) {
      final f = Frame(
        p1: const Offset(100, 200),
        p2: const Offset(140, 200),
        p3: const Offset(260, 200),
        p4: const Offset(300, 200),
        ball: const Offset(200, 260),
      );
      widget.project.frames.add(f);
    }

    _currentIndex = 0;
    _currentFrame = widget.project.frames[_currentIndex];

    _controller = AnimationController(
      vsync: this,
      duration: _segmentDuration(),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Advance to next segment if possible
        if (_currentIndex < widget.project.frames.length - 1) {
          setState(() {
            _currentIndex++;
            _currentFrame = widget.project.frames[_currentIndex];
          });
          if (_currentIndex < widget.project.frames.length - 1) {
            _controller.duration = _segmentDuration();
            _controller.forward(from: 0);
          } else {
            _stopPlayback();
          }
        } else {
          _stopPlayback();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration _segmentDuration() {
    final ms = (_baseMsPerSegment / _speed).round();
    return Duration(milliseconds: ms.clamp(120, 8000));
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      // if at last frame, restart from 0
      if (_currentIndex >= widget.project.frames.length - 1) {
        setState(() {
          _currentIndex = 0;
          _currentFrame = widget.project.frames[_currentIndex];
        });
      }
      if (widget.project.frames.length > 1) {
        setState(() {
          _isPlaying = true;
          _controller.duration = _segmentDuration();
        });
        _controller.forward(from: 0);
      }
    }
  }

  void _stopPlayback() {
    _controller.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  // Helpers to fetch frames relative to current index
  Frame? _getPreviousFrame() {
    final i = _currentIndex;
    if (i > 0) return widget.project.frames[i - 1];
    return null;
    }
  Frame? _getTwoFramesAgo() {
    final i = _currentIndex;
    if (i > 1) return widget.project.frames[i - 2];
    return null;
  }

  // Interpolation utilities
  Offset _lerp(Offset a, Offset b, double t) => Offset(
        a.dx + (b.dx - a.dx) * t,
        a.dy + (b.dy - a.dy) * t,
      );

  Offset _quad(Offset a, Offset c, Offset b, double t) {
    // Quadratic Bezier: (1-t)^2 a + 2(1-t)t c + t^2 b
    final mt = 1 - t;
    return Offset(
      mt * mt * a.dx + 2 * mt * t * c.dx + t * t * b.dx,
      mt * mt * a.dy + 2 * mt * t * c.dy + t * t * b.dy,
    );
  }

  // Get an interpolated position for a given label across the current segment
  Offset _interpFor({
    required Offset start,
    required Offset end,
    required List<Offset> controls,
    required double t,
  }) {
    if (controls.isEmpty) {
      return _lerp(start, end, t);
    }
    // Use first control for a smooth quadratic curve
    return _quad(start, controls.first, end, t);
  }

  // During playback, compute animated positions from segment start → end using end-frame's controls
  ({Offset p1, Offset p2, Offset p3, Offset p4, Offset ball}) _animatedPositions(double t) {
    final start = widget.project.frames[_currentIndex];
    final end = widget.project.frames[_currentIndex + 1];

    return (
      p1: _interpFor(start: start.p1, end: end.p1, controls: end.p1PathPoints, t: t),
      p2: _interpFor(start: start.p2, end: end.p2, controls: end.p2PathPoints, t: t),
      p3: _interpFor(start: start.p3, end: end.p3, controls: end.p3PathPoints, t: t),
      p4: _interpFor(start: start.p4, end: end.p4, controls: end.p4PathPoints, t: t),
      ball: _interpFor(start: start.ball, end: end.ball, controls: end.ballPathPoints, t: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prev = _getPreviousFrame();
    final twoAgo = _getTwoFramesAgo();

    // When playing and there is a next frame, compute animated positions
    final hasNext = _currentIndex < widget.project.frames.length - 1;
    final t = _controller.value;

    final anim = (_isPlaying && hasNext)
        ? _animatedPositions(t)
        : (
            p1: _currentFrame.p1,
            p2: _currentFrame.p2,
            p3: _currentFrame.p3,
            p4: _currentFrame.p4,
            ball: _currentFrame.ball,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            tooltip: _isPlaying ? 'Pause' : 'Play',
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlay,
          ),
        ],
      ),
      body: Column(
        children: [
          // Board
          Expanded(
            child: Container(
              color: Colors.green[400],
              child: Stack(
                children: [
                  // Paths (faded: twoAgo→prev, solid: prev→current OR segment start→end if playing)
                  CustomPaint(
                    size: Size.infinite,
                    painter: PathPainter(
                      twoFramesAgo: twoAgo,
                      previousFrame: _isPlaying && hasNext
                          ? widget.project.frames[_currentIndex] // segment start while playing
                          : prev,                                  // normal previous frame
                      currentFrame: _isPlaying && hasNext
                          ? widget.project.frames[_currentIndex + 1] // segment end while playing
                          : _currentFrame,                            // normal current frame
                    ),
                  ),

                  // Players & ball (disable drag while playing)
                  _buildPlayer(anim.p1, _currentFrame.p1Rotation, Colors.blue, "P1", enabled: !_isPlaying),
                  _buildPlayer(anim.p2, _currentFrame.p2Rotation, Colors.blue, "P2", enabled: !_isPlaying),
                  _buildPlayer(anim.p3, _currentFrame.p3Rotation, Colors.red,  "P3", enabled: !_isPlaying),
                  _buildPlayer(anim.p4, _currentFrame.p4Rotation, Colors.red,  "P4", enabled: !_isPlaying),
                  _buildBall(anim.ball, enabled: !_isPlaying),

                  // Control points (only when not playing, and on the current frame)
                  if (!_isPlaying) ...[
                    ..._buildPathControlPoints(_currentFrame.p1PathPoints),
                    ..._buildPathControlPoints(_currentFrame.p2PathPoints),
                    ..._buildPathControlPoints(_currentFrame.p3PathPoints),
                    ..._buildPathControlPoints(_currentFrame.p4PathPoints),
                    ..._buildPathControlPoints(_currentFrame.ballPathPoints),
                  ],
                ],
              ),
            ),
          ),

          // Timeline + Speed controls
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              children: [
                // Speed slider
                Row(
                  children: [
                    const Icon(Icons.speed),
                    const SizedBox(width: 8),
                    const Text('Speed'),
                    Expanded(
                      child: Slider(
                        value: _speed,
                        min: 0.25,
                        max: 3.0,
                        divisions: 11,
                        label: "${_speed.toStringAsFixed(2)}x",
                        onChanged: (v) {
                          setState(() {
                            _speed = v;
                          });
                          // apply to next segment or current if playing
                          if (_isPlaying) {
                            _controller.duration = _segmentDuration();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 84,
                  child: Row(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.project.frames.length,
                          itemBuilder: (context, index) {
                            final frame = widget.project.frames[index];
                            final isSelected = index == _currentIndex;

                            return GestureDetector(
                              onTap: () {
                                // Stop playback and select frame
                                if (_isPlaying) _stopPlayback();
                                setState(() {
                                  _currentIndex = index;
                                  _currentFrame = frame;
                                });
                              },
                              child: Container(
                                width: 60,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blueAccent : Colors.grey[400],
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(color: Colors.yellow, width: 3)
                                      : null,
                                ),
                                child: Center(child: Text("${index + 1}")),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_isPlaying) _stopPlayback();
                          _addFrameAtEnd();
                        },
                        child: const Text("Add Frame End"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_isPlaying) _stopPlayback();
                          _insertFrameAfterCurrent();
                        },
                        child: const Text("Insert Frame"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------
  // Draggable players
  // ----------------------
  Widget _buildPlayer(Offset position, double rotation, Color color, String label, {required bool enabled}) {
    return Positioned(
      left: position.dx - 20,
      top: position.dy - 20,
      child: GestureDetector(
        onScaleUpdate: !enabled
            ? null
            : (details) {
                setState(() {
                  if (details.pointerCount == 1) {
                    final delta = details.focalPointDelta;
                    _updateFramePosition(label, position + delta);
                  } else if (details.pointerCount == 2) {
                    _updateRotation(label, rotation + details.rotation);
                  }
                });
              },
        child: Transform.rotate(
          angle: rotation,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  // ----------------------
  // Draggable ball
  // ----------------------
  Widget _buildBall(Offset position, {required bool enabled}) {
    return Positioned(
      left: position.dx - 15,
      top: position.dy - 15,
      child: GestureDetector(
        onScaleUpdate: !enabled
            ? null
            : (details) {
                setState(() {
                  if (details.pointerCount == 1) {
                    _updateFramePosition("BALL", _currentFrame.ball + details.focalPointDelta);
                  }
                });
              },
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ----------------------
  // Draggable path control points (for the current frame)
  // ----------------------
  List<Widget> _buildPathControlPoints(List<Offset> points) {
    return List.generate(points.length, (i) {
      final pt = points[i];
      return Positioned(
        left: pt.dx - 8,
        top: pt.dy - 8,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              points[i] += details.delta;
            });
          },
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    });
  }

  // ----------------------
  // Update positions & rotations (with conditional control-point creation)
  // ----------------------
  void _updateFramePosition(String label, Offset newPos) {
    setState(() {
      final previousFrame = _getPreviousFrame();
      if (previousFrame == null) return;

      switch (label) {
        case "P1":
          _currentFrame.p1 = newPos;
          if ((_currentFrame.p1 - previousFrame.p1).distance > 50 && _currentFrame.p1PathPoints.isEmpty) {
            _currentFrame.p1PathPoints = [
              Offset((previousFrame.p1.dx + newPos.dx) / 2, (previousFrame.p1.dy + newPos.dy) / 2)
            ];
          }
          break;

        case "P2":
          _currentFrame.p2 = newPos;
          if ((_currentFrame.p2 - previousFrame.p2).distance > 50 && _currentFrame.p2PathPoints.isEmpty) {
            _currentFrame.p2PathPoints = [
              Offset((previousFrame.p2.dx + newPos.dx) / 2, (previousFrame.p2.dy + newPos.dy) / 2)
            ];
          }
          break;

        case "P3":
          _currentFrame.p3 = newPos;
          if ((_currentFrame.p3 - previousFrame.p3).distance > 50 && _currentFrame.p3PathPoints.isEmpty) {
            _currentFrame.p3PathPoints = [
              Offset((previousFrame.p3.dx + newPos.dx) / 2, (previousFrame.p3.dy + newPos.dy) / 2)
            ];
          }
          break;

        case "P4":
          _currentFrame.p4 = newPos;
          if ((_currentFrame.p4 - previousFrame.p4).distance > 50 && _currentFrame.p4PathPoints.isEmpty) {
            _currentFrame.p4PathPoints = [
              Offset((previousFrame.p4.dx + newPos.dx) / 2, (previousFrame.p4.dy + newPos.dy) / 2)
            ];
          }
          break;

        case "BALL":
          _currentFrame.ball = newPos;
          if ((_currentFrame.ball - previousFrame.ball).distance > 50 && _currentFrame.ballPathPoints.isEmpty) {
            _currentFrame.ballPathPoints = [
              Offset((previousFrame.ball.dx + newPos.dx) / 2, (previousFrame.ball.dy + newPos.dy) / 2)
            ];
          }
          break;
      }

      _currentFrame.save(); // persist changes (Hive)
    });
  }

  void _updateRotation(String label, double newRotation) {
    setState(() {
      switch (label) {
        case "P1":
          _currentFrame.p1Rotation = newRotation;
          break;
        case "P2":
          _currentFrame.p2Rotation = newRotation;
          break;
        case "P3":
          _currentFrame.p3Rotation = newRotation;
          break;
        case "P4":
          _currentFrame.p4Rotation = newRotation;
          break;
      }
      _currentFrame.save();
    });
  }

  // ----------------------
  // Add / Insert Frames
  // ----------------------
  void _addFrameAtEnd() {
    setState(() {
      final previousFrame = widget.project.frames.last;
      final newFrame = previousFrame.copy();
      widget.project.frames.add(newFrame);
      _currentIndex = widget.project.frames.length - 1;
      _currentFrame = newFrame;
      widget.project.save();
    });
  }

  void _insertFrameAfterCurrent() {
    setState(() {
      final previousFrame = widget.project.frames[_currentIndex];
      final newFrame = previousFrame.copy();
      widget.project.frames.insert(_currentIndex + 1, newFrame);
      _currentIndex = _currentIndex + 1;
      _currentFrame = newFrame;
      widget.project.save();
    });
  }
}
