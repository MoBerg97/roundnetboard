# BoardScreen Tutorial Integration Guide

This guide shows how to integrate the BoardTutorialOverlay into the BoardScreen.

## Step 1: Add Global Keys

Add these global keys as fields in `_BoardScreenState`:

```dart
class _BoardScreenState extends State<BoardScreen> {
  // ... existing fields ...
  
  // Tutorial keys
  final GlobalKey _boardKey = GlobalKey(debugLabel: 'board');
  final GlobalKey _timelineKey = GlobalKey(debugLabel: 'timeline');
  final GlobalKey _player1Key = GlobalKey(debugLabel: 'player1');
  final GlobalKey _player2Key = GlobalKey(debugLabel: 'player2');
  final GlobalKey _ballKey = GlobalKey(debugLabel: 'ball');
  final GlobalKey _frameAddKey = GlobalKey(debugLabel: 'frame_add');
  final GlobalKey _durationKey = GlobalKey(debugLabel: 'duration');
  final GlobalKey _playKey = GlobalKey(debugLabel: 'play');
  final GlobalKey _stopKey = GlobalKey(debugLabel: 'stop');
  
  // ... rest of the class ...
}
```

## Step 2: Add Import

At the top of `board_screen.dart`, add:

```dart
import '../services/tutorial_service.dart';
import '../widgets/board_tutorial_overlay.dart';
```

## Step 3: Add Tutorial Check and Listener

In `_BoardScreenState`, add the listener pattern:

```dart
@override
void initState() {
  super.initState();
  
  // Listen for tutorial requests
  TutorialService().addListener(_checkForPendingTutorial);
}

@override
void dispose() {
  TutorialService().removeListener(_checkForPendingTutorial);
  super.dispose();
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  // Check for pending tutorial trigger on first build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkForPendingTutorial();
  });
}

void _checkForPendingTutorial() {
  final tutorialService = TutorialService();
  if (tutorialService.pendingTutorial == TutorialType.board && !tutorialService.isActive) {
    // Use post-frame callback to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startBoardTutorial();
      }
    });
  }
}
```

## Step 4: Add Tutorial Start Method

Add this method to `_BoardScreenState`:

```dart
void _startBoardTutorial() {
  final overlay = BoardTutorialOverlay(
    context: context,
    boardKey: _boardKey,
    timelineKey: _timelineKey,
    player1Key: _player1Key,
    player2Key: _player2Key,
    ballKey: _ballKey,
    frameAddKey: _frameAddKey,
    durationKey: _durationKey,
    playKey: _playKey,
    stopKey: _stopKey,
    onFinish: () {
      // Optional: do something when tutorial finishes
    },
  );
  
  overlay.show();
}
```

## Step 5: Attach Keys to Widgets

In the `build` method, attach the keys to the corresponding widgets:

```dart
// Example for the board area
Container(
  key: _boardKey,
  // ... rest of board widget ...
)

// Example for timeline
Container(
  key: _timelineKey,
  // ... rest of timeline widget ...
)

// Example for player 1 (find the widget that represents player 1)
GestureDetector(
  key: _player1Key,
  // ... player 1 widget ...
)

// Similar for player 2, ball, etc.
```

## Finding the Right Widgets

You'll need to identify the actual widgets in your BoardScreen that correspond to each tutorial target:

1. **Board area**: The main canvas/container where players and ball are displayed
2. **Timeline**: The widget showing frame thumbnails
3. **Player 1**: The first player object on the board
4. **Player 2**: The second player object on the board
5. **Ball**: The ball object on the board
6. **Frame add button**: The button to add a new frame
7. **Duration button**: The button to set frame duration
8. **Play button**: The button to play the animation
9. **Stop button**: The button to stop the animation

## Example Widget with Key

```dart
// Before:
FloatingActionButton(
  onPressed: _addFrame,
  child: Icon(Icons.add),
)

// After:
FloatingActionButton(
  key: _frameAddKey,
  onPressed: _addFrame,
  child: Icon(Icons.add),
)
```

## Testing

After integration:

1. Navigate to Help screen
2. Tap "Start Board Tutorial"
3. Open any project
4. The tutorial should automatically start

## Notes

- The tutorial will only show once per user (stored in SharedPreferences)
- Users can skip the tutorial at any time
- The tutorial marks itself as completed when finished or skipped
- To test again, you can reset the tutorial via `TutorialService().resetTutorial(TutorialType.board)`
