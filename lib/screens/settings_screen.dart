import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../models/animation_project.dart';

class SettingsScreen extends StatefulWidget {
  final AnimationProject project;
  const SettingsScreen({super.key, required this.project});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings _settings;

  @override
  void initState() {
    super.initState();
    if (widget.project.settings == null) {
      widget.project.settings = Settings();
      widget.project.save();
    }
    _settings = widget.project.settings!;
  }

  void _saveSettings() {
    widget.project.settings = _settings;
    widget.project.save();
  }

  void _resetDefaults() {
    setState(() {
      _settings.playbackSpeed = 1.0;
      _settings.outerBoundsRadiusCm = 850.0;
      _settings.outerCircleRadiusCm = 260.0;
      _settings.innerCircleRadiusCm = 100.0;
      _settings.netCircleRadiusCm = 46.0;
      _settings.referenceRadiusCm = 260.0;
      _saveSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text("Default Playback Speed"),
            subtitle: Text("${_settings.playbackSpeed.toStringAsFixed(1)}x"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings.playbackSpeed,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                label: "${_settings.playbackSpeed.toStringAsFixed(1)}x",
                onChanged: (value) {
                  setState(() => _settings.playbackSpeed = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Show Previous Frame Lines'),
            value: _settings.showPreviousFrameLines,
            onChanged: (v) {
              setState(() => _settings.showPreviousFrameLines = v);
              _saveSettings();
            },
          ),
          const Divider(),
          ListTile(
            title: const Text("Serve Zone Radius"),
            subtitle: Text("${_settings.outerCircleRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings.outerCircleRadiusCm,
                min: 200,
                max: 400,
                divisions: 20,
                label: _settings.outerCircleRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings.outerCircleRadiusCm = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("NoHitZone Radius"),
            subtitle: Text("${_settings.innerCircleRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings.innerCircleRadiusCm,
                min: 40,
                max: 200,
                divisions: 32,
                label: _settings.innerCircleRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings.innerCircleRadiusCm = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Net Radius"),
            subtitle: Text("${_settings.netCircleRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings.netCircleRadiusCm,
                min: 10,
                max: 80,
                divisions: 35,
                label: _settings.netCircleRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings.netCircleRadiusCm = value);
                  _saveSettings();
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Reference Radius (scaling)"),
            subtitle: Text("${_settings.referenceRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings.referenceRadiusCm,
                min: 200,
                max: 400,
                divisions: 20,
                label: _settings.referenceRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings.referenceRadiusCm = value);
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