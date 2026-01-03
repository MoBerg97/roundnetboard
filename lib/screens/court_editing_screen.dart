import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../config/app_theme.dart';
import '../models/animation_project.dart';
import '../models/court_element.dart';
import '../models/settings.dart';
import '../widgets/board_background_painter.dart';
import '../widgets/court_editor_painter.dart';
import '../widgets/hover_selection_menu.dart';

enum CourtEditorTool { select, net, zone, customCircle, customLine, customRectangle, eraser }

/// Represents a snapshot of the editor state for undo/redo functionality
class _EditorSnapshot {
  final List<CourtElement> elements;
  final Color currentColor;
  final ZoneMode zoneMode;

  _EditorSnapshot({required this.elements, required this.currentColor, required this.zoneMode});

  /// Create a deep copy of this snapshot
  _EditorSnapshot copy() {
    return _EditorSnapshot(
      elements: elements.map((e) => e.copy()).toList(),
      currentColor: currentColor,
      zoneMode: zoneMode,
    );
  }
}

enum ZoneMode { inner, serve, outer }

class _ZoneOption {
  final String label;
  final ZoneMode mode;
  const _ZoneOption(this.label, this.mode);
}

class CourtEditingScreen extends StatefulWidget {
  final AnimationProject project;

  const CourtEditingScreen({super.key, required this.project});

  @override
  State<CourtEditingScreen> createState() => _CourtEditingScreenState();
}

