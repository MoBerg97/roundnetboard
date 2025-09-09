import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;

import '../models/animation_project.dart';
import '../models/frame.dart';
import '../widgets/path_painter.dart';
import '../widgets/board_background_painter.dart';
import '../models/settings.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BoardScreen extends StatefulWidget {
  final AnimationProject project;

  const BoardScreen({super.key, required this.project});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen>
    with TickerProviderStateMixin {
  late Frame currentFrame;

  // Settings
  late Settings _settings;
  late Box<Settings> _settingsBox;

  // Board pan & zoom
  Offset _boardOffset = Offset.zero; // pan translation
  double _boardScaleFactor = 1.0; // zoom factor

  // Playback
  bool _isPlaying = false;
  late Ticker _ticker;
  double _playbackT = 0.0;
  double _playbackSpeed = 1.0;
  int _playbackFrameIndex = 0;

  // Drag tracking
  Map<String, Offset> _dragStartLogical = {};
  Map<String, Offset> _dragStartScreen = {};

  // ----------------------
  // Board helpers
  // ----------------------
  Offset _boardCenter(Size size) {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 120;

    final usableHeight = size.height - appBarHeight - timelineHeight;
    final offsetTop = appBarHeight;
    final offsetBottom = timelineHeight;

    // Horizontal center is unchanged
    final cx = size.width / 2;
    // Vertical center is in the middle of the usable area
    final cy = offsetTop + usableHeight / 2;

    return Offset(cx, cy);
  }  

Offset _toScreenPosition(Offset cmPos, Size size) {
  final center = _boardCenter(size);
  return center + Offset(
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



  // ----------------------
  // Init / Dispose
  // ----------------------
  @override
  void initState() {
    super.initState();

    // Load settings
    _settingsBox = Hive.box<Settings>('settings');
    _settings = _settingsBox.getAt(0)!;

    // Listen for settings changes
    _settingsBox.watch().listen((event) {
      setState(() {
        _settings = _settingsBox.getAt(0)!;
      });
    });

    if (widget.project.frames.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final size = MediaQuery.of(context).size;
        final center = _boardCenter(size);

        final r = _settings.outerCircleRadiusCm;

        final defaultFrame = Frame(
          p1: Offset(0, -r), // top
          p2: Offset(r, 0), // right
          p3: Offset(0, r), // bottom
          p4: Offset(-r, 0), // left
          ball: Offset.zero, // center
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

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ----------------------
  // Playback
  // ----------------------
  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) {
      _stopPlayback();
      return;
    }
    setState(() {
      _playbackT += 0.02 * _playbackSpeed;
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
    setState(() => _isPlaying = false);
    _ticker.stop();
  }

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
      p1PathPoints: [],
      p2PathPoints: [],
      p3PathPoints: [],
      p4PathPoints: [],
      ballPathPoints: [],
    );
  }

  Offset _interpolateOffset(
    Offset a,
    Offset b,
    List<Offset> controlPoints,
    double t,
  ) {
    if (controlPoints.isEmpty) return Offset.lerp(a, b, t)!;
    final p0 = a;
    final p1 = controlPoints[0];
    final p2 = b;
    return Offset(
      (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx,
      (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy,
    );
  }

  double _interpolateRotation(double a, double b, double t) => a + (b - a) * t;

  // ----------------------
  // Frame helpers
  // ----------------------
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
  }

  // ----------------------
  // Insert & Delete
  // ----------------------
  void _insertFrameAfterCurrent() {
    final index = widget.project.frames.indexOf(currentFrame);
    final newFrame = Frame(
      p1: currentFrame.p1,
      p2: currentFrame.p2,
      p3: currentFrame.p3,
      p4: currentFrame.p4,
      ball: currentFrame.ball,
      p1PathPoints: [], // ✅ start empty
      p2PathPoints: [],
      p3PathPoints: [],
      p4PathPoints: [],
      ballPathPoints: [],
    );

    setState(() {
      widget.project.frames.insert(index + 1, newFrame);
      currentFrame = newFrame;
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
      setState(() {
        final index = widget.project.frames.indexOf(frame);
        if (index < 0) return;
        widget.project.frames.removeAt(index);

        if (widget.project.frames.isEmpty) {
          final defaultFrame = Frame(
            p1: const Offset(0, -265),
            p2: const Offset(265, 0),
            p3: const Offset(0, 265),
            p4: const Offset(-265, 0),
            ball: Offset.zero,
          );
          widget.project.frames.add(defaultFrame);
          currentFrame = defaultFrame;
        } else if (index == 0) {
          currentFrame = widget.project.frames.first;
          currentFrame.p1PathPoints.clear();
          currentFrame.p2PathPoints.clear();
          currentFrame.p3PathPoints.clear();
          currentFrame.p4PathPoints.clear();
          currentFrame.ballPathPoints.clear();
        } else {
          currentFrame = widget.project.frames[index - 1];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    Settings.setScreenSize(screenSize); // <-- Add this line

    final isPlayback = _isPlaying && _animatedFrame != null;
    final frameToShow = isPlayback ? _animatedFrame! : currentFrame;

    return WillPopScope(
      onWillPop: () async => true, // physical back button still works
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.project.name),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: AbsorbPointer(
                absorbing: _isPlaying,
                child: Container(
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
                      // Paths
                      if (!_isPlaying)
                        CustomPaint(
                          size: screenSize,
                          painter: PathPainter(
                            currentFrame: frameToShow,
                            previousFrame: _getPreviousFrame(),
                            twoFramesAgo: _getTwoFramesAgo(),
                            screenSize: screenSize,
                            settings: _settings
                          ),
                        ),

                      // Players
                      _buildPlayer(
                        frameToShow.p1,
                        frameToShow.p1Rotation,
                        Colors.blue,
                        "P1",
                        screenSize,
                      ),
                      _buildPlayer(
                        frameToShow.p2,
                        frameToShow.p2Rotation,
                        Colors.blue,
                        "P2",
                        screenSize,
                      ),
                      _buildPlayer(
                        frameToShow.p3,
                        frameToShow.p3Rotation,
                        Colors.red,
                        "P3",
                        screenSize,
                      ),
                      _buildPlayer(
                        frameToShow.p4,
                        frameToShow.p4Rotation,
                        Colors.red,
                        "P4",
                        screenSize,
                      ),

                      // Ball
                      _buildBall(frameToShow.ball, screenSize),

                      // Control points
                      if (!_isPlaying) ...[
                        if (currentFrame.p1PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.p1PathPoints,
                            currentFrame.p1, // start
                            currentFrame.p1PathPoints.last,
                            screenSize,
                            "P1",
                          ),
                        if (currentFrame.p2PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.p2PathPoints,
                            currentFrame.p2,
                            currentFrame.p2PathPoints.last,
                            screenSize,
                            "P2",
                          ),
                        if (currentFrame.p3PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.p3PathPoints,
                            currentFrame.p3,
                            currentFrame.p3PathPoints.last,
                            screenSize,
                            "P3",
                          ),
                        if (currentFrame.p4PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.p4PathPoints,
                            currentFrame.p4,
                            currentFrame.p4PathPoints.last,
                            screenSize,
                            "P4",
                          ),
                        if (currentFrame.ballPathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.ballPathPoints,
                            currentFrame.ball,
                            currentFrame.ballPathPoints.last,
                            screenSize,
                            "BALL",
                          ),
                      ],
                      // check if path midpoint is being tapped
                      Positioned.fill(
                        child: GestureDetector(
                          onTapDown: (details) => _handleBoardTap(
                            details.localPosition,
                            screenSize,
                          ),
                          behavior: HitTestBehavior.translucent,
                          child: Container(), // transparent
                        ),
                      ),
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
                              onChanged: (v) =>
                                  setState(() => _playbackSpeed = v),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: AbsorbPointer(
                      absorbing: _isPlaying,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.project.frames.length,
                        itemBuilder: (context, index) {
                          final frame = widget.project.frames[index];
                          final isSelected = frame == currentFrame;
                          return GestureDetector(
                            onTap: () {
                              if (!_isPlaying)
                                setState(() => currentFrame = frame);
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 60,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blueAccent
                                        : Colors.grey[400],
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.yellow,
                                            width: 3,
                                          )
                                        : null,
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
                        onPressed: _isPlaying ? _stopPlayback : _startPlayback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPlaying
                              ? Colors.red
                              : Colors.green,
                        ),
                        child: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isPlaying ? null : _insertFrameAfterCurrent,
                        child: const Icon(Icons.add),
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

  // ----------------------
  // Create control points on tap
  // ----------------------
  void _handleBoardTap(Offset tapPos, Size size) {
    if (_isPlaying) return;
    final prev = _getPreviousFrame();
    if (prev == null) return;
  
    // Helper: try to add control point for a path
    bool tryAdd(String label, Offset startCm, Offset endCm, List<Offset> points) {
      if (points.isNotEmpty) return false;
      final pathLengthCm = (endCm - startCm).distance;
      if (pathLengthCm <= 50) return false; // Only if path is long enough
  
      final midCm = (startCm + endCm) / 2;
      final midScreen = _toScreenPosition(midCm, size); // Convert cm to screen
  
      if ((tapPos - midScreen).distance < 24) { // 24 px threshold
        setState(() => points.add(midCm));
        return true;
      }
      return false;
    }
  
    // Try each path
    if (tryAdd("P1", prev.p1, currentFrame.p1, currentFrame.p1PathPoints)) return;
    if (tryAdd("P2", prev.p2, currentFrame.p2, currentFrame.p2PathPoints)) return;
    if (tryAdd("P3", prev.p3, currentFrame.p3, currentFrame.p3PathPoints)) return;
    if (tryAdd("P4", prev.p4, currentFrame.p4, currentFrame.p4PathPoints)) return;
    if (tryAdd("BALL", prev.ball, currentFrame.ball, currentFrame.ballPathPoints)) return;
  }


  // ----------------------
  // Build path control points with double-tap to delete
  // ----------------------
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
            onDoubleTap: () => _removeControlPoint(points, i, startCm, endCm, size),
            onPanStart: (details) {
              _dragStartLogical["$label-$i"] = points[i];
              _dragStartScreen["$label-$i"] = details.globalPosition;
            },
            onPanUpdate: (details) {
              setState(() {
                final deltaScreen =
                    details.globalPosition - (_dragStartScreen["$label-$i"] ?? details.globalPosition);
                final scalePerCm = _settings.cmToLogical(1.0, size);
                points[i] = (_dragStartLogical["$label-$i"] ?? points[i]) + deltaScreen / scalePerCm;
              });
            },
            onPanEnd: (_) {
              _dragStartLogical.remove("$label-$i");
              _dragStartScreen.remove("$label-$i");
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
        ),
      );
    }

    return widgets;
  }


  // ----------------------
  // Remove control point with animation
  // ----------------------
  void _removeControlPoint(
    List<Offset> points,
    int index,
    Offset startCm,
    Offset endCm,
    Size size,
  ) {
    if (index < 0 || index >= points.length) return;

    final removedPoint = points[index];
    final target = (startCm + endCm) / 2; // midpoint in cm

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
      });
    });
  }


  // ----------------------
  // Build players
  // ----------------------
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
          _dragStartScreen[label] = details.globalPosition;
        },
        onPanUpdate: (details) {
          setState(() {
            final deltaScreen =
                details.globalPosition - (_dragStartScreen[label] ?? details.globalPosition);
            final scalePerCm = _settings.cmToLogical(1.0, size);
            _updateFramePosition(
              label,
              (_dragStartLogical[label] ?? posCm) + deltaScreen / scalePerCm,
            );
          });
        },
        onPanEnd: (_) {
          _dragStartLogical.remove(label);
          _dragStartScreen.remove(label);
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
  // Build ball
  // ----------------------
  Widget _buildBall(Offset posCm, Size size) {
    final screenPos = _toScreenPosition(posCm, size);

    return Positioned(
      left: screenPos.dx - 15,
      top: screenPos.dy - 15,
      child: GestureDetector(
        onPanStart: (details) {
          _dragStartLogical["BALL"] = posCm;
          _dragStartScreen["BALL"] = details.globalPosition;
        },
        onPanUpdate: (details) {
          setState(() {
            final deltaScreen =
                details.globalPosition - (_dragStartScreen["BALL"] ?? details.globalPosition);
            final scalePerCm = _settings.cmToLogical(1.0, size);
            _updateFramePosition(
              "BALL",
              (_dragStartLogical["BALL"] ?? posCm) + deltaScreen / scalePerCm,
            );
          });
        },
        onPanEnd: (_) {
          _dragStartLogical.remove("BALL");
          _dragStartScreen.remove("BALL");
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

}
