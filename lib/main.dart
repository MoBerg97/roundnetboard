import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  runApp(const AppBootstrapper());
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  late final Future<bool> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'Roundnet Tactical Board',
            theme: AppTheme.lightTheme(),
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            title: 'Roundnet Tactical Board',
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: Center(
                child: Padding(padding: const EdgeInsets.all(24), child: Text('Startup failed: ${snapshot.error}')),
              ),
            ),
          );
        }

        return MyApp(seenOnboarding: snapshot.data ?? false);
      },
    );
  }

  Future<bool> _bootstrap() async {
    final firebaseInitFuture = Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefsFuture = SharedPreferences.getInstance();

    await _initHiveStorage();
    _registerAdaptersIfNeeded();

    await Hive.openBox<AnimationProject>('projects');
    final projectsBox = Hive.box<AnimationProject>('projects');

    // Migration: ensure each project has settings.
    for (int i = 0; i < projectsBox.length; i++) {
      final p = projectsBox.getAt(i);
      if (p != null && p.settings == null) {
        p.settings = Settings();
        await p.save();
      }
    }

    final prefs = await prefsFuture;
    await _loadPresetProjectsIfNeeded(projectsBox, prefs);

    if (!kIsWeb) {
      await firebaseInitFuture;
      // Pass all uncaught errors from the framework to Crashlytics.
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
      // Capture async errors.
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack);
        return true;
      };
    } else {
      unawaited(
        firebaseInitFuture.catchError((error) {
          debugPrint('Firebase init failed on web: $error');
        }),
      );
    }

    return prefs.getBool('seenOnboarding') ?? false;
  }

  Future<void> _initHiveStorage() async {
    if (kIsWeb) {
      await Hive.initFlutter();
      return;
    }

    // Keep local desktop storage isolated from shared Documents root to avoid
    // cross-process lock conflicts on generic box lock file names.
    final supportDir = await getApplicationSupportDirectory();
    final hiveDir = Directory('${supportDir.path}${Platform.pathSeparator}hive');
    if (!await hiveDir.exists()) {
      await hiveDir.create(recursive: true);
    }

    await _migrateLegacyProjectsBoxIfNeeded(hiveDir.path);
    Hive.init(hiveDir.path);
  }

  Future<void> _migrateLegacyProjectsBoxIfNeeded(String newHivePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    if (docsDir.path == newHivePath) return;

    final legacyProjects = File('${docsDir.path}${Platform.pathSeparator}projects.hive');
    final newProjects = File('$newHivePath${Platform.pathSeparator}projects.hive');

    if (await legacyProjects.exists() && !await newProjects.exists()) {
      await legacyProjects.copy(newProjects.path);
    }
  }
}

void _registerAdaptersIfNeeded() {
  // Register adapters (order/typeIds must match the existing data model).
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(OffsetAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FrameAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(AnnotationAdapter());
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(AnimationProjectAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(SettingsAdapter());
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(AnnotationTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(PlayerAdapter());
  if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(BallAdapter());
  if (!Hive.isAdapterRegistered(12)) {
    Hive.registerAdapter(CourtElementAdapter());
  }
}

/// Loads preset projects from assets if this is the first app start
Future<void> _loadPresetProjectsIfNeeded(Box<AnimationProject> projectsBox, SharedPreferences prefs) async {
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
