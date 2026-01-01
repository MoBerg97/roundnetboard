import 'package:flutter/material.dart';
import '../models/animation_project.dart';
import '../models/frame.dart';
import '../models/settings.dart';
import '../models/player.dart';
import '../models/ball.dart';

abstract class ProjectAction {
  int frameIndex;
  String description;
  ProjectAction({required this.frameIndex, required this.description});
  void apply(AnimationProject project);
  void revert(AnimationProject project);
}

class MoveEntityAction extends ProjectAction {
  final String id; // UUID or named ID (P1-P4, B1) of the entity
  final Offset from;
  final Offset to;
  MoveEntityAction({required super.frameIndex, required this.id, required this.from, required this.to})
    : super(description: 'Move entity');

  @override
  void apply(AnimationProject project) {
    final f = project.frames[frameIndex];
    final player = f.getPlayerById(id);
    if (player != null) {
      player.position = to;
    } else {
      final ball = f.getBallById(id);
      if (ball != null) {
        ball.position = to;
      }
    }
  }

  @override
  void revert(AnimationProject project) {
    final f = project.frames[frameIndex];
    final player = f.getPlayerById(id);
    if (player != null) {
      player.position = from;
    } else {
      final ball = f.getBallById(id);
      if (ball != null) {
        ball.position = from;
      }
    }
  }
}

class InsertFrameAction extends ProjectAction {
  final Frame inserted;
  InsertFrameAction({required super.frameIndex, required this.inserted}) : super(description: 'Insert frame');
  @override
  void apply(AnimationProject project) {
    project.frames.insert(frameIndex + 1, inserted.copy());
  }

  @override
  void revert(AnimationProject project) {
    project.frames.removeAt(frameIndex + 1);
  }
}

class DeleteFrameAction extends ProjectAction {
  Frame? removed;
  DeleteFrameAction({required super.frameIndex}) : super(description: 'Delete frame');
  @override
  void apply(AnimationProject project) {
    removed = project.frames.removeAt(frameIndex);
  }

  @override
  void revert(AnimationProject project) {
    if (removed != null) {
      project.frames.insert(frameIndex, removed!.copy());
    }
  }
}

class SetPlaybackSpeedAction extends ProjectAction {
  final double from;
  final double to;
  SetPlaybackSpeedAction({required this.from, required this.to})
    : super(frameIndex: 0, description: 'Set playback speed');
  @override
  void apply(AnimationProject project) {
    // Ensure settings exists for legacy projects
    project.settings ??= Settings();
    project.settings!.playbackSpeed = to;
  }

  @override
  void revert(AnimationProject project) {
    project.settings ??= Settings();
    project.settings!.playbackSpeed = from;
  }
}

/// Cascade delete player from all frames (undoable)
class RemovePlayerFromAllFramesAction extends ProjectAction {
  final String id; // Player ID to remove
  final Map<int, Player> removedPlayers; // Frame index -> removed player state

  RemovePlayerFromAllFramesAction({required this.id})
    : removedPlayers = {},
      super(frameIndex: 0, description: 'Delete player from all frames');

  @override
  void apply(AnimationProject project) {
    removedPlayers.clear();
    for (int i = 0; i < project.frames.length; i++) {
      final frame = project.frames[i];
      final player = frame.getPlayerById(id);
      if (player != null) {
        removedPlayers[i] = player.copy(); // Store copy for undo
        frame.removePlayerById(id);
      }
    }
  }

  @override
  void revert(AnimationProject project) {
    // Restore removed players to their original frames
    removedPlayers.forEach((frameIndex, player) {
      if (frameIndex < project.frames.length) {
        project.frames[frameIndex].players.add(player.copy());
      }
    });
  }
}

/// Cascade delete ball from all frames (undoable)
class RemoveBallFromAllFramesAction extends ProjectAction {
  final String id; // Ball ID to remove
  final Map<int, Ball> removedBalls; // Frame index -> removed ball state

  RemoveBallFromAllFramesAction({required this.id})
    : removedBalls = {},
      super(frameIndex: 0, description: 'Delete ball from all frames');

  @override
  void apply(AnimationProject project) {
    removedBalls.clear();
    for (int i = 0; i < project.frames.length; i++) {
      final frame = project.frames[i];
      final ball = frame.getBallById(id);
      if (ball != null) {
        removedBalls[i] = ball.copy(); // Store copy for undo
        frame.removeBallById(id);
      }
    }
  }

  @override
  void revert(AnimationProject project) {
    // Restore removed balls to their original frames
    removedBalls.forEach((frameIndex, ball) {
      if (frameIndex < project.frames.length) {
        project.frames[frameIndex].balls.add(ball.copy());
      }
    });
  }
}

/// Cascade create player across all frames (undoable)
class CreatePlayerAction extends ProjectAction {
  final Player player; // The player object to create

  CreatePlayerAction({required this.player}) : super(frameIndex: 0, description: 'Create player');

  @override
  void apply(AnimationProject project) {
    // Add player copy to all frames
    for (int i = 0; i < project.frames.length; i++) {
      project.frames[i].players.add(player.copy());
    }
  }

