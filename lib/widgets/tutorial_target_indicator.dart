import 'package:flutter/material.dart';

/// A pulsing target indicator to guide drag actions during tutorial steps.
/// Expects screen-space coordinates for position and radius (in logical pixels).
class TutorialTargetIndicator extends StatefulWidget {
  final Offset center;
  final double radiusPx;
  final Color color;

  const TutorialTargetIndicator({super.key, required this.center, required this.radiusPx, this.color = Colors.cyan});

  @override
  State<TutorialTargetIndicator> createState() => _TutorialTargetIndicatorState();
}

class _TutorialTargetIndicatorState extends State<TutorialTargetIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value; // 0..1
        // Two rings: inner constant, outer pulsing fade/expand
        final outerScale = 1.0 + 0.35 * t;
        final outerOpacity = (1.0 - t).clamp(0.0, 1.0);
        final outerRadius = widget.radiusPx * outerScale;

        return IgnorePointer(
          ignoring: true,
          child: Stack(
            children: [
              // Inner base ring
              Positioned(
                left: widget.center.dx - widget.radiusPx,
                top: widget.center.dy - widget.radiusPx,
                child: _Ring(radius: widget.radiusPx, color: widget.color.withValues(alpha: 0.45), thickness: 2),
              ),
              // Outer pulsing ring
              Positioned(
                left: widget.center.dx - outerRadius,
                top: widget.center.dy - outerRadius,
                child: Opacity(
                  opacity: outerOpacity * 0.9,
                  child: _Ring(radius: outerRadius, color: widget.color.withValues(alpha: 0.35), thickness: 2),
                ),
              ),
              // Center dot
              Positioned(
                left: widget.center.dx - 4,
                top: widget.center.dy - 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  final double radius;
  final Color color;
  final double thickness;

  const _Ring({required this.radius, required this.color, required this.thickness});

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: thickness),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 2)],
      ),
    );
  }
}
