import 'package:hive_flutter/hive_flutter.dart';
import '../models/animation_project.dart';
import '../models/settings.dart';
import '../models/court_templates.dart';
import '../models/court_element.dart';

/// Service for managing animation projects.
///
/// Handles CRUD operations, project duplication with automatic
/// name collision handling, and project validation.
class ProjectService {
  final Box<AnimationProject> _projectBox;

  ProjectService(this._projectBox);

  /// Creates a new project with the given [name] and optional [projectType] and [courtTemplate].
  ///
  /// Throws [ArgumentError] if name is empty.
  Future<void> createProject(String name, {ProjectType projectType = ProjectType.play, int courtTemplate = 0}) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Project name cannot be empty');
    }

    final defaultSettings = Settings();

    // Create appropriate initial frame based on project type
    final initialFrame = projectType == ProjectType.training
        ? DefaultFrames.createTrainingFrame(defaultSettings.referenceRadiusCm)
        : DefaultFrames.createPlayFrame(defaultSettings.referenceRadiusCm);

    // Get court elements based on template
    // For training projects, default to an empty court (no net, no zones)
    // Court setup options are removed from creation; elements can be edited later in court editor
    final courtElements = projectType == ProjectType.training ? <CourtElement>[] : <CourtElement>[];

    final newProject = AnimationProject(
      name: name.trim(),
      frames: [initialFrame],
      settings: defaultSettings,
      projectType: projectType,
      customCourtElements: courtElements,
    );

    await _projectBox.add(newProject);
  }

  /// Duplicates a project with automatic name collision handling.
  ///
  /// If a project with the same name exists, appends a number suffix (1), (2), etc.
  /// Returns the name of the duplicated project.
  Future<String> duplicateProject(AnimationProject project) async {
    // Find a unique name with numbered suffix
    String newName = project.name;
    int suffix = 1;

    while (_projectBox.values.any((p) => p.name == newName)) {
      newName = "${project.name} ($suffix)";
      suffix++;
    }

    // Create deep copy of the project
    final duplicatedFrames = project.frames.map((f) => f.copy()).toList();
    final duplicatedElements = (project.customCourtElements ?? []).map((e) => e.copy()).toList();

    final duplicatedProject = AnimationProject(
      name: newName,
      frames: duplicatedFrames,
      settings: project.settings?.copy(),
      projectType: project.projectType,
      customCourtElements: duplicatedElements,
    );

    // Add to box
    await _projectBox.add(duplicatedProject);

    return newName;
  }

  /// Renames a project at the given [index] to [newName].
  ///
  /// Throws [ArgumentError] if newName is empty.
  /// Throws [RangeError] if index is out of bounds.
  Future<void> renameProject(int index, String newName) async {
    if (newName.trim().isEmpty) {
      throw ArgumentError('Project name cannot be empty');
    }

    if (index < 0 || index >= _projectBox.length) {
      throw RangeError('Project index out of bounds');
    }

    final project = _projectBox.getAt(index);
    if (project != null) {
      project.name = newName.trim();
      await project.save();
    }
  }

  /// Deletes a project at the given [index].
  ///
  /// Throws [RangeError] if index is out of bounds.
  Future<void> deleteProject(int index) async {
    if (index < 0 || index >= _projectBox.length) {
      throw RangeError('Project index out of bounds');
    }

    await _projectBox.deleteAt(index);
  }

  /// Gets a project at the given [index].
  ///
  /// Returns null if index is out of bounds.
  AnimationProject? getProject(int index) {
    if (index < 0 || index >= _projectBox.length) {
      return null;
    }
    return _projectBox.getAt(index);
  }

  /// Gets all projects.
  List<AnimationProject> getAllProjects() {
    return _projectBox.values.toList();
  }

  /// Gets the count of projects.
  int get projectCount => _projectBox.length;

  /// Checks if a project name already exists.
  bool projectNameExists(String name) {
    return _projectBox.values.any((p) => p.name == name.trim());
  }

  /// Generates a unique project name by appending a suffix if needed.
  String generateUniqueName(String baseName) {
    String newName = baseName.trim();
    int suffix = 1;

    while (projectNameExists(newName)) {
      newName = "$baseName ($suffix)";
      suffix++;
    }

    return newName;
  }
}
