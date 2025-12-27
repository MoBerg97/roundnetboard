import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Feature identifiers grouped by screen/flow for clarity.
class TutorialIds {
  // Home flow
  static const String homeAddProject = 'feature_add_project';
  static const String homeImportProject = 'feature_import_project';
  static const String homeOpenProject = 'feature_open_project';

  // Board flow (reserved for future overlay steps)
  static const String boardTimeline = 'feature_board_timeline';
  static const String boardCanvas = 'feature_board_canvas';
  static const String boardAnnotation = 'feature_board_annotation';
}

/// High-level tutorial flows. Only the Home flow is wired for now; Board will
/// reuse the same overlay pattern later.
enum TutorialFlow { home, board }

/// Centralized tutorial coordinator that drives the overlay experience.
///
/// Uses the `feature_discovery` package to render modern spotlights while
/// keeping state (active flow, isActive flag) in a Provider-friendly service.
class TutorialService with ChangeNotifier {
  bool _isActive = false;
  TutorialFlow? _activeFlow;

  bool get isActive => _isActive;
  TutorialFlow? get activeFlow => _activeFlow;

  /// Start the Home tutorial flow (overlay-only) with optional project step.
  Future<void> startHomeTutorial(BuildContext context, {required bool hasProject}) async {
    final features = <String>[
      TutorialIds.homeAddProject,
      TutorialIds.homeImportProject,
      if (hasProject) TutorialIds.homeOpenProject,
    ];
    await _startFeatureSequence(context, TutorialFlow.home, features);
  }

  /// Placeholder: Board tutorial flow will reuse the same overlay infrastructure.
  Future<void> startBoardTutorial(BuildContext context) async {
    final features = <String>[TutorialIds.boardTimeline, TutorialIds.boardCanvas, TutorialIds.boardAnnotation];
    await _startFeatureSequence(context, TutorialFlow.board, features);
  }

  /// Exposed helper to trigger medium haptic feedback when a step completes.
  Future<bool> acknowledgeStepCompletion() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // no-op on platforms without haptics
    }
    return true;
  }

  Future<void> _startFeatureSequence(BuildContext context, TutorialFlow flow, List<String> featureIds) async {
    if (featureIds.isEmpty) return;

    _isActive = true;
    _activeFlow = flow;
    notifyListeners();

    // Clear previous progress so the user always sees the full flow.
    await FeatureDiscovery.clearPreferences(context, featureIds);

    // Launch the overlay sequence on next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FeatureDiscovery.discoverFeatures(context, featureIds);
    });

    _isActive = false;
    _activeFlow = null;
    notifyListeners();
  }
}
