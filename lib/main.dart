import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/offset_adapter.dart';
import 'models/frame.dart';
import 'models/animation_project.dart';
import 'models/settings.dart';
import 'models/annotation.dart';
import 'screens/home_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -------------------------
  // 🚨 Initialize Firebase & Crashlytics
  // -------------------------
  
  await Firebase.initializeApp();

  // Pass all uncaught errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Capture async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
    return true;
  };


  // -------------------------
  // 🗄 Initialize Hive
  // -------------------------

  await Hive.initFlutter();

  // Register adapters (order/typeIds must match what you used above)
  Hive.registerAdapter(OffsetAdapter());            // typeId = 0 (manual)
  Hive.registerAdapter(FrameAdapter());             // typeId = 1 (generated)
  Hive.registerAdapter(AnnotationAdapter());        // typeId = 2 (generated)
  Hive.registerAdapter(AnimationProjectAdapter());  // typeId = 3 (generated)
  Hive.registerAdapter(SettingsAdapter());          // typeId = 4 (generated)
  Hive.registerAdapter(AnnotationTypeAdapter());    // typeId = 5 (generated)

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
    return MaterialApp(
      title: 'Roundnet Tactical Board',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true, // optional, looks more modern
      ),
      home: const HomeScreen(),
    );
  }
}
