import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/app_constants.dart';
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
      _settings.objectScaleMultiplier = 1.5;
      _settings.annotationsAboveObjects = false;
      _settings.serveZoneFactor = 1.0;
      _settings.courtBackgroundColorValue = AppTheme.courtGreen.toARGB32();
      _settings.ballSectorRadiusCm = 1000.0;
      _settings.handDrawnAnnotations = false;
      _saveSettings();
    });
  }

  void _showCourtBackgroundColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Court Background Color'),
        content: Container(
          width: 280,
          height: 200,
          color: AppTheme.lightGrey,
          child: GridView.count(
            crossAxisCount: 4,
            children: AppTheme.editorColors
                .map(
                  (color) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _settings.courtBackgroundColorValue = color.toARGB32());
                      _saveSettings();
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _settings.courtBackgroundColorValue == color.toARGB32()
                            ? Border.all(color: AppTheme.lightGrey, width: 2)
                            : null,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.padding),
        children: [
          ListTile(
            title: const Text("Object Size"),
            subtitle: Text("${_settings.objectScaleMultiplier.toStringAsFixed(1)}x marker scale"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 12,
              children: [
                for (final v in const [1.0, 1.5, 2.2])
                  ChoiceChip(
                    label: Text("${v.toStringAsFixed(1)}x"),
                    selected: (_settings.objectScaleMultiplier - v).abs() < 0.001,
                    onSelected: (_) {
                      setState(() => _settings.objectScaleMultiplier = v);
                      _saveSettings();
                    },
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Court Background Color'),
            subtitle: const Text('Tap to change or reset to default'),
            onTap: _showCourtBackgroundColorPicker,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _settings.courtBackgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.darkGrey, width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _settings.courtBackgroundColorValue = AppTheme.courtGreen.toARGB32());
                    _saveSettings();
                  },
                  child: const Text('Default'),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Court Serve Zone Scaling"),
            subtitle: Text("${_settings.serveZoneFactor.toStringAsFixed(1)}x zoom factor"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 12,
              children: [
                for (final v in const [1.0, 1.3, 1.6])
                  ChoiceChip(
                    label: Text("${v.toStringAsFixed(1)}x"),
                    selected: (_settings.serveZoneFactor - v).abs() < 0.001,
                    onSelected: (_) {
                      setState(() => _settings.serveZoneFactor = v);
                      _saveSettings();
                    },
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Default Ball Sector Radius"),
            subtitle: Text("${_settings.ballSectorRadiusCm.toStringAsFixed(0)} cm"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings.ballSectorRadiusCm,
                min: 500,
                max: 2000,
                divisions: 30,
                label: _settings.ballSectorRadiusCm.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _settings.ballSectorRadiusCm = value);
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
          SwitchListTile(
            title: const Text('Show Path Control Points (always)'),
            subtitle: const Text('When off, control points only appear while editing a path'),
            value: _settings.showPathControlPoints,
            onChanged: (v) {
              setState(() => _settings.showPathControlPoints = v);
              _saveSettings();
            },
          ),
          SwitchListTile(
            title: const Text('Annotations Above Objects'),
            subtitle: const Text('When off, annotations render below players and balls'),
            value: _settings.annotationsAboveObjects,
            onChanged: (v) {
              setState(() => _settings.annotationsAboveObjects = v);
              _saveSettings();
            },
          ),
          SwitchListTile(
            title: const Text('Hand-drawn Annotation Style'),
            subtitle: const Text('Squiggly lines, hatched fills, and handwritten text'),
            value: _settings.handDrawnAnnotations,
            onChanged: (v) {
              setState(() => _settings.handDrawnAnnotations = v);
              _saveSettings();
            },
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
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingLarge),
            child: FilledButton.tonalIcon(
              onPressed: _resetDefaults,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warningAmber.withValues(alpha: 0.2),
                foregroundColor: AppTheme.darkGrey,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLarge,
                  vertical: AppConstants.padding,
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text("Reset to Defaults"),
            ),
          ),
        ],
      ),
    );
  }
}
