import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';

// Annotation tutorial is not implemented yet - placeholder for future
class AnnotationTutorialOverlay {
  final BuildContext context;
  final VoidCallback onFinish;

  AnnotationTutorialOverlay({required this.context, required this.onFinish});

  void show() {
    // TODO: Implement annotation tutorial with custom overlay
    TutorialService().startTutorial(TutorialType.annotation, []);
    onFinish();
  }
}
