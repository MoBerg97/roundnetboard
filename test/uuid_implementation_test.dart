import 'package:flutter_test/flutter_test.dart';
import 'package:roundnetboard/models/player.dart';
import 'package:roundnetboard/models/ball.dart';
import 'package:roundnetboard/models/frame.dart';
import 'package:roundnetboard/models/animation_project.dart';
import 'package:flutter/material.dart';

void main() {
  group('UUID Object Identity System Tests', () {
    group('Player ID Generation and Stability', () {
      test('Player auto-generates UUID when no ID provided', () {
        final player1 = Player(position: const Offset(100, 100));
        final player2 = Player(position: const Offset(100, 100));
        
        // IDs should be generated
        expect(player1.id, isNotNull);
        expect(player2.id, isNotNull);
        
        // IDs should be unique
        expect(player1.id, isNot(player2.id));
      });

      test('Player preserves ID when provided', () {
        const testId = 'P1';
        final player = Player(position: const Offset(0, 0), id: testId);
        expect(player.id, equals(testId));
      });

      test('Player copy preserves ID', () {
        final original = Player(position: const Offset(100, 100));
        final originalId = original.id;
        final copy = original.copy();
        
        expect(copy.id, equals(originalId));
        expect(identical(copy, original), isFalse);
      });

      test('Play mode players have fixed IDs (P1-P4)', () {
        const playModeIds = ['P1', 'P2', 'P3', 'P4'];
        
        for (final id in playModeIds) {
          final player = Player(position: Offset.zero, id: id);
          expect(player.id, equals(id));
        }
      });
    });

    group('Ball ID Generation and Stability', () {
      test('Ball auto-generates UUID when no ID provided', () {
        final ball1 = Ball(position: const Offset(0, 0));
        final ball2 = Ball(position: const Offset(0, 0));
        
        expect(ball1.id, isNotNull);
        expect(ball2.id, isNotNull);
        expect(ball1.id, isNot(ball2.id));
      });

      test('Ball preserves ID when provided', () {
        const testId = 'B1';
        final ball = Ball(position: const Offset(0, 0), id: testId);
        expect(ball.id, equals(testId));
      });

      test('Ball copy preserves ID', () {
        final original = Ball(position: const Offset(0, 0));
        final originalId = original.id;
        final copy = original.copy();
        
        expect(copy.id, equals(originalId));
        expect(identical(copy, original), isFalse);
      });

      test('Ball copy preserves path points and modifiers', () {
        final original = Ball(
          position: const Offset(100, 100),
          pathPoints: [const Offset(50, 50), const Offset(75, 75)],
          hitT: 0.5,
          isSet: true,
        );
        
        final copy = original.copy();
        
        expect(copy.id, equals(original.id));
        expect(copy.pathPoints, equals(original.pathPoints));
        expect(copy.hitT, equals(original.hitT));
        expect(copy.isSet, equals(original.isSet));
      });
    });

    group('Frame ID-Based Lookup and Removal', () {
      test('getPlayerById returns correct player', () {
        final p1 = Player(position: const Offset(0, -200), id: 'P1');
        final p2 = Player(position: const Offset(200, 0), id: 'P2');
        final frame = Frame(players: [p1, p2]);
        
        expect(frame.getPlayerById('P1'), equals(p1));
        expect(frame.getPlayerById('P2'), equals(p2));
        expect(frame.getPlayerById('P999'), isNull);
      });

      test('getBallById returns correct ball', () {
        final b1 = Ball(position: Offset.zero, id: 'B1');
        final b2 = Ball(position: const Offset(100, 100), id: 'B2');
        final frame = Frame(balls: [b1, b2]);
        
        expect(frame.getBallById('B1'), equals(b1));
        expect(frame.getBallById('B2'), equals(b2));
        expect(frame.getBallById('B999'), isNull);
      });

      test('removePlayerById removes player by ID not index', () {
        final p1 = Player(position: const Offset(0, -200), id: 'P1');
        final p2 = Player(position: const Offset(200, 0), id: 'P2');
        final p3 = Player(position: const Offset(0, 200), id: 'P3');
        final frame = Frame(players: [p1, p2, p3]);
        
        // Remove middle player by ID
        final removed = frame.removePlayerById('P2');
        
        expect(removed, isTrue);
        expect(frame.players.length, equals(2));
        expect(frame.players[0].id, equals('P1'));
        expect(frame.players[1].id, equals('P3')); // P3 stays in correct position
      });

      test('removeBallById removes ball by ID not index', () {
        final b1 = Ball(position: Offset.zero, id: 'B1');
        final b2 = Ball(position: const Offset(100, 100), id: 'B2');
        final b3 = Ball(position: const Offset(200, 200), id: 'B3');
        final frame = Frame(balls: [b1, b2, b3]);
        
        final removed = frame.removeBallById('B2');
        
        expect(removed, isTrue);
        expect(frame.balls.length, equals(2));
        expect(frame.balls[0].id, equals('B1'));
        expect(frame.balls[1].id, equals('B3'));
      });

      test('removePlayerById returns false for non-existent ID', () {
        final p1 = Player(position: Offset.zero, id: 'P1');
        final frame = Frame(players: [p1]);
        
        final removed = frame.removePlayerById('P999');
        
        expect(removed, isFalse);
        expect(frame.players.length, equals(1));
      });
    });

    group('Path Point Preservation Through Operations', () {
      test('Player path points persist through copy', () {
        final pathPoints = [const Offset(50, 50), const Offset(75, 75)];
        final player = Player(
          position: const Offset(100, 100),
          pathPoints: pathPoints,
          id: 'P1',
        );
        
        final copy = player.copy();
        
        expect(copy.pathPoints, equals(pathPoints));
        expect(copy.pathPoints, isNot(identical(player.pathPoints)));
      });

      test('Ball path points persist through copy', () {
        final pathPoints = [const Offset(50, 50), const Offset(75, 75)];
        final ball = Ball(
          position: const Offset(100, 100),
          pathPoints: pathPoints,
          id: 'B1',
        );
        
        final copy = ball.copy();
        
        expect(copy.pathPoints, equals(pathPoints));
        expect(copy.pathPoints, isNot(identical(ball.pathPoints)));
      });

      test('Path points survive frame-level operations', () {
        final p1 = Player(
          position: const Offset(0, -200),
          pathPoints: [const Offset(50, -150)],
          id: 'P1',
        );
        final frame1 = Frame(players: [p1]);
        final frame2 = frame1.copy();
        
        // Get same player by ID from both frames
        final p1_in_frame1 = frame1.getPlayerById('P1');
        final p1_in_frame2 = frame2.getPlayerById('P1');
        
        // Path points should be independent copies
        expect(p1_in_frame1?.pathPoints, equals([const Offset(50, -150)]));
        expect(p1_in_frame2?.pathPoints, equals([const Offset(50, -150)]));
        
        // Modifying one shouldn't affect the other
        p1_in_frame2?.pathPoints.add(const Offset(100, -100));
        expect(p1_in_frame1?.pathPoints.length, equals(1));
        expect(p1_in_frame2?.pathPoints.length, equals(2));
      });
    });

    group('ID Stability Across Operations', () {
      test('Adding multiple balls of same type each gets unique ID', () {
        final b1 = Ball(position: const Offset(0, 0));
        final b2 = Ball(position: const Offset(100, 100));
        final b3 = Ball(position: const Offset(200, 200));
        
        final frame = Frame(balls: [b1, b2, b3]);
        
        final ids = frame.balls.map((b) => b.id).toList();
        final uniqueIds = ids.toSet();
        
        expect(uniqueIds.length, equals(3));
      });

      test('Adding players to multiple frames preserves ID across frames', () {
        final player = Player(position: const Offset(100, 100));
        final playerId = player.id;
        
        final frame1 = Frame(players: [player.copy()]);
        final frame2 = Frame(players: [player.copy()]);
        final frame3 = Frame(players: [player.copy()]);
        
        expect(frame1.players[0].id, equals(playerId));
        expect(frame2.players[0].id, equals(playerId));
        expect(frame3.players[0].id, equals(playerId));
      });

      test('Deleting object from one frame does not affect other frames', () {
        final player = Player(position: const Offset(0, 0), id: 'P1');
        
        final frame1 = Frame(players: [player.copy()]);
        final frame2 = Frame(players: [player.copy()]);
        
        // Remove player from frame1
        frame1.removePlayerById('P1');
        
        // Frame2 should still have the player
        expect(frame1.getPlayerById('P1'), isNull);
        expect(frame2.getPlayerById('P1'), isNotNull);
        expect(frame2.getPlayerById('P1')?.id, equals('P1'));
      });
    });

    group('Training Mode Dynamic Player/Ball Management', () {
      test('Training mode supports multiple players with unique IDs', () {
        final players = List.generate(
          5,
          (i) => Player(
            position: Offset(i * 50.0, 0),
            color: Colors.blue,
          ),
        );
        
        final frame = Frame(players: players);
        
        // All players should have unique IDs
        final ids = players.map((p) => p.id).toSet();
        expect(ids.length, equals(5));
        
        // All should be retrievable by ID
        for (final player in players) {
          expect(frame.getPlayerById(player.id), isNotNull);
        }
      });

      test('Training mode supports multiple balls with unique IDs', () {
        final balls = List.generate(
          3,
          (i) => Ball(position: Offset(i * 100.0, 0)),
        );
        
        final frame = Frame(balls: balls);
        
        final ids = balls.map((b) => b.id).toSet();
        expect(ids.length, equals(3));
        
        for (final ball in balls) {
          expect(frame.getBallById(ball.id), isNotNull);
        }
      });

      test('Adding new player to training mode initializes at specified location', () {
        final initialPlayer = Player(position: const Offset(0, 0), id: 'P1');
        final frame = Frame(players: [initialPlayer]);
        
        // Add new player at specific location
        final newPlayer = Player(position: const Offset(150, 150));
        frame.players.add(newPlayer);
        
        // Verify it's at the right location and has unique ID
        expect(frame.getPlayerById(newPlayer.id)?.position, equals(const Offset(150, 150)));
        expect(newPlayer.id, isNot(initialPlayer.id));
      });
    });

    group('Play Mode Fixed ID Structure', () {
      test('Play mode frame has correct player IDs', () {
        final players = [
          Player(position: Offset.zero, id: 'P1'),
          Player(position: Offset.zero, id: 'P2'),
          Player(position: Offset.zero, id: 'P3'),
          Player(position: Offset.zero, id: 'P4'),
        ];
        
        final frame = Frame(players: players);
        
        expect(frame.getPlayerById('P1'), isNotNull);
        expect(frame.getPlayerById('P2'), isNotNull);
        expect(frame.getPlayerById('P3'), isNotNull);
        expect(frame.getPlayerById('P4'), isNotNull);
      });

      test('Play mode frame has ball with ID B1', () {
        final ball = Ball(position: Offset.zero, id: 'B1');
        final frame = Frame(balls: [ball]);
        
        expect(frame.getBallById('B1'), isNotNull);
        expect(frame.getBallById('B1')?.id, equals('B1'));
      });
    });

    group('Color Preservation Through Operations', () {
      test('Player color persists through ID-based operations', () {
        final player = Player(
          position: const Offset(0, 0),
          color: Colors.red,
          id: 'P1',
        );
        final frame = Frame(players: [player]);
        
        final retrieved = frame.getPlayerById('P1');
        expect(retrieved?.color, equals(Colors.red));
      });

      test('Ball color persists through copy and lookup', () {
        final ball = Ball(
          position: const Offset(0, 0),
          color: Colors.orange,
          id: 'B1',
        );
        
        final copy = ball.copy();
        expect(copy.color, equals(Colors.orange));
        expect(copy.id, equals('B1'));
      });

      test('Changing player color in frame updates correctly', () {
        final player = Player(
          position: const Offset(0, 0),
          color: Colors.blue,
          id: 'P1',
        );
        final frame = Frame(players: [player]);
        
        // Modify color of player in frame
        frame.getPlayerById('P1')?.color = Colors.red;
        
        // Verify color changed
        expect(frame.getPlayerById('P1')?.color, equals(Colors.red));
      });
    });

    group('Rotation Preservation', () {
      test('Player rotation persists through copy', () {
        final player = Player(
          position: Offset.zero,
          rotation: 45.0,
          id: 'P1',
        );
        
        final copy = player.copy();
        expect(copy.rotation, equals(45.0));
        expect(copy.id, equals(player.id));
      });

      test('Player rotation preserved through frame lookup', () {
        final player = Player(
          position: Offset.zero,
          rotation: 90.0,
          id: 'P1',
        );
        final frame = Frame(players: [player]);
        
        final retrieved = frame.getPlayerById('P1');
        expect(retrieved?.rotation, equals(90.0));
      });
    });

    group('Backward Compatibility Getters', () {
      test('p1, p2, p3, p4 backward compatibility getters work', () {
        final players = [
          Player(position: const Offset(0, -200), id: 'P1'),
          Player(position: const Offset(200, 0), id: 'P2'),
          Player(position: const Offset(0, 200), id: 'P3'),
          Player(position: const Offset(-200, 0), id: 'P4'),
        ];
        final frame = Frame(players: players);
        
        expect(frame.p1, equals(const Offset(0, -200)));
        expect(frame.p2, equals(const Offset(200, 0)));
        expect(frame.p3, equals(const Offset(0, 200)));
        expect(frame.p4, equals(const Offset(-200, 0)));
      });

      test('ball backward compatibility getter works', () {
        final ball = Ball(position: const Offset(100, 100), id: 'B1');
        final frame = Frame(balls: [ball]);
        
        expect(frame.ball, equals(const Offset(100, 100)));
      });

      test('ballPathPoints backward compatibility getter returns first ball paths', () {
        final balls = [
          Ball(
            position: const Offset(0, 0),
            pathPoints: [const Offset(50, 50)],
            id: 'B1',
          ),
          Ball(
            position: const Offset(100, 100),
            pathPoints: [const Offset(150, 150)],
            id: 'B2',
          ),
        ];
        final frame = Frame(balls: balls);
        
        // Backward compat getter returns first ball's paths
        expect(frame.ballPathPoints, equals([const Offset(50, 50)]));
      });
    });

    group('ID-Based Comparison and Equality', () {
      test('Two players with same ID but different positions are different objects', () {
        final p1a = Player(position: const Offset(0, 0), id: 'P1');
        final p1b = Player(position: const Offset(100, 100), id: 'P1');
        
        // Same ID but different data
        expect(p1a.id, equals(p1b.id));
        expect(p1a.position, isNot(p1b.position));
      });

      test('getPlayerById finds by ID regardless of position', () {
        final p1 = Player(position: const Offset(0, 0), id: 'P1');
        final frame = Frame(players: [p1]);
        
        // Player was added at (0,0) but we find by ID
        expect(frame.getPlayerById('P1')?.position, equals(const Offset(0, 0)));
        
        // Move player
        p1.position = const Offset(100, 100);
        expect(frame.getPlayerById('P1')?.position, equals(const Offset(100, 100)));
      });
    });
  });
}
