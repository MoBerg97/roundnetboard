import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings? _settings;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final settingsBox = Hive.box<Settings>('settings');
      if (settingsBox.isEmpty) {
        final defaultSettings = Settings();
        await settingsBox.add(defaultSettings);
        setState(() => _settings = defaultSettings);
      } else {
        final stored = settingsBox.getAt(0);
        if (stored != null) {
          setState(() => _settings = stored);
        } else {
          final defaultSettings = Settings();
          await settingsBox.putAt(0, defaultSettings);
          setState(() => _settings = defaultSettings);
        }
      }
    });
  }

  void _saveSettings() {
    _settings?.save();
  }

  void _resetDefaults() {
    setState(() {
      _settings?.playbackSpeed = 1.0;
      _settings?.outerBoundsRadiusCm = 850.0;
      _settings?.outerCircleRadiusCm = 260.0;
      _settings?.innerCircleRadiusCm = 100.0;
      _settings?.netCircleRadiusCm = 46.0;
      _settings?.referenceRadiusCm = 260.0;
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
          ListTile(
            title: const Text("Serve Zone Radius"),
            subtitle: Text("${_settings!.outerCircleRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.outerCircleRadiusCm,
                min: 200,
                max: 400,
                divisions: 20,
                label: _settings!.outerCircleRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings!.outerCircleRadiusCm = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("NoHitZone Radius"),
            subtitle: Text("${_settings!.innerCircleRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.innerCircleRadiusCm,
                min: 40,
                max: 200,
                divisions: 32,
                label: _settings!.innerCircleRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings!.innerCircleRadiusCm = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Net Radius"),
            subtitle: Text("${_settings!.netCircleRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.netCircleRadiusCm,
                min: 10,
                max: 80,
                divisions: 35,
                label: _settings!.netCircleRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings!.netCircleRadiusCm = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Reference Radius (scaling)"),
            subtitle: Text("${_settings!.referenceRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings!.referenceRadiusCm,
                min: 200,
                max: 400,
                divisions: 20,
                label: _settings!.referenceRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings!.referenceRadiusCm = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
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