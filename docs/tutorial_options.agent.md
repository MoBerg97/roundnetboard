
---

### Step-by-Step Implementation for Each Option

#### **Option 1: Gesture Validation Wrapper**
1. [BoardTutorialOverlay](lib/widgets/board_tutorial_overlay.dart#L19) - Add `isDragStep` property to step config
2. Create `TutorialGestureValidator` to intercept `onPanStart`/`onPanEnd` during tutorial
3. Modify BoardScreen's drag handlers to notify tutorial when drag completes
4. Replace tap-advance with `_validateAndAdvanceStep()` for drag steps
5. Test with Step 3 (Player 1) first

#### **Option 2: Guided Banner Mode**
1. Create `lib/widgets/tutorial_instruction_banner.dart` with instruction text
2. Modify [BoardScreen._startBoardTutorial()](lib/screens/board_screen.dart#L247) to show banner instead of overlay for drag steps
3. Add callbacks to existing drag handlers: `_onPlayerDragEnd()` → notify tutorial service
4. Banner auto-advances via `TutorialService.acknowledgeStepCompletion()`
5. Keep home/annotation tutorials with current `TutorialCoachMark`

#### **Option 3: Custom Pass-Through Overlay**
1. Create `lib/widgets/interactive_tutorial_overlay.dart` with custom rendering
2. Build widget tree that holds `IgnorePointer(ignoring: true)` for all except target
3. Mirror highlight/focus effect from `TutorialCoachMark`
4. Add drag validation logic similar to Option 1
5. Replace `BoardTutorialOverlay`'s use of `TutorialCoachMark` entirely

#### **Option 4: Hybrid Implementation**
1. Detect step type in [BoardTutorialOverlay](lib/widgets/board_tutorial_overlay.dart)
2. Create step config: `isDragStep`, `tapTarget`, `dragTarget`, `minDragDistance`
3. Show banner for drag steps; overlay for tap steps
4. Implement dual state management (banner vs overlay)
5. Reuse validation logic from Option 1

---

### Quick Decision Matrix

| Option | Ease | UX | Implementation Time | Maintenance | Mobile/Web Support |
|--------|------|-----|-------------------|-------------|-------------------|
| 1 | Medium | Good | 4-6 hrs | Medium | ✅ Both |
| 2 | Easy | Excellent | 2-3 hrs | Low | ✅ Both |
| 3 | Hard | Excellent | 8-12 hrs | High | ✅ Both |
| 4 | Medium | Excellent | 5-7 hrs | Medium | ✅ Both |

**My Recommendation**: **Start with Option 4 (Hybrid)** because:
- Reuses your existing `TutorialCoachMark` for non-drag steps (battle-tested)
- Adds banner only for drag steps (minimal changes)
- Best UX/effort ratio
- Can fallback to current behavior if issues arise