import 'package:hive/hive.dart';
import 'dart:ui';
import 'annotation.dart';
import 'player.dart';
import 'ball.dart';

part 'frame.g.dart';

// ════════════════════════════════════════════════════════════════════════════
// FRAME MODEL - Single Animation Keyframe with Players, Balls & Annotations
// ════════════════════════════════════════════════════════════════════════════
// Represents a snapshot of the game state at one point in time
// Stores dynamic lists of players/balls with arbitrary counts
// Includes per-frame duration for playback timing and annotations
// ════════════════════════════════════════════════════════════════════════════

@HiveType(typeId: 1)
class Frame extends HiveObject {
  // ════════════════════════════════════════════════════════════════════════════
  // DYNAMIC ENTITY COLLECTIONS
  // ════════════════════════════════════════════════════════════════════════════
  // Lists support arbitrary player/ball counts (not limited to 4 players)
  // Each frame is independent; entities carry unique IDs across frames
  @HiveField(0)
  List<Player> players;

  @HiveField(1)
  List<Ball> balls;

  // ════════════════════════════════════════════════════════════════════════════
  // PLAYBACK TIMING
  // ════════════════════════════════════════════════════════════════════════════
  // Duration between this frame and next during playback
  // Supports variable frame durations for realistic timing
  @HiveField(2)
  double duration;

  // ════════════════════════════════════════════════════════════════════════════
  // FRAME ANNOTATIONS
  // ════════════════════════════════════════════════════════════════════════════
  // Visual markup per-frame: lines, circles, rectangles, erasures
  // Annotations are frame-specific; not interpolated across keyframes
  @HiveField(3)
  List<Annotation> annotations;

  // ════════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR & INITIALIZATION
  // ════════════════════════════════════════════════════════════════════════════
  Frame({
    List<Player>? players,
    List<Ball>? balls,
    this.duration = 0.5,
    List<Annotation>? annotations,
  })  : players = players ?? [],
        balls = balls ?? [],
        annotations = annotations ?? [];

  // --------------------------
  // Copy frame (deep copy)
  // --------------------------
  Frame copy() => Frame(
        players: players.map((p) => p.copy()).toList(),
        balls: balls.map((b) => b.copy()).toList(),
        duration: duration,
        annotations: annotations.map((a) => a.copy()).toList(),
      );

  // ════════════════════════════════════════════════════════════════════════════
  // SPECIALIZED COPY OPERATIONS
  // ════════════════════════════════════════════════════════════════════════════
  // Support conditional copying for specific animation workflows
  Frame copyWithoutHitSetMarkers() => Frame(
        players: players.map((p) => p.copy()).toList(),
        balls: balls.map((b) => Ball(
          position: b.position,
          pathPoints: List.from(b.pathPoints),
          color: b.color,
          id: b.id,
          // hitT and isSet are NOT copied (reset to null/false)
        )).toList(),
        duration: duration,
        annotations: annotations.map((a) => a.copy()).toList(),
      );

  // ════════════════════════════════════════════════════════════════════════════
  // CONDITIONAL CONTROL POINT INITIALIZATION
  // ════════════════════════════════════════════════════════════════════════════
  // Smooths movement transitions when distance exceeds threshold

