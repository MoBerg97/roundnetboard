import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'settings.g.dart';

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS MODEL - Global Configuration & Screen Scaling
// ════════════════════════════════════════════════════════════════════════════
// Stores persistent configuration via Hive (local database)
// Manages court dimensions and scaling for coordinate conversion
// ════════════════════════════════════════════════════════════════════════════

@HiveType(typeId: 4)
class Settings extends HiveObject {
  // ────────────────────────────────────────────────────────────────────────────
  // PLAYBACK CONFIGURATION
  // ────────────────────────────────────────────────────────────────────────────

  /// Playback speed multiplier: 0.1x (slow) to 2.0x (fast)
  /// Default: 1.0x (normal speed)
  @HiveField(0)
  double playbackSpeed;

  // ────────────────────────────────────────────────────────────────────────────
  // COURT DIMENSIONS (in cm, standard Roundnet court)
  // ────────────────────────────────────────────────────────────────────────────

  /// Outer serve zone radius (~8.5m): contains all players and game area
  /// Default: 260cm (matches official Roundnet court)
  @HiveField(1)
  double outerCircleRadiusCm;

  /// Inner net structure radius: where the ball is played
  /// Default: 100cm
  @HiveField(2)
  double innerCircleRadiusCm;

  /// Actual net circle radius: the physical net structure
  /// Default: 46cm
  @HiveField(3)
  double netCircleRadiusCm;

  /// Outer boundary radius: full court extent (~28m diameter)
  /// Default: 850cm
  @HiveField(4)
  double outerBoundsRadiusCm;

  /// Reference scaling radius used on mobile/narrow screens
  /// Fallback when screen width > 800px (desktop-like)
  /// Default: 260cm (outer circle radius)
  @HiveField(5)
  double referenceRadiusCm;

  // ────────────────────────────────────────────────────────────────────────────
  // VISUAL PREFERENCES & TOGGLES
  // ────────────────────────────────────────────────────────────────────────────

  /// Show faded paths from two frames ago to indicate movement history
  /// Default: true
  @HiveField(6)
  bool showPreviousFrameLines;

  /// Show curved path control points on board during editing
  /// When false, control points only appear while actively editing a path
  /// Default: false (hidden by default for cleaner UI)
  @HiveField(7)
  bool showPathControlPoints;

  /// Multiplier applied to player and ball marker sizes (1.0x, 1.5x, 2.2x)
  /// Default: 1.5x for better visibility on most screens
  @HiveField(8)
  double objectScaleMultiplier;

  /// Court serve zone scaling factor for coordinate conversion
  /// Options: 1.0 (tight), 1.3 (balanced), 1.6 (wide)
  /// Default: 1.3 for most use cases
  @HiveField(9, defaultValue: 1.3)
  double serveZoneFactor;

  Settings({
    this.playbackSpeed = 1.0,
    this.outerCircleRadiusCm = 260.0,
    this.innerCircleRadiusCm = 100.0,
    this.netCircleRadiusCm = 46.0,
    this.outerBoundsRadiusCm = 850.0,
    this.referenceRadiusCm = 260.0,
    this.showPreviousFrameLines = true,
    this.showPathControlPoints = false,
    this.objectScaleMultiplier = 1.5,
    this.serveZoneFactor = 1.3,
  });

  // Converts cm to logical units (pixels)
  // Adaptive fit: use 1.2× serve zone on narrow (mobile-like) widths for larger default zoom, 1.4× otherwise (Windows-friendly)
  // This makes the court larger on mobile phones by default, with zoom level adjustable in future updates
  double cmToLogical(double cm, Size screenSize) {
    const double padding = 50;
    final halfMinScreen = (screenSize.shortestSide / 2) - padding;

    // Use the user-configured serve zone factor for scaling
    final double serveZoneRadius = outerCircleRadiusCm;
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
    objectScaleMultiplier: objectScaleMultiplier,
    serveZoneFactor: serveZoneFactor,
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
          showPathControlPoints == other.showPathControlPoints &&
          objectScaleMultiplier == other.objectScaleMultiplier &&
          serveZoneFactor == other.serveZoneFactor;

  @override
  int get hashCode =>
      playbackSpeed.hashCode ^
      outerCircleRadiusCm.hashCode ^
      innerCircleRadiusCm.hashCode ^
      netCircleRadiusCm.hashCode ^
      outerBoundsRadiusCm.hashCode ^
      referenceRadiusCm.hashCode ^
      showPreviousFrameLines.hashCode ^
      showPathControlPoints.hashCode ^
      objectScaleMultiplier.hashCode ^
      serveZoneFactor.hashCode;
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
    'objectScaleMultiplier': objectScaleMultiplier,
    'serveZoneFactor': serveZoneFactor,
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
    objectScaleMultiplier: (m['objectScaleMultiplier'] ?? 1.5).toDouble(),
    serveZoneFactor: (m['serveZoneFactor'] ?? 1.3).toDouble(),
  );
}
