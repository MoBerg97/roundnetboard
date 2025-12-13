import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'config/app_theme.dart';
import 'models/offset_adapter.dart';
import 'models/frame.dart';
import 'models/animation_project.dart';
import 'models/settings.dart';
import 'models/annotation.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/interactive_tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -------------------------
  // 🚨 Initialize Firebase & Crashlytics
  // -------------------------

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
  // Check onboarding state
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  runApp(MyApp(seenOnboarding: seenOnboarding));
}


class MyApp extends StatefulWidget {
  final bool seenOnboarding;
  const MyApp({super.key, required this.seenOnboarding});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _seenOnboarding;
  final Map<String, GlobalKey> _tutorialKeys = {};

  @override
  void initState() {
    super.initState();
    _seenOnboarding = widget.seenOnboarding;
  }

  void _collectTutorialKeys(Map<String, GlobalKey> keys) {
    _tutorialKeys.addAll(keys);
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    setState(() => _seenOnboarding = true);
  }

  void _startTutorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InteractiveTutorialScreen(
          onFinish: _finishOnboarding,
          highlightKeys: _tutorialKeys,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roundnet Tactical Board',
      theme: AppTheme.lightTheme(),
      home: _seenOnboarding
          ? HomeScreen(onProvideTutorialKeys: _collectTutorialKeys)
          : OnboardingScreen(onFinish: _startTutorial),
    );
  }
}
