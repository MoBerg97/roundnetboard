import 'package:flutter/material.dart';

/// Static tutorial screen that guides users through the app features
class InteractiveTutorialScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final Map<String, GlobalKey>? highlightKeys;

  const InteractiveTutorialScreen({
    Key? key,
    required this.onFinish,
    this.highlightKeys,
  }) : super(key: key);

  @override
  State<InteractiveTutorialScreen> createState() => _InteractiveTutorialScreenState();
}

class _InteractiveTutorialScreenState extends State<InteractiveTutorialScreen> {
  final List<_TutorialStep> steps = [
    _TutorialStep(
      title: 'Create a Project',
      description: 'Tap the + button to create a new animation project. Type a name and tap Create.',
      icon: Icons.add_circle,
    ),
    _TutorialStep(
      title: 'Select a Project',
      description: 'Tap on a project card to open it and start editing frames.',
      icon: Icons.folder_open,
    ),
    _TutorialStep(
      title: 'Add Frames',
      description: 'In the board editor, tap the frame button to add new animation frames.',
      icon: Icons.video_call,
    ),
    _TutorialStep(
      title: 'Position Players',
      description: 'Drag player avatars to position them on the court for each frame.',
      icon: Icons.pan_tool,
    ),
    _TutorialStep(
      title: 'Move the Ball',
      description: 'Drag the ball to set its position for ball movement tracking.',
      icon: Icons.sports_soccer,
    ),
    _TutorialStep(
      title: 'Play Animation',
      description: 'Use the play button to preview your animation sequence.',
      icon: Icons.play_arrow,
    ),
  ];

  int _currentStep = 0;

  void _nextStep() {
    if (_currentStep < steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _finish() {
    Navigator.of(context).pop();
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final step = steps[_currentStep];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _finish,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentStep + 1) / steps.length,
                minHeight: 8,
              ),
              const SizedBox(height: 24),
              Text(
                'Step ${_currentStep + 1}/${steps.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 32),
              // Step icon
              Icon(
                step.icon,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              // Step content
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_currentStep > 0)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      onPressed: _previousStep,
                    ),
                  ElevatedButton.icon(
                    icon: Icon(_currentStep == steps.length - 1
                        ? Icons.check
                        : Icons.arrow_forward),
                    label: Text(_currentStep == steps.length - 1
                        ? 'Finish'
                        : 'Next'),
                    onPressed: _nextStep,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  _TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
