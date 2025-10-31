import 'package:flutter/material.dart';
import '../models/animation_project.dart';
import '../models/frame.dart';
import '../models/settings.dart';

abstract class ProjectAction {
  int frameIndex;
  String description;
  ProjectAction({required this.frameIndex, required this.description});
  void apply(AnimationProject project);
  void revert(AnimationProject project);
}

class MoveEntityAction extends ProjectAction {
  final String label; // "P1","P2","P3","P4","BALL"
  final Offset from;
  final Offset to;
  MoveEntityAction({required super.frameIndex, required this.label, required this.from, required this.to})
      : super(description: 'Move $label');
  @override
  void apply(AnimationProject project) {
    final f = project.frames[frameIndex];
    _set(f, to);
  }

  @override
  void revert(AnimationProject project) {
    final f = project.frames[frameIndex];
    _set(f, from);
  }

  void _set(Frame f, Offset v) {
    switch (label) {
      case "P1":
        f.p1 = v;
        break;
      case "P2":
        f.p2 = v;
        break;
      case "P3":
        f.p3 = v;
        break;
      case "P4":
        f.p4 = v;
        break;
      case "BALL":
        f.ball = v;
        break;
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


