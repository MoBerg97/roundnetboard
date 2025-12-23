import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../models/animation_project.dart';
import '../models/court_templates.dart';
import '../services/project_service.dart';
import '../services/export_service.dart';
import '../services/tutorial_service.dart';
import '../utils/share_helper.dart';
import 'board_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool startTutorialOnMount;
  const HomeScreen({super.key, this.startTutorialOnMount = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _fabAddKey = GlobalKey(debugLabel: 'fab_add');
  final GlobalKey _fabImportKey = GlobalKey(debugLabel: 'fab_import');
  final GlobalKey _projectListKey = GlobalKey(debugLabel: 'project_list');
  final Map<int, GlobalKey> _projectTileKeys = {};
  bool _tutorialQueued = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tutorialQueued && widget.startTutorialOnMount) {
      _tutorialQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startHomeTutorial());
    }
  }

  Future<void> _startHomeTutorial() async {
    final box = Hive.box<AnimationProject>('projects');
    await context.read<TutorialService>().startHomeTutorial(context, hasProject: box.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final Box<AnimationProject> projectBox = Hive.box<AnimationProject>('projects');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            tooltip: 'Help & Guide',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
          ),
        ],
      ),
      body: Container(
        color: AppTheme.mediumGrey,
        child: ValueListenableBuilder(
          valueListenable: projectBox.listenable(),
          builder: (context, Box<AnimationProject> box, _) {
            if (box.values.isEmpty) {
              return Center(
                child: Text("No projects yet. Add one!", style: TextStyle(color: AppTheme.lightGrey)),
              );
            }
            return ListView.builder(
              key: _projectListKey,
              padding: const EdgeInsets.all(AppConstants.padding),
              itemCount: box.length,
              itemBuilder: (context, index) {
                final project = box.getAt(index)!;
                _projectTileKeys[index] = GlobalKey(debugLabel: 'project_tile_$index');

                final listTile = Card(
                  elevation: AppConstants.cardElevation,
                  margin: const EdgeInsets.only(bottom: AppConstants.padding),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                  child: ListTile(
                    key: _projectTileKeys[index],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.padding,
                      vertical: AppConstants.paddingSmall,
                    ),
                    title: Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text("${project.frames.length} frame${project.frames.length == 1 ? '' : 's'}"),
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => BoardScreen(project: project),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          transitionDuration: AppConstants.mediumAnimation,
                          reverseTransitionDuration: AppConstants.mediumAnimation,
                        ),
                      );
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rename') {
                          _renameProject(context, box, index, project);
                        } else if (value == 'delete') {
                          box.deleteAt(index);
                        } else if (value == 'duplicate') {
                          _duplicateProject(context, box, project);
                        } else if (value == 'export') {
                          _exportProject(context, project);
                        } else if (value == 'share') {
                          _shareProject(context, project);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: AppConstants.paddingSmall),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy, size: 20),
                              SizedBox(width: AppConstants.paddingSmall),
                              Text('Duplicate'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(Icons.file_download, size: 20),
                              SizedBox(width: AppConstants.paddingSmall),
                              Text('Export JSON'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share, size: 20),
                              SizedBox(width: AppConstants.paddingSmall),
                              Text('Share Project'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: AppTheme.errorRed),
                              SizedBox(width: AppConstants.paddingSmall),
                              Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (index == 0) {
                  return DescribedFeatureOverlay(
                    featureId: TutorialIds.homeOpenProject,
                    tapTarget: const Icon(Icons.folder_open),
                    title: const Text('Open your project'),
                    description: _buildStepDescription(
                      context,
                      primary: 'Tap a card to jump into the board.',
                      gestureHint: 'Tap once to open',
                    ),
                    backgroundColor: AppTheme.darkGrey,
                    contentLocation: ContentLocation.below,
                    pulseDuration: const Duration(milliseconds: 950),
                    overflowMode: OverflowMode.clipContent,
                    onComplete: context.read<TutorialService>().acknowledgeStepCompletion,
                    child: listTile,
                  );
                }

                return listTile;
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DescribedFeatureOverlay(
            featureId: TutorialIds.homeImportProject,
            tapTarget: const Icon(Icons.file_upload),
            title: const Text('Import an existing project'),
            description: _buildStepDescription(
              context,
              primary: 'Pull in a shared JSON file.',
              gestureHint: 'Tap once to choose a file',
            ),
            backgroundColor: AppTheme.darkGrey,
            contentLocation: ContentLocation.below,
            pulseDuration: const Duration(milliseconds: 950),
            overflowMode: OverflowMode.clipContent,
            onComplete: context.read<TutorialService>().acknowledgeStepCompletion,
            child: FloatingActionButton(
              key: _fabImportKey,
              heroTag: 'import',
              backgroundColor: AppTheme.primaryBlue,
              tooltip: 'Import Project',
              onPressed: () => _importProject(context, projectBox),
              child: const Icon(Icons.file_upload),
            ),
          ),
          const SizedBox(height: AppConstants.padding),
          DescribedFeatureOverlay(
            featureId: TutorialIds.homeAddProject,
            tapTarget: const Icon(Icons.add),
            title: const Text('Create your first project'),
            description: _buildStepDescription(
              context,
              primary: 'Start a new animation board.',
              gestureHint: 'Tap once to create',
            ),
            backgroundColor: AppTheme.darkGrey,
            contentLocation: ContentLocation.below,
            pulseDuration: const Duration(milliseconds: 950),
            overflowMode: OverflowMode.clipContent,
            onComplete: context.read<TutorialService>().acknowledgeStepCompletion,
            child: FloatingActionButton(
              key: _fabAddKey,
              heroTag: 'add',
              backgroundColor: AppTheme.primaryBlue,
              tooltip: 'Create New Project',
              onPressed: () => _addProject(context, projectBox),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDescription(BuildContext context, {required String primary, required String gestureHint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(primary, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        _GestureHintPill(label: gestureHint),
      ],
    );
  }

  void _addProject(BuildContext context, Box<AnimationProject> box) {
    final controller = TextEditingController();
    final projectService = ProjectService(box);
    var isTrainingMode = false;
    var selectedTemplateIndex = 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.dialogBorderRadius)),
          title: const Text("New Project"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "Project Name",
                    hintText: "Enter project name",
                    prefixIcon: Icon(Icons.edit),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 24),
                // Project type toggle (modern slider style)
                Text(
                  'Project Type',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4.0,
                          thumbShape: RoundSliderThumbShape(
                            elevation: 0,
                            enabledThumbRadius: 14.0,
                          ),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 18.0),
                        ),
                        child: Slider(
                          value: isTrainingMode ? 1.0 : 0.0,
                          min: 0.0,
                          max: 1.0,
                          divisions: 1,
                          onChanged: (value) {
                            setState(() {
                              isTrainingMode = value > 0.5;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  isTrainingMode ? 'Training' : 'Play',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                // Template selection for training mode
                if (isTrainingMode) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Court Template',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: List.generate(3, (index) {
                      final isSelected = selectedTemplateIndex == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected ? AppTheme.primaryBlue.withOpacity(0.1) : Colors.transparent,
                          ),
                          child: ListTile(
                            title: Text(
                              CourtTemplates.templateNames[index],
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                selectedTemplateIndex = index;
                              });
                            },
                            selected: isSelected,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            FilledButton.icon(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  try {
                    await projectService.createProject(
                      name,
                      projectType: isTrainingMode ? ProjectType.training : ProjectType.play,
                      courtTemplate: isTrainingMode ? selectedTemplateIndex : 0,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating project: $e')));
                    }
                  }
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  void _renameProject(BuildContext context, Box<AnimationProject> box, int index, AnimationProject project) {
    final controller = TextEditingController(text: project.name);
    final projectService = ProjectService(box);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.dialogBorderRadius)),
        title: const Text("Rename Project"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Project Name", prefixIcon: Icon(Icons.edit)),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton.icon(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await projectService.renameProject(index, newName);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renaming project: $e')));
                  }
                }
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _duplicateProject(BuildContext context, Box<AnimationProject> box, AnimationProject project) async {
    final projectService = ProjectService(box);

    try {
      final newName = await projectService.duplicateProject(project);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project duplicated as "$newName"')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error duplicating project: $e')));
      }
    }
  }

  Future<void> _exportProject(BuildContext context, AnimationProject project) async {
    try {
      final exportService = ExportService();
      final filePath = await exportService.exportToJson(project);

      if (filePath == null) {
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Project exported to:\n$filePath'), duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _shareProject(BuildContext context, AnimationProject project) async {
    try {
      await ShareHelper.shareProject(project);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  Future<void> _importProject(BuildContext context, Box<AnimationProject> box) async {
    try {
      final exportService = ExportService();
      final projectService = ProjectService(box);

      final importedProject = await exportService.importFromJson();

      if (importedProject == null) {
        return;
      }

      final newName = projectService.generateUniqueName(importedProject.name);
      importedProject.name = newName;

      box.add(importedProject);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project imported as "$newName"')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}

class _GestureHintPill extends StatelessWidget {
  final String label;
  const _GestureHintPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
