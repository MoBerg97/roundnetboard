import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';

/// A thumbnail widget representing a single frame in the timeline.
///
/// Displays frame number with selection state and delete button.
/// Used in the timeline ListView for frame navigation.
class FrameThumbnailWidget extends StatelessWidget {
  /// Frame number to display (0-indexed or 1-indexed based on mode)
  final int frameNumber;

  /// Whether this frame is currently selected
  final bool isSelected;

  /// Whether playback is active (changes styling)
  final bool isPlaybackMode;

  /// Whether this is the currently playing frame
  final bool isPlayingFrame;

  /// Width of the thumbnail
  final double width;

  /// Height of the thumbnail
  final double height;

  /// Callback when frame is tapped
  final VoidCallback? onTap;

  /// Callback when delete button is tapped
  final VoidCallback? onDelete;

  const FrameThumbnailWidget({
    super.key,
    required this.frameNumber,
    this.isSelected = false,
    this.isPlaybackMode = false,
    this.isPlayingFrame = false,
    this.width = 56.0,
    this.height = 48.0,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // ┌─────────────────────────────────────────────────────────────────────┐
    // │ FRAME THUMBNAIL                                                     │
    // │ Pill-shaped button representing a single animation frame           │
    // │ EDIT: Width, height, border radius, colors, padding               │
    // └─────────────────────────────────────────────────────────────────────┘
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // ─────────────────────────────────────────────────────────────────
          // FRAME CONTAINER (Pill-Shaped Background)
          // EDIT: Background color, border, shadow, border radius
          // ─────────────────────────────────────────────────────────────────
          Container(
            width: width,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall),
            decoration: BoxDecoration(
              // Background color based on state
              color: isPlaybackMode
                  ? AppTheme.timelineInactive
                  : (isSelected ? AppTheme.timelineActive : AppTheme.timelineInactive),
              // Pill-shaped border radius
              borderRadius: BorderRadius.circular(20), // ← EDIT: Pill shape
              // Border for selected frame
              border: isPlaybackMode
                  ? null
                  : (isSelected
                        ? Border.all(
                            color: AppTheme.primaryBlue,
                            width: 2.5, // ← EDIT: Border thickness
                          )
                        : null),
              // Shadow for selected frame
              boxShadow: isSelected && !isPlaybackMode
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 4, // ← EDIT: Shadow blur
                        spreadRadius: 1, // ← EDIT: Shadow spread
                      ),
                    ]
                  : null,
            ),
            // ───────────────────────────────────────────────────────────────
            // FRAME NUMBER TEXT
            // Centered text showing frame index
            // EDIT: Font size, weight, color
            // ───────────────────────────────────────────────────────────────
            child: Center(
              child: Text(
                '$frameNumber',
                style: TextStyle(
                  fontWeight: isSelected && !isPlaybackMode
                      ? FontWeight
                            .bold // ← EDIT: Selected weight
                      : FontWeight.normal, // ← EDIT: Normal weight
                  color: isSelected && !isPlaybackMode
                      ? Colors
                            .white // ← EDIT: Selected text color
                      : AppTheme.darkGrey, // ← EDIT: Normal text color
                  fontSize: 14, // ← EDIT: Text size
                ),
              ),
            ),
          ),

          // ─────────────────────────────────────────────────────────────────
          // DELETE BUTTON (Top-Right Corner)
          // Only shown when frame is selected in edit mode
          // EDIT: Size, position, color, icon
          // ─────────────────────────────────────────────────────────────────
          if (isSelected && !isPlaybackMode && onDelete != null)
            Positioned(
              top: 4, // ← EDIT: Top offset
              right: 4, // ← EDIT: Right offset
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 20, // ← EDIT: Button width
                  height: 20, // ← EDIT: Button height
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed, // ← EDIT: Button color
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 2, // ← EDIT: Shadow blur
                        spreadRadius: 0.5, // ← EDIT: Shadow spread
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14, // ← EDIT: Icon size
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
