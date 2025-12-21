# Phase 4: Performance Optimizations

## Overview
Phase 4 focuses on optimizing render performance, reducing unnecessary rebuilds, and improving frame rates during animation playback and editing.

## Issues Fixed (User Request)
✅ Play/pause and stop buttons now same size during playback (40x40, 48x40)
✅ Play button consistent position between edit and playback modes
✅ Video scrubber moved higher on screen (top: 12)
✅ Hit/Set toggle buttons don't close menu when toggled
✅ Hit/Set buttons are mutually exclusive toggles

## Performance Optimization Tasks

### 1. Add Const Constructors
**Goal:** Reduce unnecessary widget rebuilds by marking constructors as const.

**Files to Update:**
- `lib/widgets/board/player_marker.dart` - PlayerMarkerWidget
- `lib/widgets/board/ball_widget.dart` - BallWidget
- `lib/widgets/board/frame_thumbnail.dart` - FrameThumbnailWidget
- `lib/widgets/board/timeline_widget.dart` - TimelineWidget
- `lib/widgets/board/playback_controls_widget.dart` - PlaybackControlsWidget
- `lib/widgets/board/annotation_toolbar_widget.dart` - AnnotationToolbarWidget
- `lib/widgets/path_painter.dart`
- `lib/widgets/board_background_painter.dart`
- `lib/widgets/annotation_painter.dart`

**Implementation:** Mark all widget constructors with `const` and ensure all parameters are compile-time constants or final. This allows Flutter's optimizer to skip rebuilds for identical widget instances.

### 2. Optimize Custom Painters with shouldRepaint
**Goal:** Skip painting operations when nothing changed.

**Files to Update:**
- `lib/widgets/board/player_marker.dart` - `_PlayerMarkerPainter.shouldRepaint()`
- `lib/widgets/board/ball_widget.dart` - `_BallPainter.shouldRepaint()`
- `lib/widgets/board_background_painter.dart` - `BoardBackgroundPainter.shouldRepaint()`
- `lib/widgets/path_painter.dart` - `PathPainter.shouldRepaint()`
- `lib/widgets/annotation_painter.dart` - `AnnotationPainter.shouldRepaint()`
- `lib/screens/board_screen.dart` - `_StarPainter.shouldRepaint()`, `_SetIconPainter.shouldRepaint()`, `_HitIconPainter.shouldRepaint()`

**Implementation Pattern:**
```dart
@override
bool shouldRepaint(OldPainter oldPainter) {
  return oldPainter.position != position ||
      oldPainter.scale != scale ||
      oldPainter.opacity != opacity;
}
```

### 3. Implement RepaintBoundary for Expensive Widgets
**Goal:** Isolate repaints to expensive widgets, preventing entire subtree repaints.

**Candidates:**
- Timeline frame list (changes frequently during playback)
- Board canvas (expensive CustomPaint operations)
- Annotation painter (complex path drawing)
- Path control points

**Implementation:** Wrap expensive CustomPaint widgets with `RepaintBoundary()`:
```dart
RepaintBoundary(
  child: CustomPaint(
    painter: expensive_painter,
  ),
)
```

### 4. Optimize ListView.builder Items
**Goal:** Reduce build time for timeline frame thumbnails.

**Files to Update:**
- `lib/screens/board_screen.dart` - Timeline frame ListView.builder
- `lib/widgets/board/timeline_widget.dart` - Frame list building

**Optimizations:**
- Use `const` children where possible
- Implement efficient equality checks in GestureDetector callbacks
- Lazy-load expensive computed properties
- Use `.addRepaintBoundaries = false` for simple items if no nested CustomPaint

### 5. Profile Performance Bottlenecks
**Goal:** Identify and fix slowest operations.

**Measurement Strategy:**
1. Enable performance overlay during playback (press 'P' in DevTools)
2. Monitor frame time graph - target 60fps (16.67ms per frame)
3. Use Dart DevTools profiler to identify expensive functions:
   - `_updatePlayback()` - interpolation calculations
   - `_animatedFrame` getter - frame interpolation
   - Custom painters in `paint()` methods
4. Use `Timeline.startSync()`/`Timeline.finishSync()` for manual profiling

**Expected Results:**
- Consistent 60fps during playback
- <5ms rebuild time for frame changes
- <10ms for each paint operation

### 6. Optimize State Management
**Goal:** Minimize setState() calls during animation playback.

**Strategies:**
- Use `_ticker` instead of setState for smooth animation
- Update only affected state variables in setState callbacks
- Consider moving animation state to AnimationController
- Use `shouldNotify` pattern for state notifications

**Files to Focus:**
- `lib/screens/board_screen.dart` - Playback loop optimization

### 7. Cache Expensive Computations
**Goal:** Avoid recalculating values in hot loops.

**Candidates to Cache:**
- Frame interpolation (`_animatedFrame`)
- Path point calculations (`PathEngine.fromTwoQuadratics()`)
- Screen coordinate conversions (`_toScreenPosition()`)
- Hit marker positions during playback

**Implementation:** Use `late` variables and lazy initialization patterns.

### 8. Optimize Hit Marker Rendering
**Goal:** Reduce the cost of rendering persistent hit markers.

**Current Bottleneck:** `_playbackHitStarInfo()` called every frame during playback

**Optimization:**
```dart
// Cache hit marker position at frame start
late Offset? _cachedHitMarkerPos;

// Update only when frame changes
if (_playbackFrameIndex != _previousFrameIndex) {
  _cachedHitMarkerPos = _calculateHitMarkerPos();
}
```

## Performance Targets

| Metric | Current | Target |
|--------|---------|--------|
| Playback FPS | ~30-45 | 60 |
| Edit mode FPS | ~45-60 | 60 |
| Frame change time | ~50-100ms | <20ms |
| Playback control latency | ~100ms | <50ms |
| Memory usage playback | ~150MB | <100MB |

## Testing Checklist

- [ ] Run app with `--profile` flag for performance testing
- [ ] Monitor DevTools Performance tab during playback
- [ ] Verify no frame drops during speed changes (0.25x to 2x)
- [ ] Test with 30-frame projects (most demanding case)
- [ ] Profile memory leaks with `observatory`
- [ ] Test on low-end devices (if available)

## Branch & Commit Strategy

1. Create feature branch: `feature/phase-4-performance`
2. Commit each optimization separately for easy revert if issues arise
3. Test after each significant change
4. Create PR with detailed before/after metrics

## Success Criteria

✅ Maintain 60fps during animation playback
✅ <50ms response time for UI interactions
✅ No memory leaks on extended use
✅ Smooth transitions between edit/playback modes
✅ No dropped frames during timeline scrolling

## Notes

- Use Flutter's built-in DevTools profiling: `flutter pub global activate devtools`
- Profile on actual device, not emulator
- Test with varying project sizes (5, 15, 30+ frames)
- Document any performance regressions with before/after metrics

---

**Status:** In Progress
**Last Updated:** December 4, 2025
**Owner:** Development Team
