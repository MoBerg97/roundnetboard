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

class _BoardScreenState extends State<BoardScreen> {
  late Frame currentFrame;

  @override
  void initState() {
    super.initState();

    if (widget.project.frames.isEmpty) {
      final defaultFrame = Frame(
        p1: const Offset(100, 200),
        p2: const Offset(120, 300),
        p3: const Offset(250, 200),
        p4: const Offset(270, 300),
        ball: const Offset(180, 250),
      );
      widget.project.frames.add(defaultFrame);
      currentFrame = defaultFrame;
    } else {
      currentFrame = widget.project.frames.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: Column(
        children: [
          // Tactical Board
          Expanded(
            child: Container(
              color: Colors.green[400],
              child: Stack(
                children: [
                  // Draw live paths with control points
                  CustomPaint(
                    size: Size.infinite,
                    painter: PathPainter(
                      currentFrame: currentFrame,
                      previousFrame: _getPreviousFrame(),
                      twoFramesAgo: _getTwoFramesAgo()
                    ),
                  ),

                  // Draggable players
                  _buildPlayer(currentFrame.p1, currentFrame.p1Rotation, Colors.blue, "P1"),
                  _buildPlayer(currentFrame.p2, currentFrame.p2Rotation, Colors.blue, "P2"),
                  _buildPlayer(currentFrame.p3, currentFrame.p3Rotation, Colors.red, "P3"),
                  _buildPlayer(currentFrame.p4, currentFrame.p4Rotation, Colors.red, "P4"),

                  // Draggable ball
                  _buildBall(currentFrame.ball),

                  // Draggable control points for paths
                  ..._buildPathControlPoints(currentFrame.p1PathPoints),
                  ..._buildPathControlPoints(currentFrame.p2PathPoints),
                  ..._buildPathControlPoints(currentFrame.p3PathPoints),
                  ..._buildPathControlPoints(currentFrame.p4PathPoints),
                  ..._buildPathControlPoints(currentFrame.ballPathPoints),
                ],
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
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.project.frames.length,
                    itemBuilder: (context, index) {
                      final frame = widget.project.frames[index];
                      final isSelected = frame == currentFrame;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            currentFrame = frame;
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
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _addFrameAtEnd,
                      child: const Text("Add Frame End"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _insertFrameAfterCurrent,
                      child: const Text("Insert Frame"),
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
  Widget _buildPlayer(Offset position, double rotation, Color color, String label) {
    return Positioned(
      left: position.dx - 20,
      top: position.dy - 20,
      child: GestureDetector(
        onScaleUpdate: (details) {
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
            child: const Icon(Icons.arrow_upward, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ----------------------
  // Draggable ball
  // ----------------------
  Widget _buildBall(Offset position) {
    return Positioned(
      left: position.dx - 15,
      top: position.dy - 15,
      child: GestureDetector(
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 1) {
              _updateFramePosition("BALL", currentFrame.ball + details.focalPointDelta);
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
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    });
  }

  // ----------------------
  // Update player positions and rotations
  // ----------------------
  void _updateFramePosition(String label, Offset newPos) {
    setState(() {
      final previousFrame = _getPreviousFrame();
      if (previousFrame == null) return;

      switch (label) {
        case "P1":
          currentFrame.p1 = newPos;
          if ((currentFrame.p1 - previousFrame.p1).distance > 50 &&
              currentFrame.p1PathPoints.isEmpty) {
            currentFrame.p1PathPoints = [
              Offset((previousFrame.p1.dx + newPos.dx) / 2,
                    (previousFrame.p1.dy + newPos.dy) / 2)
            ];
          }
          break;

        case "P2":
          currentFrame.p2 = newPos;
          if ((currentFrame.p2 - previousFrame.p2).distance > 50 &&
              currentFrame.p2PathPoints.isEmpty) {
            currentFrame.p2PathPoints = [
              Offset((previousFrame.p2.dx + newPos.dx) / 2,
                    (previousFrame.p2.dy + newPos.dy) / 2)
            ];
          }
          break;

        case "P3":
          currentFrame.p3 = newPos;
          if ((currentFrame.p3 - previousFrame.p3).distance > 50 &&
              currentFrame.p3PathPoints.isEmpty) {
            currentFrame.p3PathPoints = [
              Offset((previousFrame.p3.dx + newPos.dx) / 2,
                    (previousFrame.p3.dy + newPos.dy) / 2)
            ];
          }
          break;

        case "P4":
          currentFrame.p4 = newPos;
          if ((currentFrame.p4 - previousFrame.p4).distance > 50 &&
              currentFrame.p4PathPoints.isEmpty) {
            currentFrame.p4PathPoints = [
              Offset((previousFrame.p4.dx + newPos.dx) / 2,
                    (previousFrame.p4.dy + newPos.dy) / 2)
            ];
          }
          break;

        case "BALL":
          currentFrame.ball = newPos;
          if ((currentFrame.ball - previousFrame.ball).distance > 50 &&
              currentFrame.ballPathPoints.isEmpty) {
            currentFrame.ballPathPoints = [
              Offset((previousFrame.ball.dx + newPos.dx) / 2,
                    (previousFrame.ball.dy + newPos.dy) / 2)
            ];
          }
          break;
      }
    });
  }


  void _updateRotation(String label, double newRotation) {
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
  void _addFrameAtEnd() {
    setState(() {
      final previousFrame = widget.project.frames.last;
      final newFrame = previousFrame.copy();
      widget.project.frames.add(newFrame);
      currentFrame = newFrame;
    });
  }

  void _insertFrameAfterCurrent() {
    setState(() {
      final currentIndex = widget.project.frames.indexOf(currentFrame);
      final previousFrame = widget.project.frames[currentIndex];
      final newFrame = previousFrame.copy();
      widget.project.frames.insert(currentIndex + 1, newFrame);
      currentFrame = newFrame;
    });
  }

  // ----------------------
  // Select frame from timeline
  // ----------------------
  void _selectFrame(Frame frame) {
    setState(() {
      currentFrame = frame;

      // No need to create new points yet — just display existing ones
      // New control points will be added dynamically when player/ball moves
    });
  }

  // ----------------------
  // Get previous frame (for path drawing)
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
}
