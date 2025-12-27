import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'player.g.dart';

/// Player model with position, rotation, path, and color
@HiveType(typeId: 10)
class Player extends HiveObject {
  @HiveField(0)
  Offset position;

  @HiveField(1)
  double rotation;

  @HiveField(2)
  List<Offset> pathPoints;

  @HiveField(3)
  int colorValue; // Store Color as int

  @HiveField(4)
  String id; // Unique identifier (UUID for training, P1-P4 for play)

  Player({required this.position, this.rotation = 0, List<Offset>? pathPoints, Color? color, String? id})
    : pathPoints = pathPoints ?? [],
      colorValue = (color ?? Colors.blue).toARGB32(),
      id = id ?? const Uuid().v4();

  Color get color => Color(colorValue);

  set color(Color value) {
    colorValue = value.toARGB32();
  }

  Player copy() => Player(
    position: position,
    rotation: rotation,
    pathPoints: [], // Don't copy path points - make them frame-specific
    color: color,
    id: id,
  );
}

extension PlayerMap on Player {
  Map<String, dynamic> toMap() => {
    'position': [position.dx, position.dy],
    'rotation': rotation,
    'pathPoints': pathPoints.map((o) => [o.dx, o.dy]).toList(),
    'color': colorValue,
    'id': id,
  };

  static Player fromMap(Map<String, dynamic> m) => Player(
    position: Offset(m['position'][0], m['position'][1]),
    rotation: (m['rotation'] ?? 0).toDouble(),
    pathPoints: (m['pathPoints'] as List? ?? []).map((e) => Offset(e[0], e[1])).toList(),
    color: Color(m['color'] as int),
    id: m['id'] as String?,
  );
}