class _CourtEditingScreenState extends State<CourtEditingScreen> {
  late CourtEditorTool _currentTool;
  late List<CourtElement> _elements;
  late Settings _settings;
  Offset? _startPos;
  Offset? _currentPos;
  CourtElement? _draggingElement;
  Offset? _dragOffset; // Offset from touch point to element position for dragging
  Offset? _dragEndOffset; // Offset for endPosition when dragging shapes
  CourtElement? _selectedElement;
  double _eraserRadius = 20.0; // cm-based eraser radius, changeable via long-tap
  final List<double> _eraserSizes = const [10.0, 20.0, 30.0];
  OverlayEntry? _eraserMenuEntry;
  int _hoverEraserIndex = -1;
  final GlobalKey _eraserButtonKey = GlobalKey(debugLabel: 'court_editor_eraser_button');
  final GlobalKey _eraserMenuKey = GlobalKey(debugLabel: 'court_editor_eraser_menu');
  final ValueNotifier<int> _eraserHoverNotifier = ValueNotifier<int>(-1);
  final List<double> _elementStrokeOptions = const [2.0, 3.5, 5.0];
  double _elementStrokeWidth = 2.0;
  OverlayEntry? _strokeWidthMenuEntry;
  int _hoverStrokeIndex = -1;
  final GlobalKey _strokeWidthButtonKey = GlobalKey(debugLabel: 'court_editor_stroke_button');
  final GlobalKey _strokeWidthMenuKey = GlobalKey(debugLabel: 'court_editor_stroke_menu');
  final ValueNotifier<int> _strokeHoverNotifier = ValueNotifier<int>(-1);
  OverlayEntry? _zoneMenuEntry;
  int _hoverZoneIndex = -1;
  final GlobalKey _zoneButtonKey = GlobalKey(debugLabel: 'court_editor_zone_button');
  final GlobalKey _zoneMenuKey = GlobalKey(debugLabel: 'court_editor_zone_menu');
  final ValueNotifier<int> _zoneHoverNotifier = ValueNotifier<int>(-1);
  final List<_ZoneOption> _zoneOptions = const [
    _ZoneOption('NHZ', ZoneMode.inner),
    _ZoneOption('SZ', ZoneMode.serve),
    _ZoneOption('OB', ZoneMode.outer),
  ];
  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'court_editor_canvas');
  Color _currentColor = Colors.white;
  ZoneMode _zoneMode = ZoneMode.inner;
  CourtElement? _previewElement;
  // Incremented whenever elements change to force background repaint
  int _elementsRevision = 0;
  Size _screenSize = Size.zero;

  // History stacks for undo/redo
  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];

  // ══════════════════════════════════════════════════════════════════════════
  // COORDINATE CONVERSION HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Calculate the center point of the board (accounting for AppBar and Timeline)
  Offset _boardCenter(Size size) {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 140; // Match the timeline height in build()
    final usableHeight = size.height - appBarHeight - timelineHeight;
    final cx = size.width / 2;
    final cy = appBarHeight + usableHeight / 2;
    return Offset(cx, cy);
  }

  /// Convert cm logical position to screen pixel position
  Offset _toScreenPosition(Offset cmPos, Size size) {
    final center = _boardCenter(size);
    return center + Offset(_settings.cmToLogical(cmPos.dx, size), _settings.cmToLogical(cmPos.dy, size));
  }

  /// Convert screen pixel position to cm logical coordinates
  Offset _screenToCm(Offset screenPos, Size size) {
    final center = _boardCenter(size);
    final logical = screenPos - center;
    final scalePerCm = _settings.cmToLogical(1.0, size);
    if (scalePerCm == 0) return Offset.zero;
    return Offset(logical.dx / scalePerCm, logical.dy / scalePerCm);
  }

  @override
  void initState() {
    super.initState();
    _currentTool = CourtEditorTool.select;
    _elements = List.from(widget.project.customCourtElements ?? []);
    _settings = widget.project.settings ?? Settings();
  }

  @override
  void dispose() {
    _removeEraserMenu();
    _removeStrokeWidthMenu();
    _removeZoneMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    _screenSize = screenSize;
    // Mirror BoardScreen canvas proportions so custom elements align 1:1 with playback view.
    const timelineHeight = 140.0;
    final boardHeight = math.max(320.0, screenSize.height - kToolbarHeight - timelineHeight);
    final boardSize = Size(screenSize.width, boardHeight);
    Settings.setScreenSize(screenSize);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Court'),
        actions: [IconButton(icon: const Icon(Icons.check), tooltip: 'Save', onPressed: _saveAndClose)],
      ),
      body: Column(
        children: [
          // Court Display
          Expanded(
            child: Container(
              color: AppTheme.darkGrey,
              padding: const EdgeInsets.all(12),
              child: Center(
                child: GestureDetector(
                  key: _canvasKey,
                  onPanDown: _onPanDown,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: SizedBox(
                    width: boardSize.width,
                    height: boardSize.height,
                    child: Stack(
                      children: [
                        // Match BoardScreen look and coordinate system.
                        RepaintBoundary(
                          child: CustomPaint(
                            size: boardSize,
                            painter: BoardBackgroundPainter(
                              screenSize: screenSize, // Use full screenSize for proper center calculation
                              settings: _settings,
                              customElements:
                                  null, // CourtEditorPainter handles all element rendering to avoid duplicates
                              projectType: widget.project.projectType,
                              elementsRevision: _elementsRevision,
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: CustomPaint(
                            size: boardSize,
                            painter: CourtEditorPainter(
                              elements: _elements,
                              eraserPos: _currentTool == CourtEditorTool.eraser && _currentPos != null
                                  ? _toScreenPosition(_currentPos!, screenSize)
                                  : null,
                              eraserRadius: _eraserRadius,
                              screenSize: screenSize, // Use full screenSize for proper center calculation
                              previewElement: _previewElement,
                              settings: _settings,
                            ),
                          ),
                        ),
                        // Draw transparent center cross (20cm x 20cm)
                        IgnorePointer(
                          ignoring: true,
                          child: CustomPaint(
                            size: boardSize,
                            painter: _CenterCrossPainter(boardSize: boardSize, settings: _settings),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Toolbar
          Container(
            color: AppTheme.darkGrey,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Select / move
                  _buildToolButton(CourtEditorTool.select, Icons.pan_tool_alt, 'Select'),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    CourtEditorTool.net,
                    _buildNetIcon(_currentTool == CourtEditorTool.net ? _currentColor : Colors.white),
                    'Net',
                  ),
                  const SizedBox(width: 4),
                  _buildZoneToggleButton(),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    CourtEditorTool.customCircle,
                    _buildMediumCircleIcon(_currentTool == CourtEditorTool.customCircle ? _currentColor : Colors.white),
                    'Circle',
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(CourtEditorTool.customLine, Symbols.diagonal_line, 'Line'),
                  const SizedBox(width: 4),
                  _buildToolButton(CourtEditorTool.customRectangle, Icons.crop_square, 'Rect'),
                  const SizedBox(width: 4),
                  _buildEraserButton(),
                  const SizedBox(width: 8),
                  _buildStrokeWidthButton(),
                  const SizedBox(width: 8),
                  _buildColorPickerButton(),
                  const SizedBox(width: 8),
                  // Undo button
                  IconButton(
                    icon: const Icon(Icons.undo),
                    color: _undoStack.isEmpty ? Colors.grey : Colors.white,
                    tooltip: 'Undo',
                    onPressed: _undoStack.isEmpty ? null : _undo,
                  ),
                  const SizedBox(width: 4),
                  // Redo button
                  IconButton(
                    icon: const Icon(Icons.redo),
                    color: _redoStack.isEmpty ? Colors.grey : Colors.white,
                    tooltip: 'Redo',
                    onPressed: _redoStack.isEmpty ? null : _redo,
                  ),
                  const SizedBox(width: 4),
                  // Duplicate selected
                  IconButton(
                    icon: const Icon(Icons.content_copy),
                    color: _selectedElement == null ? Colors.grey : Colors.white,
                    tooltip: 'Duplicate selected element',
                    onPressed: _selectedElement == null ? null : _duplicateSelected,
                  ),
                  const SizedBox(width: 8),
                  // Clear all button
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    tooltip: 'Clear All',
                    onPressed: _clearAll,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(CourtEditorTool tool, dynamic icon, String label) {
    final isActive = _currentTool == tool;
    final iconWidget = icon is IconData ? Icon(icon, color: isActive ? _currentColor : Colors.white) : icon;

    return Tooltip(
      message: label,
      child: FloatingActionButton.small(
        heroTag: 'tool-${tool.name}',
        backgroundColor: isActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
        onPressed: () => setState(() => _currentTool = tool),
        child: iconWidget,
      ),
    );
  }

  Widget _buildEraserButton() {
    final isActive = _currentTool == CourtEditorTool.eraser;
    return Tooltip(
      message: 'Eraser (long-press or right-click to choose size: ${_eraserRadius.toStringAsFixed(0)} cm)',
      child: GestureDetector(
        onLongPressStart: (details) => _toggleEraserMenu(globalPos: details.globalPosition, forceOpen: true),
        onLongPressMoveUpdate: (details) => _updateEraserMenuHover(details.globalPosition),
        onLongPressEnd: (details) {
          _updateEraserMenuHover(details.globalPosition);
          _finalizeEraserMenuSelection();
        },
        onSecondaryTapDown: (details) => _toggleEraserMenu(globalPos: details.globalPosition),
        child: FloatingActionButton.small(
          key: _eraserButtonKey,
          heroTag: 'tool-eraser',
          backgroundColor: isActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
          onPressed: () => setState(() => _currentTool = CourtEditorTool.eraser),
          child: const Icon(Symbols.ink_eraser, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildStrokeWidthButton() {
    return Tooltip(
      message: 'Line width (${_elementStrokeWidth.toStringAsFixed(1)} px)',
      child: GestureDetector(
        onLongPressStart: (details) => _toggleStrokeWidthMenu(globalPos: details.globalPosition, forceOpen: true),
        onLongPressMoveUpdate: (details) => _updateStrokeWidthMenuHover(details.globalPosition),
        onLongPressEnd: (details) {
          _updateStrokeWidthMenuHover(details.globalPosition);
          _finalizeStrokeWidthMenuSelection();
        },
        onSecondaryTapDown: (details) => _toggleStrokeWidthMenu(globalPos: details.globalPosition, forceOpen: true),
        child: FloatingActionButton.small(
          key: _strokeWidthButtonKey,
          heroTag: 'tool-stroke-width',
          backgroundColor: AppTheme.mediumGrey,
          onPressed: () => _toggleStrokeWidthMenu(forceOpen: true),
          child: const Icon(Symbols.line_weight, color: Colors.white),
        ),
      ),
    );
  }

  void _toggleEraserMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_eraserMenuEntry != null) {
      _removeEraserMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _eraserButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final origin = globalPos ?? buttonOrigin + Offset(buttonSize.width / 2, 0);

    final menuHeight = HoverSelectionMenu.totalHeightForCount(_eraserSizes.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final left = origin.dx - (menuWidth / 2);
    final top = buttonOrigin.dy - menuHeight - 12; // place above button with spacing

    _hoverEraserIndex = _eraserSizes.indexOf(_eraserRadius);
    _eraserHoverNotifier.value = _hoverEraserIndex;

    _eraserMenuEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Dismiss area
            Positioned.fill(child: GestureDetector(onTap: _removeEraserMenu)),
            Positioned(
              left: left,
              top: top,
              child: HoverSelectionMenu(
                options: List.generate(
                  _eraserSizes.length,
                  (index) => HoverMenuOption(
                    builder: (isHover) {
                      final iconRadius = 6.0 + (index * 4.0);
                      return Center(
                        child: Container(
                          width: iconRadius * 2,
                          height: iconRadius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isHover ? AppTheme.primaryBlue : Colors.white,
                              width: isHover ? 2 : 1.5,
                            ),
                            color: isHover ? Colors.white10 : Colors.transparent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                initialHover: _hoverEraserIndex,
                hoverNotifier: _eraserHoverNotifier,
                onHover: (i) => setState(() => _hoverEraserIndex = i),
                onSelect: (i) {
                  setState(() => _eraserRadius = _eraserSizes[i]);
                  _removeEraserMenu();
                },
                onDismiss: _removeEraserMenu,
                menuKey: _eraserMenuKey,
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_eraserMenuEntry!);

    // Seed hover based on current pointer location, if provided
    _updateEraserMenuHover(globalPos ?? origin);
  }

  void _removeEraserMenu() {
    _eraserMenuEntry?.remove();
    _eraserMenuEntry = null;
    _hoverEraserIndex = -1;
    _eraserHoverNotifier.value = -1;
  }

  void _updateEraserMenuHover(Offset globalPos) {
    final box = _eraserMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_eraserSizes.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _eraserHoverNotifier.value = -1;
      setState(() => _hoverEraserIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _eraserSizes.length - 1);
    if (idx != _hoverEraserIndex) {
      _eraserHoverNotifier.value = idx;
      setState(() => _hoverEraserIndex = idx);
    }
  }

  void _finalizeEraserMenuSelection() {
    if (_eraserMenuEntry == null) return;
    if (_hoverEraserIndex >= 0 && _hoverEraserIndex < _eraserSizes.length) {
      setState(() => _eraserRadius = _eraserSizes[_hoverEraserIndex]);
    }
    _removeEraserMenu();
  }

  void _toggleStrokeWidthMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_strokeWidthMenuEntry != null) {
      _removeStrokeWidthMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _strokeWidthButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final origin = globalPos ?? buttonOrigin + Offset(buttonSize.width / 2, 0);

    final menuHeight = HoverSelectionMenu.totalHeightForCount(_elementStrokeOptions.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final left = origin.dx - (menuWidth / 2);
    final top = buttonOrigin.dy - menuHeight - 12;

    _hoverStrokeIndex = _elementStrokeOptions.indexOf(_elementStrokeWidth);
    _strokeHoverNotifier.value = _hoverStrokeIndex;

    _strokeWidthMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(child: GestureDetector(onTap: _removeStrokeWidthMenu)),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: _elementStrokeOptions
                  .map(
                    (w) => HoverMenuOption(
                      builder: (isHover) => Container(
                        alignment: Alignment.center,
                        child: Container(
                          width: 34,
                          height: w + 6,
                          decoration: BoxDecoration(
                            color: isHover ? Colors.white10 : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Container(
                              height: w,
                              width: 28,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              initialHover: _hoverStrokeIndex,
              hoverNotifier: _strokeHoverNotifier,
              onHover: (i) => setState(() => _hoverStrokeIndex = i),
              onSelect: (i) {
                setState(() => _elementStrokeWidth = _elementStrokeOptions[i]);
                _removeStrokeWidthMenu();
              },
              onDismiss: _removeStrokeWidthMenu,
              menuKey: _strokeWidthMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_strokeWidthMenuEntry!);
    _updateStrokeWidthMenuHover(globalPos ?? origin);
  }

  void _removeStrokeWidthMenu() {
    _strokeWidthMenuEntry?.remove();
    _strokeWidthMenuEntry = null;
    _hoverStrokeIndex = -1;
    _strokeHoverNotifier.value = -1;
  }

  void _updateStrokeWidthMenuHover(Offset globalPos) {
    final box = _strokeWidthMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_elementStrokeOptions.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _strokeHoverNotifier.value = -1;
      setState(() => _hoverStrokeIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _elementStrokeOptions.length - 1);
    if (idx != _hoverStrokeIndex) {
      _strokeHoverNotifier.value = idx;
      setState(() => _hoverStrokeIndex = idx);
    }
  }

  void _finalizeStrokeWidthMenuSelection() {
    if (_strokeWidthMenuEntry == null) return;
    if (_hoverStrokeIndex >= 0 && _hoverStrokeIndex < _elementStrokeOptions.length) {
      setState(() => _elementStrokeWidth = _elementStrokeOptions[_hoverStrokeIndex]);
    }
    _removeStrokeWidthMenu();
  }

  void _toggleZoneMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_zoneMenuEntry != null) {
      _removeZoneMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _zoneButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final origin = globalPos ?? buttonOrigin + Offset(buttonSize.width / 2, 0);

    final menuHeight = HoverSelectionMenu.totalHeightForCount(_zoneOptions.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final left = origin.dx - (menuWidth / 2);
    final top = buttonOrigin.dy - menuHeight - 12;

    _hoverZoneIndex = _zoneOptions.indexWhere((z) => z.mode == _zoneMode);
    _zoneHoverNotifier.value = _hoverZoneIndex;

    _zoneMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(child: GestureDetector(onTap: _removeZoneMenu)),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: _zoneOptions
                  .map(
                    (option) => HoverMenuOption(
                      builder: (isHover) => Center(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            color: isHover ? AppTheme.primaryBlue : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              initialHover: _hoverZoneIndex,
              hoverNotifier: _zoneHoverNotifier,
              onHover: (i) => setState(() => _hoverZoneIndex = i),
              onSelect: (i) {
                setState(() {
                  _zoneMode = _zoneOptions[i].mode;
                  _currentTool = CourtEditorTool.zone;
                });
                _removeZoneMenu();
              },
              onDismiss: _removeZoneMenu,
              menuKey: _zoneMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_zoneMenuEntry!);
    _updateZoneMenuHover(globalPos ?? origin);
  }

  void _updateZoneMenuHover(Offset globalPos) {
    final box = _zoneMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_zoneOptions.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _zoneHoverNotifier.value = -1;
      setState(() => _hoverZoneIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _zoneOptions.length - 1);
    if (idx != _hoverZoneIndex) {
      _zoneHoverNotifier.value = idx;
      setState(() => _hoverZoneIndex = idx);
    }
  }

  void _removeZoneMenu() {
    _zoneMenuEntry?.remove();
    _zoneMenuEntry = null;
    _hoverZoneIndex = -1;
    _zoneHoverNotifier.value = -1;
  }

  void _finalizeZoneSelection() {
    if (_zoneMenuEntry == null) return;
    if (_hoverZoneIndex >= 0 && _hoverZoneIndex < _zoneOptions.length) {
      setState(() {
        _zoneMode = _zoneOptions[_hoverZoneIndex].mode;
        _currentTool = CourtEditorTool.zone;
      });
    }
    _removeZoneMenu();
  }

  Widget _buildColorPickerButton() {
    return Tooltip(
      message: 'Tool Color',
      child: FloatingActionButton.small(
        heroTag: 'tool-color-picker',
        backgroundColor: _currentColor,
        onPressed: _showColorPicker,
        child: const Icon(Icons.palette, color: Colors.black),
      ),
    );
  }

  Widget _buildNetIcon(Color color) {
    return CustomPaint(painter: _NetIconPainter(color), size: const Size(24, 24));
  }

  Widget _buildSmallCircleIcon(Color color) {
    return CustomPaint(
      painter: _CircleIconPainter(radius: 3, color: color),
      size: const Size(24, 24),
    );
  }

  Widget _buildMediumCircleIcon([Color color = Colors.white]) {
    return CustomPaint(
      painter: _CircleIconPainter(radius: 6, color: color),
      size: const Size(24, 24),
    );
  }

  Widget _buildZoneToggleButton() {
    String label;
    Widget icon;
    final zoneActive = _currentTool == CourtEditorTool.zone;
    switch (_zoneMode) {
      case ZoneMode.inner:
        label = 'Inner';
        icon = _buildSmallCircleIcon(_currentColor);
        break;
      case ZoneMode.serve:
        label = 'Serve';
        icon = _buildLargeCircleIcon(_currentColor);
        break;
      case ZoneMode.outer:
        label = 'Outer';
        icon = _buildLargeCircleIcon(_currentColor);
        break;
    }
    return Tooltip(
      message: 'Zone ($label)',
      child: GestureDetector(
        onSecondaryTapDown: (details) => _toggleZoneMenu(globalPos: details.globalPosition, forceOpen: true),
        onLongPressStart: (details) => _toggleZoneMenu(globalPos: details.globalPosition, forceOpen: true),
        onLongPressMoveUpdate: (details) => _updateZoneMenuHover(details.globalPosition),
        onLongPressEnd: (details) {
          _updateZoneMenuHover(details.globalPosition);
          _finalizeZoneSelection();
        },
        child: FloatingActionButton.small(
          key: _zoneButtonKey,
          heroTag: 'tool-zone',
          backgroundColor: zoneActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
          onPressed: () {
            _currentTool = CourtEditorTool.zone;
            _toggleZoneMenu(forceOpen: true);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: zoneActive ? _currentColor : Colors.white),
                child: icon,
              ),
              Text(label, style: TextStyle(fontSize: 9, color: zoneActive ? _currentColor : Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeCircleIcon([Color color = Colors.white]) {
    return CustomPaint(
      painter: _CircleIconPainter(radius: 10, color: color),
      size: const Size(24, 24),
    );
  }

  void _onPanDown(DragDownDetails details) {
    final localPos = details.localPosition;
    final localPosCm = _screenToCm(localPos, _screenSize);
    _startPos = localPosCm;
    _currentPos = localPosCm;
    _previewElement = null;

    if (_currentTool == CourtEditorTool.select) {
      _selectedElement = null;
      for (final element in _elements.reversed) {
        if (_isPointNearElement(localPosCm, element)) {
          _selectedElement = element;
          _draggingElement = element;
          _currentColor = element.color;
          // Store offset from touch point to element position for smooth dragging
          _dragOffset = element.position - localPosCm;
          if (element.endPosition != null) {
            _dragEndOffset = element.endPosition! - localPosCm;
          }
          // Save pre-change snapshot once at drag start
          _saveToHistory();
          break;
        }
      }
    } else if (_currentTool == CourtEditorTool.eraser) {
      // Save pre-change snapshot once at erase start
      _saveToHistory();
      _eraseAtPosition(localPosCm);
    } else {
      // Show live preview for all creation tools (circle, zone, line, rectangle, net)
      _previewElement = _createElementFromTool(_currentTool, localPosCm, localPosCm, preview: true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final localPosCm = _screenToCm(localPos, _screenSize);

    setState(() {
      _currentPos = localPosCm;

      if (_currentTool == CourtEditorTool.select && _draggingElement != null) {
        // Apply drag offset to maintain shape
        var newPos = localPosCm + (_dragOffset ?? Offset.zero);
        var newEnd = _draggingElement!.endPosition != null && _dragEndOffset != null
            ? localPosCm + _dragEndOffset!
            : _draggingElement!.endPosition;

        final snapped = _applySnap(newPos, newEnd, _draggingElement!);
        _draggingElement!
          ..position = snapped.key
          ..endPosition = snapped.value;
        // Bump revision so background repaints while dragging
        _elementsRevision++;
      } else if (_currentTool == CourtEditorTool.eraser) {
        _eraseAtPosition(localPosCm);
        // Bump revision so background repaints while erasing
        _elementsRevision++;
      } else {
        // Show live preview for all creation tools while dragging
        _previewElement = _createElementFromTool(_currentTool, _startPos ?? localPosCm, localPosCm, preview: true);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_startPos == null || _currentPos == null) return;

    final tool = _currentTool;
    final start = _startPos!;
    final end = _currentPos!;

    if (tool == CourtEditorTool.select) {
      // History was saved at drag start; do not save again to avoid duplicates
      _draggingElement = null;
      _dragOffset = null;
      _dragEndOffset = null;
      return;
    }

    if (tool == CourtEditorTool.eraser) {
      // History was saved at erase start; do not save again here
      _draggingElement = null;
      _dragOffset = null;
      _dragEndOffset = null;
      return;
    }

    // Create new element based on tool
    final element = _createElementFromTool(tool, start, end);
    if (element != null) {
      // Save pre-change snapshot before committing element
      _saveToHistory();
      setState(() => _elements.add(element));
      _elementsRevision++;
    }

    _startPos = null;
    _currentPos = null;
    _previewElement = null;
  }

  void _eraseAtPosition(Offset pos) {
    final eraserRadiusCm = _eraserRadius;
    bool intersects(CourtElement e) {
      if (e.type == CourtElementType.customLine && e.endPosition != null) {
        final d = _distanceToLineSegment(pos, e.position, e.endPosition!);
        return d <= eraserRadiusCm;
      }
      if (e.type == CourtElementType.customRectangle && e.endPosition != null) {
        final a = e.position;
        final b = e.endPosition!;
        final topLeft = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
        final bottomRight = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
        final tl = topLeft;
        final tr = Offset(bottomRight.dx, topLeft.dy);
        final bl = Offset(topLeft.dx, bottomRight.dy);
        final br = bottomRight;
        final ds = [
          _distanceToLineSegment(pos, tl, tr),
          _distanceToLineSegment(pos, tr, br),
          _distanceToLineSegment(pos, br, bl),
          _distanceToLineSegment(pos, bl, tl),
        ];
        final minD = ds.reduce(math.min);
        // Only delete if hitting outline, not interior
        return minD <= eraserRadiusCm;
      }
      // For circles/zones: remove when the eraser circle overlaps the element area
      final radius = e.radius ?? 0;
      if (radius > 0) {
        final dist = (e.position - pos).distance;
        return dist <= radius + eraserRadiusCm;
      }
      // Fallback to point distance (e.g., net end with no radius)
      return (e.position - pos).distance <= eraserRadiusCm;
    }

    _elements.removeWhere(intersects);
  }

  double _distanceToLineSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final abDot = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abDot == 0) return ap.distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abDot).clamp(0.0, 1.0);
    final closest = a + Offset(ab.dx * t, ab.dy * t);
    return (p - closest).distance;
  }

  MapEntry<Offset, Offset?> _applySnap(Offset pos, Offset? end, CourtElement dragged) {
    const double thresholdCm = 20.0; // 20cm snap threshold for cm-based coordinates
    final anchors = _anchorPointsForDragged(dragged, pos, end);
    final candidates = _snapPointsFromOtherElements(dragged);

    double bestDist = thresholdCm;
    Offset bestDelta = Offset.zero;

    for (final anchor in anchors) {
      for (final target in candidates) {
        final d = (target - anchor).distance;
        if (d < bestDist) {
          bestDist = d;
          bestDelta = target - anchor;
        }
      }
    }

    if (bestDist < thresholdCm) {
      pos += bestDelta;
      end = end != null ? end + bestDelta : end;
    }

    return MapEntry(pos, end);
  }

  List<Offset> _anchorPointsForDragged(CourtElement element, Offset pos, Offset? end) {
    final anchors = <Offset>[pos];

    if (end != null) {
      anchors.add(end);
      anchors.add((pos + end) / 2);

      if (element.type == CourtElementType.customRectangle) {
        final tl = Offset(math.min(pos.dx, end.dx), math.min(pos.dy, end.dy));
        final tr = Offset(math.max(pos.dx, end.dx), math.min(pos.dy, end.dy));
        final bl = Offset(math.min(pos.dx, end.dx), math.max(pos.dy, end.dy));
        final br = Offset(math.max(pos.dx, end.dx), math.max(pos.dy, end.dy));
        anchors.addAll([tl, tr, bl, br]);
      }
    }

    return anchors;
  }

  List<Offset> _snapPointsFromOtherElements(CourtElement dragged) {
    final points = <Offset>[];

    for (final e in _elements) {
      if (identical(e, dragged)) continue;

      points.add(e.position);
      if (e.endPosition != null) {
        final end = e.endPosition!;
        points
          ..add(end)
          ..add((e.position + end) / 2);

        if (e.type == CourtElementType.customRectangle) {
          final tl = Offset(math.min(e.position.dx, end.dx), math.min(e.position.dy, end.dy));
          final tr = Offset(math.max(e.position.dx, end.dx), math.min(e.position.dy, end.dy));
          final bl = Offset(math.min(e.position.dx, end.dx), math.max(e.position.dy, end.dy));
          final br = Offset(math.max(e.position.dx, end.dx), math.max(e.position.dy, end.dy));
          points.addAll([tl, tr, bl, br]);
        }
      }
    }

    return points;
  }

  CourtElement? _createElementFromTool(CourtEditorTool tool, Offset start, Offset end, {bool preview = false}) {
    final position = end; // Use finger-up position so tap or drag works the same.
    switch (tool) {
      case CourtEditorTool.net:
        return CourtElement(
          type: CourtElementType.net,
          position: position,
          radius: _settings.netCircleRadiusCm,
          color: _currentColor,
          strokeWidth: 2.0,
        );
      case CourtEditorTool.zone:
        final radius = _zoneMode == ZoneMode.inner
            ? _settings.innerCircleRadiusCm
            : _zoneMode == ZoneMode.serve
            ? _settings.outerCircleRadiusCm
            : _settings.outerBoundsRadiusCm;
        final type = _zoneMode == ZoneMode.inner
            ? CourtElementType.innerCircle
            : _zoneMode == ZoneMode.serve
            ? CourtElementType.outerCircle
            : CourtElementType.outerCircle;
        return CourtElement(type: type, position: position, radius: radius, color: _currentColor, strokeWidth: 2.0);
      case CourtEditorTool.customCircle:
        final radius = (end - start).distance;
        const defaultRadius = 30.0; // 30cm default radius as per ToDo list
        final targetRadius = radius > defaultRadius * 0.2 ? radius : defaultRadius;
        return CourtElement(
          type: CourtElementType.customCircle,
          position: start,
          radius: targetRadius,
          color: _currentColor,
          strokeWidth: _elementStrokeWidth,
        );
      case CourtEditorTool.customLine:
        return CourtElement(
          type: CourtElementType.customLine,
          position: start,
          endPosition: end,
          color: _currentColor,
          strokeWidth: _elementStrokeWidth,
        );
      case CourtEditorTool.customRectangle:
        return CourtElement(
          type: CourtElementType.customRectangle,
          position: start,
          endPosition: end,
          color: _currentColor,
          strokeWidth: _elementStrokeWidth,
        );
      default:
        return null;
    }
  }

  bool _isPointNearElement(Offset point, CourtElement element) {
    const threshold = 20.0; // 20cm threshold for cm-based coordinates

    // NET elements: draggable from anywhere within the widest circle
    if (element.type == CourtElementType.net) {
      final radius = element.radius ?? 0;
      final distFromCenter = (element.position - point).distance;
      // Allow dragging within the widest outer circle (outerBoundsRadius)
      // The net has multiple circles, the widest is at radius + net stroke extension
      final outerBoundsRadius = radius + 10; // approximate outer bound
      return distFromCenter <= outerBoundsRadius;
    }

    // Check center point
    final dist = (element.position - point).distance;
    if (dist < threshold) return true;

    // For shapes with end position (lines, rectangles)
    if (element.endPosition != null) {
      final endDist = (element.endPosition! - point).distance;
      if (endDist < threshold) return true;

      // For rectangles, check all four edges
      if (element.type == CourtElementType.customRectangle) {
        final a = element.position;
        final b = element.endPosition!;
        final tl = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
        final tr = Offset(math.max(a.dx, b.dx), math.min(a.dy, b.dy));
        final bl = Offset(math.min(a.dx, b.dx), math.max(a.dy, b.dy));
        final br = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));

        final edges = [
          _distanceToLineSegment(point, tl, tr),
          _distanceToLineSegment(point, tr, br),
          _distanceToLineSegment(point, br, bl),
          _distanceToLineSegment(point, bl, tl),
        ];
        return edges.any((d) => d < threshold);
      }

      // For lines, check distance to line segment
      if (element.type == CourtElementType.customLine) {
        return _distanceToLineSegment(point, element.position, element.endPosition!) < threshold;
      }
    }

    // For circles/zones, check if point is on outline (NOT anywhere within)
    final radius = element.radius ?? 0;
    if (radius > 0) {
      final distFromCenter = (element.position - point).distance;
      final distFromOutline = (distFromCenter - radius).abs();
      // Only draggable by the border, not the center area
      return distFromOutline < threshold;
    }

    return false;
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Elements?'),
        content: const Text('This will remove all court elements.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() {
                _elements.clear();
                _previewElement = null;
              });
              // Also clear and save the project state
              widget.project.customCourtElements = [];
              widget.project.save();
              // Save to history after clearing all elements
              _saveToHistory();
              _elementsRevision++;
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _saveAndClose() {
    widget.project.customCourtElements = _elements;
    widget.project.save();
    Navigator.pop(context);
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Tool Color'),
        content: SizedBox(
          width: 280,
          height: 200,
          child: GridView.count(
            crossAxisCount: 4,
            children:
                [
                  Colors.white,
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.orange,
                  Colors.purple,
                  Colors.pink,
                  Colors.cyan,
                  Colors.teal,
                  Colors.lime,
                  Colors.indigo,
                  Colors.brown,
                ].map((color) {
                  final isActive = _currentColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentColor = color;
                        if (_draggingElement != null) {
                          _draggingElement!.color = color;
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: isActive ? AppTheme.darkGrey : Colors.white, width: isActive ? 3 : 1),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  /// Save the current editor state to the undo stack and clear the redo stack
  void _saveToHistory() {
    // Avoid pushing duplicate snapshot equal to the current state
    if (_undoStack.isNotEmpty && _isSameAsSnapshot(_undoStack.last)) {
      return;
    }
    _undoStack.add(
      _EditorSnapshot(
        elements: _elements.map((e) => e.copy()).toList(),
        currentColor: _currentColor,
        zoneMode: _zoneMode,
      ),
    );
    _redoStack.clear();

    // Limit undo history to 50 snapshots to prevent memory issues
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
  }

  bool _isSameAsSnapshot(_EditorSnapshot snap) {
    if (snap.elements.length != _elements.length) return false;
    for (int i = 0; i < _elements.length; i++) {
      final a = _elements[i];
      final b = snap.elements[i];
      if (a.type != b.type) return false;
      if (a.position != b.position) return false;
      if (a.endPosition != b.endPosition) return false;
      if ((a.radius ?? 0) != (b.radius ?? 0)) return false;
      if (a.color.toARGB32() != b.color.toARGB32()) return false;
      if (a.strokeWidth != b.strokeWidth) return false;
    }
    if (snap.currentColor.toARGB32() != _currentColor.toARGB32()) return false;
    if (snap.zoneMode != _zoneMode) return false;
    return true;
  }

  /// Restore the editor to the previous state
  void _undo() {
    if (_undoStack.isEmpty) return;

    // Save current state to redo stack before undoing
    _redoStack.add(
      _EditorSnapshot(
        elements: _elements.map((e) => e.copy()).toList(),
        currentColor: _currentColor,
        zoneMode: _zoneMode,
      ),
    );

    // Pop the previous state and restore it
    final snapshot = _undoStack.removeLast();
    setState(() {
      _elements = snapshot.elements.map((e) => e.copy()).toList();
      _currentColor = snapshot.currentColor;
      _zoneMode = snapshot.zoneMode;
      _previewElement = null;
      _draggingElement = null;
      _selectedElement = null;
      _elementsRevision++;
    });
  }

  /// Restore the editor to the next state (redo)
  void _redo() {
    if (_redoStack.isEmpty) return;

    // Save current state to undo stack before redoing
    _undoStack.add(
      _EditorSnapshot(
        elements: _elements.map((e) => e.copy()).toList(),
        currentColor: _currentColor,
        zoneMode: _zoneMode,
      ),
    );

    // Pop the next state and restore it
    final snapshot = _redoStack.removeLast();
    setState(() {
      _elements = snapshot.elements.map((e) => e.copy()).toList();
      _currentColor = snapshot.currentColor;
      _zoneMode = snapshot.zoneMode;
      _previewElement = null;
      _draggingElement = null;
      _selectedElement = null;
      _elementsRevision++;
    });
  }

  void _duplicateSelected() {
    if (_selectedElement == null) return;
    final original = _selectedElement!;
    final copy = original.copy();
    const Offset delta = Offset(20, 20);
    copy
      ..position = original.position + delta
      ..endPosition = original.endPosition != null ? original.endPosition! + delta : null;

    _saveToHistory();
    setState(() {
      _elements.add(copy);
      _selectedElement = copy;
      _elementsRevision++;
    });
  }
}

class _NetIconPainter extends CustomPainter {
  final Color color;
  _NetIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 6.0;

    // Draw circle
    canvas.drawCircle(center, radius, paint);

    // Draw hash pattern
    for (double angle = 0; angle < 360; angle += 45) {
      final radians = angle * math.pi / 180;
      final x = radius * 0.7 * math.cos(radians);
      final y = radius * 0.7 * math.sin(radians);
      canvas.drawLine(Offset(center.dx - x, center.dy - y), Offset(center.dx + x, center.dy + y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleIconPainter extends CustomPainter {
  final double radius;
  final Color color;

  _CircleIconPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_CircleIconPainter oldDelegate) => oldDelegate.radius != radius || oldDelegate.color != color;
}

/// Painter for center screen transparent cross (20cm x 20cm)
class _CenterCrossPainter extends CustomPainter {
  final Size boardSize;
  final Settings settings;

  _CenterCrossPainter({required this.boardSize, required this.settings});

  @override
  void paint(Canvas canvas, Size size) {
    // Board center in screen coordinates
    final boardCenter = Offset(boardSize.width / 2, boardSize.height / 2);

    // Cross dimensions: 20cm x 20cm (10cm in each direction from center)
    final halfLengthPx = settings.cmToLogical(10, boardSize).abs();

    // Create paint for the cross (very transparent white)
    final crossPaint = Paint()
      ..color = Colors.white
          .withValues(alpha: 0.15) // Very transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw horizontal line
    canvas.drawLine(
      Offset(boardCenter.dx - halfLengthPx, boardCenter.dy),
      Offset(boardCenter.dx + halfLengthPx, boardCenter.dy),
      crossPaint,
    );

    // Draw vertical line
    canvas.drawLine(
      Offset(boardCenter.dx, boardCenter.dy - halfLengthPx),
      Offset(boardCenter.dx, boardCenter.dy + halfLengthPx),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CenterCrossPainter oldDelegate) =>
      oldDelegate.boardSize != boardSize || oldDelegate.settings != settings;
}
