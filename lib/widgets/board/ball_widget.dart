import 'package:flutter/material.dart';

/// A draggable ball marker widget with optional effects.
///
/// Displays a colored circle representing the ball.
/// Supports drag-and-drop, tap interactions, and scaling effects.
class BallWidget extends StatelessWidget {
  /// Screen position of the ball marker
  final Offset position;

  /// Ball color
  final Color color;

  /// Size of the ball in pixels
  final double size;

  /// Scale multiplier (for animation effects like set/hit)
  final double scale;

  /// Opacity of the ball (0.0 to 1.0)
  final double opacity;

  /// Whether the ball is currently being dragged
  final bool isDragging;

  /// Whether to show hit marker on the ball
  final bool showHitMarker;

  /// Whether to show set marker on the ball
  final bool showSetMarker;

  /// Callback when ball is tapped
  final VoidCallback? onTap;

  /// Callback when drag starts
  final VoidCallback? onDragStart;

  /// Callback during drag with global position
  final ValueChanged<Offset>? onDragUpdate;

  /// Callback when drag ends
  final VoidCallback? onDragEnd;

  const BallWidget({
    super.key,
    required this.position,
    required this.color,
    this.size = 20.0,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.isDragging = false,
    this.showHitMarker = false,
    this.showSetMarker = false,
    this.onTap,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scaledSize = size * scale;

    return Positioned(
      left: position.dx - scaledSize / 2,
      top: position.dy - scaledSize / 2,
      child: GestureDetector(
        onTap: onTap,
        onPanStart: (_) => onDragStart?.call(),
        onPanUpdate: (details) => onDragUpdate?.call(details.globalPosition),
        onPanEnd: (_) => onDragEnd?.call(),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: isDragging ? 1.2 : 1.0,
            child: CustomPaint(
              size: Size(scaledSize, scaledSize),
              painter: _BallPainter(
                color: color,
                showHitMarker: showHitMarker,
                showSetMarker: showSetMarker,
                isDragging: isDragging,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for ball marker (circle with optional indicators).
class _BallPainter extends CustomPainter {
  final Color color;
  final bool showHitMarker;
  final bool showSetMarker;
  final bool isDragging;

  _BallPainter({
    required this.color,
    required this.showHitMarker,
    required this.showSetMarker,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw shadow if dragging
    if (isDragging) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(center + const Offset(2, 2), radius, shadowPaint);
    }

    // Draw ball body
    final ballPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, ballPaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging ? 2.5 : 2.0;

    canvas.drawCircle(center, radius, borderPaint);

    // Draw hit marker (small red circle)
    if (showHitMarker) {
      final hitPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius * 0.3, hitPaint);

      final hitBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius * 0.3, hitBorderPaint);
    }

    // Draw set marker (small orange arc)
    if (showSetMarker) {
      final setPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius * 0.5);
      canvas.drawArc(rect, -1.57, 3.14, false, setPaint);

      // Draw endpoint circle
      final endpointPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;

      final endX = center.dx + (radius * 0.5);
      final endY = center.dy;
      canvas.drawCircle(Offset(endX, endY), 2, endpointPaint);
    }
  }

  @override
  bool shouldRepaint(_BallPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.showHitMarker != showHitMarker ||
        oldDelegate.showSetMarker != showSetMarker ||
        oldDelegate.isDragging != isDragging;
  }
}
