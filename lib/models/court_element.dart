import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'court_element.g.dart';

/// Type of court element
enum CourtElementType {
  net,
  innerCircle,
  outerCircle,
  customCircle,
  customLine,
  customRectangle,
  text,
}

/// Base court element model
@HiveType(typeId: 12)
class CourtElement extends HiveObject {
  @HiveField(0)
  int typeIndex; // Store enum as int

  @HiveField(1)
  Offset position;

  @HiveField(2)
  double? radius; // For circles

  @HiveField(3)
  Offset? endPosition; // For lines and rectangles

  @HiveField(4)
  int colorValue; // Store Color as int

  @HiveField(5)
  double strokeWidth;

  @HiveField(6)
  bool isVisible;

  @HiveField(7)
  String? text;

  @HiveField(8)
  double? fontSize;

  CourtElement({
    CourtElementType? type,
    required this.position,
    this.radius,
    this.endPosition,
    Color? color,
    this.strokeWidth = 2.0,
    this.isVisible = true,
    this.text,
    this.fontSize,
  })  : typeIndex = (type ?? CourtElementType.net).index,
      colorValue = (color ?? Colors.white).toARGB32();

  CourtElementType get type => CourtElementType.values[typeIndex];
  
  set type(CourtElementType value) {
    typeIndex = value.index;
  }

  Color get color => Color(colorValue);
  
  set color(Color value) {
    colorValue = value.toARGB32();
  }

  CourtElement copy() => CourtElement(
        type: type,
        position: position,
        radius: radius,
        endPosition: endPosition,
        color: color,
        strokeWidth: strokeWidth,
        isVisible: isVisible,
        text: text,
        fontSize: fontSize,
      );
}

extension CourtElementMap on CourtElement {
  Map<String, dynamic> toMap() => {
        'type': typeIndex,
        'position': [position.dx, position.dy],
        'radius': radius,
        'endPosition': endPosition != null ? [endPosition!.dx, endPosition!.dy] : null,
        'color': colorValue,
        'strokeWidth': strokeWidth,
        'isVisible': isVisible,
        'text': text,
        'fontSize': fontSize,
      };

  static CourtElement fromMap(Map<String, dynamic> m) => CourtElement(
        type: CourtElementType.values[m['type'] as int],
        position: Offset(m['position'][0], m['position'][1]),
        radius: m['radius'] != null ? (m['radius'] as num).toDouble() : null,
        endPosition: m['endPosition'] != null
            ? Offset(m['endPosition'][0], m['endPosition'][1])
            : null,
        color: Color(m['color'] as int),
        strokeWidth: (m['strokeWidth'] ?? 2.0).toDouble(),
        isVisible: m['isVisible'] ?? true,
        text: m['text'] as String?,
        fontSize: (m['fontSize'] as num?)?.toDouble(),
      );
}
