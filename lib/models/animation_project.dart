import 'package:hive/hive.dart';
import 'frame.dart';
import 'settings.dart';
import 'court_element.dart';

part 'animation_project.g.dart';

// ════════════════════════════════════════════════════════════════════════════
// ANIMATION PROJECT MODEL - Top-level Animation Container
// ════════════════════════════════════════════════════════════════════════════
// Represents a complete animation with frames, settings, and court customization
// Persisted via Hive; supports two project types: Play & Training
// ════════════════════════════════════════════════════════════════════════════

/// Project type enumeration
/// play: 4 fixed players, standard Roundnet court
/// training: dynamic player/ball counts, customizable court dimensions
enum ProjectType {
  play,     // Fixed 4 players, standard court geometry
  training, // Dynamic players/balls, full court customization
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

  // ════════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ════════════════════════════════════════════════════════════════════════════
  /// Creates new animation project
  ///
  /// Key parameters:
  ///   - name: human-readable project name for display
  ///   - frames: ordered list of keyframes (min 1, typically 30-120)
  ///   - settings: court dimensions, playback speed, visual prefs (auto-created if null)
  ///   - projectType: play (4-player standard) or training (dynamic) mode
  ///   - customCourtElements: optional overlay net/zone/line elements

  AnimationProject({
    required this.name,
    required this.frames,
    required this.settings,
    ProjectType? projectType,
    List<CourtElement>? customCourtElements,
  })  : projectTypeIndex = (projectType ?? ProjectType.play).index,
        customCourtElements = customCourtElements ?? [];

  ProjectType get projectType {
    if (projectTypeIndex < 0 || projectTypeIndex >= ProjectType.values.length) {
      return ProjectType.play;
    }
    return ProjectType.values[projectTypeIndex];
  }
  
  set projectType(ProjectType value) {
    projectTypeIndex = value.index;
  }
}

extension AnimationProjectMap on AnimationProject {
  // ════════════════════════════════════════════════════════════════════════════
  // SERIALIZATION & DESERIALIZATION
  // ════════════════════════════════════════════════════════════════════════════
  // JSON-compatible map for export/import and format conversion
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
