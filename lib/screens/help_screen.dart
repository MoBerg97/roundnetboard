import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            icon: Icons.add_circle,
            title: 'Creating Projects',
            description: 'Tap the + button to create a new animation project. Give it a name and start animating!',
          ),
          _buildSection(
            context,
            icon: Icons.edit,
            title: 'Editing Frames',
            description: 'Tap a project to open it. Drag players and the ball to set positions. Tap the frame thumbnail button to add new frames.',
          ),
          _buildSection(
            context,
            icon: Icons.timeline,
            title: 'Animation Timeline',
            description: 'The timeline at the bottom shows all frames. Select any frame to edit it. Each frame can have a custom duration.',
          ),
          _buildSection(
            context,
            icon: Icons.play_arrow,
            title: 'Playing Animations',
            description: 'Tap the play button to preview your animation. Use the speed slider to adjust playback speed. Tap pause to stop.',
          ),
          _buildSection(
            context,
            icon: Icons.show_chart,
            title: 'Movement Paths',
            description: 'When objects move between frames, paths are automatically created. Tap the ball path to add hit markers or set effects. Touch and drag control points to curve the path.',
          ),
          _buildSection(
            context,
            icon: Icons.draw,
            title: 'Annotations',
            description: 'Open the annotation menu to add lines or circles to the court. Use annotations to highlight tactics or mark positions. Annotations are frame-specific.',
          ),
          _buildSection(
            context,
            icon: Icons.undo,
            title: 'Undo & Redo',
            description: 'Made a mistake? Use the undo button to go back. The redo button restores undone actions.',
          ),
          _buildSection(
            context,
            icon: Icons.share,
            title: 'Sharing Projects',
            description: 'Tap the ⋮ menu on any project and select "Share Project" to send it via messaging apps, email, or save to files. Everything is preserved - positions, paths, annotations, timing, and settings.',
          ),
          _buildSection(
            context,
            icon: Icons.file_download,
            title: 'Exporting Projects',
            description: 'Select "Export JSON" from the ⋮ menu to save a project file. Choose where to save it on your device. Perfect for backups!',
          ),
          _buildSection(
            context,
            icon: Icons.file_upload,
            title: 'Importing Projects',
            description: 'Tap the ⬆ upload button on the projects screen. Select a .json project file to import it. If the name exists, a number is added automatically.',
          ),
          _buildSection(
            context,
            icon: Icons.content_copy,
            title: 'Duplicating Projects',
            description: 'Tap the ⋮ menu and select "Duplicate" to create a copy of a project. Great for creating variations of plays.',
          ),
          _buildSection(
            context,
            icon: Icons.settings,
            title: 'Project Settings',
            description: 'Access the settings menu (⋮) in the editor to adjust court dimensions, toggle previous frame lines visibility, and more.',
          ),
          const SizedBox(height: 32),
          _buildTipsSection(context),
          const SizedBox(height: 32),
          _buildQuickActionsSection(context),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsSection(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Tips & Tricks',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTip('Hold and drag objects smoothly for better control'),
            _buildTip('Use multiple frames to create complex animations'),
            _buildTip('Adjust frame duration for realistic timing'),
            _buildTip('Add annotations before sharing to explain tactics'),
            _buildTip('Export projects regularly as backups'),
            _buildTip('Use descriptive project names for easy organization'),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildQuickAction('Tap a project', 'Open and edit'),
            _buildQuickAction('Tap ⋮ menu', 'Rename, duplicate, share, export, or delete'),
            _buildQuickAction('Tap + button', 'Create new project'),
            _buildQuickAction('Tap ⬆ button', 'Import shared project'),
            _buildQuickAction('Tap frame', 'Select and edit that frame'),
            _buildQuickAction('Double tap ball path', 'Add control point'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String action, String result) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              action,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(' → '),
          Expanded(
            flex: 3,
            child: Text(result),
          ),
        ],
      ),
    );
  }
}
