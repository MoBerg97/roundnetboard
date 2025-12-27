# Navigation Fix for Tutorial Launch

## Problem

When users tapped "Start Home Tutorial" in the Help screen, the tutorial would not launch properly after returning to the Home screen. This was because:

1. Help screen calls `TutorialService().requestTutorial(TutorialType.home)`
2. Help screen pops back to Home screen
3. Home screen is already mounted, so `didChangeDependencies()` doesn't run again
4. The tutorial never launches

## Root Cause

The original implementation only checked for pending tutorials in `didChangeDependencies()`, which is a lifecycle method that runs when:

- The widget is first built
- Dependencies change (e.g., InheritedWidget updates)

But it does NOT run when you simply pop back to an already-mounted widget.

## Solution

Implemented a listener pattern using Flutter's `ChangeNotifier`:

### 1. HomeScreen Now Listens to TutorialService

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

void _checkForPendingTutorial() {
  final tutorialService = TutorialService();
  if (tutorialService.pendingTutorial == TutorialType.home && !tutorialService.isActive) {
    // Use post-frame callback to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startHomeTutorial();
      }
    });
  }
}
```

### 2. HelpScreen Delays Tutorial Request

To ensure navigation completes before triggering the tutorial:

```dart
onPressed: () {
  Navigator.of(context).pop();
  // Delay tutorial request until after navigation completes
  Future.delayed(const Duration(milliseconds: 300), () {
    TutorialService().requestTutorial(TutorialType.home);
  });
},
```

## How It Works Now

1. User taps "Start Home Tutorial" in Help screen
2. Help screen pops
3. After 300ms delay (allowing pop animation to complete), tutorial is requested
4. `TutorialService.requestTutorial()` calls `notifyListeners()`
5. Home screen's listener `_checkForPendingTutorial()` is called
6. Tutorial overlay is shown

## Benefits

- Works reliably when navigating back from Help screen
- Works when navigating from onboarding
- Automatically handles tutorial requests at any time
- Cleans up listener in dispose to prevent memory leaks
- Uses mounted check to prevent errors after disposal

## Testing

To test the fix:

1. Open the app
2. Navigate to Help screen (tap help icon in HomeScreen)
3. Tap "Start Home Tutorial"
4. Should navigate back to Home and immediately show the tutorial overlay

## Similar Pattern for Board/Annotation Tutorials

The same pattern should be implemented in BoardScreen when it's integrated:

```dart
@override
void initState() {
  super.initState();
  TutorialService().addListener(_checkForPendingTutorial);
}

@override
void dispose() {
  TutorialService().removeListener(_checkForPendingTutorial);
  super.dispose();
}

void _checkForPendingTutorial() {
  final tutorialService = TutorialService();
  if (tutorialService.pendingTutorial == TutorialType.board && !tutorialService.isActive) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startBoardTutorial();
      }
    });
  }
}
```
