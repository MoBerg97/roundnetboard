# Tutorial Launch & Guided Flows Implementation

## Summary

This implementation adds a comprehensive tutorial system to the Roundnet Board app with the following features:

## Changes Made

### 1. Tutorial Service (`lib/services/tutorial_service.dart`)

- Created a singleton service to manage tutorial state across the app
- Tracks pending tutorial requests, active tutorials, and completion status
- Stores tutorial completion state in SharedPreferences
- Supports three tutorial types: home, board, and annotation

### 2. Home Tutorial Overlay (`lib/widgets/home_tutorial_overlay.dart`)

- Implements a step-by-step tutorial for the Home screen
- Steps include:
  1. Add project (FAB)
  2. Import project (FAB)
  3. Open project (first project card, if exists)
  4. More options (project menu, if exists)
  5. Get help (help icon)
- Each step shows concise title (≤4 words), description, and gesture hint
- Uses `tutorial_coach_mark` package for overlay UI

### 3. Board Tutorial Overlay (`lib/widgets/board_tutorial_overlay.dart`)

- Implements a comprehensive tutorial for the Board screen
- Steps include:
  1. This is your court (board area)
  2. The frames store everything on court (timeline)
  3. Choose a starting position for this player (player 1)
  4. Choose a starting position for the next player (player 2)
  5. Place ball next to a player to simulate a serve (ball)
  6. Add a frame for the next action (frame add button)
  7. Drag players/ball to new positions (board area)
  8. Set duration of current movement (duration button)
  9. Play animation (play button)
  10. Stop animation (stop button)
  11. Add more frames to build a rally (final message)
- Each step shows concise title (≤8 words), description, and gesture hint

### 4. Annotation Tutorial Overlay (`lib/widgets/annotation_tutorial_overlay.dart`)

- Implements a tutorial for the Annotation tools
- Steps dynamically include available tools:
  - Annotation menu
  - Line tool
  - Circle tool
  - Eraser tool
  - Color picker
  - Undo button
- Flexible design to accommodate different UI layouts

### 5. Updated Help Screen (`lib/screens/help_screen.dart`)

- Added three tutorial buttons:
  1. **Start Home Tutorial** - Triggers home tutorial immediately
  2. **Start Board Tutorial** - Requests board tutorial (shown when user opens a project)
  3. **Start Annotation Tutorial** - Requests annotation tutorial (shown when user taps annotation button)
  4. **Replay Onboarding** - Returns to onboarding, then to Home with auto-triggered tutorial
- Removed old "Restart Tutorial" button that used the obsolete `InteractiveTutorialScreen`

### 6. Updated Home Screen (`lib/screens/home_screen.dart`)

- Removed `onProvideTutorialKeys` callback pattern
- Added global keys for all tutorial-targetable UI elements:
  - FAB add button
  - FAB import button
  - Help icon
  - First project card
  - First project menu button
- Implemented listener pattern for tutorial requests:
  - Listens to TutorialService in `initState`
  - Removes listener in `dispose`
  - Checks for pending tutorials via `_checkForPendingTutorial()`
- Automatically shows home tutorial when requested via TutorialService
- Handles navigation timing properly with post-frame callbacks

### 7. Updated Main App (`lib/main.dart`)

- Removed old tutorial key collection mechanism
- Simplified onboarding flow
- Auto-triggers Home tutorial after onboarding completes
- Removed dependency on `InteractiveTutorialScreen`

## How It Works

### Tutorial Flow

1. **From Onboarding:**
   - User completes onboarding
   - App navigates to HomeScreen
   - TutorialService requests home tutorial
   - HomeScreen detects pending tutorial and shows overlay

2. **From Help Screen:**
   - User taps "Start Home Tutorial"
   - Help screen pops
   - After 300ms delay, TutorialService requests home tutorial
   - TutorialService notifies all listeners
   - HomeScreen's listener detects pending tutorial and shows overlay

3. **Replay Onboarding:**
   - User taps "Replay Onboarding"
   - App navigates to OnboardingScreen
   - After completion, navigates to HomeScreen
   - Auto-triggers home tutorial

4. **Board/Annotation Tutorials:**
   - User requests tutorial from Help screen
   - Help screen pops
   - After 300ms delay, TutorialService stores pending request
   - When user navigates to Board screen, listener detects pending tutorial
   - Shows appropriate overlay

### Key Design Decisions

1. **Global Service Pattern**: Using a singleton TutorialService avoids passing callbacks through multiple widget layers
2. **Listener Pattern**: Screens listen to TutorialService changes, ensuring tutorials trigger even after navigation
3. **Delayed Request**: Tutorial requests are delayed after navigation to ensure the pop animation completes
4. **Pending Tutorial Pattern**: Allows tutorials to be requested before the target screen is visible
5. **SharedPreferences Persistence**: Remembers which tutorials have been completed
6. **Flexible Overlay Design**: Each tutorial overlay is self-contained and can be easily customized
7. **Skip Option**: All tutorials include a skip button for user control

## Next Steps (To Complete Implementation)

### BoardScreen Integration

The BoardScreen needs to be updated to:

1. Add global keys for all tutorial targets
2. Implement listener pattern in initState/dispose
3. Check for pending board tutorial via listener callback
4. Show BoardTutorialOverlay when requested

Example:

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
    onFinish: () {},
  );
  
  overlay.show();
}
```

### Annotation Tutorial Integration

Similar pattern for annotation tutorial, triggered when the annotation menu is opened.

## Testing Checklist

- [ ] Home tutorial launches from Help screen
- [ ] Home tutorial launches after onboarding
- [ ] Replay onboarding returns to Home and triggers tutorial
- [ ] Tutorial completion is persisted (doesn't show again unless reset)
- [ ] Skip button works and marks tutorial as completed
- [ ] All tutorial steps show correct UI elements
- [ ] Tutorials work on web and desktop/mobile
- [ ] Board tutorial can be triggered (after BoardScreen integration)
- [ ] Annotation tutorial can be triggered (after integration)
- [ ] Overlays are accessible and keyboard-navigable

## File Structure

```
lib/
├── services/
│   └── tutorial_service.dart          (NEW)
├── widgets/
│   ├── home_tutorial_overlay.dart     (NEW)
│   ├── board_tutorial_overlay.dart    (NEW)
│   └── annotation_tutorial_overlay.dart (NEW)
├── screens/
│   ├── help_screen.dart               (MODIFIED)
│   ├── home_screen.dart               (MODIFIED)
│   └── interactive_tutorial_screen.dart (DEPRECATED - can be removed)
└── main.dart                          (MODIFIED)
```

## Dependencies

Uses existing `tutorial_coach_mark: ^1.2.6` package from pubspec.yaml
