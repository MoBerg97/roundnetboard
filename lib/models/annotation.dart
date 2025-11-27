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
    colorValue = (color ?? Colors.white).value;
  }

  // Empty constructor for Hive
  Annotation.empty() {
    type = AnnotationType.line;
    colorValue = Colors.white.value;
    points = [];
  }

  /// Get color from stored value
  Color get color => Color(colorValue);

  /// Set color
  set color(Color value) => colorValue = value.value;

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
