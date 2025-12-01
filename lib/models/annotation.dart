import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'annotation.g.dart';

/// Annotation types
@HiveType(typeId: 5)
enum AnnotationType {
  @HiveField(0)
  line,
  @HiveField(1)
  circle,
}

/// Annotation model for frame-specific drawings
@HiveType(typeId: 2)
class Annotation extends HiveObject {
  @HiveField(3)
  late AnnotationType type;

  @HiveField(4)
  late int colorValue; // Store as int for Hive compatibility

  @HiveField(5)
  late List<Offset> points; // For line: [start, end]; For circle: [center, radiusPoint]

  Annotation({
    required this.type,
    Color? color,
    required this.points,
  }) {
    colorValue = (color ?? Colors.white).toARGB32();
  }

  // Empty constructor for Hive
  Annotation.empty() {
    type = AnnotationType.line;
    colorValue = Colors.white.toARGB32();
    points = [];
  }

  /// Get color from stored value
  Color get color => Color(colorValue);

  /// Set color
  set color(Color value) => colorValue = value.toARGB32();

  /// Copy annotation
  Annotation copy() => Annotation(
        type: type,
        color: color,
        points: List.from(points),
      );

  /// Get radius for circle annotations
  double? getCircleRadius() {
    if (type != AnnotationType.circle || points.length < 2) return null;
    return (points[1] - points[0]).distance;
  }
}

extension AnnotationMap on Annotation {
  Map<String, dynamic> toMap() => {
        'type': type.name,
        'colorValue': colorValue,
        'points': points.map((o) => [o.dx, o.dy]).toList(),
      };

  static Annotation fromMap(Map<String, dynamic> m) => Annotation(
        type: AnnotationType.values.firstWhere((e) => e.name == m['type']),
        color: Color(m['colorValue'] as int),
        points: (m['points'] as List).map((e) => Offset(e[0] as double, e[1] as double)).toList(),
      );
}
