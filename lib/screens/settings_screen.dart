import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings? _settings; // nullable until loaded

  @override
  void initState() {
    super.initState();

    // Delay access to Hive until after the widget tree is ready
    Future.microtask(() async {
      final settingsBox = Hive.box<Settings>('settings');

      // Safely load or create settings
      if (settingsBox.isEmpty) {
        final defaultSettings = Settings();
        await settingsBox.add(defaultSettings);
        setState(() => _settings = defaultSettings);
      } else {
        final stored = settingsBox.getAt(0);
        try {
          _settings = stored!;
        } catch (e) {
          print("Failed to read settings: $e. Replacing with defaults.");
          final defaultSettings = Settings();
          await settingsBox.putAt(0, defaultSettings);
          _settings = defaultSettings;
        }
        setState(() {});
      }
    });
  }

  void _saveSettings() {
    _settings?.save();
  }

  void _resetDefaults() {
    setState(() {
      _settings?.playbackSpeed = 1.0;
      _settings?.outerBoundsRadius = 850.0;
      _settings?.outerCircleRadius = 260.0;
      _settings?.innerCircleRadius = 100.0;
      _settings?.netCircleRadius = 46.0;
      _saveSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Playback Speed ---
          ListTile(
            title: const Text("Default Playback Speed"),
            subtitle: Text("${_settings!.playbackSpeed.toStringAsFixed(1)}x"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.playbackSpeed,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                label: "${_settings!.playbackSpeed.toStringAsFixed(1)}x",
                onChanged: (value) {
                  setState(() => _settings!.playbackSpeed = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),

          // --- OutOfBounds Radius (for future zoom-out feature) ---
          /*
          ListTile(
            title: const Text("OutOfBounds Radius"),
            subtitle: Text("${_settings!.outerBoundsRadius.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.outerBoundsRadius,
                min: 500,
                max: 1500,
                divisions: 20,
                label: "${_settings!.outerBoundsRadius.toStringAsFixed(0)}",
                onChanged: (value) {
                  setState(() => _settings!.outerBoundsRadius = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
          */

          // --- Outer Circle Radius ---
          ListTile(
            title: const Text("Serve Zone Radius"),
            subtitle: Text("${_settings!.outerCircleRadius.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.outerCircleRadius,
                min: 200,
                max: 400,
                divisions: 20,
                label: "${_settings!.outerCircleRadius.toStringAsFixed(0)}",
                onChanged: (value) {
                  setState(() => _settings!.outerCircleRadius = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),

          // --- Inner Circle Radius ---
          ListTile(
            title: const Text("NoHitZone Radius"),
            subtitle: Text("${_settings!.innerCircleRadius.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.innerCircleRadius,
                min: 40,
                max: 200,
                divisions: 32,
                label: "${_settings!.innerCircleRadius.toStringAsFixed(0)}",
                onChanged: (value) {
                  setState(() => _settings!.innerCircleRadius = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),

          // --- Net Circle Radius ---
          ListTile(
            title: const Text("Net Radius"),
            subtitle: Text("${_settings!.netCircleRadius.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.netCircleRadius,
                min: 10,
                max: 80,
                divisions: 35,
                label: "${_settings!.netCircleRadius.toStringAsFixed(0)}",
                onChanged: (value) {
                  setState(() => _settings!.netCircleRadius = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),

          // --- Reset Button ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ElevatedButton.icon(
              onPressed: _resetDefaults,
              icon: const Icon(Icons.refresh),
              label: const Text("Reset to Defaults"),
            ),
          ),
        ],
      ),
    );
  }
}
