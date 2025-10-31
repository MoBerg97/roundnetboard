import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/offset_adapter.dart';
import 'models/frame.dart';
import 'models/animation_project.dart';
import 'models/settings.dart'; 
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters (order/typeIds must match what you used above)
  Hive.registerAdapter(OffsetAdapter());            // typeId = 0 (manual)
  Hive.registerAdapter(FrameAdapter());             // typeId = 1 (generated)
  Hive.registerAdapter(AnimationProjectAdapter());  // typeId = 3 (generated)
  Hive.registerAdapter(SettingsAdapter());          // typeId = 4 (generated)

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
