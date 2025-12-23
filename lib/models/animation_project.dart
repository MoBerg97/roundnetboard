import 'package:hive/hive.dart';
import 'frame.dart';
import 'settings.dart';
import 'court_element.dart';

part 'animation_project.g.dart';

/// Project type enum
enum ProjectType {
  play,     // Fixed 4 players, standard court
  training, // Dynamic players/balls, customizable court
}

@HiveType(typeId: 3) // unique id
class AnimationProject extends HiveObject {
  @HiveField(0) String name;

  // Simple lists are fine (you'll save the whole project object when updating)
  @HiveField(1) List<Frame> frames;

  // Project-specific settings
  @HiveField(3) Settings? settings;

  // Project type (play or training mode)
  @HiveField(4) int projectTypeIndex;

  // Custom court elements (nets, zones, lines, circles, rectangles)
  @HiveField(5) List<CourtElement>? customCourtElements;

  AnimationProject({
    required this.name,
    required this.frames,
    required this.settings,
    ProjectType? projectType,
    List<CourtElement>? customCourtElements,
  })  : projectTypeIndex = (projectType ?? ProjectType.play).index,
        customCourtElements = customCourtElements ?? [];

  ProjectType get projectType => ProjectType.values[projectTypeIndex];
  
  set projectType(ProjectType value) {
    projectTypeIndex = value.index;
  }
}

extension AnimationProjectMap on AnimationProject {
  Map<String, dynamic> toMap() => {
        'name': name,
        'frames': frames.map((f) => f.toMap()).toList(),
        'settings': (settings ?? Settings()).toMap(),
        'projectType': projectTypeIndex,
        'customCourtElements': (customCourtElements ?? [])
            .map((e) => CourtElementMap(e).toMap())
            .toList(),
      };

  static AnimationProject fromMap(Map<String, dynamic> m) => AnimationProject(
        name: m['name'] as String,
        frames: (m['frames'] as List)
            .map((e) => FrameMap.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        settings: SettingsMap.fromMap(Map<String, dynamic>.from(m['settings'])),
        projectType: ProjectType.values[m['projectType'] ?? 0],
        customCourtElements: (m['customCourtElements'] as List? ?? [])
            .map((e) => CourtElementMap.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
