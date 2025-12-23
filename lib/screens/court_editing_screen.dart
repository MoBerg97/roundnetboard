import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../config/app_theme.dart';
import '../models/animation_project.dart';
import '../models/court_element.dart';
import '../models/settings.dart';
import '../widgets/board_background_painter.dart';
import '../widgets/court_editor_painter.dart';

enum CourtEditorTool {
  select,
  net,
  zone,
  customCircle,
  customLine,
  customRectangle,
  eraser,
}

enum ZoneMode { inner, serve, outer }

class CourtEditingScreen extends StatefulWidget {
  final AnimationProject project;

  const CourtEditingScreen({
    super.key,
    required this.project,
  });

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
  double _eraserRadius = 30.0;
  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'court_editor_canvas');
  Color _currentColor = Colors.white;
  ZoneMode _zoneMode = ZoneMode.inner;
  CourtElement? _previewElement;

  @override
  void initState() {
    super.initState();
    _currentTool = CourtEditorTool.select;
    _elements = List.from(widget.project.customCourtElements ?? []);
    _settings = widget.project.settings ?? Settings();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Mirror BoardScreen canvas proportions so custom elements align 1:1 with playback view.
    const timelineHeight = 140.0;
    final boardHeight = math.max(320.0, screenSize.height - kToolbarHeight - timelineHeight);
    final boardSize = Size(screenSize.width, boardHeight);
    Settings.setScreenSize(screenSize);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Court'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saveAndClose,
          ),
        ],
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
                              screenSize: screenSize,
                              settings: _settings,
                              customElements: null,
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: CustomPaint(
                            size: boardSize,
                            painter: CourtEditorPainter(
                              elements: _elements,
                              eraserPos: _currentTool == CourtEditorTool.eraser ? _currentPos : null,
                              eraserRadius: _eraserRadius,
                              screenSize: screenSize,
                              previewElement: _previewElement,
                            ),
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
                  _buildToolButton(
                    CourtEditorTool.select,
                    Icons.pan_tool_alt,
                    'Select',
                  ),
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
                  _buildToolButton(
                    CourtEditorTool.customLine,
                    Symbols.diagonal_line,
                    'Line',
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    CourtEditorTool.customRectangle,
                    Icons.crop_square,
                    'Rect',
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    CourtEditorTool.eraser,
                    Symbols.ink_eraser,
                    'Eraser',
                  ),
                  const SizedBox(width: 8),
                  _buildColorPickerButton(),
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
    final iconWidget = icon is IconData ? Icon(icon) : icon;

    return Tooltip(
      message: label,
      child: FloatingActionButton.small(
        backgroundColor: isActive ? _currentColor : AppTheme.mediumGrey,
        onPressed: () => setState(() => _currentTool = tool),
        child: IconTheme(
          data: IconThemeData(color: isActive ? Colors.black : Colors.white),
          child: iconWidget,
        ),
      ),
    );
  }

  Widget _buildColorPickerButton() {
    return Tooltip(
      message: 'Tool Color',
      child: FloatingActionButton.small(
        backgroundColor: _currentColor,
        onPressed: _showColorPicker,
        child: const Icon(Icons.palette, color: Colors.black),
      ),
    );
  }

  Widget _buildNetIcon(Color color) {
    return CustomPaint(
      painter: _NetIconPainter(color),
      size: const Size(24, 24),
    );
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
        icon = _buildSmallCircleIcon(zoneActive ? _currentColor : Colors.white);
        break;
      case ZoneMode.serve:
        label = 'Serve';
        icon = _buildLargeCircleIcon(zoneActive ? _currentColor : Colors.white);
        break;
      case ZoneMode.outer:
        label = 'Outer';
        icon = _buildLargeCircleIcon(zoneActive ? _currentColor : Colors.white);
        break;
    }
    return Tooltip(
      message: 'Zone ($label)',
      child: FloatingActionButton.small(
        backgroundColor: zoneActive ? _currentColor : AppTheme.mediumGrey,
        onPressed: () => setState(() {
          _currentTool = CourtEditorTool.zone;
          // Cycle mode on repeated taps
          if (_zoneMode == ZoneMode.inner) {
            _zoneMode = ZoneMode.serve;
          } else if (_zoneMode == ZoneMode.serve) {
            _zoneMode = ZoneMode.outer;
          } else {
            _zoneMode = ZoneMode.inner;
          }
        }),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(color: zoneActive ? Colors.black : Colors.white),
              child: icon,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: zoneActive ? Colors.black : Colors.white,
              ),
            ),
          ],
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
    _startPos = localPos;
    _currentPos = localPos;
    _previewElement = null;

    if (_currentTool == CourtEditorTool.select) {
      for (final element in _elements.reversed) {
        if (_isPointNearElement(localPos, element)) {
          _draggingElement = element;
          _currentColor = element.color;
          break;
        }
      }
    } else if (_currentTool == CourtEditorTool.eraser) {
      _eraseAtPosition(localPos);
    } else if (_currentTool == CourtEditorTool.customCircle || _currentTool == CourtEditorTool.zone) {
      _previewElement = _createElementFromTool(_currentTool, localPos, localPos, preview: true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);

    setState(() {
      _currentPos = localPos;

      if (_currentTool == CourtEditorTool.select && _draggingElement != null) {
        _draggingElement!.position = localPos;
      } else if (_currentTool == CourtEditorTool.eraser) {
        _eraseAtPosition(localPos);
      } else if (_currentTool == CourtEditorTool.customCircle || _currentTool == CourtEditorTool.zone) {
        _previewElement = _createElementFromTool(_currentTool, _startPos ?? localPos, localPos, preview: true);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_startPos == null || _currentPos == null) return;

    final tool = _currentTool;
    final start = _startPos!;
    final end = _currentPos!;
    
    if (tool == CourtEditorTool.select) {
      _draggingElement = null;
      return;
    }

    if (tool == CourtEditorTool.eraser) {
      _draggingElement = null;
      return;
    }

    // Create new element based on tool
    final element = _createElementFromTool(tool, start, end);
    if (element != null) {
      setState(() => _elements.add(element));
    }

    _startPos = null;
    _currentPos = null;
    _previewElement = null;
  }

  void _eraseAtPosition(Offset pos) {
    bool intersects(CourtElement e) {
      if (e.type == CourtElementType.customLine && e.endPosition != null) {
        final d = _distanceToLineSegment(pos, e.position, e.endPosition!);
        return d <= _eraserRadius;
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
        final inside = pos.dx >= tl.dx && pos.dx <= br.dx && pos.dy >= tl.dy && pos.dy <= br.dy;
        return inside || minD <= _eraserRadius;
      }
      final radius = e.radius ?? 0;
      final dist = (e.position - pos).distance;
      if (radius > 0) {
        return dist <= radius + _eraserRadius;
      }
      // Fallback to point distance (e.g., net end with no radius)
      return dist <= _eraserRadius;
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

  CourtElement? _createElementFromTool(
    CourtEditorTool tool,
    Offset start,
    Offset end, {
    bool preview = false,
  }) {
    final position = end; // Use finger-up position so tap or drag works the same.
    switch (tool) {
      case CourtEditorTool.net:
        return CourtElement(
          type: CourtElementType.net,
          position: position,
          radius: _settings.netCircleRadiusPx,
          color: _currentColor,
          strokeWidth: 2.0,
        );
      case CourtEditorTool.zone:
        final radius = _zoneMode == ZoneMode.inner
            ? _settings.innerCircleRadiusPx
            : _zoneMode == ZoneMode.serve
                ? _settings.outerCircleRadiusPx
                : _settings.outerBoundsRadiusPx;
        final type = _zoneMode == ZoneMode.inner
            ? CourtElementType.innerCircle
            : _zoneMode == ZoneMode.serve
                ? CourtElementType.outerCircle
                : CourtElementType.outerCircle;
        return CourtElement(
          type: type,
          position: position,
          radius: radius,
          color: _currentColor,
          strokeWidth: 2.0,
        );
      case CourtEditorTool.customCircle:
        final radius = (end - start).distance;
        return CourtElement(
          type: CourtElementType.customCircle,
          position: start,
          radius: radius > 4 ? radius : _settings.innerCircleRadiusPx,
          color: _currentColor,
          strokeWidth: 2.0,
        );
      case CourtEditorTool.customLine:
        return CourtElement(
          type: CourtElementType.customLine,
          position: start,
          endPosition: end,
          color: _currentColor,
          strokeWidth: 2.0,
        );
      case CourtEditorTool.customRectangle:
        return CourtElement(
          type: CourtElementType.customRectangle,
          position: start,
          endPosition: end,
          color: _currentColor,
          strokeWidth: 2.0,
        );
      default:
        return null;
    }
  }

  bool _isPointNearElement(Offset point, CourtElement element) {
    const threshold = 15.0;
    final dist = (element.position - point).distance;
    if (dist < threshold) return true;

    if (element.endPosition != null) {
      final endDist = (element.endPosition! - point).distance;
      if (endDist < threshold) return true;
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
              setState(() => _elements.clear());
              _previewElement = null;
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
            children: [
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
              final isActive = _currentColor.value == color.value;
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
                    border: Border.all(
                      color: isActive ? AppTheme.darkGrey : Colors.white,
                      width: isActive ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
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
      canvas.drawLine(
        Offset(center.dx - x, center.dy - y),
        Offset(center.dx + x, center.dy + y),
        paint,
      );
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
  bool shouldRepaint(_CircleIconPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}
