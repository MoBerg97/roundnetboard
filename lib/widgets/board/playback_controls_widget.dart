import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';

/// Playback controls widget for animation playback.
///
/// Provides stop, pause/play, and speed control for animation playback.
class PlaybackControlsWidget extends StatelessWidget {
  /// Whether playback is currently active
  final bool isPlaying;

  /// Whether playback is paused
  final bool isPaused;

  /// Current playback speed multiplier (0.25x, 0.5x, 1x, 2x)
  final double playbackSpeed;

  /// Callback when stop button is tapped
  final VoidCallback? onStop;

  /// Callback when pause button is tapped
  final VoidCallback? onPause;

  /// Callback when play button is tapped
  final VoidCallback? onPlay;

  /// Callback when playback speed is changed
  final ValueChanged<double>? onSpeedChanged;

  const PlaybackControlsWidget({
    super.key,
    required this.isPlaying,
    required this.isPaused,
    required this.playbackSpeed,
    this.onStop,
    this.onPause,
    this.onPlay,
    this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    // ┌─────────────────────────────────────────────────────────────────────┐
    // │ PLAYBACK CONTROLS CONTAINER                                         │
    // │ Dark grey background with elevation and padding                    │
    // │ EDIT: Background color, elevation, padding                         │
    // └─────────────────────────────────────────────────────────────────────┘
    return Container(
      color: AppTheme.darkGrey, // ← EDIT: Background color
      child: Material(
        color: Colors.transparent,
        elevation: 8, // ← EDIT: Shadow elevation
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.padding), // ← EDIT: Padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ─────────────────────────────────────────────────────────────
              // STOP BUTTON
              // Stops playback and returns to first frame
              // EDIT: Size, color, icon, shape
              // ─────────────────────────────────────────────────────────────
              SizedBox(
                width: 48, // ← EDIT: Button width
                height: 48, // ← EDIT: Button height
                child: ElevatedButton(
                  onPressed: isPlaying ? onStop : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed, // ← EDIT: Button color
                    foregroundColor: Colors.white, // ← EDIT: Icon color
                    disabledBackgroundColor: AppTheme.mediumGrey, // ← EDIT: Disabled color
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24), // ← EDIT: Pill shape
                    ),
                    elevation: AppConstants.cardElevation, // ← EDIT: Shadow
                  ),
                  child: const Icon(
                    Icons.stop,
                    size: 20, // ← EDIT: Icon size
                  ),
                ),
              ),

              // ─────────────────────────────────────────────────────────────
              // PAUSE/PLAY BUTTON
              // Toggles between pause and play states
              // EDIT: Size, color, icon, shape
              // ─────────────────────────────────────────────────────────────
              SizedBox(
                width: 48, // ← EDIT: Button width
                height: 48, // ← EDIT: Button height
                child: ElevatedButton(
                  onPressed: isPlaying ? (isPaused ? onPlay : onPause) : onPlay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue, // ← EDIT: Color
                    foregroundColor: Colors.white, // ← EDIT: Icon color
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24), // ← EDIT: Pill shape
                    ),
                    elevation: AppConstants.cardElevation, // ← EDIT: Shadow
                  ),
                  child: Icon(
                    isPaused || !isPlaying
                        ? Icons
                              .play_arrow // ← EDIT: Play icon
                        : Icons.pause, // ← EDIT: Pause icon
                    size: 36, // ← EDIT: Icon size
                  ),
                ),
              ),

              // ─────────────────────────────────────────────────────────────
              // SPEED CONTROL
              // Pill-shaped buttons to adjust playback speed
              // EDIT: Speed options, colors, text, spacing
              // ─────────────────────────────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speed label
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0), // ← EDIT: Spacing
                    child: Text(
                      'Speed:', // ← EDIT: Label text
                      style: TextStyle(
                        color: Colors.white70, // ← EDIT: Label color
                        fontSize: 12, // ← EDIT: Label size
                      ),
                    ),
                  ),
                  // Speed buttons
                  ...[0.25, 0.5, 1.0, 2.0].map((speed) {
                    final isSelected = (playbackSpeed - speed).abs() < 0.01;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2.0, // ← EDIT: Button spacing
                      ),
                      child: SizedBox(
                        width: 48, // ← EDIT: Button width
                        height: 48, // ← EDIT: Button height
                        child: ElevatedButton(
                          onPressed: isPlaying && onSpeedChanged != null ? () => onSpeedChanged!(speed) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? AppTheme
                                      .primaryBlue // ← EDIT: Selected color
                                : AppTheme.mediumGrey, // ← EDIT: Unselected color
                            foregroundColor: Colors.white, // ← EDIT: Text color
                            disabledBackgroundColor: AppTheme.mediumGrey, // ← EDIT: Disabled color
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24), // ← EDIT: Pill shape
                            ),
                            elevation: AppConstants.cardElevation, // ← EDIT: Shadow
                          ),
                          child: Text(
                            '${speed}x', // ← EDIT: Speed text format
                            style: const TextStyle(
                              fontSize: 10, // ← EDIT: Text size
                              fontWeight: FontWeight.w500, // ← EDIT: Text weight
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
