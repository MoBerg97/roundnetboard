# Testing Guide - Annotation Fixes

**Date**: January 3, 2026  
**Status**: Ready for Testing  
**Implementation**: Complete ✅

---

## Quick Test Summary

All code changes have been implemented and compile without errors. Ready for manual testing.

---

## Test Procedures

### Test #1: Circle Fill Menu (Android & All Platforms)

**Setup**:

- Build and deploy to device/emulator
- Open RoundnetBoard app
- Navigate to a project → Board editor

**Steps**:

1. Tap annotation mode button (should turn blue)
2. Long-press the circle tool button (with circle icon)
3. You should see a small menu appear above the button with 2 options (filled circle, outline circle)
4. While holding, drag up toward the filled circle option
5. **Release without tapping** (important!)
6. The menu should close
7. Draw a circle on the court by tapping and dragging
8. Verify the circle is **filled** (solid)

**Expected Result**: ✅ Circle appears filled/solid  
**If Failed**: ❌ Circle is still outline only

**Repeat for Outline**:

- Repeat steps 1-5 but drag to outline option
- Draw circle → should be outline only

---

### Test #2: Rectangle Fill Menu (Android & All Platforms)

**Setup**: Same as Test #1

**Steps**:

1. Tap annotation mode button
2. Long-press the rectangle tool button (with square icon)
3. See menu with 2 options (filled, outline)
4. Drag to select filled option
5. **Release without tapping**
6. Draw a rectangle
7. Verify rectangle is **filled**

**Expected Result**: ✅ Rectangle appears filled  
**If Failed**: ❌ Rectangle is outline only

**Repeat for Outline**:

- Repeat with outline option selected

---

### Test #3: Stroke Width (All Platforms)

**Setup**: Same as Test #1

**Steps**:

1. Tap annotation mode button
2. Draw a line first with default width (for baseline)
3. Long-press the stroke width button (with horizontal line icon)
4. See menu with 3 options (thin, medium, thick)
5. Drag to select **largest/thickest** option
6. **Release without tapping**
7. Draw another line
8. Compare widths: new line should be **noticeably thicker**

**Expected Result**: ✅ New line has thicker stroke  
**If Failed**: ❌ New line has same width as first line

**Test all widths**: Repeat with each width option

---

### Test #4: Web Drag Preview (Web Platform Only)

**Setup**:

- Build web version: `flutter build web`
- Deploy to local server or Firebase Hosting
- Open in browser (Chrome recommended)
- Open Developer Console (F12 → Console tab)

**Steps**:

1. Navigate to board editor
2. Tap annotation mode button
3. Long-press to draw a line (e.g., line tool)
4. Start dragging to create the line
5. **While dragging, watch the browser console** for "DEBUG WEB DRAG UPDATE" messages

**Expected Output**:

```
DEBUG WEB DRAG UPDATE: mode=true, points=1, pos=Offset(...)
DEBUG WEB DRAG UPDATE: mode=true, points=1, pos=Offset(...)
```

**What This Means**:

- `mode=true` → Annotation mode is active ✅
- `points=1` → Drag start was recorded ✅
- `pos=Offset(...)` → Drag position is updating ✅
- **If you see these messages**: Pan handlers are firing correctly
- **If you don't see messages**: Pan handlers aren't firing (requires different fix)

---

## Platforms to Test

| Platform | Test #1 | Test #2 | Test #3 | Test #4 | Priority |
|----------|---------|---------|---------|---------|----------|
| Android Phone | ✅ | ✅ | ✅ | — | HIGH |
| iOS Device | — | — | ✅ | — | HIGH |
| Web Browser | — | — | ✅ | ✅ | HIGH |
| Windows Desktop | — | — | ✅ | — | MEDIUM |
| macOS Desktop | — | — | ✅ | — | MEDIUM |

---

## Success Criteria

### For Issue #1 & #2 (Circle/Rectangle/Stroke)

- ✅ Menu appears correctly when long-pressed
- ✅ Selecting option without tapping commits the value
- ✅ Next drawn annotation uses the selected setting
- ✅ Works on all platforms

### For Issue #3 (Web Drag)

- ✅ Debug messages appear in console while dragging
- ✅ If yes → Issue is elsewhere in paint/state update pipeline
- ✅ If no → Pan handlers need special web handling

---

## Troubleshooting

### Circle/Rectangle Menu Doesn't Appear

- Check that annotation mode is active (button should be blue)
- Try long-pressing for longer (1+ second)
- On Android: May need to use different gesture (right-click with mouse if debugging)

### Selection Doesn't Apply

- Ensure you're **releasing without tapping** the menu
- Try tapping the menu option instead - if that works, the fix didn't apply
- Check that `flutter analyze` shows no errors

### Web Drag Debug Messages Don't Appear

- Ensure you opened browser console before dragging
- Check console is showing "All messages" not filtered
- Verify annotation mode is active (check UI button state)
- Try different browser (Chrome, Firefox, Safari)

---

## Bug Report Template

If a test fails, report with:

```
Platform: [Android/iOS/Web/Desktop]
Test: [#1 Circle Fill / #2 Rectangle / #3 Stroke / #4 Web Drag]
Expected: [what should happen]
Actual: [what actually happened]
Steps: [how to reproduce]
Console Output: [if applicable]
```

---

## Testing Checklist

- [ ] Test #1 - Circle Fill (Android)
- [ ] Test #2 - Rectangle Fill (Android)
- [ ] Test #3 - Stroke Width (Android)
- [ ] Test #3 - Stroke Width (iOS)
- [ ] Test #3 - Stroke Width (Web)
- [ ] Test #4 - Web Drag Debug (Web)
- [ ] Test #3 - Stroke Width (Windows)
- [ ] Test #3 - Stroke Width (macOS)
- [ ] Regression test - Normal annotation creation
- [ ] Regression test - Other features (playback, object editing)

---

## Timeline

- **Now**: Code implementation complete ✅
- **Next**: Manual testing on devices
- **Then**: Bug fixes if needed
- **Finally**: Deploy to production

---

**Ready to Test** ✅
