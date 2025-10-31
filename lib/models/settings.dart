import 'package:hive/hive.dart';

import 'package:flutter/material.dart';

part 'settings.g.dart';

@HiveType(typeId: 4)
class Settings extends HiveObject {
  @HiveField(0)
  double playbackSpeed;

  @HiveField(1)
  double outerCircleRadiusCm;

  @HiveField(2)
  double innerCircleRadiusCm;

  @HiveField(3)
  double netCircleRadiusCm;

  @HiveField(4)
  double outerBoundsRadiusCm;

  @HiveField(5)
  double referenceRadiusCm;

  Settings({
    this.playbackSpeed = 1.0,
    this.outerCircleRadiusCm = 260.0,
    this.innerCircleRadiusCm = 100.0,
    this.netCircleRadiusCm = 46.0,
    this.outerBoundsRadiusCm = 850.0,
    this.referenceRadiusCm = 260.0,
  });

  // Converts cm to logical units (pixels)
  double cmToLogical(double cm, Size screenSize) {
    const double padding = 50;
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 120;
    final usableHeight = screenSize.height - appBarHeight - timelineHeight;
    final usableWidth = screenSize.width;
    final halfMinScreen =
        (usableHeight < usableWidth ? usableHeight : usableWidth) / 2 - padding;
    return cm * (halfMinScreen / referenceRadiusCm);
  }

  // Convenience getters for logical units
  double get outerCircleRadiusPx => cmToLogical(outerCircleRadiusCm, _lastScreenSize);
  double get innerCircleRadiusPx => cmToLogical(innerCircleRadiusCm, _lastScreenSize);
  double get netCircleRadiusPx => cmToLogical(netCircleRadiusCm, _lastScreenSize);
  double get outerBoundsRadiusPx => cmToLogical(outerBoundsRadiusCm, _lastScreenSize);

  // Store last used screen size for conversion
  static Size _lastScreenSize = const Size(0, 0);
  static void setScreenSize(Size size) => _lastScreenSize = size;
}

extension SettingsMap on Settings {
  Map<String, dynamic> toMap() => {
        'playbackSpeed': playbackSpeed,
        'outerCircleRadiusCm': outerCircleRadiusCm,
        'innerCircleRadiusCm': innerCircleRadiusCm,
        'netCircleRadiusCm': netCircleRadiusCm,
        'outerBoundsRadiusCm': outerBoundsRadiusCm,
        'referenceRadiusCm': referenceRadiusCm,
      };

  static Settings fromMap(Map<String, dynamic> m) => Settings(
        playbackSpeed: (m['playbackSpeed'] ?? 1.0).toDouble(),
        outerCircleRadiusCm: (m['outerCircleRadiusCm'] ?? 260.0).toDouble(),
        innerCircleRadiusCm: (m['innerCircleRadiusCm'] ?? 100.0).toDouble(),
        netCircleRadiusCm: (m['netCircleRadiusCm'] ?? 46.0).toDouble(),
        outerBoundsRadiusCm: (m['outerBoundsRadiusCm'] ?? 850.0).toDouble(),
        referenceRadiusCm: (m['referenceRadiusCm'] ?? 260.0).toDouble(),
      );
}