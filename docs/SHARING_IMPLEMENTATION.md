# Project Sharing Implementation Summary

## Overview
Complete JSON serialization and quick-share UI have been implemented to enable full project sharing with all objects, paths, annotations, settings, and timing information.

## What Was Implemented

### 1. Complete JSON Serialization
All models now support full round-trip JSON serialization:

#### `lib/models/annotation.dart`
- Added `toMap()` and `fromMap()` methods to `Annotation`
- Serializes: annotation type, color value, and points
- Supports both line and circle annotation types

#### `lib/models/frame.dart`
- Extended `Frame.toMap()` to include:
  - `duration` - frame-specific animation duration
  - `ballHitT` - ball hit timing parameter (nullable)
  - `ballSet` - ball set effect toggle (nullable)
  - `annotations` - list of frame-specific annotations
- Updated `Frame.fromMap()` to deserialize all new fields with proper null handling

#### `lib/models/animation_project.dart`
- Verified complete serialization of project name, frames list, and settings
- All nested objects properly serialize/deserialize

#### `lib/models/settings.dart`
- Already had complete `toMap()`/`fromMap()` including `showPreviousFrameLines`

### 2. Sharing Infrastructure

#### `pubspec.yaml`
- Added `share_plus: ^10.1.2` dependency for cross-platform sharing

#### `lib/utils/share_helper.dart` (NEW)
- `shareProject()` - Exports project to JSON and opens system share sheet
- `exportProject()` - Exports project to JSON file and returns file path
- `shareText()` - Helper for sharing text messages
- Uses XFile for cross-platform file sharing

### 3. User Interface Updates

#### `lib/screens/home_screen.dart`
Added menu items to project popup menu:
- **Export JSON** - Saves project as JSON file to app documents directory
- **Share Project** - Opens system share sheet to share project file
- **Import Project** (via FAB) - Allows importing shared projects via file picker

Key features:
- Automatic name collision handling (adds numeric suffix if project name exists)
- Success/error notifications via SnackBars
- Deep copying of imported projects to avoid reference issues

### 4. Testing

#### `test/export_import_test.dart` (NEW)
Comprehensive unit tests covering:
- Complete project serialization with all fields (positions, rotations, paths, timing, annotations, settings)
- Empty project handling
- Null optional fields (ballHitT, ballSet)
- Round-trip serialization through JSON encoding/decoding

**Test Results**: ✅ All 3 tests passing

## What's Included in Shared Projects

When a user shares a project, the JSON file contains a **complete replica** including:

### Player & Ball Data
- Positions (p1, p2, p3, p4, ball) for each frame
- Rotations for all players (radians)
- Path control points for smooth animations

### Ball Modifiers
- Hit markers with timing (`ballHitT`)
- Set effect toggles (`ballSet`)

### Timing & Animation
- Frame-specific durations
- Playback speed settings

### Annotations
- Line annotations with start/end points
- Circle annotations with center and radius
- Colors for each annotation

### Court Settings
- Circle radii (outer, inner, net, bounds)
- Reference radius for scaling
- Previous frame line visibility toggle

## How to Use

### Sharing a Project
1. Open the app and view your project list
2. Tap the three-dot menu on any project
3. Select "Share Project"
4. Choose where to share (messaging apps, email, file save, etc.)

### Exporting a Project
1. Tap the three-dot menu on a project
2. Select "Export JSON"
3. Project is saved to app documents directory
4. Path is shown in a notification

### Importing a Project
1. Tap the upload icon (floating action button) on the home screen
2. Select a `.json` project file
3. Project is imported with all data intact
4. If name exists, a numeric suffix is automatically added

## Technical Notes

### Serialization Format
- JSON with pretty-printing (2-space indentation)
- Offset points stored as `[dx, dy]` arrays
- Enum types stored as strings (e.g., `"line"`, `"circle"`)
- Colors stored as integer values for compatibility

### Cross-Platform Compatibility
- `share_plus` works on Android, iOS, Web, Windows, macOS, and Linux
- `file_picker` used for importing on all platforms
- File paths use platform-appropriate separators

### Safe Name Handling
- Project names sanitized for filesystem (non-alphanumeric replaced with underscore)
- Automatic collision detection and numbering (e.g., "Project (1)", "Project (2)")

## Future Enhancements

Possible additions (not yet implemented):
- Image export (single frame snapshots)
- Video export (full animation to MP4)
- Cloud-backed sharing with URLs
- Gallery save integration
- Batch export (all frames as images)
- Export metadata (creation date, app version)

## Files Modified/Created

### Modified
- `lib/models/annotation.dart`
- `lib/models/frame.dart`
- `lib/screens/home_screen.dart`
- `pubspec.yaml`

### Created
- `lib/utils/share_helper.dart`
- `test/export_import_test.dart`

## Testing Recommendations

Before release:
1. ✅ Unit tests pass
2. Test sharing on each target platform (Android, iOS, Windows)
3. Test import/export with large projects (many frames, many annotations)
4. Test name collision handling with various characters
5. Verify share sheet integration on mobile devices
6. Test file picker on desktop platforms

## Dependencies Added
- `share_plus: ^10.1.2` - Cross-platform sharing API
