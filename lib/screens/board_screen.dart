import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Add this import
import '../models/animation_project.dart';
import '../models/frame.dart';
import '../widgets/path_painter.dart';
import '../widgets/board_background_painter.dart';


class BoardScreen extends StatefulWidget {
  final AnimationProject project;

  const BoardScreen({super.key, required this.project});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> with SingleTickerProviderStateMixin {
  late Frame currentFrame;

  // Animation playback state
  bool _isPlaying = false;
  late Ticker _ticker;
  double _playbackT = 0.0; // 0..1 between frames
  double _playbackSpeed = 1.0; // Speed multiplier
  int _playbackFrameIndex = 0;

  @override
void initState() {
  super.initState();

    if (widget.project.frames.isEmpty) {
      // You can't use MediaQuery in initState, so delay until first build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final size = MediaQuery.of(context).size;
        final center = Offset(size.width / 2, size.height / 2);

        final defaultFrame = Frame(
          p1: center + const Offset(0, -265),  // Top
          p2: center + const Offset(265, 0),   // Right
          p3: center + const Offset(0, 265),   // Bottom
          p4: center + const Offset(-265, 0),  // Left
          ball: center,                        // Ball in the middle
        );

        setState(() {
          widget.project.frames.add(defaultFrame);
          currentFrame = defaultFrame;
        });
      });
    } else {
      currentFrame = widget.project.frames.first;
    }

