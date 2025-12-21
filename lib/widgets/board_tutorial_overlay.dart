import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';

/// Custom tutorial overlay that highlights UI elements and shows instructions
/// Uses conditional gesture pass-through to allow interaction with highlighted widgets
class BoardTutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onFinish;
  final GlobalKey? boardKey;

  const BoardTutorialOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    this.boardKey,
  });

  @override
  State<BoardTutorialOverlay> createState() => _BoardTutorialOverlayState();
}

class _BoardTutorialOverlayState extends State<BoardTutorialOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  final GlobalKey _overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Listen to tutorial service for step changes
    TutorialService().addListener(_onTutorialChanged);
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    TutorialService().removeListener(_onTutorialChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTutorialChanged() {
    if (mounted) setState(() {});
  }

  void _handleNext() {
    final tutorial = TutorialService();
    final currentStep = tutorial.currentStep;
    if (currentStep == null) return;

    if (currentStep.isConditional) {
      // Special case for step 7 (board_drag)
      if (currentStep.id == 'board_drag' && tutorial.movedObjectsCount < 2) {
        return;
      }

      if (currentStep.autoPerformAction != null) {
        currentStep.autoPerformAction!();
        // After auto-performing, we should advance
        tutorial.nextStep();
      }
      return;
    }

    // Don't allow manual advance on drag-required steps unless it's a skip
    if (currentStep.requiresDrag) {
      return;
    }

    final isLastStep = tutorial.currentStepIndex == widget.steps.length - 1;
    tutorial.nextStep();
    if (isLastStep) {
      widget.onFinish();
    }
  }

  void _handleSkip() {
    TutorialService().finishTutorial();
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = TutorialService();
    final currentStep = tutorial.currentStep;

    if (!tutorial.isActive || currentStep == null) {
      return const SizedBox.shrink();
    }

    // Only show backdrop for non-drag steps (when not interacting on board)
    final shouldShowBackdrop = !currentStep.requiresDrag;

    return Stack(
      key: _overlayKey,
      children: [
        // Semi-transparent backdrop with hole for highlighted UI element
        if (shouldShowBackdrop)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: _TutorialBackdrop(
                targetKey: currentStep.targetKey,
                overlayKey: _overlayKey,
              ),
            ),
          ),

        // Pulsing glow around target key to create consistent highlight (only for non-drag steps)
        if (currentStep.targetKey != null && !currentStep.requiresDrag)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => IgnorePointer(
                ignoring: true,
                child: _TargetKeyPulseGlow(
                  targetKey: currentStep.targetKey,
                  t: _pulse.value,
                  overlayKey: _overlayKey,
                ),
              ),
            ),
          ),

          // Instruction card - positioned at top, smaller and more transparent
          Positioned(
            left: 12,
            right: 12,
            top: currentStep.id == 'ball_modifier' || currentStep.id == 'ball_hit' ? 80 : 12,
            child: Card(
              elevation: 4,
              color: Colors.black87.withOpacity(0.85),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentStep.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _handleSkip,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                          child: const Text('Skip', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentStep.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step ${tutorial.currentStepIndex + 1}/${widget.steps.length}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54),
                        ),
                        if (!currentStep.requiresDrag)
                          ElevatedButton(
                            onPressed: _handleNext,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              backgroundColor: (currentStep.isConditional && (currentStep.id != 'board_drag' || tutorial.movedObjectsCount < 2)) ? Colors.grey.withOpacity(0.5) : null,
                            ),
                            child: Text(
                              tutorial.currentStepIndex == widget.steps.length - 1 ? 'Finish' : 'Next',
                              style: TextStyle(
                                fontSize: 12,
                                color: (currentStep.isConditional && (currentStep.id != 'board_drag' || tutorial.movedObjectsCount < 2)) ? Colors.white60 : null,
                              ),
                            ),
                          ),
                        if (currentStep.requiresDrag)
                          Text(
                            'Perform the action →',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Success Effect Overlay
          if (tutorial.showSuccessEffect)
            const _SuccessEffect(),
        ],
      );
  }
}

class _SuccessEffect extends StatefulWidget {
  const _SuccessEffect();

  @override
  State<_SuccessEffect> createState() => _SuccessEffectState();
}

class _SuccessEffectState extends State<_SuccessEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            color: Colors.green.withOpacity(0.15 * (1.0 - _opacity.value)),
            child: Center(
              child: Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: 1.0 - _opacity.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 100),
                      const SizedBox(height: 12),
                      Text(
                        'Great!',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Backdrop with a cutout hole for the highlighted UI element
class _TutorialBackdrop extends StatelessWidget {
  final GlobalKey? targetKey;
  final GlobalKey overlayKey;

  const _TutorialBackdrop({this.targetKey, required this.overlayKey});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter(targetKey: targetKey, overlayKey: overlayKey),
      child: const SizedBox.expand(),
    );
  }
}

