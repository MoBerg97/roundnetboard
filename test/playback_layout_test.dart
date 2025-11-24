import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundnetboard/models/animation_project.dart';
import 'package:roundnetboard/models/frame.dart';
import 'package:roundnetboard/models/settings.dart';
import 'package:roundnetboard/screens/board_screen.dart';

void main() {
  group('Playback UI Layout Tests - Overflow Prevention', () {
    testWidgets('No overflow during playback', (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 5);
      final widget = MaterialApp(
        home: Scaffold(
          body: BoardScreen(project: project),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Verify play button exists
      final playButton = find.byIcon(Icons.play_arrow);
      expect(playButton, findsOneWidget, reason: 'Play button should be visible');

      // Start playback
      await tester.tap(playButton);
      await tester.pumpAndSettle();

      // Verify timeline container exists
      final animatedContainer = find.byType(AnimatedContainer);
      expect(animatedContainer, findsAtLeastNWidgets(1),
          reason: 'Timeline AnimatedContainer should exist');

      // If we get here without overflow exceptions, test passes
      expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(1));
    });

    testWidgets('Playback finished state shows stop button', 
        (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 2);
      final widget = MaterialApp(
        home: Scaffold(
          body: BoardScreen(project: project),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Start playback
      final playButton = find.byIcon(Icons.play_arrow);
      await tester.tap(playButton);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify "Playback Finished" message appears
      final finishedText = find.text('Playback Finished');
      expect(finishedText, findsOneWidget,
          reason: 'Playback finished message should be visible');

      // Verify stop button is available
      final stopButton = find.byIcon(Icons.stop);
      expect(stopButton, findsWidgets,
          reason: 'Stop button should be available to exit playback');
    });
  });
}

AnimationProject _createTestProject({int frameCount = 3}) {
  final settings = Settings();
  final project = AnimationProject(
    name: 'Test Project',
    frames: [],
    settings: settings,
  );

  for (int i = 0; i < frameCount; i++) {
    final frame = Frame(
      p1: const Offset(0, -100),
      p2: const Offset(100, 0),
      p3: const Offset(0, 100),
      p4: const Offset(-100, 0),
      ball: Offset(i * 10.0, i * 5.0),
      p1Rotation: 0,
      p2Rotation: 0,
      p3Rotation: 0,
      p4Rotation: 0,
      p1PathPoints: [],
      p2PathPoints: [],
      p3PathPoints: [],
      p4PathPoints: [],
      ballPathPoints: [],
    );
    project.frames.add(frame);
  }

  return project;
}