    _ticker = createTicker(_onTick);
  }


  // ----------------------
  // Animation playback methods
  // ----------------------
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // Called on each tick of the ticker
  void _onTick(Duration elapsed) {
    // quite if not playing 
    if (!_isPlaying) return;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) {
      _stopPlayback();
      return;
    }
    // Update interpolation parameter
    setState(() {
      _playbackT += 0.02 * _playbackSpeed; // scale with speed 
      if (_playbackT >= 1.0) {
        _playbackT = 0.0;
        _playbackFrameIndex++;
        if (_playbackFrameIndex >= frames.length - 1) {
          _stopPlayback();
          return;
        }
      }
    });
  }

  void _startPlayback() {
    if (widget.project.frames.length < 2) return;
    setState(() {
      _isPlaying = true;
      _playbackFrameIndex = 0;
      _playbackT = 0.0;
    });
    _ticker.start();
  }

  void _stopPlayback() {
    setState(() {
      _isPlaying = false;
    });
    _ticker.stop();
  }

  // --- Animation interpolation helpers ---
  Offset _interpolateOffset(Offset a, Offset b, List<Offset> controlPoints, double t) {
    if (controlPoints.isEmpty) {
      // Linear
      return Offset.lerp(a, b, t)!;
    } else if (controlPoints.length == 1) {
      // Quadratic Bezier
      final p0 = a;
      final p1 = controlPoints[0];
      final p2 = b;
      return Offset(
        (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx,
        (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy,
      );
    } else {
      // Piecewise: for simplicity, use first control point as quadratic
      final p0 = a;
      final p1 = controlPoints[0];
      final p2 = b;
      return Offset(
        (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx,
        (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy,
      );
    }
  }

  double _interpolateRotation(double a, double b, double t) {
    return a + (b - a) * t;
  }

  // --- Animated frame for playback ---
  Frame? get _animatedFrame {
    if (!_isPlaying) return null;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return null;
    final fA = frames[_playbackFrameIndex];
    final fB = frames[_playbackFrameIndex + 1];
    final t = _playbackT;

    return Frame(
      p1: _interpolateOffset(fA.p1, fB.p1, fB.p1PathPoints, t),
      p2: _interpolateOffset(fA.p2, fB.p2, fB.p2PathPoints, t),
      p3: _interpolateOffset(fA.p3, fB.p3, fB.p3PathPoints, t),
      p4: _interpolateOffset(fA.p4, fB.p4, fB.p4PathPoints, t),
      ball: _interpolateOffset(fA.ball, fB.ball, fB.ballPathPoints, t),
      p1Rotation: _interpolateRotation(fA.p1Rotation, fB.p1Rotation, t),
      p2Rotation: _interpolateRotation(fA.p2Rotation, fB.p2Rotation, t),
      p3Rotation: _interpolateRotation(fA.p3Rotation, fB.p3Rotation, t),
      p4Rotation: _interpolateRotation(fA.p4Rotation, fB.p4Rotation, t),
      p1PathPoints: [], // Not needed for playback
      p2PathPoints: [],
      p3PathPoints: [],
      p4PathPoints: [],
      ballPathPoints: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPlayback = _isPlaying && _animatedFrame != null;
    final frameToShow = isPlayback ? _animatedFrame! : currentFrame;

    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: Column(
        children: [
          // Tactical Board
          Expanded(
            child: AbsorbPointer(
              absorbing: _isPlaying, // Disable gestures during playback
              child: Container(
                color: Colors.green[400],
                child: Stack(
                  children: [
                    // Background circles + net
                    CustomPaint(
                      size: Size.infinite,
                      painter: BoardBackgroundPainter(),
                    ),
                    // Paths
                    if (!_isPlaying)
                      CustomPaint(
                        size: Size.infinite,
                        painter: PathPainter(
                          currentFrame: frameToShow,
                          previousFrame: widget.project.frames.indexOf(currentFrame) > 0 ? _getPreviousFrame() : null,
                          twoFramesAgo: widget.project.frames.indexOf(currentFrame) > 1 ? _getTwoFramesAgo() : null,
                        ),
                      ),
                    if (!isPlayback)
                      CustomPaint(
                        size: Size.infinite,
                        painter: PathPainter(
                          currentFrame: frameToShow,
                          previousFrame: widget.project.frames.indexOf(currentFrame) > 0 ? _getPreviousFrame() : null,
                          twoFramesAgo: widget.project.frames.indexOf(currentFrame) > 1 ? _getTwoFramesAgo() : null,
                        ),
                      ),
                    // Always show players and ball on top
                    _buildPlayer("P1", Colors.blue),
                    _buildPlayer("P2", Colors.blue),
                    _buildPlayer("P3", Colors.red),
                    _buildPlayer("P4", Colors.red),
                    _buildBall(),

                    // Show control points only in editing mode
                    if (!isPlayback) ...[
                      ..._buildPathControlPoints(currentFrame.p1PathPoints),
                      ..._buildPathControlPoints(currentFrame.p2PathPoints),
                      ..._buildPathControlPoints(currentFrame.p3PathPoints),
                      ..._buildPathControlPoints(currentFrame.p4PathPoints),
                      ..._buildPathControlPoints(currentFrame.ballPathPoints),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Timeline
          Container(
            height: 120,
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Playback speed slider only during playback
                if (_isPlaying)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                            onChanged: (value) {
                              setState(() {
                                _playbackSpeed = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Timeline frames
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _isPlaying, // Disable timeline tap during playback
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.project.frames.length,
                      itemBuilder: (context, index) {
                        final frame = widget.project.frames[index];
                        final isSelected = frame == currentFrame;
                        return GestureDetector(
                          onTap: () {
                            if (!_isPlaying) {
                              setState(() {
                                currentFrame = frame;
                              });
                            }
                          },
                          child: Stack(
                            children: [
                              Container(
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
                              // Optional delete button on top-right
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
                                      child: const Icon(Icons.remove, size: 12, color: Colors.white),
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
                // Play/Pause + Insert buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isPlaying ? _stopPlayback : _startPlayback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPlaying ? Colors.red : Colors.green,
                      ),
                      child: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isPlaying ? null : _insertFrameAfterCurrent,
                      child: const Icon(Icons.add), // just a "+" icon
                    ),
                  ],
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
  Widget _buildPlayer(String label, Color color) {
  final position = _getPosition(label);
  final rotation = _getRotation(label);

  return Positioned(
    left: position.dx - 20,
    top: position.dy - 20,
    child: GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          if (details.pointerCount == 1) {
            _updateFramePosition(label, _getPosition(label) + details.focalPointDelta);
          } else if (details.pointerCount == 2) {
            _updateRotation(label, _getRotation(label) + details.rotation);
          }
        });
      },
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_upward, color: Colors.white),
        ),
      ),
    ),
  );
}


  // ----------------------
  // Draggable ball
  // ----------------------
  Widget _buildBall() {
  final position = _getPosition("BALL");

  return Positioned(
    left: position.dx - 15,
    top: position.dy - 15,
    child: GestureDetector(
      onScaleUpdate: (details) {
        if (!_isPlaying) {
          setState(() {
            if (details.pointerCount == 1) {
              _updateFramePosition("BALL", currentFrame.ball + details.focalPointDelta);
            }
          });
        }
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
  // Draggable path control points
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
              color: Color.fromARGB(118, 90, 90, 90),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    });
  }

  // ----------------------
  // Helpers for accessing positions & rotations
  // ----------------------
  Offset _getPosition(String label) {
    final frame = _isPlaying && _animatedFrame != null ? _animatedFrame! : currentFrame;

    switch (label) {
      case "P1":
        return frame.p1;
      case "P2":
        return frame.p2;
      case "P3":
        return frame.p3;
      case "P4":
        return frame.p4;
      case "BALL":
        return frame.ball;
      default:
        throw ArgumentError("Unknown label: $label");
    }
  }

  double _getRotation(String label) {
    final frame = _isPlaying && _animatedFrame != null ? _animatedFrame! : currentFrame;

    switch (label) {
      case "P1":
        return frame.p1Rotation;
      case "P2":
        return frame.p2Rotation;
      case "P3":
        return frame.p3Rotation;
      case "P4":
        return frame.p4Rotation;
      default:
        return 0.0; // Ball doesn’t rotate
    }
  }

  // ----------------------
  // Update frame position
  // ----------------------
  void _updateFramePosition(String label, Offset newPos) {
    if (_isPlaying) return; // 🔒 Ignore updates during playback

    setState(() {
      final frameIndex = widget.project.frames.indexOf(currentFrame);
      final previousFrame = _getPreviousFrame();

      switch (label) {
        case "P1":
          currentFrame.p1 = newPos;
          if (frameIndex > 0 && // 🚫 Skip frame 0
              previousFrame != null &&
              (currentFrame.p1 - previousFrame.p1).distance > 50 &&
              currentFrame.p1PathPoints.isEmpty) {
            currentFrame.p1PathPoints = [
              Offset(
                (previousFrame.p1.dx + newPos.dx) / 2,
                (previousFrame.p1.dy + newPos.dy) / 2,
              )
            ];
          }
          break;

        case "P2":
          currentFrame.p2 = newPos;
          if (frameIndex > 0 &&
              previousFrame != null &&
              (currentFrame.p2 - previousFrame.p2).distance > 50 &&
              currentFrame.p2PathPoints.isEmpty) {
            currentFrame.p2PathPoints = [
              Offset(
                (previousFrame.p2.dx + newPos.dx) / 2,
                (previousFrame.p2.dy + newPos.dy) / 2,
              )
            ];
          }
          break;

        case "P3":
          currentFrame.p3 = newPos;
          if (frameIndex > 0 &&
              previousFrame != null &&
              (currentFrame.p3 - previousFrame.p3).distance > 50 &&
              currentFrame.p3PathPoints.isEmpty) {
            currentFrame.p3PathPoints = [
              Offset(
                (previousFrame.p3.dx + newPos.dx) / 2,
                (previousFrame.p3.dy + newPos.dy) / 2,
              )
            ];
          }
          break;

        case "P4":
          currentFrame.p4 = newPos;
          if (frameIndex > 0 &&
              previousFrame != null &&
              (currentFrame.p4 - previousFrame.p4).distance > 50 &&
              currentFrame.p4PathPoints.isEmpty) {
            currentFrame.p4PathPoints = [
              Offset(
                (previousFrame.p4.dx + newPos.dx) / 2,
                (previousFrame.p4.dy + newPos.dy) / 2,
              )
            ];
          }
          break;

        case "BALL":
          currentFrame.ball = newPos;
          if (frameIndex > 0 &&
              previousFrame != null &&
              (currentFrame.ball - previousFrame.ball).distance > 50 &&
              currentFrame.ballPathPoints.isEmpty) {
            currentFrame.ballPathPoints = [
              Offset(
                (previousFrame.ball.dx + newPos.dx) / 2,
                (previousFrame.ball.dy + newPos.dy) / 2,
              )
            ];
          }
          break;
      }
    });
  }

  // ----------------------
  // Update rotation
  // ----------------------
  void _updateRotation(String label, double newRotation) {
    if (_isPlaying) return; // 🔒 Ignore updates during playback

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
  }



  // ----------------------
  // Add / Insert Frames
  // ----------------------

  void _insertFrameAfterCurrent() {
  setState(() {
    Frame newFrame;
    if (widget.project.frames.isEmpty) {
      // No frames exist, create a default first frame
      newFrame = Frame(
        p1: const Offset(100, 200),
        p2: const Offset(120, 300),
        p3: const Offset(250, 200),
        p4: const Offset(270, 300),
        ball: const Offset(180, 250),
      );
      widget.project.frames.add(newFrame);
    } else {
      // Insert after current
      final currentIndex = widget.project.frames.indexOf(currentFrame);
      final previousFrame = widget.project.frames[currentIndex];
      newFrame = previousFrame.copy();
      widget.project.frames.insert(currentIndex + 1, newFrame);
    }

    currentFrame = newFrame;

    // If this is the first frame, ensure all path points are empty
    if (widget.project.frames.indexOf(currentFrame) == 0) {
      currentFrame.p1PathPoints.clear();
      currentFrame.p2PathPoints.clear();
      currentFrame.p3PathPoints.clear();
      currentFrame.p4PathPoints.clear();
      currentFrame.ballPathPoints.clear();
    }
  });
}

// ----------------------
// Confirm Delete Frame
// ----------------------
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
    setState(() {
      final index = widget.project.frames.indexOf(frame);
      if (index < 0) return; // Safety check

      widget.project.frames.removeAt(index);

      // Ensure currentFrame stays valid
      if (widget.project.frames.isEmpty) {
        // No frames left: create a default first frame
        final defaultFrame = Frame(
          p1: const Offset(100, 200),
          p2: const Offset(120, 300),
          p3: const Offset(250, 200),
          p4: const Offset(270, 300),
          ball: const Offset(180, 250),
        );
        widget.project.frames.add(defaultFrame);
        currentFrame = defaultFrame;
      } else if (index == 0) {
        // Deleted first frame: select new first frame
        currentFrame = widget.project.frames.first;

        // Clear path points so no controls are shown
        currentFrame.p1PathPoints.clear();
        currentFrame.p2PathPoints.clear();
        currentFrame.p3PathPoints.clear();
        currentFrame.p4PathPoints.clear();
        currentFrame.ballPathPoints.clear();
      } else {
        // Select previous frame
        currentFrame = widget.project.frames[index - 1];
      }
    });
  }
}

// ----------------------
// Get previous frame
// ----------------------
Frame? _getPreviousFrame() {
  if (widget.project.frames.isEmpty) return null;
  final index = widget.project.frames.indexOf(currentFrame);
  if (index > 0) return widget.project.frames[index - 1];
  return null;
}

// ----------------------
// Get two frames ago
// ----------------------
Frame? _getTwoFramesAgo() {
  if (widget.project.frames.isEmpty) return null;
  final index = widget.project.frames.indexOf(currentFrame);
  if (index >= 2) return widget.project.frames[index - 2];
  return null;
}
}


