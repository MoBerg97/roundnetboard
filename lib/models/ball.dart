import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'ball.g.dart';

/// Ball model with position, path, hit/set info, and color
@HiveType(typeId: 11)
class Ball extends HiveObject {
  @HiveField(0)
  Offset position;

  @HiveField(1)
  List<Offset> pathPoints;

  @HiveField(2)
  double? hitT; // Hit at param t in [0,1] along previous->current transition

  @HiveField(3)
  bool? isSet; // Set effect toggle for this transition

  @HiveField(4)
  int colorValue; // Store Color as int

  Ball({
    required this.position,
    List<Offset>? pathPoints,
    this.hitT,
    this.isSet,
    Color? color,
  })  : pathPoints = pathPoints ?? [],
        colorValue = (color ?? Colors.orange).value;

  Color get color => Color(colorValue);
  
  set color(Color value) {
    colorValue = value.value;
  }

  Ball copy() => Ball(
        position: position,
        pathPoints: List.from(pathPoints),
        hitT: hitT,
        isSet: isSet,
        color: color,
      );
}

extension BallMap on Ball {
  Map<String, dynamic> toMap() => {
        'position': [position.dx, position.dy],
        'pathPoints': pathPoints.map((o) => [o.dx, o.dy]).toList(),
        'hitT': hitT,
        'isSet': isSet,
        'color': colorValue,
      };

  static Ball fromMap(Map<String, dynamic> m) => Ball(
        position: Offset(m['position'][0], m['position'][1]),
        pathPoints: (m['pathPoints'] as List? ?? [])
            .map((e) => Offset(e[0], e[1]))
            .toList(),
        hitT: m['hitT'] != null ? (m['hitT'] as num).toDouble() : null,
        isSet: m['isSet'] as bool?,
        color: Color(m['color'] as int),
      );
}
