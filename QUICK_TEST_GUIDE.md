# Quick Test & Debug Guide

## 🚀 How to Test

### Test 1: Home Tutorial

```
1. Run app
2. Click Help icon (top-right of HomeScreen)
3. Click "Start Home Tutorial"
4. Watch console for output
5. Copy ALL console output and paste in response
```

### Test 2: Board Tutorial  

```
1. Run app
2. Click Help icon
3. Click "Start Board Tutorial"
4. Open or create a project
5. Watch console for output
6. Copy ALL console output and paste in response
```

## 🔍 What to Look For in Console

### Success Indicators

- ✅ `🎯 TutorialService: Listeners notified (has listeners)`
- ✅ `🏠 HomeScreen: _checkForPendingTutorial called` (appears after notification)
- ✅ `🏠 HomeScreen: Conditions met, scheduling tutorial start`
- ✅ `📚 HomeTutorialOverlay: Tutorial coach mark shown`

### Failure Indicators

- ❌ `🎯 TutorialService: Listeners notified (no listeners)` - Listener not attached
- ❌ Notification happens but no `_checkForPendingTutorial called` - Callback not firing
- ❌ `🏠 HomeScreen: Conditions not met` - Wrong state
- ❌ `⚠️ HomeScreen: Widget not mounted` - Timing issue

## 📋 Console Output Format

Please paste output in this format:

```
=== Test 1: Home Tutorial ===
[paste all console output here]

=== Test 2: Board Tutorial ===
[paste all console output here]
```

## 🎯 Expected Flow (Home Tutorial)

```
🆘 HelpScreen: Start Home Tutorial tapped
🆘 HelpScreen: Navigation popped
[wait 300ms]
🆘 HelpScreen: Delay complete, requesting tutorial
🎯 TutorialService: Requesting home tutorial
🎯 TutorialService: Pending tutorial set to home
🎯 TutorialService: Listeners notified (has listeners)
🏠 HomeScreen: _checkForPendingTutorial called
🏠 HomeScreen: Pending tutorial = home
🏠 HomeScreen: Is active = false
🏠 HomeScreen: Conditions met, scheduling tutorial start
🏠 HomeScreen: Post-frame callback for tutorial start
🏠 HomeScreen: Widget is mounted, starting tutorial
🏠 HomeScreen: _startHomeTutorial called
🏠 HomeScreen: Creating HomeTutorialOverlay
🏠 HomeScreen: Calling overlay.show()
📚 HomeTutorialOverlay: show() called
📚 HomeTutorialOverlay: Adding Step 1 - Add project
📚 HomeTutorialOverlay: Total targets = 5
📚 HomeTutorialOverlay: Calling _tutorialCoachMark.show()
▶️ TutorialService: Starting home tutorial
📚 HomeTutorialOverlay: Tutorial coach mark shown
```

## 🎯 Expected Flow (Board Tutorial)

```
🆘 HelpScreen: Start Board Tutorial tapped
[snackbar shown]
🆘 HelpScreen: Navigation popped
[wait 300ms]
🆘 HelpScreen: Delay complete, requesting tutorial
🎯 TutorialService: Requesting board tutorial
🎯 TutorialService: Pending tutorial set to board
🎯 TutorialService: Listeners notified (has listeners)
[user opens project]
🎲 BoardScreen: initState called
🎲 BoardScreen: Listener added to TutorialService
🎲 BoardScreen: didChangeDependencies called
🎲 BoardScreen: Post-frame callback from didChangeDependencies
🎲 BoardScreen: _checkForPendingTutorial called
🎲 BoardScreen: Pending tutorial = board
🎲 BoardScreen: Is active = false
🎲 BoardScreen: Conditions met, scheduling tutorial start
🎲 BoardScreen: Post-frame callback for tutorial start
🎲 BoardScreen: Widget is mounted, starting tutorial
🎲 BoardScreen: _startBoardTutorial called
🎲 BoardScreen: Calling overlay.show()
[Tutorial overlay appears]
```

## 🛠️ If Tutorial Doesn't Launch

Check console for:

1. Where does the flow stop?
2. What's the last emoji you see?
3. Are there any errors?
4. Does it say "has listeners" or "no listeners"?

Share this information and I'll provide targeted fix.

## 📱 Platform Info Needed

Also mention:

- Platform: Web / Windows / Android / iOS
- Flutter version (if known)
- Any errors or warnings in console
