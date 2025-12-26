import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../models/animation_project.dart';
import '../screens/onboarding_screen.dart';
import '../services/tutorial_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Guide')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.padding),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Start Home Tutorial'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 44),
              ),
              onPressed: () => _startHomeTutorialFromHelp(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.school_outlined),
              label: const Text('Replay Onboarding Intro'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OnboardingScreen(onFinish: () => Navigator.of(context).pop())),
                );
              },
            ),
          ),
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
            description:
                'Tap a project to open it. Drag players and the ball to set positions. Tap the frame thumbnail button to add new frames.',
          ),
          _buildSection(
            context,
            icon: Icons.timeline,
            title: 'Animation Timeline',
            description:
                'The timeline at the bottom shows all frames. Select any frame to edit it. Each frame can have a custom duration.',
          ),
          _buildSection(
            context,
            icon: Icons.play_arrow,
            title: 'Playing Animations',
            description:
                'Tap the play button to preview your animation. Use the speed slider to adjust playback speed. Tap pause to stop.',
          ),
          _buildSection(
            context,
            icon: Icons.show_chart,
            title: 'Movement Paths',
            description:
                'When objects move between frames, paths are automatically created. Tap the ball path to add hit markers or set effects. Touch and drag control points to curve the path.',
          ),
          _buildSection(
            context,
            icon: Icons.draw,
            title: 'Annotations',
            description:
                'Open the annotation menu to add lines or circles to the court. Use annotations to highlight tactics or mark positions. Annotations are frame-specific.',
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
            description:
                'Tap the ⋮ menu on any project and select "Share Project" to send it via messaging apps, email, or save to files. Everything is preserved - positions, paths, annotations, timing, and settings.',
          ),
          _buildSection(
            context,
            icon: Icons.file_download,
            title: 'Exporting Projects',
            description:
                'Select "Export JSON" from the ⋮ menu to save a project file. Choose where to save it on your device. Perfect for backups!',
          ),
          _buildSection(
            context,
            icon: Icons.file_upload,
            title: 'Importing Projects',
            description:
                'Tap the ⬆ upload button on the projects screen. Select a .json project file to import it. If the name exists, a number is added automatically.',
          ),
          _buildSection(
            context,
            icon: Icons.content_copy,
            title: 'Duplicating Projects',
            description:
                'Tap the ⋮ menu and select "Duplicate" to create a copy of a project. Great for creating variations of plays.',
          ),
          _buildSection(
            context,
            icon: Icons.settings,
            title: 'Project Settings',
            description:
                'Access the settings menu (⋮) in the editor to adjust court dimensions, toggle previous frame lines visibility, and more.',
          ),
          const SizedBox(height: AppConstants.paddingXLarge),
          _buildTipsSection(context),
          const SizedBox(height: AppConstants.paddingXLarge),
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
      elevation: AppConstants.cardElevation,
      margin: const EdgeInsets.only(bottom: AppConstants.padding),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.padding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryBlue),
            const SizedBox(width: AppConstants.padding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppConstants.paddingSmall),
                  Text(description, style: Theme.of(context).textTheme.bodyMedium),
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
      elevation: AppConstants.cardElevation,
      color: AppTheme.lightGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: AppTheme.primaryBlue),
                const SizedBox(width: AppConstants.paddingSmall),
                Text(
                  'Tips & Tricks',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSmall),
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
      elevation: AppConstants.cardElevation,
      color: AppTheme.lightGrey.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, color: AppTheme.accentOrange),
                const SizedBox(width: AppConstants.paddingSmall),
                Text(
                  'Quick Actions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSmall),
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
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          const Text(' → '),
          Expanded(flex: 3, child: Text(result)),
        ],
      ),
    );
  }

  Future<void> _startHomeTutorialFromHelp(BuildContext context) async {
    final box = Hive.box<AnimationProject>('projects');
    await context.read<TutorialService>().startHomeTutorial(context, hasProject: box.isNotEmpty);
  }
}
