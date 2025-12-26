import 'frame.dart';
import 'player.dart';
import 'ball.dart';

/// Extension providing backward-compatible access to frame players and balls
extension FrameCompat on Frame {
  /// Get player at index, safely handling both old and new formats
  Player? getPlayer(int index) {
    if (index < 0 || index >= players.length) return null;
    return players[index];
  }

  /// Get ball at index
  Ball? getBall(int index) {
    if (index < 0 || index >= balls.length) return null;
    return balls[index];
  }

  /// Update player at index
  void setPlayer(int index, Player player) {
    if (index < 0 || index >= players.length) return;
    players[index] = player;
  }

  /// Update ball at index
  void setBall(int index, Ball ball) {
    if (index < 0 || index >= balls.length) return;
    balls[index] = ball;
  }

  /// Add a player (for training mode)
  void addPlayer(Player player) {
    players.add(player);
  }

  /// Add a ball (for training mode)
  void addBall(Ball ball) {
    balls.add(ball);
  }

  /// Remove player at index (for training mode)
  void removePlayer(int index) {
    if (index >= 0 && index < players.length) {
      players.removeAt(index);
    }
  }

  /// Remove ball at index (for training mode)
  void removeBall(int index) {
    if (index >= 0 && index < balls.length) {
      balls.removeAt(index);
    }
  }
}
