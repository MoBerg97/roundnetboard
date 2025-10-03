import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/offset_adapter.dart';
import 'models/frame.dart';
import 'models/transition_paths.dart';
import 'models/animation_project.dart';
import 'models/settings.dart'; 
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters (order/typeIds must match what you used above)
  Hive.registerAdapter(OffsetAdapter());            // typeId = 0 (manual)
  Hive.registerAdapter(FrameAdapter());             // typeId = 1 (generated)
  Hive.registerAdapter(TransitionPathsAdapter());   // typeId = 2 (generated)
  Hive.registerAdapter(AnimationProjectAdapter());  // typeId = 3 (generated)
  Hive.registerAdapter(SettingsAdapter());          // typeId = 4 (generated)

  // === DELETE OLD SETTINGS BOX (OPTION 1) ===
  // Only use during development/testing
  await Hive.deleteBoxFromDisk('settings');
  // =========================================
  

  // Open Hive boxes
  await Hive.openBox<AnimationProject>('projects');
  final settingsBox = await Hive.openBox<Settings>('settings');

  // Ensure settings object exists and is valid
    if (settingsBox.isEmpty) {
      final defaultSettings = Settings();
      await settingsBox.add(defaultSettings);
    } else {
      final stored = settingsBox.getAt(0);
      try {
        stored!;
      } catch (e) {
        print("Failed to read stored settings: $e. Replacing with defaults.");
        final defaultSettings = Settings();
        await settingsBox.putAt(0, defaultSettings);
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
