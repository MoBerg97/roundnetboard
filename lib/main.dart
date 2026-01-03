import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'dart:convert';

import 'config/app_theme.dart';
import 'models/offset_adapter.dart';
import 'models/frame.dart';
import 'models/player.dart';
import 'models/ball.dart';
import 'models/animation_project.dart';
import 'models/settings.dart';
import 'models/annotation.dart';
import 'models/court_element.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/tutorial_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'utils/version_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -------------------------
  // 🚨 Initialize Firebase & Crashlytics
  // -------------------------

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    // Pass all uncaught errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    // Capture async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack);
      return true;
    };
  }

  // -------------------------
  // 🗄 Initialize Hive
  // -------------------------

  await Hive.initFlutter();

  // Register adapters (order/typeIds must match what you used above)
  Hive.registerAdapter(OffsetAdapter()); // typeId = 0 (manual)
  Hive.registerAdapter(FrameAdapter()); // typeId = 1 (generated)
  Hive.registerAdapter(AnnotationAdapter()); // typeId = 2 (generated)
  Hive.registerAdapter(AnimationProjectAdapter()); // typeId = 3 (generated)
  Hive.registerAdapter(SettingsAdapter()); // typeId = 4 (generated)
  Hive.registerAdapter(AnnotationTypeAdapter()); // typeId = 5 (generated)
  Hive.registerAdapter(PlayerAdapter()); // typeId = 10 (generated)
  Hive.registerAdapter(BallAdapter()); // typeId = 11 (generated)
  Hive.registerAdapter(CourtElementAdapter()); // typeId = 12 (generated)

  // Open Hive boxes
  await Hive.openBox<AnimationProject>('projects');
  final projectsBox = Hive.box<AnimationProject>('projects');

  // Migration: ensure each project has settings
  for (int i = 0; i < projectsBox.length; i++) {
    final p = projectsBox.getAt(i);
    if (p != null && p.settings == null) {
      p.settings = Settings();
      await p.save();
    }
  }

  // Load preset projects on first start
  await _loadPresetProjectsIfNeeded(projectsBox);

  // Check onboarding state
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  runApp(MyApp(seenOnboarding: seenOnboarding));
}

/// Loads preset projects from assets if this is the first app start
Future<void> _loadPresetProjectsIfNeeded(Box<AnimationProject> projectsBox) async {
  final prefs = await SharedPreferences.getInstance();
  final presetsLoaded = prefs.getBool('presetsLoaded') ?? false;

  // Only load presets if box is empty and they haven't been loaded before
  if (!presetsLoaded && projectsBox.isEmpty) {
    try {
      // Load Hit Queue
      final hitQueueJson = await rootBundle.loadString('assets/presetprojects/Hit_Queue.json');
      final hitQueueMap = json.decode(hitQueueJson) as Map<String, dynamic>;
      final hitQueueProject = AnimationProjectMap.fromMap(hitQueueMap);
      await projectsBox.add(hitQueueProject);

      // Load Open Defence
      final openDefenceJson = await rootBundle.loadString('assets/presetprojects/Open_Defence.json');
      final openDefenceMap = json.decode(openDefenceJson) as Map<String, dynamic>;
      final openDefenceProject = AnimationProjectMap.fromMap(openDefenceMap);
      await projectsBox.add(openDefenceProject);

      // Mark as loaded
      await prefs.setBool('presetsLoaded', true);
    } catch (e) {
      // If loading fails, continue without presets
      debugPrint('Failed to load preset projects: $e');
    }
  }
}

class MyApp extends StatefulWidget {
  final bool seenOnboarding;
  const MyApp({super.key, required this.seenOnboarding});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _seenOnboarding;
  bool _pendingHomeTutorial = false;
  late TutorialService _tutorialService;

  @override
  void initState() {
    super.initState();
    _seenOnboarding = widget.seenOnboarding;
    _tutorialService = TutorialService();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    // Wait a bit for the app to load
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      await VersionCheck.checkVersion(context);
    }
  }

  Future<void> _finishOnboardingAndQueueHomeTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    setState(() {
      _seenOnboarding = true;
      _pendingHomeTutorial = true;
    });
  }

  bool _consumePendingHomeTutorialFlag() {
    if (_pendingHomeTutorial) {
      _pendingHomeTutorial = false;
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureDiscovery(
      child: ChangeNotifierProvider.value(
        value: _tutorialService,
        child: MaterialApp(
          title: 'Roundnet Tactical Board',
          theme: AppTheme.lightTheme(),
          home: _seenOnboarding
              ? HomeScreen(startTutorialOnMount: _consumePendingHomeTutorialFlag())
              : _OnboardingWrapper(onStartTutorial: _finishOnboardingAndQueueHomeTutorial),
        ),
      ),
    );
  }
}

// Wrapper to provide proper context for navigation
class _OnboardingWrapper extends StatelessWidget {
  final Future<void> Function(BuildContext) onStartTutorial;
  const _OnboardingWrapper({required this.onStartTutorial});

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(onFinish: () => onStartTutorial(context));
  }
}
