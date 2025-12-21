import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../models/animation_project.dart';
import '../services/project_service.dart';
import '../services/export_service.dart';
import '../services/tutorial_service.dart';
import '../utils/share_helper.dart';
import '../widgets/home_tutorial_overlay.dart';
import 'board_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _fabAddKey = GlobalKey(debugLabel: 'fab_add');
  final GlobalKey _fabImportKey = GlobalKey(debugLabel: 'fab_import');
  final GlobalKey _helpIconKey = GlobalKey(debugLabel: 'help_icon');
  final GlobalKey _projectListKey = GlobalKey(debugLabel: 'project_list');
  final Map<int, GlobalKey> _projectTileKeys = {};
  final Map<int, GlobalKey> _projectMenuKeys = {};

  @override
  void initState() {
    super.initState();
    print('🏠 HomeScreen: initState called');

    // Listen for tutorial requests
    TutorialService().addListener(_checkForPendingTutorial);
    print('🏠 HomeScreen: Listener added to TutorialService');
  }

  @override
  void dispose() {
    print('🏠 HomeScreen: dispose called');
    TutorialService().removeListener(_checkForPendingTutorial);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🏠 HomeScreen: didChangeDependencies called');

    // Check for pending tutorial trigger on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🏠 HomeScreen: Post-frame callback from didChangeDependencies');
      _checkForPendingTutorial();
    });
  }

  void _checkForPendingTutorial() {
    print('🏠 HomeScreen: _checkForPendingTutorial called');
    final tutorialService = TutorialService();
    print('🏠 HomeScreen: Pending tutorial = ${tutorialService.pendingTutorial?.name ?? 'none'}');
    print('🏠 HomeScreen: Is active = ${tutorialService.isActive}');

    if (tutorialService.pendingTutorial == TutorialType.home && !tutorialService.isActive) {
      print('🏠 HomeScreen: Conditions met, scheduling tutorial start');
      // Use post-frame callback to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('🏠 HomeScreen: Post-frame callback for tutorial start');
        if (mounted) {
          print('🏠 HomeScreen: Widget is mounted, starting tutorial');
          _startHomeTutorial();
        } else {
          print('⚠️ HomeScreen: Widget not mounted, skipping tutorial');
        }
      });
    } else {
      print('🏠 HomeScreen: Conditions not met for tutorial');
    }
  }

  void _startHomeTutorial() {
    print('🏠 HomeScreen: _startHomeTutorial called');

    print('🏠 HomeScreen: Creating HomeTutorialOverlay');

    final overlay = HomeTutorialOverlay(
      context: context,
      onFinish: () {
        print('🏠 HomeScreen: Tutorial finished');
      },
    );

    print('🏠 HomeScreen: Calling overlay.show()');
    overlay.show();
  }

  @override
  Widget build(BuildContext context) {
    final Box<AnimationProject> projectBox = Hive.box<AnimationProject>('projects');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
        actions: [
          IconButton(
            key: _helpIconKey,
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
                _projectMenuKeys[index] = GlobalKey(debugLabel: 'project_menu_$index');

                return Card(
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
                      key: _projectMenuKeys[index],
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
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            key: _fabImportKey,
            heroTag: 'import',
            backgroundColor: AppTheme.primaryBlue,
            tooltip: 'Import Project',
            onPressed: () => _importProject(context, projectBox),
            child: const Icon(Icons.file_upload),
          ),
          const SizedBox(height: AppConstants.padding),
          FloatingActionButton(
            key: _fabAddKey,
            heroTag: 'add',
            backgroundColor: AppTheme.primaryBlue,
            tooltip: 'Create New Project',
            onPressed: () => _addProject(context, projectBox),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _addProject(BuildContext context, Box<AnimationProject> box) {
    final controller = TextEditingController();
    final projectService = ProjectService(box);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.dialogBorderRadius)),
        title: const Text("New Project"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Project Name",
            hintText: "Enter project name",
            prefixIcon: Icon(Icons.edit),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton.icon(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                try {
                  await projectService.createProject(name);
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

