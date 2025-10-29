import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'dart:ui';


part 'transition_paths.g.dart';

@HiveType(typeId: 2) // unique id
class TransitionPaths extends HiveObject {
  @HiveField(0) Offset p1Ctrl;
  @HiveField(1) Offset p2Ctrl;
  @HiveField(2) Offset p3Ctrl;
  @HiveField(3) Offset p4Ctrl;
  @HiveField(4) Offset ballCtrl;

  TransitionPaths({
    required this.p1Ctrl,
    required this.p2Ctrl,
    required this.p3Ctrl,
    required this.p4Ctrl,
    required this.ballCtrl,
  });

  TransitionPaths copy() => TransitionPaths(
    p1Ctrl: p1Ctrl, p2Ctrl: p2Ctrl, p3Ctrl: p3Ctrl, p4Ctrl: p4Ctrl, ballCtrl: ballCtrl,
  );
}
