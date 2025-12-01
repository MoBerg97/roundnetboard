import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/animation_project.dart';
import '../models/settings.dart';
import '../utils/share_helper.dart';
import '../utils/export_import.dart';
import 'board_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Box<AnimationProject> projectBox = Hive.box<AnimationProject>('projects');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
      ),
      body: ValueListenableBuilder(
        valueListenable: projectBox.listenable(),
        builder: (context, Box<AnimationProject> box, _) {
          if (box.values.isEmpty) {
            return const Center(child: Text("No projects yet. Add one!"));
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final project = box.getAt(index)!;

              return ListTile(
                title: Text(project.name),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          BoardScreen(project: project),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                      reverseTransitionDuration: const Duration(milliseconds: 300),
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
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    const PopupMenuItem(value: 'export', child: Text('Export JSON')),
                    const PopupMenuItem(value: 'share', child: Text('Share Project')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'import',
            onPressed: () => _importProject(context, projectBox),
            child: const Icon(Icons.file_upload),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => _addProject(context, projectBox),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _addProject(BuildContext context, Box<AnimationProject> box) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Project"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Project Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final defaultSettings = Settings();
                box.add(AnimationProject(name: name, frames: [], settings: defaultSettings));
              }
              Navigator.pop(context);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _renameProject(BuildContext context, Box<AnimationProject> box, int index, AnimationProject project) {
    final controller = TextEditingController(text: project.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename Project"),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                project.name = newName;
                project.save(); // Save changes to Hive
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _duplicateProject(BuildContext context, Box<AnimationProject> box, AnimationProject project) {
    // Find a unique name with numerated suffix
    String newName = project.name;
    int suffix = 1;

    while (box.values.any((p) => p.name == newName)) {
      newName = "${project.name} ($suffix)";
      suffix++;
    }

    // Create deep copy of the project
    final duplicatedFrames = project.frames.map((f) => f.copy()).toList();
    final duplicatedProject = AnimationProject(
      name: newName,
      frames: duplicatedFrames,
      settings: project.settings?.copy(),
    );

    // Add to box
    box.add(duplicatedProject);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Project duplicated as "$newName"')),
    );
  }

  Future<void> _exportProject(BuildContext context, AnimationProject project) async {
    try {
      final file = await ProjectIO.exportToJsonWithPicker(project);
      
      if (file == null) {
        // User cancelled the save dialog
        return;
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project exported to:\n${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _shareProject(BuildContext context, AnimationProject project) async {
    try {
      await ShareHelper.shareProject(project);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  Future<void> _importProject(BuildContext context, Box<AnimationProject> box) async {
    try {
      // Pick a JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final importedProject = await ProjectIO.importFromJsonFile(file);

        // Find unique name if project name already exists
        String newName = importedProject.name;
        int suffix = 1;
        while (box.values.any((p) => p.name == newName)) {
          newName = "${importedProject.name} ($suffix)";
          suffix++;
        }
        importedProject.name = newName;

        // Add to box
        box.add(importedProject);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Project imported as "$newName"')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }
}
