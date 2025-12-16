import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../services/tutorial_service.dart';

class HomeTutorialOverlay {
  final BuildContext context;
  final GlobalKey fabAddKey;
  final GlobalKey fabImportKey;
  final GlobalKey? firstProjectKey;
  final GlobalKey? projectMenuKey;
  final GlobalKey helpIconKey;
  final VoidCallback onFinish;

  TutorialCoachMark? _tutorialCoachMark;

  HomeTutorialOverlay({
    required this.context,
    required this.fabAddKey,
    required this.fabImportKey,
    this.firstProjectKey,
    this.projectMenuKey,
    required this.helpIconKey,
    required this.onFinish,
  });

  void show() {
    print('📚 HomeTutorialOverlay: show() called');
    final targets = <TargetFocus>[];

    // Step 1: Add project
    print('📚 HomeTutorialOverlay: Adding Step 1 - Add project');
    targets.add(
      TargetFocus(
        identify: 'fab_add',
        keyTarget: fabAddKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent('Add project', 'Create a new roundnet animation', 'Tap'),
          ),
        ],
      ),
    );

    // Step 2: Import project
    targets.add(
      TargetFocus(
        identify: 'fab_import',
        keyTarget: fabImportKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent('Import project', 'Load a shared project file', 'Tap'),
          ),
        ],
      ),
    );

    // Step 3: Open project (if exists)
    if (firstProjectKey != null) {
      targets.add(
        TargetFocus(
          identify: 'first_project',
          keyTarget: firstProjectKey!,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildContent('Open project', 'Tap to start editing', 'Tap'),
            ),
          ],
        ),
      );

      // Step 4: Project menu (if exists)
      if (projectMenuKey != null) {
        targets.add(
          TargetFocus(
            identify: 'project_menu',
            keyTarget: projectMenuKey!,
            alignSkip: Alignment.topRight,
            shape: ShapeLightFocus.Circle,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                builder: (context, controller) =>
                    _buildContent('More options', 'Rename, duplicate, share, or delete', 'Tap'),
              ),
            ],
          ),
        );
      }
    }

    // Step 5: Help icon
    targets.add(
      TargetFocus(
        identify: 'help_icon',
        keyTarget: helpIconKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildContent('Get help', 'Access guides and replay tutorials', 'Tap'),
          ),
        ],
      ),
    );

    print('📚 HomeTutorialOverlay: Total targets = ${targets.length}');

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "Skip",
      paddingFocus: 10,
      opacityShadow: 0.8,
      imageFilter: null,
      onFinish: () {
        print('📚 HomeTutorialOverlay: Tutorial finished');
        TutorialService().finishTutorial();
        TutorialService().markTutorialCompleted(TutorialType.home);
        onFinish();
      },
      onSkip: () {
        print('📚 HomeTutorialOverlay: Tutorial skipped');
        TutorialService().finishTutorial();
        TutorialService().markTutorialCompleted(TutorialType.home);
        onFinish();
        return true;
      },
    );

    print('📚 HomeTutorialOverlay: Calling _tutorialCoachMark.show()');
    TutorialService().startTutorial(TutorialType.home);
    _tutorialCoachMark!.show(context: context);
    print('📚 HomeTutorialOverlay: Tutorial coach mark shown');
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 16, color: Colors.white70)),
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
