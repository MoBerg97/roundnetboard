import 'package:flutter/material.dart';

/// Application-wide constants for RoundnetBoard.
///
/// Defines animation durations, layout dimensions, court measurements,
/// and other constant values used throughout the app.
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // Animation durations

  /// Short animation duration (e.g., button press, icon change)
  static const Duration shortAnimation = Duration(milliseconds: 200);

  /// Medium animation duration (e.g., page transitions, dialog appearance)
  static const Duration mediumAnimation = Duration(milliseconds: 300);

  /// Long animation duration (e.g., complex transitions)
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Layout constants

  /// Standard app bar height
  static const double appBarHeight = kToolbarHeight;

  /// Timeline height when editing frames
  static const double timelineHeightEditing = 120.0;

  /// Timeline height during playback
  static const double timelineHeightPlayback = 80.0;

  /// Standard padding (16dp)
  static const double padding = 16.0;

  /// Small padding (8dp)
  static const double paddingSmall = 8.0;

  /// Large padding (24dp)
  static const double paddingLarge = 24.0;

  /// Extra large padding (32dp)
  static const double paddingXLarge = 32.0;

  /// Standard border radius (12dp)
  static const double borderRadius = 12.0;

  /// Small border radius (8dp)
  static const double borderRadiusSmall = 8.0;

  /// Minimum touch target size (accessibility)
  static const double minTouchTarget = 48.0;

  /// Card elevation
  static const double cardElevation = 2.0;

  // Court dimensions (in centimeters)

  /// Default outer circle diameter
  static const double defaultOuterCircle = 260.0;

  /// Default inner circle diameter
  static const double defaultInnerCircle = 100.0;

  /// Default net circle diameter
  static const double defaultNetCircle = 46.0;

  /// Default outer bounds (court perimeter)
  static const double defaultOuterBounds = 850.0;

  /// Default reference measurement
  static const double defaultReference = 260.0;

  // Player & ball settings

  /// Default player marker radius in cm (scaled via Settings.cmToLogical)
  static const double playerRadiusCm = 18.0;

  /// Default ball marker radius in cm (scaled via Settings.cmToLogical)
  static const double ballRadiusCm = 9.0;

  /// Path stroke width in cm (scaled)
  static const double pathStrokeWidthCm = 1.2;

  /// Annotation stroke width in cm (scaled)
  static const double annotationStrokeWidthCm = 1.0;

  /// Default radius for tap-added circles (cm)
  static const double defaultCircleRadiusCm = 30.0;

  // Animation settings

  /// Default frame duration (milliseconds)
  static const int defaultFrameDuration = 1000;

  /// Minimum frame duration (milliseconds)
  static const int minFrameDuration = 100;

  /// Maximum frame duration (milliseconds)
  static const int maxFrameDuration = 10000;

  /// Playback timer interval (milliseconds)
  static const int playbackTimerInterval = 16; // ~60 FPS

  // File & export settings

  /// Export file extension
  static const String exportFileExtension = 'json';

  /// JSON indent spaces for pretty printing
  static const int jsonIndentSpaces = 2;

  /// Default export file name prefix
  static const String defaultExportPrefix = 'roundnet_project_';

  // Feature flags

  /// Enable Firebase Analytics
  static const bool enableFirebaseAnalytics = true;

  /// Enable Firebase Crashlytics
  static const bool enableFirebaseCrashlytics = true;

  // Database

  /// Hive box name for projects
  static const String projectsBoxName = 'animationProjects';

  /// Hive box name for settings
  static const String settingsBoxName = 'userSettings';

  // Undo/Redo

  /// Maximum history size for undo/redo
  static const int maxHistorySize = 50;

  // Miscellaneous

  /// Maximum project name length
  static const int maxProjectNameLength = 100;

  /// Dialog border radius
  static const double dialogBorderRadius = 12.0;

  /// Snackbar duration
  static const Duration snackbarDuration = Duration(seconds: 3);
}
