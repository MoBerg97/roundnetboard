import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A draggable player marker widget with rotation indicator.
///
/// Displays a colored circle with a direction indicator (line).
/// Supports drag-and-drop for repositioning on the board.
class PlayerMarkerWidget extends StatelessWidget {
  /// Player identifier (e.g., "P1", "P2", "P3", "P4")
  final String label;

  /// Screen position of the player marker
  final Offset position;

  /// Player color (from theme or custom)
  final Color color;

  /// Rotation angle in radians (0 = pointing up)
  final double rotation;

  /// Size of the marker circle in pixels
  final double size;

  /// Opacity of the marker (0.0 to 1.0)
  final double opacity;

  /// Whether the marker is currently being dragged
  final bool isDragging;

  /// Callback when drag starts
  final VoidCallback? onDragStart;

  /// Callback during drag with global position
  final ValueChanged<Offset>? onDragUpdate;

  /// Callback when drag ends
  final VoidCallback? onDragEnd;

  const PlayerMarkerWidget({
    super.key,
    required this.label,
    required this.position,
    required this.color,
    this.rotation = 0.0,
    this.size = 30.0,
    this.opacity = 1.0,
    this.isDragging = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: GestureDetector(
        onPanStart: (_) => onDragStart?.call(),
        onPanUpdate: (details) => onDragUpdate?.call(details.globalPosition),
        onPanEnd: (_) => onDragEnd?.call(),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: isDragging ? 1.2 : 1.0,
            child: CustomPaint(
              size: Size(size, size),
              painter: _PlayerMarkerPainter(color: color, rotation: rotation, isDragging: isDragging),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for player marker (circle with direction line).
class _PlayerMarkerPainter extends CustomPainter {
  final Color color;
  final double rotation;
  final bool isDragging;

  _PlayerMarkerPainter({required this.color, required this.rotation, required this.isDragging});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer circle (player body)
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, circlePaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging ? 3.0 : 2.0;

    canvas.drawCircle(center, radius, borderPaint);

    // Draw direction indicator (line)
    final directionPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging ? 3.0 : 2.0
      ..strokeCap = StrokeCap.round;

    final directionLength = radius * 0.7;
    final endX = center.dx + directionLength * math.sin(rotation);
    final endY = center.dy - directionLength * math.cos(rotation);

    canvas.drawLine(center, Offset(endX, endY), directionPaint);

    // Draw drag shadow
    if (isDragging) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(center + const Offset(2, 2), radius, shadowPaint);
    }
  }

  @override
  bool shouldRepaint(_PlayerMarkerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.rotation != rotation || oldDelegate.isDragging != isDragging;
  }
}
