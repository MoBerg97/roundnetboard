import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

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
  @HiveField(6)
  bool showPreviousFrameLines;

  @HiveField(7)
  bool showPathControlPoints;

  Settings({
    this.playbackSpeed = 1.0,
    this.outerCircleRadiusCm = 260.0,
    this.innerCircleRadiusCm = 100.0,
    this.netCircleRadiusCm = 46.0,
    this.outerBoundsRadiusCm = 850.0,
    this.referenceRadiusCm = 260.0,
    this.showPreviousFrameLines = true,
    this.showPathControlPoints = false,
  });

  // Converts cm to logical units (pixels)
  // Adaptive fit: use 1.1× serve zone on narrow (mobile-like) widths, 1.5× otherwise (Windows-friendly)
  double cmToLogical(double cm, Size screenSize) {
    const double padding = 50;
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 120;
    final usableHeight = screenSize.height - appBarHeight - timelineHeight;
    final usableWidth = screenSize.width;
    final halfMinScreen = (usableHeight < usableWidth ? usableHeight : usableWidth) / 2 - padding;

    // Heuristic: widths up to 800px behave like mobile/tablet; above that treat as desktop.
    final bool isMobileLikeWidth = screenSize.width <= 800;
    final double serveZoneRadius = outerCircleRadiusCm;
    final double serveZoneFactor = isMobileLikeWidth ? 1.1 : 1.5;
    final double targetReference = serveZoneRadius * serveZoneFactor;
    final double safeReference = targetReference == 0 ? 1.0 : targetReference;
    return cm * (halfMinScreen / safeReference);
  }

  // Convenience getters for logical units
  double get outerCircleRadiusPx => cmToLogical(outerCircleRadiusCm, _lastScreenSize);
  double get innerCircleRadiusPx => cmToLogical(innerCircleRadiusCm, _lastScreenSize);
  double get netCircleRadiusPx => cmToLogical(netCircleRadiusCm, _lastScreenSize);
  double get outerBoundsRadiusPx => cmToLogical(outerBoundsRadiusCm, _lastScreenSize);

  // Store last used screen size for conversion
  static Size _lastScreenSize = const Size(0, 0);
  static void setScreenSize(Size size) => _lastScreenSize = size;

  /// Create a deep copy of settings
  Settings copy() => Settings(
    playbackSpeed: playbackSpeed,
    outerCircleRadiusCm: outerCircleRadiusCm,
    innerCircleRadiusCm: innerCircleRadiusCm,
    netCircleRadiusCm: netCircleRadiusCm,
    outerBoundsRadiusCm: outerBoundsRadiusCm,
    referenceRadiusCm: referenceRadiusCm,
    showPreviousFrameLines: showPreviousFrameLines,
    showPathControlPoints: showPathControlPoints,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settings &&
          runtimeType == other.runtimeType &&
          playbackSpeed == other.playbackSpeed &&
          outerCircleRadiusCm == other.outerCircleRadiusCm &&
          innerCircleRadiusCm == other.innerCircleRadiusCm &&
          netCircleRadiusCm == other.netCircleRadiusCm &&
          outerBoundsRadiusCm == other.outerBoundsRadiusCm &&
          referenceRadiusCm == other.referenceRadiusCm &&
          showPreviousFrameLines == other.showPreviousFrameLines &&
          showPathControlPoints == other.showPathControlPoints;

  @override
  int get hashCode =>
      playbackSpeed.hashCode ^
      outerCircleRadiusCm.hashCode ^
      innerCircleRadiusCm.hashCode ^
      netCircleRadiusCm.hashCode ^
      outerBoundsRadiusCm.hashCode ^
      referenceRadiusCm.hashCode ^
      showPreviousFrameLines.hashCode ^
      showPathControlPoints.hashCode;
}

extension SettingsMap on Settings {
  Map<String, dynamic> toMap() => {
    'playbackSpeed': playbackSpeed,
    'outerCircleRadiusCm': outerCircleRadiusCm,
    'innerCircleRadiusCm': innerCircleRadiusCm,
    'netCircleRadiusCm': netCircleRadiusCm,
    'outerBoundsRadiusCm': outerBoundsRadiusCm,
    'referenceRadiusCm': referenceRadiusCm,
    'showPreviousFrameLines': showPreviousFrameLines,
    'showPathControlPoints': showPathControlPoints,
  };

  static Settings fromMap(Map<String, dynamic> m) => Settings(
    playbackSpeed: (m['playbackSpeed'] ?? 1.0).toDouble(),
    outerCircleRadiusCm: (m['outerCircleRadiusCm'] ?? 260.0).toDouble(),
    innerCircleRadiusCm: (m['innerCircleRadiusCm'] ?? 100.0).toDouble(),
    netCircleRadiusCm: (m['netCircleRadiusCm'] ?? 46.0).toDouble(),
    outerBoundsRadiusCm: (m['outerBoundsRadiusCm'] ?? 850.0).toDouble(),
    referenceRadiusCm: (m['referenceRadiusCm'] ?? 260.0).toDouble(),
    showPreviousFrameLines: (m['showPreviousFrameLines'] ?? true) as bool,
    showPathControlPoints: (m['showPathControlPoints'] ?? false) as bool,
  );
}
