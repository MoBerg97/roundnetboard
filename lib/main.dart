import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:feature_discovery/feature_discovery.dart';

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
import 'services/tutorial_service.dart';
import 'firebase_options.dart';

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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TutorialService(),
      child: FeatureDiscovery(
        child: MaterialApp(title: 'Roundnet Tactical Board', theme: AppTheme.lightTheme(), home: const HomeScreen()),
      ),
    );
  }
}
