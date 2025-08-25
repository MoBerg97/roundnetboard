import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:ui';

import 'models/offset_adapter.dart';
import 'models/frame.dart';
import 'models/transition_paths.dart';
import 'models/animation_project.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters (order/typeIds must match what you used above)
  Hive.registerAdapter(OffsetAdapter());          // typeId = 0 (manual)
  Hive.registerAdapter(FrameAdapter());           // typeId = 1 (generated)
  Hive.registerAdapter(TransitionPathsAdapter()); // typeId = 2 (generated)
  Hive.registerAdapter(AnimationProjectAdapter()); // typeId = 3 (generated)

  // Open a single box to store projects
  await Hive.openBox<AnimationProject>('projects');

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
