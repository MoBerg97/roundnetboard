import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../services/tutorial_service.dart';

class AnnotationTutorialOverlay {
  final BuildContext context;
  final GlobalKey annotationMenuKey;
  final GlobalKey? lineToolKey;
  final GlobalKey? circleToolKey;
  final GlobalKey? eraserToolKey;
  final GlobalKey? colorPickerKey;
  final GlobalKey? undoKey;
  final VoidCallback onFinish;

  TutorialCoachMark? _tutorialCoachMark;

  AnnotationTutorialOverlay({
    required this.context,
    required this.annotationMenuKey,
    this.lineToolKey,
    this.circleToolKey,
    this.eraserToolKey,
    this.colorPickerKey,
    this.undoKey,
    required this.onFinish,
  });

  void show() {
    final targets = <TargetFocus>[];

    // Step 1: Annotation menu
    targets.add(
      TargetFocus(
        identify: 'annotation_menu',
        keyTarget: annotationMenuKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) =>
                _buildContent('Annotation tools', 'Add drawings to highlight tactics', 'Tap'),
          ),
        ],
      ),
    );

    // Step 2: Line tool (if available)
    if (lineToolKey != null) {
      targets.add(
        TargetFocus(
          identify: 'line_tool',
          keyTarget: lineToolKey!,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) =>
                  _buildContent('Draw lines', 'Tap and drag to draw straight lines', 'Drag'),
            ),
          ],
        ),
      );
    }

    // Step 3: Circle tool (if available)
    if (circleToolKey != null) {
      targets.add(
        TargetFocus(
          identify: 'circle_tool',
          keyTarget: circleToolKey!,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildContent('Draw circles', 'Tap and drag to draw circles', 'Drag'),
            ),
          ],
        ),
      );
    }

    // Step 4: Eraser tool (if available)
    if (eraserToolKey != null) {
      targets.add(
        TargetFocus(
          identify: 'eraser_tool',
          keyTarget: eraserToolKey!,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) =>
                  _buildContent('Erase annotations', 'Remove drawings you don\'t need', 'Tap'),
            ),
          ],
        ),
      );
    }

    // Step 5: Color picker (if available)
    if (colorPickerKey != null) {
      targets.add(
        TargetFocus(
          identify: 'color_picker',
          keyTarget: colorPickerKey!,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildContent('Choose colors', 'Change annotation colors', 'Tap'),
            ),
          ],
        ),
      );
    }

    // Step 6: Undo (if available)
    if (undoKey != null) {
      targets.add(
        TargetFocus(
          identify: 'undo',
          keyTarget: undoKey!,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildContent('Undo changes', 'Remove the last annotation', 'Tap'),
            ),
          ],
        ),
      );
    }

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "Skip",
      paddingFocus: 10,
      opacityShadow: 0.8,
      imageFilter: null,
      onFinish: () {
        TutorialService().finishTutorial();
        TutorialService().markTutorialCompleted(TutorialType.annotation);
        onFinish();
      },
      onSkip: () {
        TutorialService().finishTutorial();
        TutorialService().markTutorialCompleted(TutorialType.annotation);
        onFinish();
        return true;
      },
    );

    TutorialService().startTutorial(TutorialType.annotation);
    _tutorialCoachMark!.show(context: context);
  }

  Widget _buildContent(String title, String description, String gesture) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 15, color: Colors.white70)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(
              gesture,
              style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
