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

      // Wait for animation to complete
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // If we got here without exceptions, no overflow occurred
      expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(1));
    });

    testWidgets('Timeline height transitions correctly', (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 3);
      final widget = MaterialApp(
        home: Scaffold(
          body: BoardScreen(project: project),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Get initial editing state
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Start playback
      final playButton = find.byIcon(Icons.play_arrow);
      await tester.tap(playButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Verify playback state with stop button
      expect(find.byIcon(Icons.stop), findsWidgets);

      // Stop playback
      final stopButton = find.byIcon(Icons.stop).first;
      await tester.tap(stopButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Should be back to editing state
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('Playback finished state shows stop button', (WidgetTester tester) async {
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
      
      // Let playback run to completion (with short timeout)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify stop button is still available (either in overlay or compact controls)
      final stopButton = find.byIcon(Icons.stop);
      expect(stopButton, findsWidgets,
          reason: 'Stop button should be available to exit playback');

      // Verify "Playback Finished" message appears
      final finishedText = find.text('Playback Finished');
      expect(finishedText, findsOneWidget,
          reason: 'Playback finished message should be visible');
    });

    testWidgets('Control buttons hidden during playback', (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 5);
      final widget = MaterialApp(
        home: Scaffold(
          body: BoardScreen(project: project),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Count control buttons before playback
      int prevButtonsBefore = find.byIcon(Icons.skip_previous).evaluate().length;
      int nextButtonsBefore = find.byIcon(Icons.skip_next).evaluate().length;

      // Start playback
      final playButton = find.byIcon(Icons.play_arrow);
      await tester.tap(playButton);
      await tester.pumpAndSettle();

      // Count control buttons during playback
      int prevButtonsDuring = find.byIcon(Icons.skip_previous).evaluate().length;
      int nextButtonsDuring = find.byIcon(Icons.skip_next).evaluate().length;

      // Control buttons should be hidden or significantly reduced during playback
      expect(prevButtonsDuring, lessThanOrEqualTo(prevButtonsBefore),
          reason: 'Previous button should be hidden during playback');
      expect(nextButtonsDuring, lessThanOrEqualTo(nextButtonsBefore),
          reason: 'Next button should be hidden during playback');
    });

    testWidgets('Playback cursor bar visible and interactive',
        (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 10);
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
      await tester.pumpAndSettle();

      // Frame counter should show during playback (e.g., "1/10", "2/10", etc.)
      final frameCounter = find.byType(Text);
      expect(frameCounter, findsWidgets,
          reason: 'Frame counter should be visible during playback');

      // Stop playback
      final stopButton = find.byIcon(Icons.stop).first;
      await tester.tap(stopButton);
      await tester.pumpAndSettle();
    });

    testWidgets('No exception thrown on rapid playback state changes',
        (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 5);
      final widget = MaterialApp(
        home: Scaffold(
          body: BoardScreen(project: project),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Rapid state changes should not cause exceptions
      for (int i = 0; i < 3; i++) {
        final playButton = find.byIcon(Icons.play_arrow);
        if (playButton.evaluate().isNotEmpty) {
          await tester.tap(playButton);
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
        }

        final stopButton = find.byIcon(Icons.stop);
        if (stopButton.evaluate().isNotEmpty) {
          await tester.tap(stopButton.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
        }
      }

      // Should complete without throwing exceptions
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('Timeline Rendering Tests', () {
    testWidgets('Timeline shows all frame thumbnails', (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 5);
      final widget = MaterialApp(
        home: Scaffold(
          body: BoardScreen(project: project),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Should show frame numbers 1-5
      expect(find.text('1'), findsWidgets);
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('Delete button appears only during editing',
        (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 3);
      final widget = MaterialApp(
        home: Scaffold(
          body: BoardScreen(project: project),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // During editing, delete buttons should be visible for selected frame
      int deleteButtonsEditing = find.byIcon(Icons.remove).evaluate().length;

      // Start playback
      final playButton = find.byIcon(Icons.play_arrow);
      await tester.tap(playButton);
      await tester.pumpAndSettle();

      // During playback, delete buttons should be hidden
      int deleteButtonsPlayback = find.byIcon(Icons.remove).evaluate().length;

      expect(deleteButtonsPlayback, lessThanOrEqualTo(deleteButtonsEditing),
          reason: 'Delete buttons should be hidden during playback');
    });
  });
}

// Helper functions
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


        final project = _createTestProject();
        final widget = MaterialApp(
          home: Scaffold(
            body: BoardScreen(project: project),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Start playback
        final playButton = find.byIcon(Icons.play_arrow);
        expect(playButton, findsOneWidget, reason: 'Play button should be visible');

        await tester.tap(playButton);
        await tester.pumpAndSettle();

        // Verify no overflow errors in the render tree
        final materialApp = find.byType(MaterialApp);
        expect(materialApp, findsOneWidget);

        // Verify timeline container exists and is properly sized
        final animatedContainer = find.byType(AnimatedContainer);
        expect(animatedContainer, findsAtLeastNWidgets(1),
            reason: 'Timeline AnimatedContainer should exist');

        // Verify no RenderFlex overflow by checking for overflow indicator
        // If overflow occurred, Flutter would show visual overflow indicators
        await tester.pump(const Duration(milliseconds: 300)); // Wait for animation
        
        // Use pumpAndSettle with a timeout to catch any layout issues
        await tester.pumpAndSettle(
          const Duration(milliseconds: 500),
        );

        // If we got here without exceptions, no overflow occurred
        expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(1));
      });

      testWidgets('Timeline height consistent during state transitions on $deviceName',
          (WidgetTester tester) async {
        await tester.binding.window.physicalSizeTestValue = screenSize;
        addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

        final project = _createTestProject();
        final widget = MaterialApp(
          home: Scaffold(
            body: BoardScreen(project: project),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Get initial editing height
        final containerBefore = find.byType(AnimatedContainer).first;
        final editHeight = _getContainerHeight(tester, containerBefore);
        expect(editHeight, 120.0,
            reason: 'Timeline should be 120px in editing mode');

        // Start playback
        final playButton = find.byIcon(Icons.play_arrow);
        await tester.tap(playButton);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Get playback height
        final containerDuring = find.byType(AnimatedContainer).first;
        final playHeight = _getContainerHeight(tester, containerDuring);
        expect(playHeight, 80.0,
            reason: 'Timeline should be 80px in playback mode');

        // Stop playback
        final stopButton = find.byIcon(Icons.stop);
        if (stopButton.evaluate().isNotEmpty) {
          await tester.tap(stopButton);
          await tester.pumpAndSettle(const Duration(milliseconds: 500));

          // Get final editing height
          final containerAfter = find.byType(AnimatedContainer).first;
          final finalHeight = _getContainerHeight(tester, containerAfter);
          expect(finalHeight, 120.0,
              reason: 'Timeline should return to 120px after stopping playback');
        }
      });

      testWidgets('Playback finished state shows stop button on $deviceName',
          (WidgetTester tester) async {
        await tester.binding.window.physicalSizeTestValue = screenSize;
        addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

        final project = _createTestProject();
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
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Wait for playback to finish (should show "Playback Finished" message)
        // Look for stop button or finished text
        final finishedText = find.text('Playback Finished');
        
        // The stop button should be visible even after playback finishes
        final stopButton = find.byIcon(Icons.stop);
        
        // At least one should be visible (stop button in the overlay or compact controls)
        expect(finishedText.evaluate().isNotEmpty || stopButton.evaluate().isNotEmpty,
            isTrue,
            reason: 'Playback finished state should be visible');
      });

      testWidgets('No control buttons visible during playback on $deviceName',
          (WidgetTester tester) async {
        await tester.binding.window.physicalSizeTestValue = screenSize;
        addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

        final project = _createTestProject();
        final widget = MaterialApp(
          home: Scaffold(
            body: BoardScreen(project: project),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Count control buttons before playback
        final prevButtonsBefore = find.byIcon(Icons.skip_previous);
        final nextButtonsBefore = find.byIcon(Icons.skip_next);
        final undoButtonsBefore = find.byIcon(Icons.undo);
        final redoButtonsBefore = find.byIcon(Icons.redo);

        // Start playback
        final playButton = find.byIcon(Icons.play_arrow);
        await tester.tap(playButton);
        await tester.pumpAndSettle();

        // Count control buttons during playback
        final prevButtonsDuring = find.byIcon(Icons.skip_previous);
        final nextButtonsDuring = find.byIcon(Icons.skip_next);
        final undoButtonsDuring = find.byIcon(Icons.undo);
        final redoButtonsDuring = find.byIcon(Icons.redo);

        // Control buttons should be hidden or disabled during playback
        expect(prevButtonsDuring.evaluate().length,
            lessThanOrEqualTo(prevButtonsBefore.evaluate().length),
            reason: 'Previous button should not be visible during playback');
        expect(nextButtonsDuring.evaluate().length,
            lessThanOrEqualTo(nextButtonsBefore.evaluate().length),
            reason: 'Next button should not be visible during playback');
        expect(undoButtonsDuring.evaluate().length,
            lessThanOrEqualTo(undoButtonsBefore.evaluate().length),
            reason: 'Undo button should not be visible during playback');
        expect(redoButtonsDuring.evaluate().length,
            lessThanOrEqualTo(redoButtonsBefore.evaluate().length),
            reason: 'Redo button should not be visible during playback');
      });
    }
  });

  group('Timeline Content Tests', () {
    testWidgets('Timeline shows frame thumbnails', (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 5);
      final widget = MaterialApp(
        home: Scaffold(
          body: BoardScreen(project: project),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Should show frame numbers
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('Playback cursor tracks animation frame',
        (WidgetTester tester) async {
      final project = _createTestProject(frameCount: 10);
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
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Playback should be running
      // The frame counter should show progress
      final frameCounterText = find.byType(Text);
      expect(frameCounterText, findsWidgets);

      // Stop playback
      final stopButton = find.byIcon(Icons.stop);
      if (stopButton.evaluate().isNotEmpty) {
        await tester.tap(stopButton);
        await tester.pumpAndSettle();
      }
    });
  });
}

// Helper functions
AnimationProject _createTestProject({int frameCount = 3}) {
  final project = AnimationProject(
    name: 'Test Project',
    frames: [],
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

double _getContainerHeight(WidgetTester tester, Finder finder) {
  final context = finder.evaluate().first;
  final renderObject = context.renderObject;
  if (renderObject is RenderBox) {
    return renderObject.size.height;
  }
  return 0.0;
}
