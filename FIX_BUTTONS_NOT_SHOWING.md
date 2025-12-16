# Critical Steps to Fix Tutorial Buttons

## Issue

The tutorial buttons are not showing in the Help screen, and there's no debug output.

## Root Cause

The code changes haven't been picked up by Flutter's hot reload on web. This requires a **full restart**.

## Solution - Step by Step

### Step 1: Stop the App

Press `Ctrl+C` in the terminal running Flutter, or stop it from VS Code/IDE

### Step 2: Clean Build

Run these commands:

```bash
flutter clean
flutter pub get
```

### Step 3: Restart App

```bash
flutter run -d chrome
```

(or whatever command you use to run the app)

### Step 4: Wait for Full Build

Wait for the full compilation to complete (not just hot reload)

### Step 5: Test Again

1. Open the app
2. Click Help icon
3. You should now see THREE buttons:
   - "Start Home Tutorial" (with home icon)
   - "Start Board Tutorial" (with dashboard icon)  
   - "Start Annotation Tutorial" (with draw icon)
   - "Replay Onboarding" (with school icon)

### Step 6: Test Home Tutorial

1. Click "Start Home Tutorial"
2. Watch the console
3. You should see output starting with: `🆘 HelpScreen: Start Home Tutorial tapped`

## If Still Not Working

### Check 1: Verify File Saved

Make sure `lib/screens/help_screen.dart` is saved with the changes

### Check 2: Check for Compilation Errors

Look in the terminal for any red error messages during `flutter run`

### Check 3: Clear Browser Cache

If running on web:

- Press `Ctrl+Shift+Delete` in Chrome
- Clear cached images and files
- Reload page

### Check 4: Verify Imports

The help_screen.dart should have these imports at the top:

```dart
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../services/tutorial_service.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
```

## Alternative: Force Full Rebuild

If hot restart doesn't work, try:

```bash
# Stop app
# Delete build folder
rm -rf build/  # On Mac/Linux
# or
rmdir /s build  # On Windows

# Rebuild
flutter run -d chrome
```

## What You Should See After Fix

Help screen should show this layout:

```
┌─────────────────────────────────────┐
│ Help & Guide                    ← X │
├─────────────────────────────────────┤
│                                     │
│  [🏠  Start Home Tutorial      ]   │
│                                     │
│  [📊 Start Board Tutorial      ]   │
│                                     │
│  [✏️  Start Annotation Tutorial]   │
│                                     │
│  [🎓 Replay Onboarding         ]   │
│                                     │
│  Creating Projects                  │
│  Tap the + button to create...     │
│  ...                                │
└─────────────────────────────────────┘
```

## Console Output After Fix

When you click "Start Home Tutorial", console should show:

```
🆘 HelpScreen: Start Home Tutorial tapped
🆘 HelpScreen: Navigation popped
[wait 300ms]
🆘 HelpScreen: Delay complete, requesting tutorial
🎯 TutorialService: Requesting home tutorial
🎯 TutorialService: Pending tutorial set to home
🎯 TutorialService: Listeners notified (has listeners/no listeners)
🏠 HomeScreen: _checkForPendingTutorial called
...
```

Please try a full restart and let me know what you see!
