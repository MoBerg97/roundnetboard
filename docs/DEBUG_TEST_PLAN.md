# Tutorial Navigation Debug & Test Plan

## Current Issue

Tutorial does not launch when "Start Home Tutorial" is pressed in HelpScreen.

## Debug Logging Added

I've added comprehensive console logging throughout the tutorial flow. Look for these emoji prefixes:

- 🎯 = TutorialService operations
- 🏠 = HomeScreen operations
- 🆘 = HelpScreen operations
- 📚 = HomeTutorialOverlay operations
- ▶️ = Tutorial start
- ⏹️ = Tutorial finish
- 🗑️ = Tutorial clear
- ⚠️ = Warning/error condition

## Expected Console Output (Successful Flow)

When you tap "Start Home Tutorial" in HelpScreen, you should see this sequence:

```
🆘 HelpScreen: Start Home Tutorial tapped
🆘 HelpScreen: Navigation popped
🏠 HomeScreen: didChangeDependencies called
🏠 HomeScreen: Post-frame callback from didChangeDependencies
🏠 HomeScreen: _checkForPendingTutorial called
🏠 HomeScreen: Pending tutorial = none
🏠 HomeScreen: Is active = false
🏠 HomeScreen: Conditions not met for tutorial
🆘 HelpScreen: Delay complete, requesting tutorial
🎯 TutorialService: Requesting home tutorial
🎯 TutorialService: Pending tutorial set to home
🎯 TutorialService: Listeners notified (has listeners/no listeners)
🏠 HomeScreen: _checkForPendingTutorial called
🏠 HomeScreen: Pending tutorial = home
🏠 HomeScreen: Is active = false
🏠 HomeScreen: Conditions met, scheduling tutorial start
🏠 HomeScreen: Post-frame callback for tutorial start
🏠 HomeScreen: Widget is mounted, starting tutorial
🏠 HomeScreen: _startHomeTutorial called
🏠 HomeScreen: Creating HomeTutorialOverlay
🏠 HomeScreen: Project count = X
🏠 HomeScreen: Calling overlay.show()
📚 HomeTutorialOverlay: show() called
📚 HomeTutorialOverlay: Adding Step 1 - Add project
📚 HomeTutorialOverlay: Total targets = 5
📚 HomeTutorialOverlay: Calling _tutorialCoachMark.show()
▶️ TutorialService: Starting home tutorial
📚 HomeTutorialOverlay: Tutorial coach mark shown
```

## Test Steps

### Test 1: First Time App Launch

1. Clear app data / reinstall app
2. Run app
3. Complete onboarding
4. **Expected**: Home tutorial should auto-start
5. **Check console** for the sequence starting with onboarding completion

### Test 2: Tutorial from Help Screen

1. Open app (with onboarding already completed)
2. Tap Help icon in HomeScreen
3. Tap "Start Home Tutorial" button
4. **Expected**: Return to Home and see tutorial overlay
5. **Paste console output** - we'll analyze what's happening

### Test 3: Replay Onboarding

1. Open app
2. Tap Help icon
3. Tap "Replay Onboarding"
4. Complete onboarding
5. **Expected**: Return to Home and see tutorial overlay
6. **Paste console output**

## Things to Check in Console Output

### 1. Is the listener being added?

Look for: `🏠 HomeScreen: Listener added to TutorialService`

### 2. Are listeners being notified?

Look for: `🎯 TutorialService: Listeners notified (has listeners)`

- If it says "no listeners" → HomeScreen listener didn't attach properly
- If it says "has listeners" → Good, listeners are attached

### 3. Is the callback being triggered?

After `🎯 TutorialService: Listeners notified`, you should see:
`🏠 HomeScreen: _checkForPendingTutorial called`

- If you DON'T see this → Listener callback is not firing

### 4. Are the conditions being met?

Look for:

```
🏠 HomeScreen: Pending tutorial = home
🏠 HomeScreen: Is active = false
🏠 HomeScreen: Conditions met, scheduling tutorial start
```

- If you see "Conditions not met" → Either tutorial is not pending or already active

### 5. Is the overlay being created?

Look for:

```
🏠 HomeScreen: _startHomeTutorial called
📚 HomeTutorialOverlay: show() called
```

## Common Issues & Solutions

### Issue 1: "no listeners" in TutorialService

**Symptoms**: `🎯 TutorialService: Listeners notified (no listeners)`
**Cause**: HomeScreen's initState never ran or listener was removed
**Solution**: Check if HomeScreen is being disposed and recreated

### Issue 2: Listener callback never fires

**Symptoms**: See `🎯 TutorialService: Listeners notified` but never see `🏠 HomeScreen: _checkForPendingTutorial called` afterwards
**Cause**: ChangeNotifier not properly connected
**Solution**: Verify TutorialService is singleton and same instance everywhere

### Issue 3: Tutorial already active

**Symptoms**: `🏠 HomeScreen: Is active = true`
**Cause**: Previous tutorial didn't finish properly
**Solution**: Ensure finishTutorial() is called in overlay onFinish/onSkip

### Issue 4: Widget not mounted

**Symptoms**: `⚠️ HomeScreen: Widget not mounted, skipping tutorial`
**Cause**: HomeScreen was disposed before tutorial could start
**Solution**: Check navigation timing

## Alternative Fix Strategy

If listener pattern still doesn't work, we can try:

### Option A: RouteAware Pattern

Use Flutter's RouteObserver to detect when HomeScreen becomes active

### Option B: Global Key Pattern

Store a GlobalKey<_HomeScreenState> and call method directly

### Option C: Stream/BLoC Pattern

Use a StreamController instead of ChangeNotifier

### Option D: Named Route with Arguments

Pass tutorial request as route argument

## Next Steps After Getting Console Output

1. Run Test 2 (Help Screen → Home Tutorial)
2. Copy the entire console output
3. Paste it in your response
4. I'll analyze and identify the exact failure point
5. We'll implement the targeted fix

## Board Screen Tutorial Integration (Parallel Task)

While debugging, I can also start implementing the board screen tutorial. Please provide:

1. Location of board_screen.dart
2. Any existing global keys or identifiable widgets
3. Whether you want me to proceed with board tutorial integration in parallel
