import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundnetboard/models/animation_project.dart';
import 'package:roundnetboard/models/frame.dart';
import 'package:roundnetboard/models/annotation.dart';
import 'package:roundnetboard/models/settings.dart';

void main() {
  group('Export/Import JSON Round-Trip Tests', () {
    test('Complete project serialization with all fields', () {
      // Create a complex project with all features
      final settings = Settings(
        playbackSpeed: 1.5,
        outerCircleRadiusCm: 260.0,
        innerCircleRadiusCm: 100.0,
        netCircleRadiusCm: 46.0,
        outerBoundsRadiusCm: 850.0,
        referenceRadiusCm: 260.0,
        showPreviousFrameLines: true,
      );

      final annotations = [
        Annotation(
          type: AnnotationType.line,
          color: Colors.red,
          points: [const Offset(10, 20), const Offset(30, 40)],
        ),
        Annotation(
          type: AnnotationType.circle,
          color: Colors.blue,
          points: [const Offset(100, 100), const Offset(120, 100)],
        ),
      ];

      final frame1 = Frame(
        p1: const Offset(100, 100),
        p2: const Offset(200, 100),
        p3: const Offset(100, 200),
        p4: const Offset(200, 200),
        ball: const Offset(150, 150),
        p1Rotation: 0.5,
        p2Rotation: 1.0,
        p3Rotation: 1.5,
        p4Rotation: 2.0,
        p1PathPoints: [const Offset(110, 110)],
        p2PathPoints: [const Offset(210, 110)],
        p3PathPoints: [const Offset(110, 210)],
        p4PathPoints: [const Offset(210, 210)],
        ballPathPoints: [const Offset(160, 160), const Offset(165, 165)],
        duration: 1.2,
        ballHitT: 0.7,
        ballSet: true,
        annotations: annotations.map((a) => a.copy()).toList(),
      );

      final frame2 = Frame(
        p1: const Offset(120, 120),
        p2: const Offset(220, 120),
        p3: const Offset(120, 220),
        p4: const Offset(220, 220),
        ball: const Offset(170, 170),
        p1Rotation: 0.6,
        p2Rotation: 1.1,
        p3Rotation: 1.6,
        p4Rotation: 2.1,
        duration: 0.8,
        ballHitT: null,
        ballSet: false,
        annotations: [],
      );

      final originalProject = AnimationProject(
        name: 'Test Project',
        frames: [frame1, frame2],
        settings: settings,
      );

      // Serialize to map (simulates JSON export)
      final projectMap = originalProject.toMap();
      
      // Convert to JSON string and back (simulates file I/O)
      final jsonString = json.encode(projectMap);
      final decodedMap = json.decode(jsonString) as Map<String, dynamic>;
      
      // Deserialize from map (simulates JSON import)
      final importedProject = AnimationProjectMap.fromMap(decodedMap);

      // Verify project-level fields
      expect(importedProject.name, originalProject.name);
      expect(importedProject.frames.length, originalProject.frames.length);

      // Verify settings
      expect(importedProject.settings?.playbackSpeed, settings.playbackSpeed);
      expect(importedProject.settings?.outerCircleRadiusCm, settings.outerCircleRadiusCm);
      expect(importedProject.settings?.showPreviousFrameLines, settings.showPreviousFrameLines);

      // Verify Frame 1
      final importedFrame1 = importedProject.frames[0];
      expect(importedFrame1.p1, frame1.p1);
      expect(importedFrame1.p2, frame1.p2);
      expect(importedFrame1.p3, frame1.p3);
      expect(importedFrame1.p4, frame1.p4);
      expect(importedFrame1.ball, frame1.ball);
      expect(importedFrame1.p1Rotation, frame1.p1Rotation);
      expect(importedFrame1.p2Rotation, frame1.p2Rotation);
      expect(importedFrame1.p3Rotation, frame1.p3Rotation);
      expect(importedFrame1.p4Rotation, frame1.p4Rotation);
      expect(importedFrame1.duration, frame1.duration);
      expect(importedFrame1.ballHitT, frame1.ballHitT);
      expect(importedFrame1.ballSet, frame1.ballSet);

      // Verify path points
      expect(importedFrame1.p1PathPoints.length, frame1.p1PathPoints.length);
      expect(importedFrame1.p1PathPoints[0], frame1.p1PathPoints[0]);
      expect(importedFrame1.ballPathPoints.length, frame1.ballPathPoints.length);
      expect(importedFrame1.ballPathPoints[0], frame1.ballPathPoints[0]);
      expect(importedFrame1.ballPathPoints[1], frame1.ballPathPoints[1]);

      // Verify annotations
      expect(importedFrame1.annotations.length, 2);
      expect(importedFrame1.annotations[0].type, AnnotationType.line);
      expect(importedFrame1.annotations[0].colorValue, Colors.red.toARGB32());
      expect(importedFrame1.annotations[0].points.length, 2);
      expect(importedFrame1.annotations[0].points[0], const Offset(10, 20));
      expect(importedFrame1.annotations[0].points[1], const Offset(30, 40));

      expect(importedFrame1.annotations[1].type, AnnotationType.circle);
      expect(importedFrame1.annotations[1].colorValue, Colors.blue.toARGB32());

      // Verify Frame 2
      final importedFrame2 = importedProject.frames[1];
      expect(importedFrame2.ball, frame2.ball);
      expect(importedFrame2.duration, frame2.duration);
      expect(importedFrame2.ballHitT, null);
      expect(importedFrame2.ballSet, false);
      expect(importedFrame2.annotations.length, 0);
    });

    test('Empty project serialization', () {
      final emptyProject = AnimationProject(
        name: 'Empty Project',
        frames: [],
        settings: Settings(),
      );

      final projectMap = emptyProject.toMap();
      final jsonString = json.encode(projectMap);
      final decodedMap = json.decode(jsonString) as Map<String, dynamic>;
      final importedProject = AnimationProjectMap.fromMap(decodedMap);

      expect(importedProject.name, emptyProject.name);
      expect(importedProject.frames.length, 0);
      expect(importedProject.settings, isNotNull);
    });

    test('Frame with null optional fields', () {
      final frameWithNulls = Frame(
        p1: const Offset(0, 0),
        p2: const Offset(100, 0),
        p3: const Offset(0, 100),
        p4: const Offset(100, 100),
        ball: const Offset(50, 50),
        ballHitT: null,
        ballSet: null,
        duration: 0.5,
      );

      final project = AnimationProject(
        name: 'Null Fields Test',
        frames: [frameWithNulls],
        settings: Settings(),
      );

      final projectMap = project.toMap();
      final jsonString = json.encode(projectMap);
      final decodedMap = json.decode(jsonString) as Map<String, dynamic>;
      final importedProject = AnimationProjectMap.fromMap(decodedMap);

      final importedFrame = importedProject.frames[0];
      expect(importedFrame.ballHitT, null);
      expect(importedFrame.ballSet, null);
      expect(importedFrame.duration, 0.5);
    });
  });
}
