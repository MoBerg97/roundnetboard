import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';

// Home tutorial is not implemented yet - placeholder for future
class HomeTutorialOverlay {
  final BuildContext context;
  final VoidCallback onFinish;

  HomeTutorialOverlay({required this.context, required this.onFinish});

  void show() {
    // TODO: Implement home tutorial with custom overlay
    TutorialService().startTutorial(TutorialType.home, []);
    onFinish();
  }
}
