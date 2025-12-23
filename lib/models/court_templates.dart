import 'package:flutter/material.dart';
import 'court_element.dart';
import 'frame.dart';
import 'player.dart';
import 'ball.dart';

/// Court templates for training mode
class CourtTemplates {
  /// Template 1: Only net, no zones
  static List<CourtElement> netOnly() {
    return [
      CourtElement(
        type: CourtElementType.net,
        position: Offset.zero,
        radius: 46.0,
        color: Colors.white,
        strokeWidth: 2.0,
        isVisible: true,
      ),
    ];
  }

  /// Template 2: Empty court (no elements)
  static List<CourtElement> empty() {
    return [];
  }

  /// Template 3: Full elements (net + zones)
  static List<CourtElement> full() {
    return [
      CourtElement(
        type: CourtElementType.net,
        position: Offset.zero,
        radius: 46.0,
        color: Colors.white,
        strokeWidth: 2.0,
        isVisible: true,
      ),
      CourtElement(
        type: CourtElementType.innerCircle,
        position: Offset.zero,
        radius: 100.0,
        color: Colors.white,
        strokeWidth: 2.0,
        isVisible: true,
      ),
      CourtElement(
        type: CourtElementType.outerCircle,
        position: Offset.zero,
        radius: 260.0,
        color: Colors.white,
        strokeWidth: 2.0,
        isVisible: true,
      ),
    ];
  }

  /// Get template by index (0: net-only, 1: empty, 2: full)
  static List<CourtElement> getTemplate(int index) {
    switch (index) {
      case 0:
        return netOnly();
      case 1:
        return empty();
      case 2:
        return full();
      default:
        return netOnly();
    }
  }

  /// Template names for UI
  static const List<String> templateNames = [
    'Net Only',
    'Empty',
    'Full Elements',
  ];
}

/// Default frame creators based on project type
class DefaultFrames {
  /// Create default frame for play mode (4 players at standard positions)
  static Frame createPlayFrame(double referenceRadius) {
    final r = referenceRadius;
    return Frame(
      players: [
        Player(position: Offset(0, -r), color: Colors.blue),       // P1: Top
        Player(position: Offset(r, 0), color: Colors.blue),        // P2: Right
        Player(position: Offset(0, r), color: Colors.red),         // P3: Bottom
        Player(position: Offset(-r, 0), color: Colors.red),        // P4: Left
      ],
      balls: [
        Ball(position: Offset.zero, color: Colors.orange),
      ],
      duration: 0.5,
      annotations: [],
    );
  }

  /// Create default frame for training mode (2 players, 1 ball)
  static Frame createTrainingFrame(double referenceRadius) {
    final r = referenceRadius;
    return Frame(
      players: [
        Player(position: Offset(0, -r * 0.5), color: Colors.red),  // P1: Top-center
        Player(position: Offset(0, r * 0.5), color: Colors.blue),  // P2: Bottom-center
      ],
      balls: [
        Ball(position: Offset.zero, color: Colors.orange),
      ],
      duration: 0.5,
      annotations: [],
    );
  }
}
