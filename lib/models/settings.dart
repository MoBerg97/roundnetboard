import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 4) 
class Settings extends HiveObject {

  @HiveField(0)
  double playbackSpeed;

  @HiveField(1)
  double outerCircleRadius;

  @HiveField(2)
  double innerCircleRadius;

  @HiveField(3)
  double netCircleRadius;

  @HiveField(4)
  double outerBoundsRadius = 850.0;

  Settings({
    this.playbackSpeed = 1.0,
    this.outerCircleRadius = 260.0,
    this.innerCircleRadius = 100.0,
    this.netCircleRadius = 46,
  });
}
