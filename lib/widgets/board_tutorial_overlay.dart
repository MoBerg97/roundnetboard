import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../services/tutorial_service.dart';

class BoardTutorialOverlay {
  final BuildContext context;
  final GlobalKey boardKey;
  final GlobalKey timelineKey;
  final GlobalKey player1Key;
  final GlobalKey player2Key;
  final GlobalKey ballKey;
  final GlobalKey frameAddKey;
  final GlobalKey durationKey;
  final GlobalKey playKey;
  final GlobalKey stopKey;
  final VoidCallback onFinish;
  final Function(VoidCallback)? onAwaitUserAction;

  TutorialCoachMark? _tutorialCoachMark;
  int _currentStep = 0;

  BoardTutorialOverlay({
    required this.context,
    required this.boardKey,
    required this.timelineKey,
    required this.player1Key,
    required this.player2Key,
    required this.ballKey,
    required this.frameAddKey,
    required this.durationKey,
    required this.playKey,
    required this.stopKey,
    required this.onFinish,
    this.onAwaitUserAction,
  });

  void show() {
    final targets = <TargetFocus>[];

    // Step 1: Board area
    targets.add(
      TargetFocus(
        identify: 'board',
        keyTarget: boardKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) =>
                _buildContent('This is your court', 'The roundnet court where you position players and ball', 'Look'),
          ),
        ],
      ),
    );

    // Step 2: Timeline
    targets.add(
      TargetFocus(
        identify: 'timeline',
        keyTarget: timelineKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
              'The frames store everything on court',
              'Each frame captures positions at a moment in time',
              'Look',
            ),
          ),
        ],
      ),
    );

    // Step 3: Player 1
    targets.add(
      TargetFocus(
        identify: 'player1',
        keyTarget: player1Key,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) =>
                _buildContent('Choose a starting position for this player', 'Drag to move', 'Drag'),
          ),
        ],
      ),
    );

    // Step 4: Player 2
    targets.add(
      TargetFocus(
        identify: 'player2',
        keyTarget: player2Key,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) =>
                _buildContent('Choose a starting position for the next player', 'Drag to move', 'Drag'),
          ),
        ],
      ),
    );

    // Step 5: Ball
    targets.add(
      TargetFocus(
        identify: 'ball',
        keyTarget: ballKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) =>
                _buildContent('Place ball next to a player to simulate a serve', 'Drag close to any player', 'Drag'),
          ),
        ],
      ),
    );

    // Step 6: Add frame
    targets.add(
      TargetFocus(
        identify: 'frame_add',
        keyTarget: frameAddKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) =>
                _buildContent('Add a frame for the next action', 'Creates a new moment in time', 'Tap'),
          ),
        ],
      ),
    );

    // Step 7: Drag objects
    targets.add(
      TargetFocus(
        identify: 'board_drag',
        keyTarget: boardKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) =>
                _buildContent('Drag players/ball to new positions', 'Shows movement between frames', 'Drag'),
          ),
        ],
      ),
    );

    // Step 8: Duration
    targets.add(
      TargetFocus(
        identify: 'duration',
        keyTarget: durationKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) =>
                _buildContent('Set duration of current movement', 'How long the movement takes', 'Tap'),
          ),
        ],
      ),
    );

    // Step 9: Play
    targets.add(
      TargetFocus(
        identify: 'play',
        keyTarget: playKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildContent('Play animation', 'Watch your rally come to life', 'Tap'),
          ),
        ],
      ),
    );

    // Step 10: Stop
    targets.add(
      TargetFocus(
        identify: 'stop',
        keyTarget: stopKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildContent('Stop animation', 'Pause playback', 'Tap'),
          ),
        ],
      ),
    );

    // Step 11: Final message
    targets.add(
      TargetFocus(
        identify: 'final',
        keyTarget: frameAddKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) =>
                _buildContent('Add more frames to build a rally', 'Keep creating to tell your story!', 'Create'),
          ),
        ],
      ),
    );

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "Skip",
      paddingFocus: 10,
      opacityShadow: 0.8,
      imageFilter: null,
      onClickTarget: (target) {
        _currentStep++;
      },
      onFinish: () {
        TutorialService().finishTutorial();
        TutorialService().markTutorialCompleted(TutorialType.board);
        onFinish();
      },
      onSkip: () {
        TutorialService().finishTutorial();
        TutorialService().markTutorialCompleted(TutorialType.board);
        onFinish();
        return true;
      },
    );

    TutorialService().startTutorial(TutorialType.board);
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
