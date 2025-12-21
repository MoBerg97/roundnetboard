import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TutorialType { home, board, annotation }

/// Configuration for a single tutorial step
class TutorialStep {
  final String id;
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final bool requiresDrag;
  final String? dragTargetId; // Which widget should be draggable (e.g., 'P1', 'P2', 'BALL')
  final Offset? targetPosition; // Target position in cm (for drag steps)
  final double? targetProximity; // Required proximity in cm
  final bool isConditional; // If true, Next is disabled until action is performed
  final bool showSuccess; // If true, show success animation when step is completed
  final VoidCallback? autoPerformAction; // Action to perform when Next is tapped while disabled

  const TutorialStep({
    required this.id,
    required this.title,
    required this.description,
    this.targetKey,
    this.requiresDrag = false,
    this.dragTargetId,
    this.targetPosition,
    this.targetProximity,
    this.isConditional = false,
    this.showSuccess = false,
    this.autoPerformAction,
  });
}

class TutorialService extends ChangeNotifier {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  TutorialType? _pendingTutorial;
  bool _isActive = false;
  int _currentStepIndex = 0;
  List<TutorialStep> _steps = [];
  bool _showSuccessEffect = false;
  int _movedObjectsCount = 0;

  TutorialType? get pendingTutorial => _pendingTutorial;
  bool get isActive => _isActive;
  int get currentStepIndex => _currentStepIndex;
  TutorialStep? get currentStep => _isActive && _currentStepIndex < _steps.length ? _steps[_currentStepIndex] : null;
  List<TutorialStep> get steps => _steps;
  bool get showSuccessEffect => _showSuccessEffect;
  int get movedObjectsCount => _movedObjectsCount;

  void setMovedObjectsCount(int count) {
    _movedObjectsCount = count;
    notifyListeners();
  }

  void requestTutorial(TutorialType type) {
    _pendingTutorial = type;
    notifyListeners();
  }

  void startTutorial(TutorialType type, List<TutorialStep> steps) {
    _pendingTutorial = null;
    _currentStepIndex = 0;
    _steps = steps;
    _showSuccessEffect = false;

    // No steps? End immediately so UI stays interactive.
    if (steps.isEmpty) {
      _isActive = false;
      notifyListeners();
      return;
    }

    _isActive = true;
    notifyListeners();
  }

  void updateStepTarget(String id, Offset position) {
    final index = _steps.indexWhere((s) => s.id == id);
    if (index != -1) {
      final oldStep = _steps[index];
      _steps[index] = TutorialStep(
        id: oldStep.id,
        title: oldStep.title,
        description: oldStep.description,
        targetKey: oldStep.targetKey,
        requiresDrag: oldStep.requiresDrag,
        dragTargetId: oldStep.dragTargetId,
        targetPosition: position,
        targetProximity: oldStep.targetProximity,
        isConditional: oldStep.isConditional,
        showSuccess: oldStep.showSuccess,
        autoPerformAction: oldStep.autoPerformAction,
      );
      notifyListeners();
    }
  }

  void nextStep() {
    final step = currentStep;
    final shouldShowEffect = step != null && step.showSuccess;

    if (_currentStepIndex < _steps.length - 1) {
      if (shouldShowEffect) {
        _triggerSuccessEffect();
        Future.delayed(const Duration(milliseconds: 800), () {
          _currentStepIndex++;
          _showSuccessEffect = false;
          notifyListeners();
        });
      } else {
        _currentStepIndex++;
        notifyListeners();
      }
    } else {
      if (shouldShowEffect) {
        _triggerSuccessEffect();
        Future.delayed(const Duration(milliseconds: 800), () {
          finishTutorial();
        });
      } else {
        finishTutorial();
      }
    }
  }

  void _triggerSuccessEffect() {
    _showSuccessEffect = true;
    notifyListeners();
    // Play a subtle success sound
    SystemSound.play(SystemSoundType.click);
  }

  void previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      notifyListeners();
    }
  }

  void finishTutorial() {
    _isActive = false;
    _currentStepIndex = 0;
    _steps = [];
    _showSuccessEffect = false;
    notifyListeners();
  }

  void clearPendingTutorial() {
    _pendingTutorial = null;
    notifyListeners();
  }

  /// Validate if a drag gesture meets the requirements for the current step
  bool validateDragForCurrentStep(String draggedId, Offset finalPosition) {
    final step = currentStep;
    if (step == null || !step.requiresDrag) return false;

    // Check if the dragged object matches the expected target
    if (step.dragTargetId != null && step.dragTargetId != draggedId) {
      return false;
    }

    // Check if position requirement exists
    if (step.targetPosition != null && step.targetProximity != null) {
      final distance = (finalPosition - step.targetPosition!).distance;
      return distance <= step.targetProximity!;
    }

    // No specific position requirement, any drag is valid
    return true;
  }

  /// Mark tutorial as completed in persistent storage
  Future<void> markTutorialCompleted(TutorialType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_${type.name}_completed', true);
  }

  /// Check if a tutorial has been completed
  Future<bool> isTutorialCompleted(TutorialType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('tutorial_${type.name}_completed') ?? false;
  }

  /// Reset all tutorials
  Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    for (final type in TutorialType.values) {
      await prefs.remove('tutorial_${type.name}_completed');
    }
  }
}
