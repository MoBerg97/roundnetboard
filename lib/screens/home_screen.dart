import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/animation_project.dart';
import 'board_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Box<AnimationProject> projectBox = Hive.box<AnimationProject>('projects');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
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
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addProject(context, projectBox),
        child: const Icon(Icons.add),
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
                box.add(AnimationProject(name: name, frames: [], paths: []));
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
}
