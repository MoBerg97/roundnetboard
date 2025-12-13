import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';


class InteractiveTutorialScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final Map<String, GlobalKey>? highlightKeys;

  InteractiveTutorialScreen({Key? key, required this.onFinish, this.highlightKeys}) : super(key: key);

  @override
  State<InteractiveTutorialScreen> createState() => _InteractiveTutorialScreenState();
}

class _InteractiveTutorialScreenState extends State<InteractiveTutorialScreen> {
  int step = 0;
  TutorialCoachMark? _tutorialCoachMark;
  List<TargetFocus> _targets = [];

  final List<_TutorialStep> steps = [
    _TutorialStep(
      title: 'Create a Project',
      description: 'Tap the + button to create a new project.',
      highlightKey: 'fab_add',
    ),
    _TutorialStep(
      title: 'Name Your Project',
      description: 'Enter a name for your project and tap Create.',
      highlightKey: 'dialog_create',
    ),
    _TutorialStep(
      title: 'Open the Project',
      description: 'Tap your new project to open it.',
      highlightKey: 'project_tile',
    ),
    _TutorialStep(
      title: 'Set Initial Positions',
      description: 'Frame 0: Drag players and the ball to choose starting positions.',
      highlightKey: 'board_objects',
    ),
    _TutorialStep(
      title: 'Add a New Frame',
      description: 'Tap the frame add button to create a new frame. Positions are copied!',
      highlightKey: 'timeline_add',
    ),
    _TutorialStep(
      title: 'Move Players',
      description: 'Drag a player to a new position in the new frame to show movement.',
      highlightKey: 'board_objects',
    ),
    _TutorialStep(
      title: 'Curve a Path',
      description: 'Tap and drag on a path to add a curve.',
      highlightKey: 'path_curve',
    ),
    _TutorialStep(
      title: 'Straighten a Path',
      description: 'Double tap a curve point to make the path straight again.',
      highlightKey: 'path_curve',
    ),
    _TutorialStep(
      title: 'Move the Ball',
      description: 'Drag the ball to a new position.',
      highlightKey: 'ball_object',
    ),
    _TutorialStep(
      title: 'Set & Hit',
      description: 'Tap the ball, choose Set, then switch to Hit and pick the hit point along the path.',
      highlightKey: 'ball_modifiers',
    ),
    _TutorialStep(
      title: 'Add Annotations',
      description: 'Open the annotation menu, add lines/circles, use eraser, and try all annotation tools.',
      highlightKey: 'annotation_menu',
    ),
    _TutorialStep(
      title: 'Tutorial Complete!',
      description: 'You are ready to use Roundnet Board. Tap Finish to start creating!',
      highlightKey: null,
    ),
  ];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
  }

  void _showTutorial() {
    if (widget.highlightKeys == null) {
      widget.onFinish();
      return;
    }
    _targets = [];
    for (final s in steps) {
      if (s.highlightKey != null && widget.highlightKeys![s.highlightKey!] != null) {
        _targets.add(
          TargetFocus(
            identify: s.highlightKey!,
            keyTarget: widget.highlightKeys![s.highlightKey!],
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text(s.description, style: const TextStyle(fontSize: 18, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }
    if (_targets.isNotEmpty) {
      _tutorialCoachMark = TutorialCoachMark(
        targets: _targets,
        colorShadow: Colors.black,
        textSkip: "Skip",
        paddingFocus: 8,
        opacityShadow: 0.7,
        onFinish: widget.onFinish,
        onSkip: () {
          widget.onFinish();
          return true;
        },
      );
      _tutorialCoachMark!.show(context: context);
    } else {
      // Fallback: just finish
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The tutorial_coach_mark overlays the UI, so just return an empty container
    return const SizedBox.shrink();
  }
}

class _TutorialStep {
  final String title;
  final String description;
  final String? highlightKey;
  const _TutorialStep({required this.title, required this.description, this.highlightKey});
}
