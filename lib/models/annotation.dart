import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../config/app_constants.dart';

part 'annotation.g.dart';

/// Annotation types
@HiveType(typeId: 5)
enum AnnotationType {
  @HiveField(0)
  line,
  @HiveField(1)
  circle,
  @HiveField(2)
  rectangle,
  @HiveField(3)
  sector,
  @HiveField(4)
  text,
  @HiveField(5)
  curvedLine,
}

enum AnnotationLineStyle { straight, arrow, dashed }

/// Annotation model for frame-specific drawings
@HiveType(typeId: 2)
class Annotation extends HiveObject {
  @HiveField(3)
  late AnnotationType type;

  @HiveField(4)
  late int colorValue; // Store as int for Hive compatibility

  @HiveField(5)
  late List<Offset> points; // For line: [start, end]; For circle: [center, radiusPoint]

  @HiveField(6)
  bool filled = false;

  @HiveField(7)
  double strokeWidthCm = AppConstants.annotationStrokeWidthCm;

  @HiveField(8)
  String? circleAnnotationId; // For sector: reference to the circle annotation

  @HiveField(9)
  double? startAngle; // For sector: start angle in radians

  @HiveField(10)
  double? endAngle; // For sector: end angle in radians

  @HiveField(11)
  String? id; // Unique identifier for this annotation (for referencing from other annotations)

  @HiveField(12)
  String? text; // For text annotations: displayed label

  @HiveField(13)
  double? fontSize; // For text annotations: font size in logical pixels

  @HiveField(14)
  int lineStyleIndex = 0;

  @HiveField(15)
  String? sectorAttachmentType;

  @HiveField(16)
  String? sectorAttachmentId;

  Annotation({
    required this.type,
    Color? color,
    required this.points,
    this.filled = false,
    this.strokeWidthCm = AppConstants.annotationStrokeWidthCm,
    this.circleAnnotationId,
    this.startAngle,
    this.endAngle,
    String? id,
    this.text,
    this.fontSize,
    AnnotationLineStyle lineStyle = AnnotationLineStyle.straight,
    this.sectorAttachmentType,
    this.sectorAttachmentId,
  }) {
    colorValue = (color ?? Colors.white).toARGB32();
    this.id = id ?? _generateId();
    lineStyleIndex = lineStyle.index;
  }

  // Empty constructor for Hive
  Annotation.empty() {
    type = AnnotationType.line;
    colorValue = Colors.white.toARGB32();
    points = [];
    filled = false;
    strokeWidthCm = AppConstants.annotationStrokeWidthCm;
    circleAnnotationId = null;
    startAngle = null;
    endAngle = null;
    id = _generateId();
    text = null;
    fontSize = null;
    lineStyleIndex = AnnotationLineStyle.straight.index;
    sectorAttachmentType = null;
    sectorAttachmentId = null;
  }

  /// Generate a unique ID for this annotation
  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 1000000)}';
  }

  /// Get color from stored value
  Color get color => Color(colorValue);

  /// Set color
  set color(Color value) => colorValue = value.toARGB32();

  /// Copy annotation
  Annotation copy() => Annotation(
    type: type,
    color: color,
    id: id,
    points: List.from(points),
    filled: filled,
    strokeWidthCm: strokeWidthCm,
    circleAnnotationId: circleAnnotationId,
    startAngle: startAngle,
    endAngle: endAngle,
    text: text,
    fontSize: fontSize,
    lineStyle: lineStyle,
    sectorAttachmentType: sectorAttachmentType,
    sectorAttachmentId: sectorAttachmentId,
  );

  AnnotationLineStyle get lineStyle {
    if (lineStyleIndex < 0 || lineStyleIndex >= AnnotationLineStyle.values.length) {
      return AnnotationLineStyle.straight;
    }
    return AnnotationLineStyle.values[lineStyleIndex];
  }

  set lineStyle(AnnotationLineStyle value) => lineStyleIndex = value.index;

  /// Get radius for circle annotations
  double? getCircleRadius() {
    if (type != AnnotationType.circle || points.length < 2) return null;
    return (points[1] - points[0]).distance;
  }
}

extension AnnotationMap on Annotation {
  Map<String, dynamic> toMap() => {
    'type': type.name,
    'id': id,
    'colorValue': colorValue,
    'points': points.map((o) => [o.dx, o.dy]).toList(),
    'filled': filled,
    'strokeWidthCm': strokeWidthCm,
    'circleAnnotationId': circleAnnotationId,
    'startAngle': startAngle,
    'endAngle': endAngle,
    'text': text,
    'fontSize': fontSize,
    'lineStyle': lineStyle.name,
    'sectorAttachmentType': sectorAttachmentType,
    'sectorAttachmentId': sectorAttachmentId,
  };

  static AnnotationLineStyle _lineStyleFromValue(dynamic value) {
    if (value is String) {
      for (final style in AnnotationLineStyle.values) {
        if (style.name == value) return style;
      }
    }
    if (value is num) {
      final idx = value.toInt();
      if (idx >= 0 && idx < AnnotationLineStyle.values.length) {
        return AnnotationLineStyle.values[idx];
      }
    }
    return AnnotationLineStyle.straight;
  }

  static Annotation fromMap(Map<String, dynamic> m) => Annotation(
    type: AnnotationType.values.firstWhere((e) => e.name == m['type']),
    color: Color(m['colorValue'] as int),
    points: (m['points'] as List).map((e) => Offset(e[0] as double, e[1] as double)).toList(),
    filled: (m['filled'] as bool?) ?? false,
    strokeWidthCm: (m['strokeWidthCm'] as num?)?.toDouble() ?? AppConstants.annotationStrokeWidthCm,
    circleAnnotationId: m['circleAnnotationId'] as String?,
    id: m['id'] as String?,
    startAngle: (m['startAngle'] as num?)?.toDouble(),
    endAngle: (m['endAngle'] as num?)?.toDouble(),
    text: m['text'] as String?,
    fontSize: (m['fontSize'] as num?)?.toDouble() ?? 20.0,
    lineStyle: _lineStyleFromValue(m['lineStyle'] ?? m['lineStyleIndex']),
    sectorAttachmentType: m['sectorAttachmentType'] as String?,
    sectorAttachmentId: m['sectorAttachmentId'] as String?,
  );
}