  /// Copy and conditionally initialize midpoint control points
  /// Sets control point to midpoint between previous/current if distance > 50 units
  /// Creates smooth easing for large jumps; skips small movements
  ///
  /// Key parameters:
  ///   - distance threshold: 50 units (independent coords system)
  ///   - control point placement: (prev + curr) / 2 for mid-frame arc
  Frame copyWithConditionalControlPoints(Frame previousFrame) {
    final newFrame = copy();

    // Process players
    for (int i = 0; i < newFrame.players.length && i < previousFrame.players.length; i++) {
      final currPlayer = newFrame.players[i];
      final prevPlayer = previousFrame.players[i];
      
      if ((currPlayer.position - prevPlayer.position).distance > 50) {
        currPlayer.pathPoints = [
          Offset(
            (prevPlayer.position.dx + currPlayer.position.dx) / 2,
            (prevPlayer.position.dy + currPlayer.position.dy) / 2,
          )
        ];
      }
    }

    // Process balls
    for (int i = 0; i < newFrame.balls.length && i < previousFrame.balls.length; i++) {
      final currBall = newFrame.balls[i];
      final prevBall = previousFrame.balls[i];
      
      if ((currBall.position - prevBall.position).distance > 50) {
        currBall.pathPoints = [
          Offset(
            (prevBall.position.dx + currBall.position.dx) / 2,
            (prevBall.position.dy + currBall.position.dy) / 2,
          )
        ];
      }
    }

    return newFrame;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ID-BASED ENTITY LOOKUP & REMOVAL
  // ════════════════════════════════════════════════════════════════════════════
  // O(n) lookup by entity ID; returns null if not found
  // Supports dynamic removal with return status confirmation
  Player? getPlayerById(String id) {
    try {
      return players.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get ball by ID, returns null if not found
  Ball? getBallById(String id) {
    try {
      return balls.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Remove player by ID, returns true if removed
  bool removePlayerById(String id) {
    final index = players.indexWhere((p) => p.id == id);
    if (index >= 0) {
      players.removeAt(index);
      return true;
    }
    return false;
  }

  /// Remove ball by ID, returns true if removed
  bool removeBallById(String id) {
    final index = balls.indexWhere((b) => b.id == id);
    if (index >= 0) {
      balls.removeAt(index);
      return true;
    }
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BACKWARD COMPATIBILITY: LEGACY PLAYER/BALL ACCESSORS
  // ════════════════════════════════════════════════════════════════════════════
  // Support old code using p1..p4 and ball properties
  // Gracefully handle missing entities; return defaults for out-of-range indices
  /// Get p1 (first player) position - for backward compatibility
  Offset get p1 => players.isNotEmpty ? players[0].position : Offset.zero;
  set p1(Offset value) {
    if (players.isNotEmpty) players[0].position = value;
  }

  /// Get p2 (second player) position
  Offset get p2 => players.length > 1 ? players[1].position : Offset.zero;
  set p2(Offset value) {
    if (players.length > 1) players[1].position = value;
  }

  /// Get p3 (third player) position
  Offset get p3 => players.length > 2 ? players[2].position : Offset.zero;
  set p3(Offset value) {
    if (players.length > 2) players[2].position = value;
  }

  /// Get p4 (fourth player) position
  Offset get p4 => players.length > 3 ? players[3].position : Offset.zero;
  set p4(Offset value) {
    if (players.length > 3) players[3].position = value;
  }

  /// Get ball position
  Offset get ball => balls.isNotEmpty ? balls[0].position : Offset.zero;
  set ball(Offset value) {
    if (balls.isNotEmpty) balls[0].position = value;
  }

  /// Get p1 rotation
  double get p1Rotation => players.isNotEmpty ? players[0].rotation : 0;
  set p1Rotation(double value) {
    if (players.isNotEmpty) players[0].rotation = value;
  }

  /// Get p2 rotation
  double get p2Rotation => players.length > 1 ? players[1].rotation : 0;
  set p2Rotation(double value) {
    if (players.length > 1) players[1].rotation = value;
  }

  /// Get p3 rotation
  double get p3Rotation => players.length > 2 ? players[2].rotation : 0;
  set p3Rotation(double value) {
    if (players.length > 2) players[2].rotation = value;
  }

  /// Get p4 rotation
  double get p4Rotation => players.length > 3 ? players[3].rotation : 0;
  set p4Rotation(double value) {
    if (players.length > 3) players[3].rotation = value;
  }

  /// Get p1 path points
  List<Offset> get p1PathPoints => players.isNotEmpty ? players[0].pathPoints : [];

  /// Get p2 path points
  List<Offset> get p2PathPoints => players.length > 1 ? players[1].pathPoints : [];

  /// Get p3 path points
  List<Offset> get p3PathPoints => players.length > 2 ? players[2].pathPoints : [];

  /// Get p4 path points
  List<Offset> get p4PathPoints => players.length > 3 ? players[3].pathPoints : [];

  /// Get ball path points
  List<Offset> get ballPathPoints => balls.isNotEmpty ? balls[0].pathPoints : [];

  /// Get ball hit time
  double? get ballHitT => balls.isNotEmpty ? balls[0].hitT : null;
  set ballHitT(double? value) {
    if (balls.isNotEmpty) balls[0].hitT = value;
  }

  /// Get ball set flag
  bool? get ballSet => balls.isNotEmpty ? balls[0].isSet : null;
  set ballSet(bool? value) {
    if (balls.isNotEmpty) balls[0].isSet = value;
  }
}

extension FrameMap on Frame {
  // ════════════════════════════════════════════════════════════════════════════
  // SERIALIZATION & DESERIALIZATION
  // ════════════════════════════════════════════════════════════════════════════
  // JSON-compatible map conversion for export/import and database persistence
  Map<String, dynamic> toMap() => {
        'players': players.map((p) => PlayerMap(p).toMap()).toList(),
        'balls': balls.map((b) => BallMap(b).toMap()).toList(),
        'duration': duration,
        'annotations': annotations.map((a) => a.toMap()).toList(),
      };

  static Frame fromMap(Map<String, dynamic> m) => Frame(
        players: (m['players'] as List? ?? [])
            .map((e) => PlayerMap.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        balls: (m['balls'] as List? ?? [])
            .map((e) => BallMap.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        duration: (m['duration'] ?? 0.5).toDouble(),
        annotations: (m['annotations'] as List? ?? [])
            .map((e) => AnnotationMap.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
