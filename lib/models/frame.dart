import 'package:hive/hive.dart';
import 'dart:ui';

part 'frame.g.dart';

/// --------------------------
/// Frame model
/// --------------------------
@HiveType(typeId: 1)
class Frame extends HiveObject {
  // --------------------------
  // Player and ball positions
  // --------------------------
  @HiveField(0)
  Offset p1;
  @HiveField(1)
  Offset p2;
  @HiveField(2)
  Offset p3;
  @HiveField(3)
  Offset p4;
  @HiveField(4)
  Offset ball;

  // --------------------------
  // Player rotations (radians)
  // --------------------------
  @HiveField(5)
  double p1Rotation;
  @HiveField(6)
  double p2Rotation;
  @HiveField(7)
  double p3Rotation;
  @HiveField(8)
  double p4Rotation;

  // --------------------------
  // Editable path control points
  // --------------------------
  @HiveField(9)
  List<Offset> p1PathPoints;
  @HiveField(10)
  List<Offset> p2PathPoints;
  @HiveField(11)
  List<Offset> p3PathPoints;
  @HiveField(12)
  List<Offset> p4PathPoints;
  @HiveField(13)
  List<Offset> ballPathPoints;

  // --------------------------
  // Ball event annotations
  // --------------------------
  // Hit at param t in [0,1] along previous->current transition
  @HiveField(14)
  double? ballHitT;
  // Set effect toggle for this transition (centered at t=0.5)
  @HiveField(15)
  bool? ballSet;

  // --------------------------
  // Frame duration (seconds)
  // --------------------------
  // Duration from this frame to the next frame during playback
  @HiveField(16)
  double duration;

  // --------------------------
  // Constructor
  // --------------------------
  Frame({
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
    required this.ball,
    this.p1Rotation = 0,
    this.p2Rotation = 0,
    this.p3Rotation = 0,
    this.p4Rotation = 0,
    List<Offset>? p1PathPoints,
    List<Offset>? p2PathPoints,
    List<Offset>? p3PathPoints,
    List<Offset>? p4PathPoints,
    List<Offset>? ballPathPoints,
    this.ballHitT,
    this.ballSet,
    this.duration = 0.5,
  })  : p1PathPoints = p1PathPoints ?? [],
        p2PathPoints = p2PathPoints ?? [],
        p3PathPoints = p3PathPoints ?? [],
        p4PathPoints = p4PathPoints ?? [],
        ballPathPoints = ballPathPoints ?? [];

  // --------------------------
  // Copy frame (deep copy)
  // --------------------------
  Frame copy() => Frame(
        p1: p1,
        p2: p2,
        p3: p3,
        p4: p4,
        ball: ball,
        p1Rotation: p1Rotation,
        p2Rotation: p2Rotation,
        p3Rotation: p3Rotation,
        p4Rotation: p4Rotation,
        p1PathPoints: List.from(p1PathPoints),
        p2PathPoints: List.from(p2PathPoints),
        p3PathPoints: List.from(p3PathPoints),
        p4PathPoints: List.from(p4PathPoints),
        ballPathPoints: List.from(ballPathPoints),
        ballHitT: ballHitT,
        ballSet: ballSet,
        duration: duration,
      );

  // --------------------------
  // Copy frame and initialize control points at midpoints to previous frame
  // if movement > 50 units
  // --------------------------
  Frame copyWithConditionalControlPoints(Frame previousFrame) {
    final newFrame = copy();

    if ((newFrame.p1 - previousFrame.p1).distance > 50) {
      newFrame.p1PathPoints = [
        Offset(
          (previousFrame.p1.dx + newFrame.p1.dx) / 2,
          (previousFrame.p1.dy + newFrame.p1.dy) / 2,
        )
      ];
    }

    if ((newFrame.p2 - previousFrame.p2).distance > 50) {
      newFrame.p2PathPoints = [
        Offset(
          (previousFrame.p2.dx + newFrame.p2.dx) / 2,
          (previousFrame.p2.dy + newFrame.p2.dy) / 2,
        )
      ];
    }

    if ((newFrame.p3 - previousFrame.p3).distance > 50) {
      newFrame.p3PathPoints = [
        Offset(
          (previousFrame.p3.dx + newFrame.p3.dx) / 2,
          (previousFrame.p3.dy + newFrame.p3.dy) / 2,
        )
      ];
    }

    if ((newFrame.p4 - previousFrame.p4).distance > 50) {
      newFrame.p4PathPoints = [
        Offset(
          (previousFrame.p4.dx + newFrame.p4.dx) / 2,
          (previousFrame.p4.dy + newFrame.p4.dy) / 2,
        )
      ];
    }

    if ((newFrame.ball - previousFrame.ball).distance > 50) {
      newFrame.ballPathPoints = [
        Offset(
          (previousFrame.ball.dx + newFrame.ball.dx) / 2,
          (previousFrame.ball.dy + newFrame.ball.dy) / 2,
        )
      ];
    }

    return newFrame;
  }
}

extension FrameMap on Frame {
  Map<String, dynamic> toMap() => {
        'p1': [p1.dx, p1.dy],
        'p2': [p2.dx, p2.dy],
        'p3': [p3.dx, p3.dy],
        'p4': [p4.dx, p4.dy],
        'ball': [ball.dx, ball.dy],
        'p1Rotation': p1Rotation,
        'p2Rotation': p2Rotation,
        'p3Rotation': p3Rotation,
        'p4Rotation': p4Rotation,
        'p1PathPoints': p1PathPoints.map((o) => [o.dx, o.dy]).toList(),
        'p2PathPoints': p2PathPoints.map((o) => [o.dx, o.dy]).toList(),
        'p3PathPoints': p3PathPoints.map((o) => [o.dx, o.dy]).toList(),
        'p4PathPoints': p4PathPoints.map((o) => [o.dx, o.dy]).toList(),
        'ballPathPoints': ballPathPoints.map((o) => [o.dx, o.dy]).toList(),
      };

  static Frame fromMap(Map<String, dynamic> m) => Frame(
        p1: Offset(m['p1'][0], m['p1'][1]),
        p2: Offset(m['p2'][0], m['p2'][1]),
        p3: Offset(m['p3'][0], m['p3'][1]),
        p4: Offset(m['p4'][0], m['p4'][1]),
        ball: Offset(m['ball'][0], m['ball'][1]),
        p1Rotation: (m['p1Rotation'] ?? 0).toDouble(),
        p2Rotation: (m['p2Rotation'] ?? 0).toDouble(),
        p3Rotation: (m['p3Rotation'] ?? 0).toDouble(),
        p4Rotation: (m['p4Rotation'] ?? 0).toDouble(),
        p1PathPoints: (m['p1PathPoints'] as List).map((e) => Offset(e[0], e[1])).toList(),
        p2PathPoints: (m['p2PathPoints'] as List).map((e) => Offset(e[0], e[1])).toList(),
        p3PathPoints: (m['p3PathPoints'] as List).map((e) => Offset(e[0], e[1])).toList(),
        p4PathPoints: (m['p4PathPoints'] as List).map((e) => Offset(e[0], e[1])).toList(),
        ballPathPoints: (m['ballPathPoints'] as List).map((e) => Offset(e[0], e[1])).toList(),
      );
}