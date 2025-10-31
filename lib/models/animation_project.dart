import 'package:hive/hive.dart';
import 'frame.dart';
import 'settings.dart';

part 'animation_project.g.dart';

@HiveType(typeId: 3) // unique id
class AnimationProject extends HiveObject {
  @HiveField(0) String name;

  // Simple lists are fine (you'll save the whole project object when updating)
  @HiveField(1) List<Frame> frames;

  // Project-specific settings
  @HiveField(3) Settings? settings;

  AnimationProject({
    required this.name,
    required this.frames,
    required this.settings,
  });
}

extension AnimationProjectMap on AnimationProject {
  Map<String, dynamic> toMap() => {
        'name': name,
        'frames': frames.map((f) => f.toMap()).toList(),
        'settings': (settings ?? Settings()).toMap(),
      };

  static AnimationProject fromMap(Map<String, dynamic> m) => AnimationProject(
        name: m['name'] as String,
        frames: (m['frames'] as List)
            .map((e) => FrameMap.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        settings: SettingsMap.fromMap(Map<String, dynamic>.from(m['settings'])),
      );
}
