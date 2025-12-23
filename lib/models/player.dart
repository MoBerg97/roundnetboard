import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

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

  Player({
    required this.position,
    this.rotation = 0,
    List<Offset>? pathPoints,
    Color? color,
  })  : pathPoints = pathPoints ?? [],
        colorValue = (color ?? Colors.blue).value;

  Color get color => Color(colorValue);
  
  set color(Color value) {
    colorValue = value.value;
  }

  Player copy() => Player(
        position: position,
        rotation: rotation,
        pathPoints: List.from(pathPoints),
        color: color,
      );
}

extension PlayerMap on Player {
  Map<String, dynamic> toMap() => {
        'position': [position.dx, position.dy],
        'rotation': rotation,
        'pathPoints': pathPoints.map((o) => [o.dx, o.dy]).toList(),
        'color': colorValue,
      };

  static Player fromMap(Map<String, dynamic> m) => Player(
        position: Offset(m['position'][0], m['position'][1]),
        rotation: (m['rotation'] ?? 0).toDouble(),
        pathPoints: (m['pathPoints'] as List? ?? [])
            .map((e) => Offset(e[0], e[1]))
            .toList(),
        color: Color(m['color'] as int),
      );
}
