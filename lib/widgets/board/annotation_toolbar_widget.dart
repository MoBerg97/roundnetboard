import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../models/annotation.dart';

/// Annotation toolbar widget for drawing tools.
///
/// Provides tool selection (line, circle, eraser) and color picker.
class AnnotationToolbarWidget extends StatelessWidget {
  /// Currently selected annotation tool
  final AnnotationType selectedTool;

  /// Currently selected color for annotations
  final Color selectedColor;

  /// Callback when tool is changed
  final ValueChanged<AnnotationType>? onToolChanged;

  /// Callback when color picker is tapped
  final VoidCallback? onColorPickerTapped;

  const AnnotationToolbarWidget({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    this.onToolChanged,
    this.onColorPickerTapped,
  });

  @override
  Widget build(BuildContext context) {
    // ┌─────────────────────────────────────────────────────────────────────┐
    // │ ANNOTATION TOOLBAR CONTAINER                                        │
    // │ Vertical toolbar with tool buttons and color picker               │
    // │ EDIT: Background color, width, elevation, padding                  │
    // └─────────────────────────────────────────────────────────────────────┘
    return Container(
      width: 56, // ← EDIT: Toolbar width
      color: AppTheme.mediumGrey, // ← EDIT: Background color
      child: Material(
        color: Colors.transparent,
        elevation: 8, // ← EDIT: Shadow elevation
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.padding, // ← EDIT: Vertical padding
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────────────────────
              // LINE TOOL BUTTON
              // Draw straight lines on the court
              // EDIT: Icon, size, colors, shape
              // ─────────────────────────────────────────────────────────────
              _buildToolButton(
                icon: Icons.edit, // ← EDIT: Line tool icon
                tool: AnnotationType.line,
                tooltip: 'Draw Line', // ← EDIT: Tooltip text
              ),

              const SizedBox(height: 8), // ← EDIT: Button spacing
              // ─────────────────────────────────────────────────────────────
              // CIRCLE TOOL BUTTON
              // Draw circles on the court
              // EDIT: Icon, size, colors, shape
              // ─────────────────────────────────────────────────────────────
              _buildToolButton(
                icon: Icons.circle_outlined, // ← EDIT: Circle tool icon
                tool: AnnotationType.circle,
                tooltip: 'Draw Circle', // ← EDIT: Tooltip text
              ),

              const SizedBox(height: 16), // ← EDIT: Separator spacing
              // ─────────────────────────────────────────────────────────────
              // DIVIDER LINE
              // Visual separator between tools and color picker
              // EDIT: Color, thickness, width
              // ─────────────────────────────────────────────────────────────
              Container(
                width: 40, // ← EDIT: Divider width
                height: 1, // ← EDIT: Divider thickness
                color: AppTheme.lightGrey.withOpacity(0.3), // ← EDIT: Color
              ),

              const SizedBox(height: 16), // ← EDIT: Separator spacing
              // ─────────────────────────────────────────────────────────────
              // COLOR PICKER BUTTON
              // Opens color picker dialog
              // EDIT: Size, border, shadow
              // ─────────────────────────────────────────────────────────────
              Tooltip(
                message: 'Change Color', // ← EDIT: Tooltip text
                child: InkWell(
                  onTap: onColorPickerTapped,
                  borderRadius: BorderRadius.circular(8), // ← EDIT: Shape
                  child: Container(
                    width: 40, // ← EDIT: Button width
                    height: 40, // ← EDIT: Button height
                    decoration: BoxDecoration(
                      color: selectedColor, // Shows current color
                      borderRadius: BorderRadius.circular(8), // ← EDIT: Corner radius
                      border: Border.all(
                        color: Colors.white, // ← EDIT: Border color
                        width: 2, // ← EDIT: Border width
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 2, // ← EDIT: Shadow blur
                          spreadRadius: 0.5, // ← EDIT: Shadow spread
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.palette, // ← EDIT: Icon overlay
                      color: Colors.white, // ← EDIT: Icon color
                      size: 20, // ← EDIT: Icon size
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a tool selection button
  Widget _buildToolButton({required IconData icon, required AnnotationType tool, required String tooltip}) {
    final isSelected = selectedTool == tool;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40, // ← EDIT: Button width
        height: 40, // ← EDIT: Button height
        child: ElevatedButton(
          onPressed: onToolChanged != null ? () => onToolChanged!(tool) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? AppTheme
                      .primaryBlue // ← EDIT: Selected color
                : AppTheme.darkGrey, // ← EDIT: Unselected color
            foregroundColor: Colors.white, // ← EDIT: Icon color
            disabledBackgroundColor: AppTheme.mediumGrey, // ← EDIT: Disabled color
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius), // ← EDIT: Shape
            ),
            elevation: AppConstants.cardElevation, // ← EDIT: Shadow
          ),
          child: Icon(
            icon,
            size: 20, // ← EDIT: Icon size
          ),
        ),
      ),
    );
  }
}