/// Custom painter that draws a semi-transparent dim with a hole around UI element
class _BackdropPainter extends CustomPainter {
  final GlobalKey? targetKey;
  final GlobalKey overlayKey;

  _BackdropPainter({required this.targetKey, required this.overlayKey});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw semi-transparent dim overlay
    final dimPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // If we have a target widget, try to cut a hole for it
    if (targetKey != null) {
      try {
        final renderObject = targetKey!.currentContext?.findRenderObject();
        final overlayObject = overlayKey.currentContext?.findRenderObject();

        if (renderObject is RenderBox && renderObject.attached && overlayObject is RenderBox && overlayObject.attached) {
          final targetSize = renderObject.size;
          final targetGlobalPos = renderObject.localToGlobal(Offset.zero);
          final overlayGlobalPos = overlayObject.localToGlobal(Offset.zero);
          final targetPosition = targetGlobalPos - overlayGlobalPos;

          // Create path with hole around the UI element
          // Clamp the hole to be at least partially visible and ensure glow is visible
          final highlightRect = Rect.fromLTWH(
            targetPosition.dx - 6,
            targetPosition.dy - 6,
            targetSize.width + 12,
            targetSize.height + 12,
          );

          final path = Path()
            ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
            ..addRRect(
              RRect.fromRectAndRadius(
                highlightRect,
                const Radius.circular(10),
              ),
            )
            ..fillType = PathFillType.evenOdd;

          canvas.drawPath(path, dimPaint);

          // Draw glowing highlight border around the hole
          final glowPaint = Paint()
            ..color = Colors.cyan.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);

          canvas.drawRRect(
            RRect.fromRectAndRadius(highlightRect, const Radius.circular(10)),
            glowPaint,
          );

          return;
        }
      } catch (e) {
        // Target not found or not ready, fall through to full backdrop
      }
    }

    // No target or target not ready, just draw full dim
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) {
    return targetKey != oldDelegate.targetKey || overlayKey != oldDelegate.overlayKey;
  }
}

/// Animated pulsing glow around a target widget identified by GlobalKey.
class _TargetKeyPulseGlow extends StatelessWidget {
  final GlobalKey? targetKey;
  final double t; // 0..1
  final GlobalKey overlayKey;

  const _TargetKeyPulseGlow({required this.targetKey, required this.t, required this.overlayKey});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _KeyPulsePainter(targetKey: targetKey, t: t, overlayKey: overlayKey),
      child: const SizedBox.expand(),
    );
  }
}

class _KeyPulsePainter extends CustomPainter {
  final GlobalKey? targetKey;
  final double t;
  final GlobalKey overlayKey;

  _KeyPulsePainter({required this.targetKey, required this.t, required this.overlayKey});

  @override
  void paint(Canvas canvas, Size size) {
    if (targetKey == null) return;
    final ro = targetKey!.currentContext?.findRenderObject();
    final oo = overlayKey.currentContext?.findRenderObject();

    if (ro is! RenderBox || !ro.attached || oo is! RenderBox || !oo.attached) return;

    final targetSize = ro.size;
    final targetGlobalPos = ro.localToGlobal(Offset.zero);
    final overlayGlobalPos = oo.localToGlobal(Offset.zero);
    final targetPos = targetGlobalPos - overlayGlobalPos;

    final baseRect = Rect.fromLTWH(
      targetPos.dx - 6,
      targetPos.dy - 6,
      targetSize.width + 12,
      targetSize.height + 12,
    );

    // Draw a static highlight border first
    final staticPaint = Paint()
      ..color = Colors.cyan.withOpacity(1.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(12)), staticPaint);

    // Pulse scales outward and fades
    final scale = 1.0 + 0.4 * t;
    final pulseRect = Rect.fromCenter(
      center: baseRect.center,
      width: baseRect.width * scale,
      height: baseRect.height * scale,
    );

    final opacity = (1.0 - t).clamp(0.0, 1.0);
    final glowPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.8 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);

    canvas.drawRRect(RRect.fromRectAndRadius(pulseRect, Radius.circular(12 * scale)), glowPaint);
  }

  @override
  bool shouldRepaint(_KeyPulsePainter oldDelegate) {
    return oldDelegate.targetKey != targetKey || oldDelegate.t != t || oldDelegate.overlayKey != overlayKey;
  }
}
