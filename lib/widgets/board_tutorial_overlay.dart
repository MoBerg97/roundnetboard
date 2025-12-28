import 'package:flutter/material.dart';

/// Placeholder for custom tutorial overlay
/// Using feature_discovery package for actual implementation
class BoardTutorialOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> steps;
  final VoidCallback onFinish;
  final GlobalKey? boardKey;

  const BoardTutorialOverlay({super.key, required this.steps, required this.onFinish, this.boardKey});

  @override
  State<BoardTutorialOverlay> createState() => _BoardTutorialOverlayState();
}

class _BoardTutorialOverlayState extends State<BoardTutorialOverlay> {
  @override
  void initState() {
    super.initState();
    // Board tutorial implementation pending
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
