import 'package:hive/hive.dart';
import 'frame.dart';
import 'transition_paths.dart';

part 'animation_project.g.dart';

@HiveType(typeId: 3) // unique id
class AnimationProject extends HiveObject {
  @HiveField(0) String name;

  // Simple lists are fine (you'll save the whole project object when updating)
  @HiveField(1) List<Frame> frames;

  @HiveField(2) List<TransitionPaths> paths;

  AnimationProject({
    required this.name,
    required this.frames,
    required this.paths,
  });
}
