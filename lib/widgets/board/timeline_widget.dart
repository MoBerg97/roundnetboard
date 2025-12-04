import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../models/animation_project.dart';
import 'frame_thumbnail.dart';

/// Timeline widget displaying all frames with scroll controls.
///
/// Shows frame thumbnails in a horizontal scrollable list with
/// add frame button and auto-scroll to selected frame.
class TimelineWidget extends StatefulWidget {
  /// The animation project containing all frames
  final AnimationProject project;

  /// Currently selected frame index
  final int currentFrameIndex;

  /// Whether playback is active
  final bool isPlaybackMode;

  /// Callback when frame is selected
  final ValueChanged<int> onFrameSelected;

  /// Callback when add frame button is tapped
  final VoidCallback onAddFrame;

  /// Callback when delete frame is requested
  final ValueChanged<int> onDeleteFrame;

  const TimelineWidget({
    super.key,
    required this.project,
    required this.currentFrameIndex,
    required this.isPlaybackMode,
    required this.onFrameSelected,
    required this.onAddFrame,
    required this.onDeleteFrame,
  });

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Auto-scroll to selected frame after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentFrame();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll when frame changes
    if (oldWidget.currentFrameIndex != widget.currentFrameIndex) {
      _scrollToCurrentFrame();
    }
  }

  /// Scrolls the timeline to make the current frame visible
  void _scrollToCurrentFrame() {
    if (!_scrollController.hasClients) return;

    // Calculate position of current frame
    // Frame width (56) + margins (8 * 2) = 72px per frame
    const frameWidth = 72.0;
    final targetOffset = widget.currentFrameIndex * frameWidth;

    // Get viewport width
    final viewportWidth = _scrollController.position.viewportDimension;

    // Calculate desired scroll position (center the frame)
    final centerOffset = targetOffset - (viewportWidth / 2) + (frameWidth / 2);

    // Clamp to valid scroll range
    final minScroll = _scrollController.position.minScrollExtent;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final scrollTo = centerOffset.clamp(minScroll, maxScroll);

    // Animate scroll
    _scrollController.animateTo(scrollTo, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    // ┌─────────────────────────────────────────────────────────────────────┐
    // │ TIMELINE CONTAINER                                                  │
    // │ Background container with elevation and padding                    │
    // │ EDIT: Background color, elevation, height                          │
    // └─────────────────────────────────────────────────────────────────────┘
    return Container(
      height: 80, // ← EDIT: Timeline height (includes padding)
      color: AppTheme.mediumGrey, // ← EDIT: Background color
      child: Material(
        color: Colors.transparent,
        elevation: 8, // ← EDIT: Shadow elevation
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.padding, // ← EDIT: Vertical padding
          ),
          child: Row(
            children: [
              // ─────────────────────────────────────────────────────────────
              // ADD FRAME BUTTON (Left Side)
              // Pill-shaped button to add new frames
              // EDIT: Size, color, icon, margin
              // ─────────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(
                  left: AppConstants.padding, // ← EDIT: Left margin
                  right: AppConstants.paddingSmall, // ← EDIT: Right margin
                ),
                child: SizedBox(
                  width: 48, // ← EDIT: Button width
                  height: 48, // ← EDIT: Button height
                  child: ElevatedButton(
                    onPressed: widget.isPlaybackMode ? null : widget.onAddFrame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue, // ← EDIT: Color
                      foregroundColor: Colors.white, // ← EDIT: Icon color
                      disabledBackgroundColor: AppTheme.mediumGrey, // ← EDIT: Disabled color
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24), // ← EDIT: Pill shape
                      ),
                      elevation: AppConstants.cardElevation, // ← EDIT: Shadow
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 24, // ← EDIT: Icon size
                    ),
                  ),
                ),
              ),

              // ─────────────────────────────────────────────────────────────
              // FRAME LIST (Scrollable)
              // Horizontal list of frame thumbnails
              // EDIT: Spacing, scroll behavior
              // ─────────────────────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.project.frames.length,
                  itemBuilder: (context, index) {
                    return FrameThumbnailWidget(
                      frameNumber: index + 1, // ← EDIT: 1-indexed display
                      isSelected: index == widget.currentFrameIndex,
                      isPlaybackMode: widget.isPlaybackMode,
                      width: 56, // ← EDIT: Thumbnail width
                      height: 48, // ← EDIT: Thumbnail height
                      onTap: widget.isPlaybackMode ? null : () => widget.onFrameSelected(index),
                      onDelete: widget.project.frames.length > 1
                          ? () => widget.onDeleteFrame(index)
                          : null, // Prevent deleting last frame
                    );
                  },
                ),
              ),

              // ─────────────────────────────────────────────────────────────
              // RIGHT PADDING
              // Spacing after last frame
              // EDIT: Padding size
              // ─────────────────────────────────────────────────────────────
              const SizedBox(width: AppConstants.padding),
            ],
          ),
        ),
      ),
    );
  }
}
