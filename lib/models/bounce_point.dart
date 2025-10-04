import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'bounce_point.g.dart';

@HiveType(typeId: 7)
class BouncePoint{

  @HiveField(0)
  final Offset position;

  @HiveField(1)
  final double minScale;

  @HiveField(2)
  final double endScale;

  @HiveField(3)
  final int starDurationMs;

  @HiveField(4)
  final bool showStar;

  BouncePoint({
    required this.position,
    this.minScale = 0.7,
    this.endScale = 1.0,
    this.starDurationMs = 220,
    this.showStar = true,
  });
}