  @override
  void revert(AnimationProject project) {
    // Remove the player (by ID) from all frames
    for (int i = 0; i < project.frames.length; i++) {
      project.frames[i].removePlayerById(player.id);
    }
  }
}

/// Cascade create ball across all frames (undoable)
class CreateBallAction extends ProjectAction {
  final Ball ball; // The ball object to create

  CreateBallAction({required this.ball}) : super(frameIndex: 0, description: 'Create ball');

  @override
  void apply(AnimationProject project) {
    // Add ball copy to all frames
    for (int i = 0; i < project.frames.length; i++) {
      project.frames[i].balls.add(ball.copy());
    }
  }

  @override
  void revert(AnimationProject project) {
    // Remove the ball (by ID) from all frames
    for (int i = 0; i < project.frames.length; i++) {
      project.frames[i].removeBallById(ball.id);
    }
  }
}

/// Change player color (undoable)
class ChangePlayerColorAction extends ProjectAction {
  final String id; // Player ID
  final Color from;
  final Color to;

  ChangePlayerColorAction({required super.frameIndex, required this.id, required this.from, required this.to})
    : super(description: 'Change player color');

  @override
  void apply(AnimationProject project) {
    final frame = project.frames[frameIndex];
    final player = frame.getPlayerById(id);
    if (player != null) {
      player.color = to;
    }
  }

  @override
  void revert(AnimationProject project) {
    final frame = project.frames[frameIndex];
    final player = frame.getPlayerById(id);
    if (player != null) {
      player.color = from;
    }
  }
}

/// Change player color across all frames (undoable)
class ChangePlayerColorAllFramesAction extends ProjectAction {
  final String id; // Player ID
  final Color from;
  final Color to;

  ChangePlayerColorAllFramesAction({required this.id, required this.from, required this.to})
    : super(frameIndex: 0, description: 'Change player color');

  @override
  void apply(AnimationProject project) {
    for (final frame in project.frames) {
      final player = frame.getPlayerById(id);
      if (player != null) {
        player.color = to;
      }
    }
  }

  @override
  void revert(AnimationProject project) {
    for (final frame in project.frames) {
      final player = frame.getPlayerById(id);
      if (player != null) {
        player.color = from;
      }
    }
  }
}

/// Change player label across all frames (undoable)
class ChangePlayerLabelAllFramesAction extends ProjectAction {
  final String id; // Player ID
  final String? from;
  final String? to;

  ChangePlayerLabelAllFramesAction({required this.id, required this.from, required this.to})
    : super(frameIndex: 0, description: 'Change player label');

  @override
  void apply(AnimationProject project) {
    for (final frame in project.frames) {
      final player = frame.getPlayerById(id);
      if (player != null) {
        player.label = to;
      }
    }
  }

  @override
  void revert(AnimationProject project) {
    for (final frame in project.frames) {
      final player = frame.getPlayerById(id);
      if (player != null) {
        player.label = from;
      }
    }
  }
}

/// Change ball color (undoable)
class ChangeBallColorAction extends ProjectAction {
  final String id; // Ball ID
  final Color from;
  final Color to;

  ChangeBallColorAction({required super.frameIndex, required this.id, required this.from, required this.to})
    : super(description: 'Change ball color');

  @override
  void apply(AnimationProject project) {
    final frame = project.frames[frameIndex];
    final ball = frame.getBallById(id);
    if (ball != null) {
      ball.color = to;
    }
  }

  @override
  void revert(AnimationProject project) {
    final frame = project.frames[frameIndex];
    final ball = frame.getBallById(id);
    if (ball != null) {
      ball.color = from;
    }
  }
}

/// Change ball color across all frames (undoable)
class ChangeBallColorAllFramesAction extends ProjectAction {
  final String id; // Ball ID
  final Color from;
  final Color to;

  ChangeBallColorAllFramesAction({required this.id, required this.from, required this.to})
    : super(frameIndex: 0, description: 'Change ball color');

  @override
  void apply(AnimationProject project) {
    for (final frame in project.frames) {
      final ball = frame.getBallById(id);
      if (ball != null) {
        ball.color = to;
      }
    }
  }

  @override
  void revert(AnimationProject project) {
    for (final frame in project.frames) {
      final ball = frame.getBallById(id);
      if (ball != null) {
        ball.color = from;
      }
    }
  }
}

class HistoryManager {
  final AnimationProject project;
  final List<ProjectAction> _undo = [];
  final List<ProjectAction> _redo = [];

  HistoryManager(this.project);

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  int push(ProjectAction action) {
    action.apply(project);
    project.save();
    _undo.add(action);
    _redo.clear();
    return action.frameIndex;
  }

  int? undo() {
    if (!canUndo) return null;
    final action = _undo.removeLast();
    action.revert(project);
    project.save();
    _redo.add(action);
    return action.frameIndex;
  }

  int? redo() {
    if (!canRedo) return null;
    final action = _redo.removeLast();
    action.apply(project);
    project.save();
    _undo.add(action);
    return action.frameIndex;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
