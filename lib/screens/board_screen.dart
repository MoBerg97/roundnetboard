import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/animation_project.dart';
import '../models/frame.dart';
import '../models/player.dart';
import '../models/ball.dart';
import '../models/court_element.dart';
import '../widgets/path_painter.dart';
import '../widgets/board_background_painter.dart';
import '../models/annotation.dart';
import '../widgets/annotation_painter.dart';
import '../models/settings.dart';
import '../utils/path_engine.dart';
import '../services/tutorial_service.dart';
import 'settings_screen.dart';
import 'court_editing_screen.dart';
import '../utils/history.dart';
import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../widgets/hover_selection_menu.dart';

// ════════════════════════════════════════════════════════════════════════════
// BOARD SCREEN - Main Animation Editor
// ════════════════════════════════════════════════════════════════════════════
// This screen contains:
// - Interactive board for positioning players and ball
// - Timeline with frame thumbnails
// - Playback controls with speed adjustment
// - Annotation tools (lines, circles, eraser)
// - Ball modifiers (set, hit markers)
// - Path control points for curved movement
// ════════════════════════════════════════════════════════════════════════════

class BoardScreen extends StatefulWidget {
  final AnimationProject project;
  final void Function(Map<String, GlobalKey>)? onProvideTutorialKeys;
  final TutorialService? tutorialService;
  final Map<String, GlobalKey>? tutorialKeys;

  const BoardScreen({
    super.key,
    required this.project,
    this.onProvideTutorialKeys,
    this.tutorialService,
    this.tutorialKeys,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

// ────────────────────────────────────────────────────────────────────────────
// ANNOTATION TOOLS ENUM
// ────────────────────────────────────────────────────────────────────────────
// Available drawing tools for annotations on the board
enum AnnotationTool { none, move, line, freehand, marker, circle, rectangle, sector, text }

enum BoardMenu { none, objects, annotations }

enum ColorChangeScope { onlyThisFrame, fromThisFrameToEnd }

enum _SectorAttachmentType { zone, ball, player }

enum _PlaybackAnnotationStopAction { save, discard, cancel }

class _AnnotationTextDialogResult {
  final String text;
  final double size;
  const _AnnotationTextDialogResult(this.text, this.size);
}

class _BoardScreenState extends State<BoardScreen> with TickerProviderStateMixin {
  // ──────────────────────────────────────────────────────────────────────────
  // STATE VARIABLES
  // ──────────────────────────────────────────────────────────────────────────

  // Current frame being edited
  late Frame currentFrame;

  // Project settings (court dimensions, visual preferences)
  late Settings _settings;

  // Settings revision counter to force repaint when settings change
  int _settingsRevision = 0;
  // Path revision counter to force repaint when path control points change
  int _pathRevision = 0;

  // Undo/redo history manager
  late HistoryManager _history;

  // ──────────────────────────────────────────────────────────────────────────
  // PLAYBACK STATE
  // ──────────────────────────────────────────────────────────────────────────
  bool _isPlaying = false; // Is animation currently playing?
  bool _isPaused = false; // Is playback paused?
  bool _endedAtLastFrame = false; // Did playback reach the end?
  bool _scrubberMovedManually = false; // Did user drag the scrubber?
  late Ticker _ticker; // Frame ticker for smooth animation
  double _playbackT = 0.0; // Interpolation value (0.0 to 1.0) between frames
  double _playbackSpeed = 1.0; // Playback speed multiplier (0.1x to 2.0x)
  int _playbackFrameIndex = 0; // Current frame index during playback
  bool _playbackZoomLockedByUser = false;
  double? _playbackManualZoomFactor;
  double _activeRenderZoomFactor = 1.0;
  late AnimationController _selectionPulseController; // Shared pulse for sonar highlights
  late AnimationController _snapPulseController;
  Offset? _lastSnapPointCm;

  // ──────────────────────────────────────────────────────────────────────────
  // BALL MODIFIER STATE
  // ──────────────────────────────────────────────────────────────────────────
  String? _pendingBallMark; // 'hit' or 'set' when placing ball modifier
  bool _showModifierMenu = false; // Show ball modifier menu (set/hit/clear)?

  // ──────────────────────────────────────────────────────────────────────────
  // PLAYER MODIFIER STATE
  // ──────────────────────────────────────────────────────────────────────────
  bool _showPlayerMenu = false; // Show player modifier menu (color/delete)?
  String? _activePlayerId; // Which player ID is currently selected for modifier menu

  // ──────────────────────────────────────────────────────────────────────────
  // ANNOTATION STATE
  // ──────────────────────────────────────────────────────────────────────────
  BoardMenu _activeMenu = BoardMenu.objects;
  AnnotationTool _activeAnnotationTool = AnnotationTool.none; // Current drawing tool
  bool _eraserMode = false; // Is eraser active?
  Offset? _eraserPosCm; // Current eraser position in cm coordinates
  double _annotationEraserRadiusCm = 20; // Eraser radius in cm (40cm diameter)
  final List<double> _annotationEraserSizes = const [10.0, 20.0, 30.0];
  OverlayEntry? _annotationEraserMenuEntry;
  int _annotationHoverEraserIndex = -1;
  final GlobalKey _annotationEraserButtonKey = GlobalKey(debugLabel: 'annotation_eraser_button');
  final GlobalKey _annotationEraserMenuKey = GlobalKey(debugLabel: 'annotation_eraser_menu');
  final ValueNotifier<int> _annotationEraserHoverNotifier = ValueNotifier<int>(-1);
  final List<Offset> _pendingAnnotationPoints = []; // Points being drawn (not committed)
  Color _annotationColor = AppTheme.editorColors[7]; // Current annotation color
  final List<double> _annotationStrokeOptionsCm = const [5.0, 10.0, 15.0];
  double _annotationStrokeCm = AppConstants.annotationStrokeWidthCm;
  AnnotationLineStyle _annotationLineStyle = AnnotationLineStyle.straight;
  AnnotationLineStyle _freehandLineStyle = AnnotationLineStyle.straight;
  AnnotationLineStyle _annotationMarkerStyle = AnnotationLineStyle.markerX;
  OverlayEntry? _annotationStrokeMenuEntry;
  OverlayEntry? _annotationLineStyleMenuEntry;
  OverlayEntry? _freehandLineStyleMenuEntry;
  OverlayEntry? _annotationMarkerStyleMenuEntry;
  int _annotationStrokeHoverIndex = -1;
  int _annotationLineStyleHoverIndex = -1;
  int _freehandLineStyleHoverIndex = -1;
  int _annotationMarkerStyleHoverIndex = -1;
  final GlobalKey _annotationStrokeButtonKey = GlobalKey(debugLabel: 'annotation_stroke_button');
  final GlobalKey _annotationLineStyleButtonKey = GlobalKey(debugLabel: 'annotation_line_style_button');
  final GlobalKey _freehandLineStyleButtonKey = GlobalKey(debugLabel: 'annotation_freehand_line_style_button');
  final GlobalKey _annotationStrokeMenuKey = GlobalKey(debugLabel: 'annotation_stroke_menu');
  final GlobalKey _annotationLineStyleMenuKey = GlobalKey(debugLabel: 'annotation_line_style_menu');
  final GlobalKey _freehandLineStyleMenuKey = GlobalKey(debugLabel: 'annotation_freehand_line_style_menu');
  final GlobalKey _annotationMarkerStyleButtonKey = GlobalKey(debugLabel: 'annotation_marker_style_button');
  final GlobalKey _annotationMarkerStyleMenuKey = GlobalKey(debugLabel: 'annotation_marker_style_menu');
  final ValueNotifier<int> _annotationStrokeHoverNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<int> _annotationLineStyleHoverNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<int> _freehandLineStyleHoverNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<int> _annotationMarkerStyleHoverNotifier = ValueNotifier<int>(-1);
  bool _annotationSnappingEnabled = true;
  bool _circleFilled = false;
  bool _rectangleFilled = false;
  OverlayEntry? _circleFillMenuEntry;
  OverlayEntry? _rectangleFillMenuEntry;
  int _circleFillHoverIndex = -1;
  int _rectangleFillHoverIndex = -1;
  final GlobalKey _circleFillButtonKey = GlobalKey(debugLabel: 'annotation_circle_fill_button');
  final GlobalKey _rectangleFillButtonKey = GlobalKey(debugLabel: 'annotation_rectangle_fill_button');
  final GlobalKey _circleFillMenuKey = GlobalKey(debugLabel: 'annotation_circle_fill_menu');
  final GlobalKey _rectangleFillMenuKey = GlobalKey(debugLabel: 'annotation_rectangle_fill_menu');
  final ValueNotifier<int> _circleFillHoverNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<int> _rectangleFillHoverNotifier = ValueNotifier<int>(-1);
  static const String _annotationTextFontFamily = 'Roboto';
  static const double _defaultAnnotationTextSize = 20.0;
  final List<double> _annotationTextSizeOptions = const [16.0, 24.0, 34.0];
  double _annotationTextSize = _defaultAnnotationTextSize;
  OverlayEntry? _annotationTextSizeMenuEntry;
  int _annotationTextSizeHoverIndex = -1;
  final GlobalKey _annotationTextButtonKey = GlobalKey(debugLabel: 'annotation_text_button');
  final GlobalKey _annotationTextSizeMenuKey = GlobalKey(debugLabel: 'annotation_text_size_menu');
  final ValueNotifier<int> _annotationTextSizeHoverNotifier = ValueNotifier<int>(-1);
  final List<Annotation> _stagedAnnotations = []; // Annotations staged for preview
  final List<Annotation> _erasingAnnotations = []; // Annotations being erased (preview)
  final Map<int, List<Annotation>> _playbackSessionAnnotationsByFrame =
      {}; // Temporary annotations keyed by frame index for the active playback session
  Offset? _currentDragPos; // Current drag position for live preview
  Annotation? _draggingAnnotation; // Annotation being moved/dragged
  Annotation? _selectedAnnotation; // Currently selected annotation for highlighting
  Offset? _annotationDragOffset; // Offset from touch point to annotation's start position for smooth dragging
  List<Annotation>? _annotationGestureStartSnapshot; // Snapshot used to persist undo/redo for annotation edits

  // ──────────────────────────────────────────────────────────────────────────
  // SECTOR TOOL STATE (Two-stage: select target, then draw sectors)
  // ──────────────────────────────────────────────────────────────────────────
  bool _sectorToolNeedsTargetSelection = false; // True when sector tool active but no target selected yet
  String? _selectedSectorTarget; // "innerCircle", "outerCircle", "outerBounds", or ball ID
  String? _selectedSectorAttachmentId;
  _SectorAttachmentType _sectorAttachmentType = _SectorAttachmentType.zone;
  Offset? _selectedSectorCenterCm; // Center point for sector reference (origin or ball position)
  double? _selectedSectorRadiusCm; // Radius for sector's reference circle (zone radius or 260cm for balls)
  bool _sectorTargetHighlightActive = false; // True when target selected and highlighting active
  OverlayEntry? _sectorAttachmentMenuEntry;
  int _sectorAttachmentHoverIndex = -1;
  final GlobalKey _sectorAttachmentButtonKey = GlobalKey(debugLabel: 'annotation_sector_attachment_button');
  final GlobalKey _sectorAttachmentMenuKey = GlobalKey(debugLabel: 'annotation_sector_attachment_menu');
  final ValueNotifier<int> _sectorAttachmentHoverNotifier = ValueNotifier<int>(-1);
  double? _sectorDragStartAngle; // Start angle captured on drag start
  double? _sectorDragPrevAngle; // Previous drag angle for delta accumulation
  double _sectorDragSweepAngle = 0.0; // Accumulated sweep angle following drag direction
  double? _sectorDragEndAngle; // End angle derived from drag sweep

  // ──────────────────────────────────────────────────────────────────────────
  // DRAG STATE (for moving objects and control points)
  // ──────────────────────────────────────────────────────────────────────────
  final Map<String, Offset> _dragStartLogical = {}; // Starting position in cm coordinates
  final Map<String, Offset> _dragStartScreen = {}; // Starting position in screen pixels
  String? _activePathDragId; // Which entity ID's path control is being dragged
  int? _activePathDragIndex; // Index of the control point being dragged (currently first only)
  final Map<String, List<Offset>> _pathDragStartPoints =
      {}; // Stores initial path points when drag starts for undo/redo

  // ──────────────────────────────────────────────────────────────────────────
  // TRAINING MODE STATE (for dynamic player/ball management)
  // ──────────────────────────────────────────────────────────────────────────
  Color? _lastTappedPlayerColor; // Last tapped player color (for new player color inheritance)
  String? _activeBallId; // Which ball ID is currently selected for modifier menu (training mode only)
  String? _addingObjectType; // Indicates "player" or "ball" when user is in place-object mode, null otherwise

  // ──────────────────────────────────────────────────────────────────────────
  // PATH TRACKING STATE (for showing full paths during playback)
  // ──────────────────────────────────────────────────────────────────────────
  final Set<String> _trackedEntityIds = {}; // Entity IDs with full path tracking enabled

  // ──────────────────────────────────────────────────────────────────────────
  // UI REFERENCES
  // ──────────────────────────────────────────────────────────────────────────
  final GlobalKey _boardKey = GlobalKey(debugLabel: 'board'); // Key for board RenderBox (coordinate conversion)
  final GlobalKey _timelineKey = GlobalKey(debugLabel: 'timeline'); // Key for timeline widget
  final GlobalKey _playButtonKey = GlobalKey(debugLabel: 'playback_play'); // Key for play button
  final GlobalKey _frameAddButtonKey = GlobalKey(debugLabel: 'timeline_add'); // Key for frame add button
  final GlobalKey _annotationModeButtonKey = GlobalKey(debugLabel: 'annotation_menu'); // Key for annotation mode toggle
  late final ScrollController _timelineController; // Scroll controller for timeline
  int? _deleteFrameButtonIndex; // Which frame index currently shows the delete button (double-tap toggle)

  static const double _objectsMenuHeight = 56.0;
  static const double _annotationMenuHeight = 108.0;
  static const double _timelineHeight = 140.0;
  static const double _menuButtonSize = 40.0;
  static const List<double> _zoomStageFactors = <double>[0.5, 1.0, 1.5, 2.2, 3.269230769230769];

  bool get _objectsMenuOpen => _activeMenu == BoardMenu.objects;
  bool get _annotationsMenuOpen => _activeMenu == BoardMenu.annotations;

  double _normalizeZoomFactor(double factor) {
    if (!factor.isFinite || factor <= 0) return 1.0;
    final min = _zoomStageFactors.first;
    final max = _zoomStageFactors.last;
    return factor.clamp(min, max);
  }

  double _frameZoomFactor(Frame frame) => _normalizeZoomFactor(frame.zoomStageFactor);

  int _nearestZoomStageIndex(double factor) {
    var bestIndex = 0;
    var bestDelta = double.infinity;
    for (var i = 0; i < _zoomStageFactors.length; i++) {
      final delta = (_zoomStageFactors[i] - factor).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  double _zoomFactorForStage(int stageIndex) {
    final clamped = stageIndex.clamp(0, _zoomStageFactors.length - 1);
    return _zoomStageFactors[clamped];
  }

  double _cmToLogical(double cm, Size size, {double? zoomFactor}) {
    return _settings.cmToLogical(cm, size, serveZoneFactorOverride: zoomFactor ?? _activeRenderZoomFactor);
  }

  double _autoPlaybackZoomFactor(Frame frame, Size viewportSize) {
    final playerRadius = AppConstants.playerRadiusCm * _settings.objectScaleMultiplier * 1.2;
    final ballRadius = AppConstants.ballRadiusCm * 1.2;
    double maxDistanceCm = 0.0;

    for (final p in frame.players) {
      maxDistanceCm = math.max(maxDistanceCm, p.position.distance + playerRadius);
    }
    for (final b in frame.balls) {
      maxDistanceCm = math.max(maxDistanceCm, b.position.distance + ballRadius);
    }
    for (final element in (widget.project.customCourtElements ?? const <CourtElement>[])) {
      final radius = element.radius ?? 0.0;
      maxDistanceCm = math.max(maxDistanceCm, element.position.distance + radius);
    }

    final baseRadius = _settings.outerCircleRadiusCm == 0 ? 1.0 : _settings.outerCircleRadiusCm;
    final margin = viewportSize.shortestSide < 520 ? 1.18 : 1.12;
    final requiredFactor = _normalizeZoomFactor((maxDistanceCm * margin) / baseRadius);
    for (final factor in _zoomStageFactors) {
      if (factor >= requiredFactor) return factor;
    }
    return _zoomStageFactors.last;
  }

  double _resolveRenderZoomFactor(Frame frameToShow, bool inPlaybackView, Size viewportSize) {
    if (inPlaybackView) {
      if (_playbackZoomLockedByUser && _playbackManualZoomFactor != null) {
        return _normalizeZoomFactor(_playbackManualZoomFactor!);
      }
      return _autoPlaybackZoomFactor(frameToShow, viewportSize);
    }
    return _frameZoomFactor(frameToShow);
  }

  void _setZoomStageFromSlider(double sliderValue, {required bool inPlaybackView}) {
    final stage = sliderValue.round().clamp(0, _zoomStageFactors.length - 1);
    final factor = _zoomFactorForStage(stage);
    if (inPlaybackView) {
      setState(() {
        _playbackZoomLockedByUser = true;
        _playbackManualZoomFactor = factor;
      });
      return;
    }

    setState(() {
      currentFrame.zoomStageFactor = factor;
      final idx = widget.project.frames.indexOf(currentFrame);
      if (idx >= 0) widget.project.frames[idx] = currentFrame;
    });
    _saveProject();
  }

  double _interactionTopInset() {
    if (_annotationsMenuOpen) return _annotationMenuHeight;
    if (_objectsMenuOpen) return _objectsMenuHeight;
    return 0.0;
  }

  Offset _clampToInteractionBounds(Offset screenPos, Size size) {
    final top = _interactionTopInset();
    final bottom = size.height;
    final clampedX = screenPos.dx.clamp(0.0, size.width);
    final clampedY = screenPos.dy.clamp(top, bottom);
    return Offset(clampedX, clampedY);
  }

  @override
  void initState() {
    super.initState();

    // Initialize settings
    if (widget.project.settings == null) {
      widget.project.settings = Settings();
      widget.project.save();
    }
    _settings = widget.project.settings!;
    _playbackSpeed = _settings.playbackSpeed;

    // Create default frame if project is empty
    if (widget.project.frames.isEmpty) {
      final r = _settings.outerCircleRadiusCm;

      final defaultFrame = widget.project.projectType == ProjectType.play
          ? Frame(
              players: [
                Player(position: Offset(0, -r), color: AppTheme.playerColors[0], id: 'P1'),
                Player(position: Offset(r, 0), color: AppTheme.playerColors[0], id: 'P2'),
                Player(position: Offset(0, r), color: AppTheme.playerColors[1], id: 'P3'),
                Player(position: Offset(-r, 0), color: AppTheme.playerColors[1], id: 'P4'),
              ],
              balls: [Ball(position: Offset.zero, color: AppTheme.ballColor, id: 'B1')],
            )
          : Frame(
              players: [
                Player(position: Offset(0, -r), color: AppTheme.playerColors[0]),
                Player(position: Offset(r, 0), color: AppTheme.playerColors[0]),
                Player(position: Offset(0, r), color: AppTheme.playerColors[1]),
                Player(position: Offset(-r, 0), color: AppTheme.playerColors[1]),
              ],
              balls: [Ball(position: Offset.zero, color: AppTheme.ballColor)],
            );
      widget.project.frames.add(defaultFrame);
      currentFrame = defaultFrame;
      _saveProject();
    } else {
      currentFrame = widget.project.frames.first;
    }

    _ticker = createTicker(_onTick);
    _selectionPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _snapPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _history = HistoryManager(widget.project);
    _timelineController = ScrollController();

    // Ensure object-specific menus are never pre-opened on screen entry.
    _closeObjectMenusAndSelection();
    if (widget.project.projectType == ProjectType.play) {
      _activeMenu = BoardMenu.none;
    }

    // Provide tutorial keys after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _provideTutorialKeys());
  }

  void _provideTutorialKeys() {
    if (!mounted) return;
    final keys = {
      'board_canvas': _boardKey,
      'timeline': _timelineKey,
      'play_button': _playButtonKey,
      'frame_add_button': _frameAddButtonKey,
      'annotation_button': _annotationModeButtonKey,
    };
    widget.onProvideTutorialKeys?.call(keys);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _selectionPulseController.dispose();
    _snapPulseController.dispose();
    _timelineController.dispose();
    _removeAnnotationEraserMenu();
    _removeAnnotationMarkerStyleMenu();
    _removeAnnotationLineStyleMenu();
    _removeFreehandLineStyleMenu();
    _removeAnnotationStrokeMenu();
    _removeAnnotationTextSizeMenu();
    _removeSectorAttachmentMenu();
    super.dispose();
  }

  void _saveProject() {
    widget.project.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TIMELINE SCROLLING HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Scroll timeline to center the currently selected frame (edit mode)
  void _scrollToSelectedFrame() {
    final index = widget.project.frames.indexOf(currentFrame);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_timelineController.hasClients) return;
      const itemExtent = 68.0; // 60 width + 2*4 margin
      final viewport = _timelineController.position.viewportDimension;
      final target = index * itemExtent - (viewport - itemExtent) / 2;
      final max = _timelineController.position.maxScrollExtent;
      final offset = target.clamp(0.0, max);
      _timelineController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    });
  }

  /// Scroll timeline to center the current playback frame
  void _scrollToPlaybackFrame() {
    final index = (_playbackFrameIndex).clamp(0, widget.project.frames.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_timelineController.hasClients) return;
      const itemExtent = 68.0; // 60 width + 2*4 margin
      final viewport = _timelineController.position.viewportDimension;
      final target = index * itemExtent - (viewport - itemExtent) / 2;
      final max = _timelineController.position.maxScrollExtent;
      final offset = target.clamp(0.0, max);
      _timelineController.animateTo(offset, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COORDINATE CONVERSION & SCREEN SIZE HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  // Converts between cm-based court coordinates and screen pixel coordinates
  // Uses Settings.cmToLogical() for adaptive scaling based on screen size

  /// Calculate the center point of the board within its own container.
  Offset _boardCenter(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    return Offset(cx, cy);
  }

  /// Convert cm logical position to screen pixel position
  /// Uses Settings.cmToLogical() to scale based on:
  /// - Screen size (adaptive: 1.1x serve zone on mobile, 1.5x on desktop)
  /// - Usable board area (accounting for AppBar ~56px, Timeline 120px)
  /// - Court reference radius (default 260cm outer circle)
  Offset _toScreenPosition(Offset cmPos, Size size) {
    final center = _boardCenter(size);
    return center + Offset(_cmToLogical(cmPos.dx, size), _cmToLogical(cmPos.dy, size));
  }

  bool _isPhone(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    return shortest < 600; // heuristic for handset
  }

  bool _shouldShowEraserOverlay(BuildContext context) {
    if (!_eraserMode || _eraserPosCm == null) return false;
    // Show eraser overlay on all platforms
    return true;
  }

  static const List<AnnotationLineStyle> _annotationLineStyleOptions = [
    AnnotationLineStyle.straight,
    AnnotationLineStyle.arrow,
    AnnotationLineStyle.arrowStart,
    AnnotationLineStyle.dashed,
  ];

  static const List<AnnotationLineStyle> _annotationMarkerStyleOptions = [
    AnnotationLineStyle.markerX,
    AnnotationLineStyle.markerPylon,
    AnnotationLineStyle.markerDot,
  ];

  static const List<_SectorAttachmentType> _sectorAttachmentOptions = [
    _SectorAttachmentType.zone,
    _SectorAttachmentType.ball,
    _SectorAttachmentType.player,
  ];

  static const double _objectAttachedSectorRadiusCm = 260.0;

  IconData _iconForLineStyle(AnnotationLineStyle style) {
    switch (style) {
      case AnnotationLineStyle.straight:
        return Icons.horizontal_rule;
      case AnnotationLineStyle.arrow:
        return Icons.trending_flat;
      case AnnotationLineStyle.arrowStart:
        return Icons.keyboard_backspace;
      case AnnotationLineStyle.dashed:
        return Icons.more_horiz;
      case AnnotationLineStyle.markerX:
        return Icons.close;
      case AnnotationLineStyle.markerPylon:
        return Icons.circle;
      case AnnotationLineStyle.markerDot:
        return Icons.fiber_manual_record;
    }
  }

  String _lineStyleLabel(AnnotationLineStyle style) {
    switch (style) {
      case AnnotationLineStyle.straight:
        return 'Straight line';
      case AnnotationLineStyle.arrow:
        return 'Arrow (to end)';
      case AnnotationLineStyle.arrowStart:
        return 'Arrow (to start)';
      case AnnotationLineStyle.dashed:
        return 'Dashed line';
      case AnnotationLineStyle.markerX:
        return 'X marker';
      case AnnotationLineStyle.markerPylon:
        return 'Pylon marker';
      case AnnotationLineStyle.markerDot:
        return 'Dot marker';
    }
  }

  String _shortSectorAttachmentLabel(_SectorAttachmentType type) {
    switch (type) {
      case _SectorAttachmentType.zone:
        return 'zone';
      case _SectorAttachmentType.ball:
        return 'ball';
      case _SectorAttachmentType.player:
        return 'player';
    }
  }

  IconData _iconForSectorAttachment(_SectorAttachmentType type) {
    switch (type) {
      case _SectorAttachmentType.zone:
        return Icons.adjust;
      case _SectorAttachmentType.ball:
        return Icons.sports_baseball;
      case _SectorAttachmentType.player:
        return Icons.person_pin_circle;
    }
  }

  String _labelForSectorAttachment(_SectorAttachmentType type) {
    switch (type) {
      case _SectorAttachmentType.zone:
        return 'Zone attachment';
      case _SectorAttachmentType.ball:
        return 'Ball attachment';
      case _SectorAttachmentType.player:
        return 'Player attachment';
    }
  }

  String _storageValueForSectorAttachment(_SectorAttachmentType type) {
    switch (type) {
      case _SectorAttachmentType.zone:
        return 'zone';
      case _SectorAttachmentType.ball:
        return 'ball';
      case _SectorAttachmentType.player:
        return 'player';
    }
  }

  void _toggleAnnotationEraserMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_annotationEraserMenuEntry != null) {
      _removeAnnotationEraserMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _annotationEraserButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final origin = globalPos ?? buttonOrigin + Offset(buttonSize.width / 2, 0);

    final menuHeight = HoverSelectionMenu.totalHeightForCount(_annotationEraserSizes.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenHeight = MediaQuery.of(context).size.height;
    final placeAbove = buttonOrigin.dy > (screenHeight / 2);
    final left = origin.dx - (menuWidth / 2);
    final top = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;

    _annotationHoverEraserIndex = _annotationEraserSizes.indexOf(_annotationEraserRadiusCm);
    _annotationEraserHoverNotifier.value = _annotationHoverEraserIndex;

    _annotationEraserMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          IgnorePointer(),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: List.generate(
                _annotationEraserSizes.length,
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
              initialHover: _annotationHoverEraserIndex,
              hoverNotifier: _annotationEraserHoverNotifier,
              onHover: (i) => setState(() => _annotationHoverEraserIndex = i),
              onSelect: (i) {
                setState(() => _annotationEraserRadiusCm = _annotationEraserSizes[i]);
                _removeAnnotationEraserMenu();
              },
              onDismiss: _removeAnnotationEraserMenu,
              menuKey: _annotationEraserMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_annotationEraserMenuEntry!);
    _updateAnnotationEraserMenuHover(globalPos ?? origin);
  }

  void _updateAnnotationEraserMenuHover(Offset globalPos) {
    final box = _annotationEraserMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_annotationEraserSizes.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _annotationEraserHoverNotifier.value = -1;
      setState(() => _annotationHoverEraserIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _annotationEraserSizes.length - 1);
    if (idx != _annotationHoverEraserIndex) {
      _annotationEraserHoverNotifier.value = idx;
      setState(() => _annotationHoverEraserIndex = idx);
    }
  }

  void _removeAnnotationEraserMenu() {
    _annotationEraserMenuEntry?.remove();
    _annotationEraserMenuEntry = null;
    _annotationHoverEraserIndex = -1;
    _annotationEraserHoverNotifier.value = -1;
  }

  void _toggleAnnotationLineStyleMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_annotationLineStyleMenuEntry != null) {
      _removeAnnotationLineStyleMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _annotationLineStyleButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final anchor = globalPos ?? (buttonOrigin + Offset(buttonSize.width / 2, buttonSize.height / 2));
    final menuHeight = HoverSelectionMenu.totalHeightForCount(_annotationLineStyleOptions.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenSize = MediaQuery.of(context).size;
    final placeAbove = anchor.dy > (screenSize.height / 2);
    final unclampedLeft = anchor.dx - (menuWidth / 2);
    final unclampedTop = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;
    final left = unclampedLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);
    final top = unclampedTop.clamp(8.0, screenSize.height - menuHeight - 8.0);

    _annotationLineStyleHoverIndex = _annotationLineStyleOptions.indexOf(_annotationLineStyle);
    if (_annotationLineStyleHoverIndex < 0) {
      _annotationLineStyleHoverIndex = 0;
    }
    _annotationLineStyleHoverNotifier.value = _annotationLineStyleHoverIndex;

    _annotationLineStyleMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          IgnorePointer(),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: _annotationLineStyleOptions
                  .map(
                    (style) => HoverMenuOption(
                      builder: (isHover) => Center(
                        child: Icon(
                          _iconForLineStyle(style),
                          color: isHover ? AppTheme.primaryBlue : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              initialHover: _annotationLineStyleHoverIndex,
              hoverNotifier: _annotationLineStyleHoverNotifier,
              onHover: (i) => setState(() => _annotationLineStyleHoverIndex = i),
              onSelect: (i) {
                setState(() {
                  _annotationLineStyle = _annotationLineStyleOptions[i];
                  if (_activeAnnotationTool != AnnotationTool.line) {
                    _setAnnotationTool(AnnotationTool.line);
                  }
                });
                _removeAnnotationLineStyleMenu();
              },
              onDismiss: _removeAnnotationLineStyleMenu,
              menuKey: _annotationLineStyleMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_annotationLineStyleMenuEntry!);
    _updateAnnotationLineStyleMenuHover(anchor);
  }

  void _updateAnnotationLineStyleMenuHover(Offset globalPos) {
    final box = _annotationLineStyleMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_annotationLineStyleOptions.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _annotationLineStyleHoverNotifier.value = -1;
      setState(() => _annotationLineStyleHoverIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _annotationLineStyleOptions.length - 1);
    if (idx != _annotationLineStyleHoverIndex) {
      _annotationLineStyleHoverNotifier.value = idx;
      setState(() => _annotationLineStyleHoverIndex = idx);
    }
  }

  void _removeAnnotationLineStyleMenu() {
    _annotationLineStyleMenuEntry?.remove();
    _annotationLineStyleMenuEntry = null;
    _annotationLineStyleHoverIndex = -1;
    _annotationLineStyleHoverNotifier.value = -1;
  }

  void _toggleFreehandLineStyleMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_freehandLineStyleMenuEntry != null) {
      _removeFreehandLineStyleMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _freehandLineStyleButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final anchor = globalPos ?? (buttonOrigin + Offset(buttonSize.width / 2, buttonSize.height / 2));
    final menuHeight = HoverSelectionMenu.totalHeightForCount(_annotationLineStyleOptions.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenSize = MediaQuery.of(context).size;
    final placeAbove = anchor.dy > (screenSize.height / 2);
    final unclampedLeft = anchor.dx - (menuWidth / 2);
    final unclampedTop = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;
    final left = unclampedLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);
    final top = unclampedTop.clamp(8.0, screenSize.height - menuHeight - 8.0);

    _freehandLineStyleHoverIndex = _annotationLineStyleOptions.indexOf(_freehandLineStyle);
    if (_freehandLineStyleHoverIndex < 0) {
      _freehandLineStyleHoverIndex = 0;
    }
    _freehandLineStyleHoverNotifier.value = _freehandLineStyleHoverIndex;

    _freehandLineStyleMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          IgnorePointer(),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: _annotationLineStyleOptions
                  .map(
                    (style) => HoverMenuOption(
                      builder: (isHover) => Center(
                        child: Icon(
                          _iconForLineStyle(style),
                          color: isHover ? AppTheme.primaryBlue : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              initialHover: _freehandLineStyleHoverIndex,
              hoverNotifier: _freehandLineStyleHoverNotifier,
              onHover: (i) => setState(() => _freehandLineStyleHoverIndex = i),
              onSelect: (i) {
                setState(() {
                  _freehandLineStyle = _annotationLineStyleOptions[i];
                  _setAnnotationTool(AnnotationTool.freehand);
                });
                _removeFreehandLineStyleMenu();
              },
              onDismiss: _removeFreehandLineStyleMenu,
              menuKey: _freehandLineStyleMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_freehandLineStyleMenuEntry!);
    _updateFreehandLineStyleMenuHover(anchor);
  }

  void _updateFreehandLineStyleMenuHover(Offset globalPos) {
    final box = _freehandLineStyleMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_annotationLineStyleOptions.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _freehandLineStyleHoverNotifier.value = -1;
      setState(() => _freehandLineStyleHoverIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _annotationLineStyleOptions.length - 1);
    if (idx != _freehandLineStyleHoverIndex) {
      _freehandLineStyleHoverNotifier.value = idx;
      setState(() => _freehandLineStyleHoverIndex = idx);
    }
  }

  void _removeFreehandLineStyleMenu() {
    _freehandLineStyleMenuEntry?.remove();
    _freehandLineStyleMenuEntry = null;
    _freehandLineStyleHoverIndex = -1;
    _freehandLineStyleHoverNotifier.value = -1;
  }

  void _toggleAnnotationMarkerStyleMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_annotationMarkerStyleMenuEntry != null) {
      _removeAnnotationMarkerStyleMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _annotationMarkerStyleButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final anchor = globalPos ?? (buttonOrigin + Offset(buttonSize.width / 2, buttonSize.height / 2));
    final menuHeight = HoverSelectionMenu.totalHeightForCount(_annotationMarkerStyleOptions.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenSize = MediaQuery.of(context).size;
    final placeAbove = anchor.dy > (screenSize.height / 2);
    final unclampedLeft = anchor.dx - (menuWidth / 2);
    final unclampedTop = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;
    final left = unclampedLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);
    final top = unclampedTop.clamp(8.0, screenSize.height - menuHeight - 8.0);

    _annotationMarkerStyleHoverIndex = _annotationMarkerStyleOptions.indexOf(_annotationMarkerStyle);
    _annotationMarkerStyleHoverNotifier.value = _annotationMarkerStyleHoverIndex;

    _annotationMarkerStyleMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          IgnorePointer(),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: _annotationMarkerStyleOptions
                  .map(
                    (style) => HoverMenuOption(
                      builder: (isHover) => Center(
                        child: Icon(
                          _iconForLineStyle(style),
                          color: isHover ? AppTheme.primaryBlue : Colors.white,
                          size: style == AnnotationLineStyle.markerDot ? 14 : 22,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              initialHover: _annotationMarkerStyleHoverIndex,
              hoverNotifier: _annotationMarkerStyleHoverNotifier,
              onHover: (i) => setState(() => _annotationMarkerStyleHoverIndex = i),
              onSelect: (i) {
                setState(() {
                  _annotationMarkerStyle = _annotationMarkerStyleOptions[i];
                  _setAnnotationTool(AnnotationTool.marker);
                });
                _removeAnnotationMarkerStyleMenu();
              },
              onDismiss: _removeAnnotationMarkerStyleMenu,
              menuKey: _annotationMarkerStyleMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_annotationMarkerStyleMenuEntry!);
    _updateAnnotationMarkerStyleMenuHover(anchor);
  }

  void _updateAnnotationMarkerStyleMenuHover(Offset globalPos) {
    final box = _annotationMarkerStyleMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_annotationMarkerStyleOptions.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _annotationMarkerStyleHoverNotifier.value = -1;
      setState(() => _annotationMarkerStyleHoverIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _annotationMarkerStyleOptions.length - 1);
    if (idx != _annotationMarkerStyleHoverIndex) {
      _annotationMarkerStyleHoverNotifier.value = idx;
      setState(() => _annotationMarkerStyleHoverIndex = idx);
    }
  }

  void _removeAnnotationMarkerStyleMenu() {
    _annotationMarkerStyleMenuEntry?.remove();
    _annotationMarkerStyleMenuEntry = null;
    _annotationMarkerStyleHoverIndex = -1;
    _annotationMarkerStyleHoverNotifier.value = -1;
  }

  void _toggleAnnotationStrokeMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_annotationStrokeMenuEntry != null) {
      _removeAnnotationStrokeMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _annotationStrokeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final anchor = buttonOrigin + Offset(buttonSize.width / 2, buttonSize.height / 2);
    final menuHeight = HoverSelectionMenu.totalHeightForCount(_annotationStrokeOptionsCm.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenSize = MediaQuery.of(context).size;
    final placeAbove = anchor.dy > (screenSize.height / 2);
    final unclampedLeft = anchor.dx - (menuWidth / 2);
    final unclampedTop = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;
    final left = unclampedLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);
    final top = unclampedTop.clamp(8.0, screenSize.height - menuHeight - 8.0);

    _annotationStrokeHoverIndex = _annotationStrokeOptionsCm.indexOf(_annotationStrokeCm);
    _annotationStrokeHoverNotifier.value = _annotationStrokeHoverIndex;

    _annotationStrokeMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          IgnorePointer(),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: _annotationStrokeOptionsCm
                  .map(
                    (w) => HoverMenuOption(
                      builder: (isHover) => Center(
                        child: Container(
                          width: 34,
                          height: w * 6 + 6,
                          decoration: BoxDecoration(
                            color: isHover ? Colors.white10 : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Container(
                              height: w * 3,
                              width: 28,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              initialHover: _annotationStrokeHoverIndex,
              hoverNotifier: _annotationStrokeHoverNotifier,
              onHover: (i) => setState(() => _annotationStrokeHoverIndex = i),
              onSelect: (i) {
                setState(() => _annotationStrokeCm = _annotationStrokeOptionsCm[i]);
                _removeAnnotationStrokeMenu();
              },
              onDismiss: _removeAnnotationStrokeMenu,
              menuKey: _annotationStrokeMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_annotationStrokeMenuEntry!);
    _updateAnnotationStrokeMenuHover(anchor);
  }

  void _updateAnnotationStrokeMenuHover(Offset globalPos) {
    final box = _annotationStrokeMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_annotationStrokeOptionsCm.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _annotationStrokeHoverNotifier.value = -1;
      setState(() => _annotationStrokeHoverIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _annotationStrokeOptionsCm.length - 1);
    if (idx != _annotationStrokeHoverIndex) {
      _annotationStrokeHoverNotifier.value = idx;
      setState(() => _annotationStrokeHoverIndex = idx);
    }
  }

  void _removeAnnotationStrokeMenu() {
    _annotationStrokeMenuEntry?.remove();
    _annotationStrokeMenuEntry = null;
    _annotationStrokeHoverIndex = -1;
    _annotationStrokeHoverNotifier.value = -1;
  }

  void _toggleCircleFillMenu({Offset? globalPos, bool forceOpen = false}) {
    // Close rectangle menu if it's open
    if (_rectangleFillMenuEntry != null) {
      _removeRectangleFillMenu();
    }

    if (_circleFillMenuEntry != null) {
      _removeCircleFillMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _circleFillButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final anchor = buttonOrigin + Offset(buttonSize.width / 2, buttonSize.height / 2);

    const options = [true, false];
    final menuHeight = HoverSelectionMenu.totalHeightForCount(options.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenSize = MediaQuery.of(context).size;
    final placeAbove = anchor.dy > (screenSize.height / 2);
    final unclampedLeft = anchor.dx - (menuWidth / 2);
    final unclampedTop = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;
    final left = unclampedLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);
    final top = unclampedTop.clamp(8.0, screenSize.height - menuHeight - 8.0);

    _circleFillHoverIndex = options.indexOf(_circleFilled);
    _circleFillHoverNotifier.value = _circleFillHoverIndex;

    _circleFillMenuEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeCircleFillMenu,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: () {}, // Consume taps on menu itself
                child: HoverSelectionMenu(
                  options: options
                      .map(
                        (filled) => HoverMenuOption(
                          builder: (isHover) => Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled ? _annotationColor.withValues(alpha: 0.5) : Colors.transparent,
                                border: Border.all(
                                  color: isHover ? AppTheme.primaryBlue : Colors.white,
                                  width: isHover ? 2 : 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  initialHover: _circleFillHoverIndex,
                  hoverNotifier: _circleFillHoverNotifier,
                  onHover: (i) => setState(() => _circleFillHoverIndex = i),
                  onSelect: (i) {
                    setState(() => _circleFilled = options[i]);
                    _activeAnnotationTool = AnnotationTool.circle;
                    _removeCircleFillMenu();
                  },
                  onDismiss: _removeCircleFillMenu,
                  menuKey: _circleFillMenuKey,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(_circleFillMenuEntry!);
    _updateCircleFillMenuHover(anchor);
  }

  void _updateCircleFillMenuHover(Offset globalPos) {
    final box = _circleFillMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    const optionsCount = 2;
    final height = HoverSelectionMenu.totalHeightForCount(optionsCount);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _circleFillHoverNotifier.value = -1;
      setState(() => _circleFillHoverIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, optionsCount - 1);
    if (idx != _circleFillHoverIndex) {
      _circleFillHoverNotifier.value = idx;
      setState(() => _circleFillHoverIndex = idx);
    }
  }

  void _removeCircleFillMenu() {
    _circleFillMenuEntry?.remove();
    _circleFillMenuEntry = null;
    _circleFillHoverIndex = -1;
    _circleFillHoverNotifier.value = -1;
  }

  void _toggleRectangleFillMenu({Offset? globalPos, bool forceOpen = false}) {
    // Close circle menu if it's open
    if (_circleFillMenuEntry != null) {
      _removeCircleFillMenu();
    }

    if (_rectangleFillMenuEntry != null) {
      _removeRectangleFillMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _rectangleFillButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final anchor = buttonOrigin + Offset(buttonSize.width / 2, buttonSize.height / 2);

    const options = [true, false];
    final menuHeight = HoverSelectionMenu.totalHeightForCount(options.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenSize = MediaQuery.of(context).size;
    final placeAbove = anchor.dy > (screenSize.height / 2);
    final unclampedLeft = anchor.dx - (menuWidth / 2);
    final unclampedTop = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;
    final left = unclampedLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);
    final top = unclampedTop.clamp(8.0, screenSize.height - menuHeight - 8.0);

    _rectangleFillHoverIndex = options.indexOf(_rectangleFilled);
    _rectangleFillHoverNotifier.value = _rectangleFillHoverIndex;

    _rectangleFillMenuEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeRectangleFillMenu,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: () {}, // Consume taps on menu itself
                child: HoverSelectionMenu(
                  options: options
                      .map(
                        (filled) => HoverMenuOption(
                          builder: (isHover) => Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: filled ? _annotationColor.withValues(alpha: 0.5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isHover ? AppTheme.primaryBlue : Colors.white,
                                  width: isHover ? 2 : 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  initialHover: _rectangleFillHoverIndex,
                  hoverNotifier: _rectangleFillHoverNotifier,
                  onHover: (i) => setState(() => _rectangleFillHoverIndex = i),
                  onSelect: (i) {
                    setState(() => _rectangleFilled = options[i]);
                    _activeAnnotationTool = AnnotationTool.rectangle;
                    _removeRectangleFillMenu();
                  },
                  onDismiss: _removeRectangleFillMenu,
                  menuKey: _rectangleFillMenuKey,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(_rectangleFillMenuEntry!);
    _updateRectangleFillMenuHover(anchor);
  }

  void _updateRectangleFillMenuHover(Offset globalPos) {
    final box = _rectangleFillMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    const optionsCount = 2;
    final height = HoverSelectionMenu.totalHeightForCount(optionsCount);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _rectangleFillHoverNotifier.value = -1;
      setState(() => _rectangleFillHoverIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, optionsCount - 1);
    if (idx != _rectangleFillHoverIndex) {
      _rectangleFillHoverNotifier.value = idx;
      setState(() => _rectangleFillHoverIndex = idx);
    }
  }

  void _removeRectangleFillMenu() {
    _rectangleFillMenuEntry?.remove();
    _rectangleFillMenuEntry = null;
    _rectangleFillHoverIndex = -1;
    _rectangleFillHoverNotifier.value = -1;
  }

  void _toggleAnnotationTextSizeMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_annotationTextSizeMenuEntry != null) {
      _removeAnnotationTextSizeMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _annotationTextButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final anchor = buttonOrigin + Offset(buttonSize.width / 2, buttonSize.height / 2);
    final menuHeight = HoverSelectionMenu.totalHeightForCount(_annotationTextSizeOptions.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenSize = MediaQuery.of(context).size;
    final placeAbove = anchor.dy > (screenSize.height / 2);
    final unclampedLeft = anchor.dx - (menuWidth / 2);
    final unclampedTop = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;
    final left = unclampedLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);
    final top = unclampedTop.clamp(8.0, screenSize.height - menuHeight - 8.0);

    _annotationTextSizeHoverIndex = _annotationTextSizeOptions.indexOf(_annotationTextSize);
    _annotationTextSizeHoverNotifier.value = _annotationTextSizeHoverIndex;

    _annotationTextSizeMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          IgnorePointer(),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: _annotationTextSizeOptions
                  .map(
                    (size) => HoverMenuOption(
                      builder: (isHover) => Container(
                        alignment: Alignment.center,
                        child: Text(
                          size.toStringAsFixed(0),
                          style: TextStyle(
                            color: isHover ? AppTheme.primaryBlue : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              initialHover: _annotationTextSizeHoverIndex,
              hoverNotifier: _annotationTextSizeHoverNotifier,
              onHover: (i) => setState(() => _annotationTextSizeHoverIndex = i),
              onSelect: (i) {
                setState(() => _annotationTextSize = _annotationTextSizeOptions[i]);
                _removeAnnotationTextSizeMenu();
              },
              onDismiss: _removeAnnotationTextSizeMenu,
              menuKey: _annotationTextSizeMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_annotationTextSizeMenuEntry!);
    _updateAnnotationTextSizeMenuHover(anchor);
  }

  void _updateAnnotationTextSizeMenuHover(Offset globalPos) {
    final box = _annotationTextSizeMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_annotationTextSizeOptions.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _annotationTextSizeHoverNotifier.value = -1;
      setState(() => _annotationTextSizeHoverIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _annotationTextSizeOptions.length - 1);
    if (idx != _annotationTextSizeHoverIndex) {
      _annotationTextSizeHoverNotifier.value = idx;
      setState(() => _annotationTextSizeHoverIndex = idx);
    }
  }

  void _removeAnnotationTextSizeMenu() {
    _annotationTextSizeMenuEntry?.remove();
    _annotationTextSizeMenuEntry = null;
    _annotationTextSizeHoverIndex = -1;
    _annotationTextSizeHoverNotifier.value = -1;
  }

  void _toggleSectorAttachmentMenu({Offset? globalPos, bool forceOpen = false}) {
    if (_sectorAttachmentMenuEntry != null) {
      _removeSectorAttachmentMenu();
      if (!forceOpen) return;
    }

    final overlay = Overlay.of(context);
    final box = _sectorAttachmentButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final buttonOrigin = box.localToGlobal(Offset.zero);
    final buttonSize = box.size;
    final anchor = globalPos ?? (buttonOrigin + Offset(buttonSize.width / 2, buttonSize.height / 2));
    final menuHeight = HoverSelectionMenu.totalHeightForCount(_sectorAttachmentOptions.length);
    final menuWidth = HoverSelectionMenu.menuWidth;
    final screenSize = MediaQuery.of(context).size;
    final placeAbove = anchor.dy > (screenSize.height / 2);
    final unclampedLeft = anchor.dx - (menuWidth / 2);
    final unclampedTop = placeAbove ? buttonOrigin.dy - menuHeight - 12 : buttonOrigin.dy + buttonSize.height + 12;
    final left = unclampedLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);
    final top = unclampedTop.clamp(8.0, screenSize.height - menuHeight - 8.0);

    _sectorAttachmentHoverIndex = _sectorAttachmentOptions.indexOf(_sectorAttachmentType);
    _sectorAttachmentHoverNotifier.value = _sectorAttachmentHoverIndex;

    _sectorAttachmentMenuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          IgnorePointer(),
          Positioned(
            left: left,
            top: top,
            child: HoverSelectionMenu(
              options: _sectorAttachmentOptions
                  .map(
                    (type) => HoverMenuOption(
                      builder: (isHover) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _iconForSectorAttachment(type),
                              color: isHover ? AppTheme.primaryBlue : Colors.white,
                              size: 18,
                            ),
                            const SizedBox(height: 1),
                            SizedBox(
                              height: 10,
                              child: Text(
                                _shortSectorAttachmentLabel(type),
                                style: TextStyle(
                                  fontSize: 8,
                                  height: 1.0,
                                  color: isHover ? AppTheme.primaryBlue : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
              initialHover: _sectorAttachmentHoverIndex,
              hoverNotifier: _sectorAttachmentHoverNotifier,
              onHover: (i) => setState(() => _sectorAttachmentHoverIndex = i),
              onSelect: (i) {
                setState(() {
                  _sectorAttachmentType = _sectorAttachmentOptions[i];
                  _setAnnotationTool(AnnotationTool.sector);
                });
                _removeSectorAttachmentMenu();
              },
              onDismiss: _removeSectorAttachmentMenu,
              menuKey: _sectorAttachmentMenuKey,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_sectorAttachmentMenuEntry!);
    _updateSectorAttachmentMenuHover(anchor);
  }

  void _updateSectorAttachmentMenuHover(Offset globalPos) {
    final box = _sectorAttachmentMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final width = HoverSelectionMenu.menuWidth;
    final height = HoverSelectionMenu.totalHeightForCount(_sectorAttachmentOptions.length);
    if (local.dx < 0 || local.dx > width || local.dy < 0 || local.dy > height) {
      _sectorAttachmentHoverNotifier.value = -1;
      setState(() => _sectorAttachmentHoverIndex = -1);
      return;
    }
    final idx = (local.dy / HoverSelectionMenu.itemExtent).floor().clamp(0, _sectorAttachmentOptions.length - 1);
    if (idx != _sectorAttachmentHoverIndex) {
      _sectorAttachmentHoverNotifier.value = idx;
      setState(() => _sectorAttachmentHoverIndex = idx);
    }
  }

  void _removeSectorAttachmentMenu() {
    _sectorAttachmentMenuEntry?.remove();
    _sectorAttachmentMenuEntry = null;
    _sectorAttachmentHoverIndex = -1;
    _sectorAttachmentHoverNotifier.value = -1;
  }

  /// Derive available logical screen size from the active window (web/windows) or MediaQuery elsewhere.
  Size _effectiveScreenSize(BuildContext context) {
    final mqSize = MediaQuery.of(context).size;
    if (!(kIsWeb || defaultTargetPlatform == TargetPlatform.windows)) {
      return mqSize;
    }

    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      if (dispatcher.views.isEmpty) return mqSize;
      final ui.FlutterView view = dispatcher.views.first;
      final double ratio = view.devicePixelRatio;
      final double logicalWidth = view.physicalSize.width / ratio;
      final double logicalHeight = view.physicalSize.height / ratio;

      final double padLeft = view.viewPadding.left / ratio;
      final double padRight = view.viewPadding.right / ratio;
      final double padTop = view.viewPadding.top / ratio;
      final double padBottom = view.viewPadding.bottom / ratio;

      final double insetLeft = view.viewInsets.left / ratio;
      final double insetRight = view.viewInsets.right / ratio;
      final double insetTop = view.viewInsets.top / ratio;
      final double insetBottom = view.viewInsets.bottom / ratio;

      final double availableWidth = (logicalWidth - padLeft - padRight - insetLeft - insetRight).clamp(
        0.0,
        logicalWidth,
      );
      final double availableHeight = (logicalHeight - padTop - padBottom - insetTop - insetBottom).clamp(
        0.0,
        logicalHeight,
      );

      return Size(availableWidth, availableHeight);
    } catch (_) {
      return mqSize;
    }
  }

  /// Convert screen pixel position to cm logical coordinates
  Offset _screenToCm(Offset screenPos, Size size) {
    final center = _boardCenter(size);
    final logical = screenPos - center;
    final scalePerCm = _cmToLogical(1.0, size);
    if (scalePerCm == 0) return Offset.zero;
    return Offset(logical.dx / scalePerCm, logical.dy / scalePerCm);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PLAYBACK LOGIC & ANIMATION STATE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════
  // Manages animation playback, frame interpolation, and timeline synchronization
  // Key parameters:
  //   _playbackFrameIndex: current keyframe (0 to frames.length-1)
  //   _playbackT: interpolation [0.0..1.0] between keyframe and next
  //   _playbackSpeed: 0.1x to 2.0x multiplier
  //   _endedAtLastFrame: prevents auto-exit to edit mode; requires Stop button

  /// Called on every frame during playback to update animation state
  void _onTick(Duration elapsed) {
    if (!_isPlaying || _isPaused) return;
    final frames = widget.project.frames;

    // Detect frame transitions for auto-scrolling
    final prevAnimIndex = ((_playbackFrameIndex + _playbackT).clamp(0.0, (frames.length - 1).toDouble())).round();

    // Stop playback at last frame, but stay in playback view (don't return to editing mode)
    // This allows user to still access the scrubber and only exit via stop button
    if (_playbackFrameIndex >= frames.length - 1) {
      setState(() {
        _endedAtLastFrame = true;
        _isPlaying = false; // Stop advancing, but don't disable scrubber
      });
      _ticker.stop();
      return;
    }

    // Calculate frame duration and tick increment
    // Duration[i] applies to the transition FROM frame i-1 TO frame i
    final nextFrameIndex = (_playbackFrameIndex + 1).clamp(0, frames.length - 1);
    final nextFrame = frames[nextFrameIndex];
    final frameDuration = nextFrameIndex > 0 ? (nextFrame.duration > 0 ? nextFrame.duration : 0.5) : 0.5;

    // Each tick represents 16.67ms (60fps), increment based on frame duration and playback speed
    final tickIncrement = (1.0 / (frameDuration * 60.0)) * _playbackSpeed;

    setState(() {
      _playbackT += tickIncrement;
      if (_playbackT >= 1.0) {
        _playbackT -= 1.0; // Keep fractional part for smooth interpolation
        _playbackFrameIndex++;
        if (_playbackFrameIndex >= frames.length - 1) {
          _endedAtLastFrame = true;
        }
        _scrollToPlaybackFrame();
      }
    });

    // Auto-scroll timeline when crossing frame boundary
    final newAnimIndex = ((_playbackFrameIndex + _playbackT).clamp(0.0, (frames.length - 1).toDouble())).round();
    if (newAnimIndex != prevAnimIndex) {
      _scrollToPlaybackFrame();
    }
  }

  /// Start playback from the beginning
  void _startPlayback() {
    if (widget.project.frames.length < 2) return;
    setState(() {
      _resetPlaybackAnnotationSession();
      _isPlaying = true;
      _endedAtLastFrame = false;
      _scrubberMovedManually = false;
      _playbackZoomLockedByUser = false;
      _playbackManualZoomFactor = null;
      _playbackFrameIndex = 0;
      _playbackT = 0.0;
      _activeMenu = BoardMenu.none;
      _pendingBallMark = null;
      _deactivateAnnotationTools();
      _closeObjectMenusAndSelection();
    });
    _ticker.start();
    _scrollToPlaybackFrame();
  }

  /// Stop playback and return to edit mode
  void _stopPlayback() {
    setState(() {
      _resetPlaybackAnnotationSession();
      _isPlaying = false;
      _isPaused = false;
      _endedAtLastFrame = false;
      _scrubberMovedManually = false;
      _playbackZoomLockedByUser = false;
      _playbackManualZoomFactor = null;
      _playbackFrameIndex = 0;
      _playbackT = 0.0;
    });
    _ticker.stop();
  }

  Future<void> _handleStopPlaybackPressed() async {
    if (!_hasPlaybackSessionAnnotations()) {
      _stopPlayback();
      return;
    }

    final action = await _showSavePlaybackAnnotationsDialog();
    if (!mounted || action == _PlaybackAnnotationStopAction.cancel) return;

    if (action == _PlaybackAnnotationStopAction.save) {
      _persistPlaybackAnnotationsToProject();
    }

    _stopPlayback();
  }

  Future<void> _handleBackNavigationRequested() async {
    if ((_isPlaying || _endedAtLastFrame) && _hasPlaybackSessionAnnotations()) {
      final action = await _showSavePlaybackAnnotationsDialog();
      if (!mounted || action == _PlaybackAnnotationStopAction.cancel) return;
      if (action == _PlaybackAnnotationStopAction.save) {
        _persistPlaybackAnnotationsToProject();
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<_PlaybackAnnotationStopAction> _showSavePlaybackAnnotationsDialog() async {
    final choice = await showDialog<_PlaybackAnnotationStopAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save annotations?'),
        content: const Text('You added temporary playback annotations. Save them to their corresponding frames?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_PlaybackAnnotationStopAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_PlaybackAnnotationStopAction.discard),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(_PlaybackAnnotationStopAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return choice ?? _PlaybackAnnotationStopAction.cancel;
  }

  bool _hasPlaybackSessionAnnotations() {
    for (final frameAnnotations in _playbackSessionAnnotationsByFrame.values) {
      if (frameAnnotations.isNotEmpty) return true;
    }
    return false;
  }

  void _persistPlaybackAnnotationsToProject() {
    if (!_hasPlaybackSessionAnnotations()) return;
    for (int frameIndex = 0; frameIndex < widget.project.frames.length; frameIndex++) {
      final tempAnnotations = _playbackSessionAnnotationsForFrame(frameIndex);
      if (tempAnnotations.isEmpty) continue;
      final from = _cloneAnnotations(widget.project.frames[frameIndex].annotations);
      final to = <Annotation>[...from, ...tempAnnotations.map((annotation) => annotation.copy())];
      _history.push(SetFrameAnnotationsAction(frameIndex: frameIndex, fromAnnotations: from, toAnnotations: to));
    }
  }

  /// Pause playback (can be resumed)
  void _pausePlayback() {
    setState(() {
      _isPaused = true;
    });
    _ticker.stop();
  }

  /// Resume paused playback
  void _resumePlayback() {
    setState(() {
      _isPaused = false;
      _activeMenu = BoardMenu.none;
      _deactivateAnnotationTools();
    });
    _ticker.start();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FRAME DURATION PICKER DIALOG
  // ══════════════════════════════════════════════════════════════════════════
  // Shows a dialog to set the duration of the current frame (0.25s, 0.5s, 1.0s, 2.0s)

  void _showDurationPicker() {
    final durations = [0.25, 0.5, 1.0, 2.0];
    final isFirstFrame = widget.project.frames.indexOf(currentFrame) == 0;

    // First frame has no duration (it's just starting position)
    if (isFirstFrame) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("First Frame"),
          content: const Text(
            "The first frame defines starting positions only.\nIt has no duration for animation.\n\nSet duration for frame 2 instead.",
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        ),
      );
      return;
    }

    // ┌─────────────────────────────────────────────────────────────────────┐
    // │ DURATION PICKER DIALOG                                              │
    // │ GUI STRUCTURE: AlertDialog with pill-shaped option buttons          │
    // └─────────────────────────────────────────────────────────────────────┘
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Frame Duration"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: durations.map((d) {
            final isSelected = (currentFrame.duration - d).abs() < 0.01;
            return GestureDetector(
              onTap: () {
                setState(() => currentFrame.duration = d);
                _saveProject();
                Navigator.pop(context);
              },
              // ─────────────────────────────────────────────────────────────
              // DURATION OPTION BUTTON (Pill-Shaped)
              // EDIT: Padding, border radius, colors
              // ─────────────────────────────────────────────────────────────
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(24), // ← EDIT: Pill shape radius
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Duration label text
                    Text(
                      "${d.toStringAsFixed(2)}s",
                      style: TextStyle(
                        fontSize: 14, // ← EDIT: Text size
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppTheme.darkGrey,
                      ),
                    ),
                    // Checkmark icon when selected
                    if (isSelected) const Icon(Icons.check, color: Colors.white, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FRAME INTERPOLATION & ANIMATION RENDERING
  // ══════════════════════════════════════════════════════════════════════════
  // Smoothly interpolates between keyframes during playback or scrubbing
  // Supports path-based movement via PathEngine (quadratic Bezier curves)
  // Handles ball scale effects (set/hit animations) via _ballScaleAt()

  /// Generate interpolated frame between two keyframes during playback or scrubbing
  Frame? get _animatedFrame {
    if (!(_isPlaying || _endedAtLastFrame)) return null;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return null;

    final fA = frames[_playbackFrameIndex];
    final fB = frames[_playbackFrameIndex + 1];
    final t = _playbackT;

    // Helper to interpolate along path or linearly
    Offset getPathOrLinear(String entityId, Offset start, Offset end, List<Offset> pathPoints) {
      if (pathPoints.isNotEmpty) {
        final engine = PathEngine.fromTwoQuadratics(start: start, control: pathPoints.first, end: end, resolution: 400);
        return engine.sample(t);
      }
      return Offset.lerp(start, end, t)!;
    }

    // Interpolate players by ID matching
    final interpPlayers = <Player>[];
    for (final pB in fB.players) {
      final pA = fA.getPlayerById(pB.id);
      if (pA == null) {
        // Player doesn't exist in previous frame, use current position
        interpPlayers.add(pB.copy());
      } else {
        final interpPos = getPathOrLinear(pB.id, pA.position, pB.position, pB.pathPoints);
        final interpRot = _interpolateRotation(pA.rotation, pB.rotation, t);

        interpPlayers.add(
          Player(position: interpPos, rotation: interpRot, color: pB.color, id: pB.id, label: pB.label),
        );
      }
    }

    // Interpolate balls by ID matching
    final interpBalls = <Ball>[];
    for (final bB in fB.balls) {
      final bA = fA.getBallById(bB.id);
      if (bA == null) {
        // Ball doesn't exist in previous frame, use current position
        interpBalls.add(bB.copy());
      } else {
        final interpPos = getPathOrLinear(bB.id, bA.position, bB.position, bB.pathPoints);

        interpBalls.add(Ball(position: interpPos, hitT: bB.hitT, isSet: bB.isSet, color: bB.color, id: bB.id));
      }
    }

    return Frame(players: interpPlayers, balls: interpBalls, duration: fB.duration, annotations: fB.annotations);
  }

  /// Calculate ball scale during playback based on set/hit effects
  /// Returns the animated scale for the specified ball by ID
  double _ballScaleAt(double t, {String? ballId}) {
    const double base = 1.0;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return base;
    final fB = frames[_playbackFrameIndex + 1];

    // Get the specific ball by ID, or first ball if no ID provided
    Ball? ball;
    if (ballId != null) {
      ball = fB.getBallById(ballId);
    } else if (fB.balls.isNotEmpty) {
      ball = fB.balls.first;
    }

    if (ball == null) return base;

    // Set animation: subtle swell when set is enabled
    if ((ball.isSet ?? false) && ball.hitT == null) {
      final quad = 1.0 + (1.0 - 4.0 * (t - 0.5) * (t - 0.5));
      return quad.clamp(0.5, 2.0);
    }

    // Hit modifier: shrink to minimum 0.25 at hit time, easing back to 1.0
    if (ball.hitT != null && !(ball.isSet ?? false)) {
      final th = ball.hitT!.clamp(0.0, 1.0);
      const window = 0.25;
      final d = (t - th).abs();
      if (d > window) return 1.0;
      final frac = (d / window).clamp(0.0, 1.0);
      final eased = frac * frac;
      final scale = 0.25 + (1.0 - 0.25) * eased;
      return scale.clamp(0.25, 1.0);
    }
    return base;
  }

  /// Interpolate rotation angle between two frames
  double _interpolateRotation(double a, double b, double t) => a + (b - a) * t;

  // ══════════════════════════════════════════════════════════════════════════
  // FRAME HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get the frame before the current frame (for path drawing)
  Frame? _getPreviousFrame() {
    final index = widget.project.frames.indexOf(currentFrame);
    if (index > 0) return widget.project.frames[index - 1];
    return null;
  }

  /// Get the frame two positions before current (for extended path preview)
  Frame? _getTwoFramesAgo() {
    final index = widget.project.frames.indexOf(currentFrame);
    if (index >= 2) return widget.project.frames[index - 2];
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENTITY POSITION UPDATES
  // ══════════════════════════════════════════════════════════════════════════

  /// Update the position of a player or ball in the current frame by ID
  void _updateFramePosition(String entityId, Offset newPos) {
    if (_isPlaying || _endedAtLastFrame) return;
    setState(() {
      // Try to find player by ID
      final player = currentFrame.getPlayerById(entityId);
      if (player != null) {
        player.position = newPos;
      } else {
        // Try to find ball by ID
        final ball = currentFrame.getBallById(entityId);
        if (ball != null) {
          ball.position = newPos;
        }
      }
      final idx = widget.project.frames.indexOf(currentFrame);
      if (idx >= 0) widget.project.frames[idx] = currentFrame;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FRAME MANAGEMENT (Insert, Delete, Undo/Redo)
  // ══════════════════════════════════════════════════════════════════════════
  // Manages frame lifecycle and history tracking via HistoryManager
  // All modifications are undoable/redoable

  /// Insert a new frame after the current frame (deep copy including annotations)
  void _insertFrameAfterCurrent() {
    final index = widget.project.frames.indexOf(currentFrame);
    // Deep-copy current frame without hit/set markers so they don't carry over to new frames
    // Also copies duration from current frame
    final newFrame = currentFrame.copyWithoutHitSetMarkers();
    final newIdx = _history.push(InsertFrameAction(frameIndex: index, inserted: newFrame));
    setState(() {
      currentFrame = widget.project.frames[newIdx + 1];
    });
    _scrollToSelectedFrame();
  }

  /// Confirm and delete a frame
  void _confirmDeleteFrame(Frame frame) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Frame"),
        content: const Text("Are you sure you want to delete this frame?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final index = widget.project.frames.indexOf(frame);
      _history.push(DeleteFrameAction(frameIndex: index));
      setState(() {
        _deleteFrameButtonIndex = null;
        if (widget.project.frames.isEmpty) {
          // Create default frame if all frames deleted
          final r = _settings.outerCircleRadiusCm;
          final defaultFrame = widget.project.projectType == ProjectType.play
              ? Frame(
                  players: [
                    Player(position: Offset(0, -r), color: AppTheme.playerColors[0], id: 'P1'),
                    Player(position: Offset(r, 0), color: AppTheme.playerColors[0], id: 'P2'),
                    Player(position: Offset(0, r), color: AppTheme.playerColors[1], id: 'P3'),
                    Player(position: Offset(-r, 0), color: AppTheme.playerColors[1], id: 'P4'),
                  ],
                  balls: [Ball(position: Offset.zero, color: Colors.white, id: 'B1')],
                )
              : Frame(
                  players: [
                    Player(position: Offset(0, -r), color: AppTheme.playerColors[0]),
                    Player(position: Offset(r, 0), color: AppTheme.playerColors[0]),
                    Player(position: Offset(0, r), color: AppTheme.playerColors[1]),
                    Player(position: Offset(-r, 0), color: AppTheme.playerColors[1]),
                  ],
                  balls: [Ball(position: Offset.zero, color: Colors.white)],
                );
          widget.project.frames.add(defaultFrame);
          currentFrame = defaultFrame;
          _saveProject();
        } else {
          final safeIdx = index > 0 ? index - 1 : 0;
          currentFrame = widget.project.frames[math.min(safeIdx, widget.project.frames.length - 1)];
        }
      });
    }
  }

  /// Build a creation tool button with visual distinction (active shows with blue background)
  Widget _buildAnnotationCreationButton({
    required Widget icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
    Key? buttonKey,
    Widget? cornerBadge,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryBlue.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              key: buttonKey,
              icon: icon,
              tooltip: tooltip,
              color: isActive ? AppTheme.primaryBlue : AppTheme.darkGrey,
              onPressed: onPressed,
            ),
            if (cornerBadge != null) Positioned(right: 6, top: 6, child: cornerBadge),
          ],
        ),
      ),
    );
  }

  Color _contrastIconColor(Color background, Color preferred) {
    final bgLum = background.computeLuminance();
    final prefLum = preferred.computeLuminance();
    if (bgLum < 0.5 && prefLum < 0.5) return Colors.white;
    if (bgLum >= 0.5 && prefLum >= 0.5) return Colors.black;
    return preferred;
  }

  Widget _buildMenuButton({
    required Widget child,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? iconColorOverride,
    bool enabled = true,
    VoidCallback? onDoubleTap,
    Key? buttonKey,
  }) {
    final bg = backgroundColor ?? AppTheme.mediumGrey;
    final iconColor = iconColorOverride ?? _contrastIconColor(bg, Colors.white);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: _menuButtonSize,
        height: _menuButtonSize,
        child: FloatingActionButton.small(
          key: buttonKey,
          heroTag: null,
          backgroundColor: bg,
          onPressed: enabled ? onPressed : null,
          child: IconTheme(
            data: IconThemeData(color: iconColor),
            child: child,
          ),
        ),
      ),
    );

    final wrapped = onDoubleTap == null ? content : GestureDetector(onDoubleTap: onDoubleTap, child: content);

    return Tooltip(message: tooltip, child: wrapped);
  }

  void _deactivateAnnotationTools() {
    _activeAnnotationTool = AnnotationTool.none;
    _clearSectorSelectionVisuals();
    _selectedAnnotation = null;
    _draggingAnnotation = null;
    _eraserMode = false;
    _eraserPosCm = null;
    _removeAnnotationEraserMenu();
    _removeAnnotationMarkerStyleMenu();
    _removeAnnotationLineStyleMenu();
    _removeFreehandLineStyleMenu();
    _removeAnnotationStrokeMenu();
    _removeAnnotationTextSizeMenu();
    _removeSectorAttachmentMenu();
  }

  void _clearSectorSelectionVisuals() {
    _sectorToolNeedsTargetSelection = false;
    _selectedSectorTarget = null;
    _selectedSectorAttachmentId = null;
    _selectedSectorCenterCm = null;
    _selectedSectorRadiusCm = null;
    _sectorTargetHighlightActive = false;
    _sectorDragStartAngle = null;
    _sectorDragPrevAngle = null;
    _sectorDragSweepAngle = 0.0;
    _sectorDragEndAngle = null;
    _pendingAnnotationPoints.clear();
    _currentDragPos = null;
    _stagedAnnotations.clear();
  }

  void _setAnnotationTool(AnnotationTool tool) {
    if (_activeAnnotationTool == tool) {
      _activeAnnotationTool = AnnotationTool.none;
      if (tool == AnnotationTool.sector) {
        _clearSectorSelectionVisuals();
      }
      _eraserMode = false;
      return;
    }

    _activeAnnotationTool = tool;
    _eraserMode = false;

    if (tool == AnnotationTool.sector) {
      _sectorToolNeedsTargetSelection = true;
      _selectedSectorTarget = null;
      _selectedSectorAttachmentId = null;
      _selectedSectorCenterCm = null;
      _selectedSectorRadiusCm = null;
      _sectorTargetHighlightActive = false;
      _sectorDragStartAngle = null;
      _sectorDragPrevAngle = null;
      _sectorDragSweepAngle = 0.0;
      _sectorDragEndAngle = null;
      _pendingAnnotationPoints.clear();
      _currentDragPos = null;
      _stagedAnnotations.clear();
      return;
    }

    _clearSectorSelectionVisuals();
  }

  void _closeObjectMenusAndSelection() {
    _showModifierMenu = false;
    _showPlayerMenu = false;
    _activePlayerId = null;
    _activeBallId = null;
    _addingObjectType = null;
  }

  bool get _isPausedPlayback => _isPlaying && _isPaused;

  bool get _isTemporaryPlaybackAnnotationMode => _isPausedPlayback;

  int _playbackDisplayFrameIndex() {
    if (widget.project.frames.isEmpty) return 0;
    final lastIndex = widget.project.frames.length - 1;
    if (_playbackFrameIndex >= lastIndex) return lastIndex;
    return (_playbackFrameIndex + 1).clamp(0, lastIndex);
  }

  List<Annotation> _resolvedPlaybackSessionAnnotationsForFrame(int frameIndex) {
    if (widget.project.frames.isEmpty) return <Annotation>[];
    final clampedFrame = frameIndex.clamp(0, widget.project.frames.length - 1);
    for (int idx = clampedFrame; idx >= 0; idx--) {
      final annotations = _playbackSessionAnnotationsByFrame[idx];
      if (annotations != null) {
        return _cloneAnnotations(annotations);
      }
    }
    return <Annotation>[];
  }

  List<Annotation> _playbackSessionAnnotationsForFrame(int frameIndex, {bool createIfMissing = false}) {
    if (createIfMissing) {
      return _playbackSessionAnnotationsByFrame.putIfAbsent(
        frameIndex,
        () => _resolvedPlaybackSessionAnnotationsForFrame(frameIndex),
      );
    }
    return _resolvedPlaybackSessionAnnotationsForFrame(frameIndex);
  }

  List<Annotation> _activeAnnotationList() {
    if (_isTemporaryPlaybackAnnotationMode) {
      return _playbackSessionAnnotationsForFrame(_playbackDisplayFrameIndex(), createIfMissing: true);
    }
    return currentFrame.annotations;
  }

  void _setPlaybackSessionAnnotationsForFrame(int frameIndex, List<Annotation> annotations) {
    _playbackSessionAnnotationsByFrame[frameIndex] = _cloneAnnotations(annotations);
  }

  Annotation _interpolatePlaybackAnnotation(Annotation from, Annotation to, double t) {
    final interpolated = to.copy();
    if (from.points.length == to.points.length) {
      interpolated.points = List<Offset>.generate(
        to.points.length,
        (index) => Offset.lerp(from.points[index], to.points[index], t) ?? to.points[index],
      );
    }
    if (from.startAngle != null && to.startAngle != null) {
      interpolated.startAngle = (from.startAngle! + (to.startAngle! - from.startAngle!) * t);
    }
    if (from.endAngle != null && to.endAngle != null) {
      interpolated.endAngle = (from.endAngle! + (to.endAngle! - from.endAngle!) * t);
    }
    if (from.fontSize != null && to.fontSize != null) {
      interpolated.fontSize = from.fontSize! + (to.fontSize! - from.fontSize!) * t;
    }
    return interpolated;
  }

  List<Annotation> _interpolatePlaybackSessionAnnotations(int fromFrame, int toFrame, double t) {
    final fromAnnotations = _playbackSessionAnnotationsForFrame(fromFrame);
    final toAnnotations = _playbackSessionAnnotationsForFrame(toFrame);

    if (toAnnotations.isEmpty) return <Annotation>[];
    if (fromAnnotations.isEmpty) return _cloneAnnotations(toAnnotations);

    final fromById = <String, Annotation>{};
    for (final annotation in fromAnnotations) {
      if (annotation.id != null) {
        fromById[annotation.id!] = annotation;
      }
    }

    final interpolated = <Annotation>[];
    for (final annotation in toAnnotations) {
      final annotationId = annotation.id;
      if (annotationId == null) {
        interpolated.add(annotation.copy());
        continue;
      }
      final fromMatch = fromById[annotationId];
      if (fromMatch == null ||
          fromMatch.type != annotation.type ||
          fromMatch.points.length != annotation.points.length) {
        interpolated.add(annotation.copy());
        continue;
      }
      interpolated.add(_interpolatePlaybackAnnotation(fromMatch, annotation, t));
    }

    return interpolated;
  }

  void _resetPlaybackAnnotationSession() {
    _playbackSessionAnnotationsByFrame.clear();
    _annotationGestureStartSnapshot = null;
  }

  String _newAnnotationId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final random = math.Random().nextInt(1 << 20);
    return '${ts}_$random';
  }

  List<Annotation> _cloneAnnotations(List<Annotation> source) => source.map((annotation) => annotation.copy()).toList();

  bool _annotationEquals(Annotation a, Annotation b) {
    if (a.type != b.type) return false;
    if (a.colorValue != b.colorValue) return false;
    if (a.filled != b.filled) return false;
    if (a.lineStyleIndex != b.lineStyleIndex) return false;
    if ((a.strokeWidthCm - b.strokeWidthCm).abs() > 0.001) return false;
    if (a.circleAnnotationId != b.circleAnnotationId) return false;
    if (a.sectorAttachmentType != b.sectorAttachmentType) return false;
    if (a.sectorAttachmentId != b.sectorAttachmentId) return false;
    if (((a.startAngle ?? 0) - (b.startAngle ?? 0)).abs() > 0.001) {
      return false;
    }
    if (((a.endAngle ?? 0) - (b.endAngle ?? 0)).abs() > 0.001) {
      return false;
    }
    if (a.id != b.id) return false;
    if (a.text != b.text) return false;
    if (((a.fontSize ?? 0) - (b.fontSize ?? 0)).abs() > 0.001) return false;
    if (a.points.length != b.points.length) return false;
    for (int i = 0; i < a.points.length; i++) {
      if ((a.points[i].dx - b.points[i].dx).abs() > 0.001 || (a.points[i].dy - b.points[i].dy).abs() > 0.001) {
        return false;
      }
    }
    return true;
  }

  bool _annotationsEqual(List<Annotation> a, List<Annotation> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_annotationEquals(a[i], b[i])) return false;
    }
    return true;
  }

  void _pushAnnotationHistoryIfChanged(List<Annotation> before, List<Annotation> after) {
    if (_annotationsEqual(before, after)) return;

    if (_isTemporaryPlaybackAnnotationMode) {
      final frameIndex = _playbackDisplayFrameIndex();
      _setPlaybackSessionAnnotationsForFrame(frameIndex, after);
      return;
    }

    final frameIndex = widget.project.frames.indexOf(currentFrame);
    if (frameIndex < 0) return;
    _history.push(SetFrameAnnotationsAction(frameIndex: frameIndex, fromAnnotations: before, toAnnotations: after));
  }

  void _setActiveMenu(BoardMenu menu) {
    setState(() {
      _activeMenu = (_activeMenu == menu) ? BoardMenu.none : menu;

      if (_activeMenu == BoardMenu.annotations) {
        _closeObjectMenusAndSelection();
      } else {
        _deactivateAnnotationTools();
        if (_activeMenu != BoardMenu.objects) {
          _closeObjectMenusAndSelection();
        }
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COLOR PICKER DIALOGS
  // ══════════════════════════════════════════════════════════════════════════
  // Provides UI for selecting annotation colors and player/ball colors
  // Applies to all frames for player/ball color changes

  // todo make color picker background lightgrey
  void _showColorPicker() {
    Color selectedColor = _annotationColor;
    double alpha = selectedColor.a.clamp(0.0, 1.0);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Select Color'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppTheme.editorColors.map((color) {
                    final baseSelected = selectedColor.withValues(alpha: 1.0).toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => setStateDialog(() {
                        selectedColor = color.withValues(alpha: alpha);
                      }),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: baseSelected ? AppTheme.darkGrey : Colors.transparent, width: 2),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text('Transparency ${(alpha * 100).round()}%', style: Theme.of(context).textTheme.labelMedium),
                Slider(
                  value: alpha,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  onChanged: (value) => setStateDialog(() {
                    alpha = value;
                    selectedColor = selectedColor.withValues(alpha: alpha);
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() => _annotationColor = selectedColor);
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows color picker dialog for player
  void _showPlayerColorPicker() {
    ColorChangeScope scope = ColorChangeScope.onlyThisFrame;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Player Color'),
          content: Container(
            width: 280,
            height: 260,
            color: AppTheme.lightGrey,
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Only this frame'),
                      selected: scope == ColorChangeScope.onlyThisFrame,
                      onSelected: (_) => setDialogState(() => scope = ColorChangeScope.onlyThisFrame),
                    ),
                    ChoiceChip(
                      label: const Text('From this frame to end'),
                      selected: scope == ColorChangeScope.fromThisFrameToEnd,
                      onSelected: (_) => setDialogState(() => scope = ColorChangeScope.fromThisFrameToEnd),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 4,
                    children: AppTheme.editorColors
                        .map(
                          (color) => GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              if (_activePlayerId == null) return;

                              final frameIndex = widget.project.frames.indexOf(currentFrame);
                              if (frameIndex < 0) return;

                              final player = currentFrame.getPlayerById(_activePlayerId!);
                              if (player == null) return;

                              final oldColor = player.color;
                              if (oldColor.toARGB32() == color.toARGB32()) {
                                return;
                              }

                              if (scope == ColorChangeScope.onlyThisFrame) {
                                _history.push(
                                  ChangePlayerColorAction(
                                    frameIndex: frameIndex,
                                    id: _activePlayerId!,
                                    from: oldColor,
                                    to: color,
                                  ),
                                );
                              } else {
                                _history.push(
                                  ChangePlayerColorFromFrameAction(
                                    frameIndex: frameIndex,
                                    id: _activePlayerId!,
                                    from: oldColor,
                                    to: color,
                                  ),
                                );
                              }

                              setState(() {
                                _lastTappedPlayerColor = color;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border:
                                    _activePlayerId != null &&
                                        currentFrame.getPlayerById(_activePlayerId!)?.color == color
                                    ? Border.all(color: AppTheme.lightGrey, width: 2)
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows single-character label dialog for player
  void _showPlayerLabelDialog() {
    if (_activePlayerId == null) return;
    final player = currentFrame.getPlayerById(_activePlayerId!);
    final controller = TextEditingController(text: player?.label ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Player Label'),
        content: TextField(
          controller: controller,
          maxLength: 1,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter 1 character (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final label = controller.text.trim();
              if (player != null) {
                setState(() {
                  player.label = label.isEmpty ? null : label;
                });
                _saveProject();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _duplicateLastAnnotation() {
    final annotations = _activeAnnotationList();
    if (annotations.isEmpty) return;
    const Offset delta = Offset(10, 10); // shift in cm coords
    final before = _cloneAnnotations(annotations);
    final dup = annotations.last.copy();
    dup.id = _newAnnotationId();
    dup.points = dup.points.map((p) => p + delta).toList();
    setState(() {
      annotations.add(dup);
    });
    _pushAnnotationHistoryIfChanged(before, _cloneAnnotations(annotations));
  }

  /// Shows color picker dialog for ball
  void _showBallColorPicker() {
    ColorChangeScope scope = ColorChangeScope.onlyThisFrame;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Ball Color'),
          content: Container(
            width: 280,
            height: 260,
            color: AppTheme.lightGrey,
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Only this frame'),
                      selected: scope == ColorChangeScope.onlyThisFrame,
                      onSelected: (_) => setDialogState(() => scope = ColorChangeScope.onlyThisFrame),
                    ),
                    ChoiceChip(
                      label: const Text('From this frame to end'),
                      selected: scope == ColorChangeScope.fromThisFrameToEnd,
                      onSelected: (_) => setDialogState(() => scope = ColorChangeScope.fromThisFrameToEnd),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 4,
                    children: AppTheme.editorColors
                        .map(
                          (color) => GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              if (_activeBallId == null) return;

                              final frameIndex = widget.project.frames.indexOf(currentFrame);
                              if (frameIndex < 0) return;

                              final ball = currentFrame.getBallById(_activeBallId!);
                              if (ball == null) return;

                              final oldColor = ball.color;
                              if (oldColor.toARGB32() == color.toARGB32()) {
                                return;
                              }

                              if (scope == ColorChangeScope.onlyThisFrame) {
                                _history.push(
                                  ChangeBallColorAction(
                                    frameIndex: frameIndex,
                                    id: _activeBallId!,
                                    from: oldColor,
                                    to: color,
                                  ),
                                );
                              } else {
                                _history.push(
                                  ChangeBallColorFromFrameAction(
                                    frameIndex: frameIndex,
                                    id: _activeBallId!,
                                    from: oldColor,
                                    to: color,
                                  ),
                                );
                              }

                              setState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border:
                                    _activeBallId != null && currentFrame.getBallById(_activeBallId!)?.color == color
                                    ? Border.all(color: AppTheme.lightGrey, width: 2)
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOARD TAP & DRAG INTERACTION HANDLERS
  // ══════════────────────────────────────────────────────────────────────────
  // Handles all touch/mouse interactions on the board:
  // - Tap: ball marker placement, path midpoint addition
  // - Drag: annotation drawing, eraser, object movement, path control editing

  void _handleBoardTap(Offset tapPos, Size size) {
    if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;

    // Path tracking toggle during paused playback while objects menu is open
    if (_isPausedPlayback && _objectsMenuOpen) {
      _togglePathTracking(tapPos, size);
      return;
    }

    if (!_objectsMenuOpen && !_annotationsMenuOpen) return;

    final clampedTap = _clampToInteractionBounds(tapPos, size);

    // Convert tap position to cm coordinates
    final tapCm = _screenToCm(clampedTap, size);

    // If adding player/ball, place object at tap location
    if (_addingObjectType == 'player') {
      _createPlayerAtLocation(tapCm);
      return;
    }
    if (_addingObjectType == 'ball') {
      _createBallAtLocation(tapCm);
      return;
    }

    // If in annotation mode, handle text and sector tool tap behavior
    if (_annotationsMenuOpen) {
      if (_activeAnnotationTool == AnnotationTool.text && !_eraserMode) {
        _handleTextAnnotationTap(tapCm, size);
        return;
      }
      if (_activeAnnotationTool == AnnotationTool.sector && _sectorToolNeedsTargetSelection) {
        if (_trySelectSectorTarget(tapCm, size)) return;
      }
      return;
    }

    final prev = _getPreviousFrame();
    if (prev == null) return;

    // Check if tapping on ball - if annotations menu is open, close it and open ball menu
    if (_pendingBallMark == 'hit') {
      _placeBallHitAt(clampedTap, size);
      return;
    }
    bool tryAdd(String label, Offset startCm, Offset endCm, List<Offset> points) {
      if (points.isNotEmpty) return false;
      final pathLengthCm = (endCm - startCm).distance;
      if (pathLengthCm <= 50) return false;
      final midCm = (startCm + endCm) / 2;
      final midScreen = _toScreenPosition(midCm, size);
      if ((tapPos - midScreen).distance < 24) {
        final fromPoints = List<Offset>.from(points); // Empty list
        setState(() {
          points.add(midCm);
          // ensure the project's frame list has the updated frame object
          final idx = widget.project.frames.indexOf(currentFrame);
          if (idx >= 0) widget.project.frames[idx] = currentFrame;
          _pathRevision++;
        });
        final idx = widget.project.frames.indexOf(currentFrame);
        PathEngine.invalidateCacheFor(idx, label);

        // Save to history
        if (idx >= 0) {
          final toPoints = List<Offset>.from(points);
          _history.push(
            EditPathControlPointsAction(frameIndex: idx, entityId: label, fromPoints: fromPoints, toPoints: toPoints),
          );
        }

        _saveProject();
        return true;
      }
      return false;
    }

    if (tryAdd("P1", prev.p1, currentFrame.p1, currentFrame.p1PathPoints)) return;
    if (tryAdd("P2", prev.p2, currentFrame.p2, currentFrame.p2PathPoints)) return;
    if (tryAdd("P3", prev.p3, currentFrame.p3, currentFrame.p3PathPoints)) return;
    if (tryAdd("P4", prev.p4, currentFrame.p4, currentFrame.p4PathPoints)) return;
    // For balls, use the selected ball if available; otherwise fall back to the first ball
    if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
      final prevBall = prev.getBallById(_activeBallId!);
      final currBall = currentFrame.getBallById(_activeBallId!);
      if (prevBall != null && currBall != null) {
        if (tryAdd("BALL", prevBall.position, currBall.position, currBall.pathPoints)) return;
      }
    }
    if (tryAdd("BALL", prev.ball, currentFrame.ball, currentFrame.ballPathPoints)) return;

    if (_showModifierMenu || _showPlayerMenu || _activePlayerId != null || _activeBallId != null) {
      setState(() {
        _closeObjectMenusAndSelection();
      });
    }
  }

  /// Select a sector target (ball or zone) from a tap/drag position.
  /// Returns true if a target was selected.
  bool _trySelectSectorTarget(Offset cmPos, Size size) {
    final pxPerCm = _cmToLogical(1.0, size).abs();
    final cmPerPx = pxPerCm == 0 ? 0.0 : (1.0 / pxPerCm);
    final zoneOutlineMarginCm = 5.0 * cmPerPx;
    final zoneOutlineToleranceCm = 50.0 + zoneOutlineMarginCm;
    final objectToleranceCm = 50.0 + zoneOutlineMarginCm;

    if (_sectorAttachmentType == _SectorAttachmentType.ball) {
      for (final ball in currentFrame.balls) {
        final distToBall = (cmPos - ball.position).distance;
        if (distToBall <= objectToleranceCm) {
          _selectSectorTarget(
            targetKey: 'ball_${ball.id}',
            attachmentId: ball.id,
            centerCm: ball.position,
            radiusCm: _objectAttachedSectorRadiusCm,
          );
          return true;
        }
      }
      return false;
    }

    if (_sectorAttachmentType == _SectorAttachmentType.player) {
      for (final player in currentFrame.players) {
        final distToPlayer = (cmPos - player.position).distance;
        if (distToPlayer <= objectToleranceCm) {
          _selectSectorTarget(
            targetKey: 'player_${player.id}',
            attachmentId: player.id,
            centerCm: player.position,
            radiusCm: _objectAttachedSectorRadiusCm,
          );
          return true;
        }
      }
      return false;
    }

    // Build list of available zones based on project type
    List<Map<String, dynamic>> zones = [];

    if (widget.project.projectType == ProjectType.play) {
      // Play scenario: Use standard court zones (center-based)
      zones = [
        {'type': 'innerCircle', 'center': Offset.zero, 'radius': _settings.innerCircleRadiusCm},
        {'type': 'outerCircle', 'center': Offset.zero, 'radius': _settings.outerCircleRadiusCm},
        {'type': 'outerBounds', 'center': Offset.zero, 'radius': _settings.outerBoundsRadiusCm},
      ];
    } else {
      // Training scenario: Use custom court zone elements
      if (widget.project.customCourtElements != null) {
        for (final element in widget.project.customCourtElements!) {
          if (element.type == CourtElementType.innerCircle ||
              element.type == CourtElementType.outerCircle ||
              element.type == CourtElementType.customCircle) {
            zones.add({
              'type':
                  '${element.type.toString().split('.').last}_${element.position.dx.toStringAsFixed(0)}_${element.position.dy.toStringAsFixed(0)}',
              'center': element.position,
              'radius': element.radius ?? 0,
            });
          }
        }
      }
    }

    // Check zones (±30cm tolerance) - only if no ball was selected
    for (final zone in zones) {
      final center = zone['center'] as Offset;
      final radius = zone['radius'] as double;
      final distFromZoneCenter = (cmPos - center).distance;
      final distanceToOutline = (distFromZoneCenter - radius).abs();

      if (distanceToOutline <= zoneOutlineToleranceCm) {
        final zoneKey = zone['type'] as String;
        _selectSectorTarget(targetKey: zoneKey, attachmentId: zoneKey, centerCm: center, radiusCm: radius);
        return true;
      }
    }

    return false;
  }

  void _selectSectorTarget({
    required String targetKey,
    required String attachmentId,
    required Offset centerCm,
    required double radiusCm,
  }) {
    setState(() {
      _selectedSectorTarget = targetKey;
      _selectedSectorAttachmentId = attachmentId;
      _selectedSectorCenterCm = centerCm;
      _selectedSectorRadiusCm = radiusCm;
      _sectorTargetHighlightActive = true;
      _pendingAnnotationPoints.clear();
      _currentDragPos = centerCm;
      _stagedAnnotations.clear();
      _sectorToolNeedsTargetSelection = false;
    });
  }

  double _normalizeAngleDelta(double delta) {
    while (delta <= -math.pi) {
      delta += 2 * math.pi;
    }
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    return delta;
  }

  double _normalizeAnglePositive(double angle) {
    while (angle < 0) {
      angle += 2 * math.pi;
    }
    while (angle >= 2 * math.pi) {
      angle -= 2 * math.pi;
    }
    return angle;
  }

  bool _isAngleWithinSector(double angle, double startAngle, double endAngle) {
    final sweep = endAngle - startAngle;
    if (sweep >= 0) {
      final delta = _normalizeAnglePositive(angle - startAngle);
      return delta <= sweep;
    }

    final delta = _normalizeAnglePositive(startAngle - angle);
    return delta <= -sweep;
  }

  /// Get the court zone containing a point (for sector tool)
  /// Returns zone type and radius, prioritizing inner zones
  Map<String, dynamic>? _getContainingZone(Offset point) {
    final distFromCenter = point.distance;

    // Check zones from inner to outer
    if (distFromCenter <= _settings.innerCircleRadiusCm) {
      return {'type': 'innerCircle', 'radius': _settings.innerCircleRadiusCm};
    } else if (distFromCenter <= _settings.outerCircleRadiusCm) {
      return {'type': 'outerCircle', 'radius': _settings.outerCircleRadiusCm};
    } else if (distFromCenter <= _settings.outerBoundsRadiusCm) {
      return {'type': 'outerBounds', 'radius': _settings.outerBoundsRadiusCm};
    }

    return null; // Point is outside all zones
  }

  Rect? _textBoundsPx(Annotation annotation, Size size) {
    final label = annotation.text ?? '';
    if (label.isEmpty || annotation.points.isEmpty) return null;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: annotation.fontSize ?? _annotationTextSize,
          fontFamily: _annotationTextFontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final centerPx = _toScreenPosition(annotation.points.first, size);
    return Rect.fromCenter(center: centerPx, width: textPainter.width, height: textPainter.height);
  }

  Annotation? _findTextAnnotationAt(Offset pointCm, Size size) {
    final annotations = _activeAnnotationList();
    for (final ann in annotations.reversed) {
      if (ann.type != AnnotationType.text) continue;
      final rect = _textBoundsPx(ann, size);
      if (rect == null) continue;
      final pointPx = _toScreenPosition(pointCm, size);
      if (rect.inflate(_cmToLogical(20, size).abs()).contains(pointPx)) {
        return ann;
      }
    }
    return null;
  }

  Annotation? _findAnnotationAt(Offset pointCm, Size size) {
    final annotations = _activeAnnotationList();
    for (final ann in annotations.reversed) {
      if (_isPointNearAnnotation(pointCm, ann, 30.0, size)) {
        return ann;
      }
    }
    return null;
  }

  bool _isMarkerLineStyle(AnnotationLineStyle style) {
    return style == AnnotationLineStyle.markerX ||
        style == AnnotationLineStyle.markerPylon ||
        style == AnnotationLineStyle.markerDot;
  }

  Future<void> _editAnnotationStyle(Annotation annotation, Size size) async {
    final annotations = _activeAnnotationList();
    final before = _cloneAnnotations(annotations);

    Color selectedColor = annotation.color;
    double alpha = selectedColor.a.clamp(0.0, 1.0);
    double selectedStroke = annotation.strokeWidthCm;
    AnnotationLineStyle selectedLineStyle = annotation.lineStyle;
    bool selectedFilled = annotation.filled;
    bool deleteRequested = false;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isMarkerAnnotation = annotation.type == AnnotationType.line && _isMarkerLineStyle(annotation.lineStyle);
          final supportsFill = annotation.type == AnnotationType.circle || annotation.type == AnnotationType.rectangle;
          final supportsLineStyle =
              (annotation.type == AnnotationType.line || annotation.type == AnnotationType.curvedLine) &&
              !isMarkerAnnotation;
          final supportsMarkerStyle = isMarkerAnnotation;
          return AlertDialog(
            backgroundColor: AppTheme.darkGrey,
            title: const Text('Annotation Style', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppTheme.editorColors.map((color) {
                      final bool selected = selectedColor.withValues(alpha: 1.0).toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setStateDialog(() {
                          selectedColor = color.withValues(alpha: alpha);
                        }),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Transparency', style: TextStyle(color: Colors.white70)),
                  Slider(
                    value: alpha,
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    label: '${(alpha * 100).round()}%',
                    onChanged: (value) => setStateDialog(() {
                      alpha = value;
                      selectedColor = selectedColor.withValues(alpha: alpha);
                    }),
                  ),
                  const SizedBox(height: 4),
                  const Text('Stroke Size', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _annotationStrokeOptionsCm.map((w) {
                      final selected = (selectedStroke - w).abs() < 0.001;
                      return ChoiceChip(
                        label: Text(w.toStringAsFixed(0)),
                        selected: selected,
                        onSelected: (_) => setStateDialog(() => selectedStroke = w),
                      );
                    }).toList(),
                  ),
                  if (supportsFill) ...[
                    const SizedBox(height: 12),
                    const Text('Fill', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      value: selectedFilled,
                      onChanged: (v) => setStateDialog(() => selectedFilled = v),
                      title: const Text('Filled', style: TextStyle(color: Colors.white)),
                      dense: true,
                    ),
                  ],
                  if (supportsLineStyle) ...[
                    const SizedBox(height: 10),
                    const Text('Line Style', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _annotationLineStyleOptions.map((style) {
                        final selected = selectedLineStyle == style;
                        return ChoiceChip(
                          avatar: Icon(
                            _iconForLineStyle(style),
                            size: style == AnnotationLineStyle.markerDot ? 14 : 18,
                          ),
                          label: Text(_lineStyleLabel(style)),
                          selected: selected,
                          onSelected: (_) => setStateDialog(() => selectedLineStyle = style),
                        );
                      }).toList(),
                    ),
                  ],
                  if (supportsMarkerStyle) ...[
                    const SizedBox(height: 10),
                    const Text('Marker Style', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _annotationMarkerStyleOptions.map((style) {
                        final selected = selectedLineStyle == style;
                        return ChoiceChip(
                          avatar: Icon(
                            _iconForLineStyle(style),
                            size: style == AnnotationLineStyle.markerDot ? 14 : 18,
                          ),
                          label: Text(_lineStyleLabel(style)),
                          selected: selected,
                          onSelected: (_) => setStateDialog(() => selectedLineStyle = style),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  deleteRequested = true;
                  Navigator.pop(context, true);
                },
                child: const Text('Delete'),
              ),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply')),
            ],
          );
        },
      ),
    );

    if (accepted != true) return;

    if (deleteRequested) {
      setState(() {
        annotations.remove(annotation);
      });
      _pushAnnotationHistoryIfChanged(before, _cloneAnnotations(annotations));
      return;
    }

    setState(() {
      annotation
        ..color = selectedColor
        ..strokeWidthCm = selectedStroke
        ..filled = selectedFilled
        ..lineStyle = selectedLineStyle;
      if (_isMarkerLineStyle(selectedLineStyle)) {
        _annotationMarkerStyle = selectedLineStyle;
      }
    });

    _pushAnnotationHistoryIfChanged(before, _cloneAnnotations(annotations));
  }

  Future<_AnnotationTextDialogResult?> _promptForAnnotationText({String initialText = '', double? initialSize}) async {
    final controller = TextEditingController(text: initialText);
    double size = initialSize ?? _annotationTextSize;

    return showDialog<_AnnotationTextDialogResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(initialText.isEmpty ? 'Add Text' : 'Edit Text'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Text content'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Size', style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _annotationTextSizeOptions.map((opt) {
                    final isActive = opt == size;
                    return ChoiceChip(
                      label: Text(opt.toStringAsFixed(0)),
                      selected: isActive,
                      onSelected: (_) => setStateDialog(() => size = opt),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, _AnnotationTextDialogResult(controller.text, size)),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleTextAnnotationTap(Offset positionCm, Size size) async {
    final result = await _promptForAnnotationText(initialSize: _annotationTextSize);
    final textValue = result?.text.trim();
    if (textValue == null || textValue.isEmpty) return;

    final chosenSize = result!.size;
    final annotations = _activeAnnotationList();
    final before = _cloneAnnotations(annotations);
    setState(() {
      _annotationTextSize = chosenSize;
      annotations.add(
        Annotation(
          type: AnnotationType.text,
          color: _annotationColor,
          points: [positionCm],
          text: textValue,
          fontSize: chosenSize,
          strokeWidthCm: _annotationStrokeCm,
        ),
      );
    });
    _pushAnnotationHistoryIfChanged(before, _cloneAnnotations(annotations));
  }

  Future<void> _editTextAnnotation(Annotation annotation, Size size) async {
    final result = await _promptForAnnotationText(
      initialText: annotation.text ?? '',
      initialSize: annotation.fontSize ?? _annotationTextSize,
    );
    final textValue = result?.text.trim();
    if (textValue == null || textValue.isEmpty) return;

    final chosenSize = result!.size;
    final hasChanges =
        textValue != (annotation.text ?? '') || chosenSize != (annotation.fontSize ?? _annotationTextSize);
    if (!hasChanges) return;

    final annotations = _activeAnnotationList();
    final before = _cloneAnnotations(annotations);
    setState(() {
      annotation
        ..text = textValue
        ..fontSize = chosenSize;
    });
    _pushAnnotationHistoryIfChanged(before, _cloneAnnotations(annotations));
  }

  /// Check if a point is near an annotation (for selecting it with move tool)
  bool _isPointNearAnnotation(Offset point, Annotation ann, double toleranceCm, Size size) {
    if (ann.type == AnnotationType.line && ann.points.length >= 2) {
      final start = ann.points[0];
      final end = ann.points[1];
      final dist = _distanceToLineSegment(point, start, end);
      return dist <= toleranceCm;
    } else if (ann.type == AnnotationType.curvedLine && ann.points.length >= 2) {
      final dist = _distanceToCurvedLineAnnotation(point, ann);
      return dist <= toleranceCm;
    } else if (ann.type == AnnotationType.circle && ann.points.length >= 2) {
      final center = ann.points[0];
      final radiusPoint = ann.points[1];
      final radius = (radiusPoint - center).distance;
      final distToCenter = (point - center).distance;
      final circleWidthCm = ann.strokeWidthCm;
      return (distToCenter - radius).abs() <= (toleranceCm + circleWidthCm / 2);
    } else if (ann.type == AnnotationType.rectangle && ann.points.length >= 2) {
      final a = ann.points[0];
      final b = ann.points[1];
      final topLeft = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
      final bottomRight = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
      final tl = topLeft;
      final tr = Offset(bottomRight.dx, topLeft.dy);
      final bl = Offset(topLeft.dx, bottomRight.dy);
      final br = bottomRight;
      final dTop = _distanceToLineSegment(point, tl, tr);
      final dBottom = _distanceToLineSegment(point, bl, br);
      final dLeft = _distanceToLineSegment(point, tl, bl);
      final dRight = _distanceToLineSegment(point, tr, br);
      final minD = math.min(math.min(dTop, dBottom), math.min(dLeft, dRight));
      return minD <= toleranceCm;
    } else if (ann.type == AnnotationType.sector && ann.points.length >= 2) {
      // For sector, check if point is within the sector area
      final center = ann.points[0];
      final radiusPoint = ann.points[1];
      final radius = (radiusPoint - center).distance;
      final distToCenter = (point - center).distance;

      if (distToCenter > radius + toleranceCm) return false;
      if (distToCenter < radius - toleranceCm) {
        // Check if angle is within sector
        if (ann.startAngle != null && ann.endAngle != null) {
          final vec = point - center;
          final angle = math.atan2(vec.dy, vec.dx);
          final start = ann.startAngle!;
          final end = ann.endAngle!;

          // Normalize angles to [0, 2π]
          double normalizedAngle = angle;
          while (normalizedAngle < 0) {
            normalizedAngle += 2 * math.pi;
          }
          double normalizedStart = start;
          while (normalizedStart < 0) {
            normalizedStart += 2 * math.pi;
          }
          double normalizedEnd = end;
          while (normalizedEnd < 0) {
            normalizedEnd += 2 * math.pi;
          }

          if (normalizedStart <= normalizedEnd) {
            return normalizedAngle >= normalizedStart && normalizedAngle <= normalizedEnd;
          } else {
            return normalizedAngle >= normalizedStart || normalizedAngle <= normalizedEnd;
          }
        }
      }
      return distToCenter <= radius + toleranceCm;
    } else if (ann.type == AnnotationType.text && ann.points.isNotEmpty) {
      final rect = _textBoundsPx(ann, size);
      if (rect == null) return false;
      final pointPx = _toScreenPosition(point, size);
      final tolerancePx = _cmToLogical(toleranceCm, size).abs();
      return rect.inflate(tolerancePx).contains(pointPx);
    }
    return false;
  }

  /// Handle drag start for line drawing
  void _handleAnnotationDragStart(DragStartDetails details, Size size) {
    if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
    if (!_annotationsMenuOpen) return;
    _annotationGestureStartSnapshot = null;
    if (_eraserMode) {
      _annotationGestureStartSnapshot = _cloneAnnotations(_activeAnnotationList());
      // Start eraser drag
      if (_showModifierMenu) {
        setState(() => _showModifierMenu = false);
      }
      final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
      final localPos = box.globalToLocal(details.globalPosition);
      final clampedPos = _clampToInteractionBounds(localPos, size);
      final cmPos = _screenToCm(clampedPos, size);
      setState(() {
        _eraserPosCm = cmPos;
      });
      return;
    }

    // Handle move tool - find annotation under cursor
    if (_activeAnnotationTool == AnnotationTool.move) {
      if (_showModifierMenu) {
        setState(() => _showModifierMenu = false);
      }
      final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
      final localPos = box.globalToLocal(details.globalPosition);
      final clampedPos = _clampToInteractionBounds(localPos, size);
      final cmPos = _screenToCm(clampedPos, size);
      final annotations = _activeAnnotationList();

      // Find annotation under cursor (check in reverse order so top annotations are selected first)
      for (final ann in annotations.reversed) {
        if (_isPointNearAnnotation(cmPos, ann, 30.0, size)) {
          _annotationGestureStartSnapshot = _cloneAnnotations(annotations);
          setState(() {
            _draggingAnnotation = ann;
            _annotationDragOffset = ann.points.isNotEmpty ? ann.points.first - cmPos : Offset.zero;
          });
          break;
        }
      }
      return;
    }

    if (_activeAnnotationTool == AnnotationTool.text) return;

    if (_activeAnnotationTool == AnnotationTool.none) return;

    // Close ball modifier menu if open and annotations are being touched
    if (_showModifierMenu) {
      setState(() => _showModifierMenu = false);
    }

    // Get board position relative to the board widget to avoid coordinate offset
    final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    final clampedPos = _clampToInteractionBounds(localPos, size);
    final cmPos = _screenToCm(clampedPos, size);

    // Special handling for sector tool - detect zone and ball taps for target selection
    if (_activeAnnotationTool == AnnotationTool.sector && _sectorToolNeedsTargetSelection) {
      if (_trySelectSectorTarget(cmPos, size)) return;
      return; // If not on a ball or zone outline, don't do anything
    }

    final startPoint = (_annotationSnappingEnabled && _shouldSnapDuringCreation(_activeAnnotationTool))
        ? _applyAnnotationCreationSnap(cmPos, size)
        : cmPos;

    _annotationGestureStartSnapshot = _cloneAnnotations(_activeAnnotationList());

    setState(() {
      _pendingAnnotationPoints.clear();
      _pendingAnnotationPoints.add(startPoint);
      _currentDragPos = startPoint;
      _stagedAnnotations.clear();
      if (_activeAnnotationTool == AnnotationTool.sector &&
          _selectedSectorCenterCm != null &&
          _selectedSectorRadiusCm != null) {
        final center = _selectedSectorCenterCm!;
        final startVec = startPoint - center;
        final startAngle = math.atan2(startVec.dy, startVec.dx);
        _sectorDragStartAngle = startAngle;
        _sectorDragPrevAngle = startAngle;
        _sectorDragSweepAngle = 0.0;
        _sectorDragEndAngle = startAngle;
      }
    });
  }

  /// Handle drag update for live line preview and erasing
  void _handleAnnotationDragUpdate(DragUpdateDetails details, Size size) {
    if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
    if (!_annotationsMenuOpen) return;

    final currentPos = details.globalPosition;
    // Get board position relative to the board widget
    final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
    final localPos = box.globalToLocal(currentPos);
    final clampedPos = _clampToInteractionBounds(localPos, size);
    final cmPos = _screenToCm(clampedPos, size);

    if (_eraserMode) {
      // Close ball modifier menu if open and eraser is being used
      if (_showModifierMenu) {
        setState(() => _showModifierMenu = false);
      }

      // Update eraser position and instantly delete annotations touched by circle
      final annotations = _activeAnnotationList();
      setState(() {
        _eraserPosCm = cmPos;
        annotations.removeWhere((ann) => _isAnnotationTouchedByCircle(ann, cmPos, _annotationEraserRadiusCm, size));
      });
    } else if (!_eraserMode && _activeAnnotationTool == AnnotationTool.text) {
      return;
    } else if (_activeAnnotationTool == AnnotationTool.move && _draggingAnnotation != null) {
      // Update annotation position while dragging with snapping
      final annotations = _activeAnnotationList();
      setState(() {
        final offset = _annotationDragOffset ?? Offset.zero;
        var newPos = cmPos + offset;

        if (_draggingAnnotation!.points.isNotEmpty) {
          final draggingId = _draggingAnnotation!.id;
          final idx = draggingId != null
              ? annotations.indexWhere((annotation) => annotation.id == draggingId)
              : annotations.indexOf(_draggingAnnotation!);
          if (idx != -1) {
            // Apply snapping to the new position
            if (_annotationSnappingEnabled) {
              newPos = _applyAnnotationSnap(newPos, _draggingAnnotation!, annotations, size);
            }

            final delta = newPos - _draggingAnnotation!.points.first;
            final updated = _draggingAnnotation!.copy();
            updated.points = updated.points.map((p) => p + delta).toList();
            _draggingAnnotation = updated;
            final nextAnnotations = List<Annotation>.from(annotations);
            nextAnnotations[idx] = updated;
            if (_isTemporaryPlaybackAnnotationMode) {
              _setPlaybackSessionAnnotationsForFrame(_playbackDisplayFrameIndex(), nextAnnotations);
            } else {
              currentFrame.annotations = nextAnnotations;
            }
          }
        }
      });
    } else if (_pendingAnnotationPoints.isNotEmpty && _activeAnnotationTool != AnnotationTool.none) {
      final previewPos = (_annotationSnappingEnabled && _shouldSnapDuringCreation(_activeAnnotationTool))
          ? _applyAnnotationCreationSnap(cmPos, size)
          : cmPos;

      // Update preview position for active tool
      setState(() {
        if (_activeAnnotationTool == AnnotationTool.freehand) {
          if ((_pendingAnnotationPoints.last - previewPos).distance >= 1.4) {
            _pendingAnnotationPoints.add(previewPos);
          }
        }

        _currentDragPos = previewPos;
        _stagedAnnotations.clear();
        if (_activeAnnotationTool == AnnotationTool.freehand) {
          final previewPoints = <Offset>[..._pendingAnnotationPoints];
          if (previewPoints.isEmpty) {
            previewPoints.add(previewPos);
          } else if ((previewPoints.last - previewPos).distance >= 0.001) {
            previewPoints.add(previewPos);
          }
          if (previewPoints.length >= 2) {
            _stagedAnnotations.add(
              Annotation(
                type: AnnotationType.curvedLine,
                color: _annotationColor,
                points: previewPoints,
                strokeWidthCm: _annotationStrokeCm,
                lineStyle: _freehandLineStyle,
              ),
            );
          }
        } else if (_activeAnnotationTool == AnnotationTool.rectangle) {
          _stagedAnnotations.add(
            Annotation(
              type: AnnotationType.rectangle,
              color: _annotationColor,
              points: [_pendingAnnotationPoints.first, previewPos],
              filled: _rectangleFilled,
              strokeWidthCm: _annotationStrokeCm,
            ),
          );
        } else if (_activeAnnotationTool == AnnotationTool.circle) {
          _stagedAnnotations.add(
            Annotation(
              type: AnnotationType.circle,
              color: _annotationColor,
              points: [_pendingAnnotationPoints.first, previewPos],
              filled: _circleFilled,
              strokeWidthCm: _annotationStrokeCm,
            ),
          );
        } else if (_activeAnnotationTool == AnnotationTool.sector &&
            _selectedSectorCenterCm != null &&
            _selectedSectorRadiusCm != null) {
          // Preview sector annotation based on selected zone
          final center = _selectedSectorCenterCm!;
          final radius = _selectedSectorRadiusCm!;
          final radiusPoint = center + Offset(radius, 0);

          // Calculate angles from center to start and current drag position
          final startPoint = _pendingAnnotationPoints.first;
          final startVec = startPoint - center;
          final startAngle = _sectorDragStartAngle ?? math.atan2(startVec.dy, startVec.dx);
          final currentVec = cmPos - center;
          final currentAngle = math.atan2(currentVec.dy, currentVec.dx);

          if (_sectorDragPrevAngle != null) {
            final delta = _normalizeAngleDelta(currentAngle - _sectorDragPrevAngle!);
            _sectorDragSweepAngle += delta;
            _sectorDragSweepAngle = _sectorDragSweepAngle.clamp(-2 * math.pi, 2 * math.pi);
          }
          _sectorDragPrevAngle = currentAngle;
          _sectorDragStartAngle = startAngle;
          final endAngle = startAngle + _sectorDragSweepAngle;
          _sectorDragEndAngle = endAngle;

          _stagedAnnotations.add(
            Annotation(
              type: AnnotationType.sector,
              color: _annotationColor,
              points: [center, radiusPoint],
              filled: true,
              strokeWidthCm: _annotationStrokeCm,
              circleAnnotationId: _selectedSectorTarget,
              sectorAttachmentType: _storageValueForSectorAttachment(_sectorAttachmentType),
              sectorAttachmentId: _selectedSectorAttachmentId,
              startAngle: startAngle,
              endAngle: endAngle,
            ),
          );
        }
      });
    }
  }

  /// Clear all annotations on the current frame
  void _clearCurrentFrameAnnotations() {
    if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
    final annotations = _activeAnnotationList();
    if (annotations.isEmpty) return;
    final before = _cloneAnnotations(annotations);
    setState(() {
      annotations.clear();
      _stagedAnnotations.clear();
      _erasingAnnotations.clear();
      _eraserPosCm = null;
    });
    _pushAnnotationHistoryIfChanged(before, _cloneAnnotations(annotations));
  }

  /// Check if an annotation intersects with the eraser circle
  bool _isAnnotationTouchedByCircle(Annotation ann, Offset eraserCenterCm, double eraserRadiusCm, Size size) {
    if ((ann.type == AnnotationType.line || ann.type == AnnotationType.curvedLine) && ann.points.length >= 2) {
      final dist = ann.type == AnnotationType.curvedLine
          ? _distanceToCurvedLineAnnotation(eraserCenterCm, ann)
          : _distanceToLineSegment(eraserCenterCm, ann.points[0], ann.points[1]);
      return dist <= eraserRadiusCm;
    } else if (ann.type == AnnotationType.circle && ann.points.length >= 2) {
      final center = ann.points[0];
      final radiusPoint = ann.points[1];
      final radius = (radiusPoint - center).distance;
      final distToCenter = (eraserCenterCm - center).distance;
      // Check if annotation circle overlaps with eraser circle
      final circleWidthCm = ann.strokeWidthCm;
      return (distToCenter - radius).abs() <= (eraserRadiusCm + circleWidthCm / 2);
    } else if (ann.type == AnnotationType.rectangle && ann.points.length >= 2) {
      final a = ann.points[0];
      final b = ann.points[1];
      final topLeft = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
      final bottomRight = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
      final tl = topLeft;
      final tr = Offset(bottomRight.dx, topLeft.dy);
      final bl = Offset(topLeft.dx, bottomRight.dy);
      final br = bottomRight;
      // Check distance to each edge of rectangle
      final dTop = _distanceToLineSegment(eraserCenterCm, tl, tr);
      final dBottom = _distanceToLineSegment(eraserCenterCm, bl, br);
      final dLeft = _distanceToLineSegment(eraserCenterCm, tl, bl);
      final dRight = _distanceToLineSegment(eraserCenterCm, tr, br);
      final minD = math.min(math.min(dTop, dBottom), math.min(dLeft, dRight));
      return minD <= eraserRadiusCm;
    } else if (ann.type == AnnotationType.sector && ann.points.length >= 2) {
      final center = ann.points[0];
      final radiusPoint = ann.points[1];
      final radius = (radiusPoint - center).distance;
      final distToCenter = (eraserCenterCm - center).distance;
      if (ann.startAngle == null || ann.endAngle == null) return false;
      // Radial overlap check
      if (distToCenter - eraserRadiusCm > radius) return false;
      if (distToCenter <= eraserRadiusCm) return true; // eraser covers center

      final theta = math.atan2(eraserCenterCm.dy - center.dy, eraserCenterCm.dx - center.dx);
      final ratio = (eraserRadiusCm / distToCenter).clamp(0.0, 1.0);
      final halfAngle = math.asin(ratio);
      final startAngle = ann.startAngle!;
      final endAngle = ann.endAngle!;

      // Check if any part of the eraser circle intersects the sector sweep
      return _isAngleWithinSector(theta, startAngle, endAngle) ||
          _isAngleWithinSector(theta - halfAngle, startAngle, endAngle) ||
          _isAngleWithinSector(theta + halfAngle, startAngle, endAngle);
    } else if (ann.type == AnnotationType.text && ann.points.isNotEmpty) {
      final rect = _textBoundsPx(ann, size);
      if (rect == null) return false;
      final eraserCenterPx = _toScreenPosition(eraserCenterCm, size);
      final eraserRadiusPx = _cmToLogical(eraserRadiusCm, size).abs();
      return rect.inflate(eraserRadiusPx).contains(eraserCenterPx);
    }
    return false;
  }

  /// Calculate distance from a point to a line segment
  double _distanceToLineSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final abDot = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abDot == 0) return ap.distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abDot).clamp(0.0, 1.0);
    final closest = a + Offset(ab.dx * t, ab.dy * t);
    return (p - closest).distance;
  }

  double _distanceToCurvedLineAnnotation(Offset pointCm, Annotation annotation) {
    if (annotation.points.length < 2) {
      return double.infinity;
    }
    return _distanceToPolyline(pointCm, annotation.points);
  }

  double _distanceToPolyline(Offset p, List<Offset> points) {
    if (points.length < 2) {
      return double.infinity;
    }

    var best = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final d = _distanceToLineSegment(p, points[i], points[i + 1]);
      if (d < best) {
        best = d;
      }
    }
    return best;
  }

  double _polylineLength(List<Offset> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  List<Offset> _dedupeNearPoints(List<Offset> points, {double minDistanceCm = 0.6}) {
    if (points.length < 2) return List<Offset>.from(points);
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      if ((points[i] - result.last).distance >= minDistanceCm) {
        result.add(points[i]);
      }
    }
    if ((result.last - points.last).distance > 0.001) {
      result.add(points.last);
    }
    return result;
  }

  List<Offset> _rdpSimplify(List<Offset> points, double epsilonCm) {
    if (points.length < 3) return List<Offset>.from(points);

    var maxDistance = 0.0;
    var index = 0;
    final first = points.first;
    final last = points.last;

    for (var i = 1; i < points.length - 1; i++) {
      final d = _distanceToLineSegment(points[i], first, last);
      if (d > maxDistance) {
        maxDistance = d;
        index = i;
      }
    }

    if (maxDistance <= epsilonCm) {
      return [first, last];
    }

    final left = _rdpSimplify(points.sublist(0, index + 1), epsilonCm);
    final right = _rdpSimplify(points.sublist(index), epsilonCm);
    return [...left.take(left.length - 1), ...right];
  }

  List<Offset> _chaikinSmooth(List<Offset> points, int iterations) {
    var current = List<Offset>.from(points);
    for (var iter = 0; iter < iterations; iter++) {
      if (current.length < 3) break;
      final next = <Offset>[current.first];
      for (var i = 0; i < current.length - 1; i++) {
        final p0 = current[i];
        final p1 = current[i + 1];
        next.add(Offset.lerp(p0, p1, 0.25)!);
        next.add(Offset.lerp(p0, p1, 0.75)!);
      }
      next.add(current.last);
      current = next;
    }
    return current;
  }

  List<Offset> _downsamplePoints(List<Offset> points, int maxPoints) {
    if (points.length <= maxPoints || maxPoints < 2) return points;
    final result = <Offset>[points.first];
    final stride = (points.length - 1) / (maxPoints - 1);
    for (var i = 1; i < maxPoints - 1; i++) {
      final idx = (i * stride).round().clamp(1, points.length - 2);
      result.add(points[idx]);
    }
    result.add(points.last);
    return result;
  }

  List<Offset> _smoothFreehandPoints(List<Offset> rawPoints) {
    var points = _dedupeNearPoints(rawPoints, minDistanceCm: 0.5);
    if (points.length < 2) return points;

    final totalLength = _polylineLength(points);
    final epsilon = totalLength < 120
        ? 1.6
        : totalLength < 260
        ? 2.2
        : 3.0;

    points = _rdpSimplify(points, epsilon);
    if (points.length < 2) return points;

    final iterations = totalLength < 160
        ? 1
        : totalLength < 380
        ? 2
        : 3;

    points = _chaikinSmooth(points, iterations);
    points = _dedupeNearPoints(points, minDistanceCm: 0.35);
    points = _downsamplePoints(points, 120);
    return points;
  }

  /// Apply snapping to annotation position based on nearby annotations
  Offset _applyAnnotationSnap(Offset newPos, Annotation dragged, List<Annotation> allAnnotations, Size size) {
    final thresholdCm = _snapThresholdCm(size);
    final anchors = _annotationAnchorPoints(dragged, newPos);
    final candidates = <Offset>[
      ..._snapPointsFromAnnotations(allAnnotations, exclude: dragged),
      ..._snapPointsFromCourtAndObjects(),
    ];

    double bestDist = thresholdCm;
    Offset bestDelta = Offset.zero;
    Offset? bestTarget;

    for (final anchor in anchors) {
      for (final target in candidates) {
        final d = (target - anchor).distance;
        if (d < bestDist) {
          bestDist = d;
          bestDelta = target - anchor;
          bestTarget = target;
        }
      }
    }

    if (bestDist < thresholdCm) {
      _triggerSnapPulse(bestTarget!);
      return newPos + bestDelta;
    }

    return newPos;
  }

  bool _shouldSnapDuringCreation(AnnotationTool tool) {
    return tool == AnnotationTool.line ||
        tool == AnnotationTool.marker ||
        tool == AnnotationTool.circle ||
        tool == AnnotationTool.rectangle;
  }

  double _snapThresholdCm(Size size) {
    final pxPerCm = _cmToLogical(1.0, size).abs();
    if (pxPerCm <= 0) return 20.0;
    return 20.0 / pxPerCm;
  }

  Offset _applyAnnotationCreationSnap(Offset pointCm, Size size) {
    final thresholdCm = _snapThresholdCm(size);
    final candidates = <Offset>[
      ..._snapPointsFromAnnotations(_activeAnnotationList()),
      ..._snapPointsFromCourtAndObjects(),
    ];

    double bestDist = thresholdCm;
    Offset? best;
    for (final target in candidates) {
      final dist = (target - pointCm).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = target;
      }
    }

    if (best != null) {
      _triggerSnapPulse(best);
      return best;
    }
    return pointCm;
  }

  void _triggerSnapPulse(Offset cmPoint) {
    // Only fire a new burst when the snap target actually changes
    if (_lastSnapPointCm != null && (_lastSnapPointCm! - cmPoint).distance < 2.0) return;
    _lastSnapPointCm = cmPoint;
    _snapPulseController.forward(from: 0.0);
  }

  /// Get anchor points from the dragged annotation (center, endpoints, corners)
  List<Offset> _annotationAnchorPoints(Annotation annotation, Offset newPos) {
    final anchors = <Offset>[];

    if (annotation.points.isEmpty) return anchors;

    // Calculate delta from original to new position
    final delta = newPos - annotation.points.first;

    // Add all points as anchors
    for (final point in annotation.points) {
      anchors.add(point + delta);
    }

    // For rectangles, add the four corners
    if (annotation.type == AnnotationType.rectangle && annotation.points.length >= 2) {
      final a = annotation.points[0] + delta;
      final b = annotation.points[1] + delta;
      final tl = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
      final tr = Offset(math.max(a.dx, b.dx), math.min(a.dy, b.dy));
      final bl = Offset(math.min(a.dx, b.dx), math.max(a.dy, b.dy));
      final br = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
      anchors.addAll([tl, tr, bl, br]);

      // Add midpoints of rectangle edges
      anchors.add((tl + tr) / 2); // top mid
      anchors.add((tr + br) / 2); // right mid
      anchors.add((br + bl) / 2); // bottom mid
      anchors.add((bl + tl) / 2); // left mid
    }

    // For lines, add midpoint
    if ((annotation.type == AnnotationType.line || annotation.type == AnnotationType.curvedLine) &&
        annotation.points.length >= 2) {
      final a = annotation.points[0] + delta;
      final b = annotation.points.last + delta;
      anchors.add((a + b) / 2);
    }

    // For circles, add center (already included as first point)
    // Could add points on the circle perimeter if needed

    return anchors;
  }

  List<Offset> _snapPointsFromAnnotations(List<Annotation> annotations, {Annotation? exclude}) {
    final points = <Offset>[];

    for (final ann in annotations) {
      if (exclude != null) {
        final sameId = ann.id != null && exclude.id != null && ann.id == exclude.id;
        if (identical(ann, exclude) || sameId) {
          continue;
        }
      }
      if (ann.points.isEmpty) continue;

      // Add all annotation points
      points.addAll(ann.points);

      // For rectangles, add corners and midpoints
      if (ann.type == AnnotationType.rectangle && ann.points.length >= 2) {
        final a = ann.points[0];
        final b = ann.points[1];
        final tl = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
        final tr = Offset(math.max(a.dx, b.dx), math.min(a.dy, b.dy));
        final bl = Offset(math.min(a.dx, b.dx), math.max(a.dy, b.dy));
        final br = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
        points.addAll([tl, tr, bl, br]);

        // Add midpoints of rectangle edges
        points.add((tl + tr) / 2); // top mid
        points.add((tr + br) / 2); // right mid
        points.add((br + bl) / 2); // bottom mid
        points.add((bl + tl) / 2); // left mid
      }

      // For lines, add midpoint
      if ((ann.type == AnnotationType.line || ann.type == AnnotationType.curvedLine) && ann.points.length >= 2) {
        points.add((ann.points[0] + ann.points.last) / 2);
      }

      if ((ann.type == AnnotationType.circle || ann.type == AnnotationType.sector) && ann.points.length >= 2) {
        final center = ann.points[0];
        final radiusPoint = ann.points[1];
        final radius = (radiusPoint - center).distance;
        if (radius > 0) {
          for (int i = 0; i < 8; i++) {
            final angle = (-math.pi / 2) + (math.pi / 4) * i;
            points.add(center + Offset(math.cos(angle) * radius, math.sin(angle) * radius));
          }
        }
      }
    }

    return points;
  }

  List<Offset> _snapPointsFromCourtAndObjects() {
    final points = <Offset>[Offset.zero];

    final customElements = widget.project.customCourtElements ?? const <CourtElement>[];
    for (final element in customElements) {
      if (!element.isVisible) continue;
      points.add(element.position);

      if (element.endPosition != null) {
        final end = element.endPosition!;
        points
          ..add(end)
          ..add((element.position + end) / 2);

        if (element.type == CourtElementType.customRectangle) {
          final tl = Offset(math.min(element.position.dx, end.dx), math.min(element.position.dy, end.dy));
          final tr = Offset(math.max(element.position.dx, end.dx), math.min(element.position.dy, end.dy));
          final bl = Offset(math.min(element.position.dx, end.dx), math.max(element.position.dy, end.dy));
          final br = Offset(math.max(element.position.dx, end.dx), math.max(element.position.dy, end.dy));
          points.addAll([tl, tr, bl, br]);
          points.addAll([(tl + tr) / 2, (tr + br) / 2, (br + bl) / 2, (bl + tl) / 2]);
        }
      }

      final radius = element.radius ?? 0.0;
      if (radius > 0 &&
          (element.type == CourtElementType.net ||
              element.type == CourtElementType.innerCircle ||
              element.type == CourtElementType.outerCircle ||
              element.type == CourtElementType.customCircle)) {
        for (int i = 0; i < 8; i++) {
          final angle = (-math.pi / 2) + (math.pi / 4) * i;
          points.add(element.position + Offset(math.cos(angle) * radius, math.sin(angle) * radius));
        }
      }
    }

    for (final player in currentFrame.players) {
      points.add(player.position);
    }
    for (final ball in currentFrame.balls) {
      points.add(ball.position);
    }

    return points;
  }

  /// Handle drag end for committing line or finishing erase
  void _handleAnnotationDragEnd(DragEndDetails details, Size size) {
    if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
    if (!_annotationsMenuOpen) return;

    if (_activeAnnotationTool == AnnotationTool.move) {
      // Finish moving annotation (keep selected for highlighting)
      final before = _annotationGestureStartSnapshot;
      final after = _cloneAnnotations(_activeAnnotationList());
      setState(() {
        _draggingAnnotation = null;
        _annotationDragOffset = null;
      });
      if (before != null) {
        _pushAnnotationHistoryIfChanged(before, after);
      }
      _annotationGestureStartSnapshot = null;
      return;
    }

    if (_eraserMode) {
      // Erasing already happened during drag, clear eraser position
      final before = _annotationGestureStartSnapshot;
      final after = _cloneAnnotations(_activeAnnotationList());
      setState(() {
        _erasingAnnotations.clear();
        _eraserPosCm = null;
      });
      if (before != null) {
        _pushAnnotationHistoryIfChanged(before, after);
      }
      _annotationGestureStartSnapshot = null;
      return;
    }

    if (_activeAnnotationTool == AnnotationTool.text) {
      _pendingAnnotationPoints.clear();
      _currentDragPos = null;
      _annotationGestureStartSnapshot = null;
      return;
    }

    if (_pendingAnnotationPoints.isNotEmpty && _currentDragPos != null) {
      final start = _pendingAnnotationPoints[0];
      final end = _currentDragPos!;

      final dist = (end - start).distance;
      Annotation? ann;

      // Special handling for sector tool - create if zone was selected
      if (_activeAnnotationTool == AnnotationTool.sector) {
        // Create sector from selected zone
        if (_selectedSectorCenterCm != null && _selectedSectorRadiusCm != null) {
          final center = _selectedSectorCenterCm!;
          final radius = _selectedSectorRadiusCm!;
          final radiusPoint = center + Offset(radius, 0);

          // Calculate angles from center following the drag direction
          final startVec = start - center;
          final fallbackStartAngle = math.atan2(startVec.dy, startVec.dx);
          final startAngle = _sectorDragStartAngle ?? fallbackStartAngle;
          final endAngle = _sectorDragEndAngle ?? startAngle;

          ann = Annotation(
            type: AnnotationType.sector,
            color: _annotationColor,
            points: [center, radiusPoint],
            filled: true, // Sectors are always filled
            strokeWidthCm: _annotationStrokeCm,
            circleAnnotationId: _selectedSectorTarget,
            sectorAttachmentType: _storageValueForSectorAttachment(_sectorAttachmentType),
            sectorAttachmentId: _selectedSectorAttachmentId,
            startAngle: startAngle,
            endAngle: endAngle,
          );
        }
      } else if (_activeAnnotationTool == AnnotationTool.freehand) {
        final rawPoints = <Offset>[..._pendingAnnotationPoints];
        if ((rawPoints.last - end).distance > 0.001) {
          rawPoints.add(end);
        }
        final smoothPoints = _smoothFreehandPoints(rawPoints);
        if (smoothPoints.length >= 2) {
          ann = Annotation(
            type: AnnotationType.curvedLine,
            color: _annotationColor,
            points: smoothPoints,
            strokeWidthCm: _annotationStrokeCm,
            lineStyle: _freehandLineStyle,
          );
        }
      } else if (_activeAnnotationTool == AnnotationTool.line) {
        if (dist > 0.8) {
          ann = Annotation(
            type: AnnotationType.line,
            color: _annotationColor,
            points: [start, end],
            strokeWidthCm: _annotationStrokeCm,
            lineStyle: _annotationLineStyle,
          );
        }
      } else if (_activeAnnotationTool == AnnotationTool.marker) {
        // All marker styles are single-point symbols placed at drag end.
        ann = Annotation(
          type: AnnotationType.line,
          color: _annotationColor,
          points: [end, end],
          strokeWidthCm: _annotationStrokeCm,
          lineStyle: _annotationMarkerStyle,
        );
      } else if (dist > 10) {
        if (_activeAnnotationTool == AnnotationTool.circle) {
          ann = Annotation(
            type: AnnotationType.circle,
            color: _annotationColor,
            points: [start, end],
            filled: _circleFilled,
            strokeWidthCm: _annotationStrokeCm,
          );
        } else if (_activeAnnotationTool == AnnotationTool.rectangle) {
          ann = Annotation(
            type: AnnotationType.rectangle,
            color: _annotationColor,
            points: [start, end],
            filled: _rectangleFilled,
            strokeWidthCm: _annotationStrokeCm,
          );
        }
      } else if (_activeAnnotationTool == AnnotationTool.circle) {
        // Tap-only circle: default to 30cm radius
        final defaultRadius = AppConstants.defaultCircleRadiusCm;
        ann = Annotation(
          type: AnnotationType.circle,
          color: _annotationColor,
          points: [start, start + Offset(defaultRadius, 0)],
          filled: _circleFilled,
          strokeWidthCm: _annotationStrokeCm,
        );
      }
      // Remove the duplicate sector handling that was here

      if (ann != null) {
        final annotations = _activeAnnotationList();
        final before = _annotationGestureStartSnapshot ?? _cloneAnnotations(annotations);
        setState(() {
          annotations.add(ann!);
          _pendingAnnotationPoints.clear();
          _currentDragPos = null;
          _stagedAnnotations.clear();
          _sectorDragStartAngle = null;
          _sectorDragPrevAngle = null;
          _sectorDragSweepAngle = 0.0;
          _sectorDragEndAngle = null;
          // Don't reset sector selection - allow multiple sectors from same zone
          // _sectorToolNeedsTargetSelection remains false
          // _selectedSectorTarget, _selectedSectorCenterCm, _selectedSectorRadiusCm stay selected
        });
        _pushAnnotationHistoryIfChanged(before, _cloneAnnotations(annotations));
        _annotationGestureStartSnapshot = null;
      } else {
        setState(() {
          _pendingAnnotationPoints.clear();
          _currentDragPos = null;
          _stagedAnnotations.clear();
          // Don't reset sector selection here either
        });
        _annotationGestureStartSnapshot = null;
      }
    }

    _annotationGestureStartSnapshot = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BALL PATH PLACEMENT (Hit/Set)
  // ══════════════════════════════════════════════════════════════════════════

  /// Place a ball hit marker at the nearest point on the ball path to the tap position
  void _placeBallHitAt(Offset tapPos, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return;

    // Resolve target ball (active in training, else first)
    Ball? targetPrevBall;
    Ball? targetCurrBall;
    if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
      targetPrevBall = prev.getBallById(_activeBallId!);
      targetCurrBall = currentFrame.getBallById(_activeBallId!);
    }
    targetPrevBall ??= prev.balls.isNotEmpty ? prev.balls.first : null;
    targetCurrBall ??= currentFrame.balls.isNotEmpty ? currentFrame.balls.first : null;
    if (targetPrevBall == null || targetCurrBall == null) return;

    // Check if ball path distance is >= 30cm for the selected ball
    final pathDistance = (targetCurrBall.position - targetPrevBall.position).distance;
    if (pathDistance < 30.0) {
      // Silently ignore - path too short for hit
      return;
    }
    // Build samples along path from prev->current for the selected ball
    final hasCtrl = targetCurrBall.pathPoints.isNotEmpty;
    final engine = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: targetPrevBall.position,
            control: targetCurrBall.pathPoints.first,
            end: targetCurrBall.position,
            resolution: 200,
          )
        : null;
    double bestT = 0.5;
    double bestD = double.infinity;
    const int res = 200;
    for (int i = 0; i <= res; i++) {
      final t = i / res;
      final posCm = hasCtrl ? engine!.sample(t) : Offset.lerp(targetPrevBall.position, targetCurrBall.position, t)!;
      final posScreen = _toScreenPosition(posCm, size);
      final d = (tapPos - posScreen).distance;
      if (d < bestD) {
        bestD = d;
        bestT = t;
      }
    }
    if (bestD < 40) {
      setState(() {
        // Set hit T on selected ball
        final ball = currentFrame.getBallById(_activeBallId ?? targetCurrBall!.id);
        if (ball != null) ball.hitT = bestT;
        _pendingBallMark = null;
      });
      _saveProject();
    } else {
      // ignore if too far from path
    }
  }

  /// Find the nearest t value on the ball path to the tap position
  double _nearestTOnBallPath(Offset tapPos, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return 0.5;
    // Resolve ball by active ID (training) or first
    Ball? targetPrevBall;
    Ball? targetCurrBall;
    if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
      targetPrevBall = prev.getBallById(_activeBallId!);
      targetCurrBall = currentFrame.getBallById(_activeBallId!);
    }
    targetPrevBall ??= prev.balls.isNotEmpty ? prev.balls.first : null;
    targetCurrBall ??= currentFrame.balls.isNotEmpty ? currentFrame.balls.first : null;
    if (targetPrevBall == null || targetCurrBall == null) return 0.5;

    final hasCtrl = targetCurrBall.pathPoints.isNotEmpty;
    final engine = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: targetPrevBall.position,
            control: targetCurrBall.pathPoints.first,
            end: targetCurrBall.position,
            resolution: 400,
          )
        : null;
    const int res = 400;
    double bestT = 0.5;
    double bestD = double.infinity;
    for (int i = 0; i <= res; i++) {
      final t = i / res;
      final posCm = hasCtrl ? engine!.sample(t) : Offset.lerp(targetPrevBall.position, targetCurrBall.position, t)!;
      final posScreen = _toScreenPosition(posCm, size);
      final d = (tapPos - posScreen).distance;
      if (d < bestD) {
        bestD = d;
        bestT = t;
      }
    }
    return bestT;
  }

  /// Avoid control point overlap by adjusting t value based on estimated path length
  /// Calculate total arc length of a path by sampling from t=0 to t=1
  double _calculatePathArcLength(PathEngine engine) {
    double totalLength = 0.0;
    Offset prevPos = engine.sample(0.0);
    const int samples = 200;
    for (int i = 1; i <= samples; i++) {
      final t = i / samples.toDouble();
      final currPos = engine.sample(t);
      totalLength += (currPos - prevPos).distance;
      prevPos = currPos;
    }
    return totalLength;
  }

  /// Find the parametric t value that corresponds to a specific arc length distance
  /// Uses binary search to locate t where arc length from 0 to t equals targetDistance
  double _tForArcLength(PathEngine engine, double targetDistance) {
    double left = 0.0, right = 1.0;
    const double tolerance = 0.1; // 0.1 cm tolerance
    const int maxIterations = 15;

    for (int iter = 0; iter < maxIterations; iter++) {
      final mid = (left + right) / 2;
      double arcLength = 0.0;

      // Calculate arc length from 0 to mid
      Offset prevPos = engine.sample(0.0);
      const int samples = 100;
      for (int i = 1; i <= samples; i++) {
        final t = (mid * i) / samples;
        final currPos = engine.sample(t);
        arcLength += (currPos - prevPos).distance;
        prevPos = currPos;
      }

      if ((arcLength - targetDistance).abs() < tolerance) {
        return mid;
      } else if (arcLength < targetDistance) {
        left = mid;
      } else {
        right = mid;
      }
    }
    return (left + right) / 2;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH CONTROL POINT EDITING & DRAG HANDLING
  // ══════════════════════════════════════════════════════════════════════════
  // Manages curve paths for players and balls during animation transitions
  // Uses PathEngine for quadratic Bezier sampling and hit detection
  // Key parameters:
  //   bufferCm: 50cm tap radius for path hit detection (adaptive via cmToLogical)
  //   pathPoints: first point is control point; stores in entity.pathPoints

  List<Offset>? _pathPointsForLabel(String label) {
    // Support both old hardcoded format (P1-P4) and new dynamic IDs
    final player = currentFrame.getPlayerById(label);
    if (player != null) {
      return player.pathPoints;
    }

    // If label is "BALL", handle ball ID lookup
    if (label == "BALL") {
      if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
        final b = currentFrame.getBallById(_activeBallId!);
        return b?.pathPoints ?? [];
      }
      return currentFrame.balls.isNotEmpty ? currentFrame.balls.first.pathPoints : null;
    }

    return null;
  }

  Offset? _pathStartForLabel(String label, Frame prev) {
    final player = prev.getPlayerById(label);
    if (player != null) {
      return player.position;
    }

    if (label == "BALL") {
      if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
        final pb = prev.getBallById(_activeBallId!);
        return pb?.position ?? (prev.balls.isNotEmpty ? prev.balls.first.position : null);
      }
      return prev.balls.isNotEmpty ? prev.balls.first.position : null;
    }

    return null;
  }

  Offset? _pathEndForLabel(String label) {
    final player = currentFrame.getPlayerById(label);
    if (player != null) {
      return player.position;
    }

    if (label == "BALL") {
      if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
        final cb = currentFrame.getBallById(_activeBallId!);
        return cb?.position ?? (currentFrame.balls.isNotEmpty ? currentFrame.balls.first.position : null);
      }
      return currentFrame.balls.isNotEmpty ? currentFrame.balls.first.position : null;
    }

    return null;
  }

  /// Locate the nearest path under a touch and snap/create a control point for drag.
  ///
  /// Tap-to-path hit testing depends on:
  /// - `bufferCm` converted to pixels via `Settings.cmToLogical(...)`, so screen size,
  ///   safe-area insets, and the current court scaling all change the allowed tap radius.
  /// - Path sampling resolution (200 samples) to find the nearest spot along the path.
  /// - Path length guard (`pathLen < 1` cm) to skip tiny paths.
  /// Increase tap leniency by raising `bufferCm` (currently 50cm) or sampling at
  /// a lower resolution requirement; both enlarge how far off the path a tap can be.
  bool _maybeStartPathDrag(Offset localPos, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return false;

    const double bufferCm = 37.5; // Decreased from 50cm (20px → 15px snapping threshold)
    final bufferPx = _cmToLogical(bufferCm, size).abs();

    String? bestLabel;
    Offset? bestPointCm;
    double bestDistPx = double.infinity;

    void scanPath(String label, Offset start, Offset end, List<Offset> points) {
      final pathLen = (end - start).distance;
      if (pathLen < 1) return;

      final hasCtrl = points.isNotEmpty;
      final engine = hasCtrl
          ? PathEngine.fromTwoQuadratics(start: start, control: points.first, end: end, resolution: 200)
          : null;

      const int res = 200;
      for (int i = 0; i <= res; i++) {
        final t = i / res;
        final posCm = hasCtrl ? engine!.sample(t) : Offset.lerp(start, end, t)!;
        final posScreen = _toScreenPosition(posCm, size);
        final d = (localPos - posScreen).distance;
        if (d < bestDistPx) {
          bestDistPx = d;
          bestPointCm = posCm;
          bestLabel = label;
        }
      }
    }

    // Scan all player paths dynamically (supports unlimited players)
    for (final player in currentFrame.players) {
      final label = player.id;
      final start = _pathStartForLabel(label, prev);
      final end = _pathEndForLabel(label);
      final points = _pathPointsForLabel(label);
      if (start == null || end == null || points == null) continue;
      scanPath(label, start, end, points);
    }

    // Scan all ball paths independently to choose nearest, set activeBall accordingly
    String? bestBallId;
    for (final ball in currentFrame.balls) {
      final prevBall = prev.getBallById(ball.id) ?? (prev.balls.isNotEmpty ? prev.balls.first : null);
      if (prevBall == null) continue;
      final start = prevBall.position;
      final end = ball.position;
      final points = ball.pathPoints;
      final pathLen = (end - start).distance;
      if (pathLen < 1) continue;

      final hasCtrl = points.isNotEmpty;
      final engine = hasCtrl
          ? PathEngine.fromTwoQuadratics(start: start, control: points.first, end: end, resolution: 200)
          : null;

      const int res = 200;
      for (int i = 0; i <= res; i++) {
        final t = i / res;
        final posCm = hasCtrl ? engine!.sample(t) : Offset.lerp(start, end, t)!;
        final posScreen = _toScreenPosition(posCm, size);
        final d = (localPos - posScreen).distance;
        if (d < bestDistPx) {
          bestDistPx = d;
          bestPointCm = posCm;
          bestLabel = "BALL";
          bestBallId = ball.id;
        }
      }
    }

    final labelToUse = bestLabel;
    final snappedPoint = bestPointCm;
    if (labelToUse == null || snappedPoint == null) return false;
    if (bestDistPx > bufferPx) return false;

    List<Offset>? points;
    if (labelToUse == "BALL") {
      if (bestBallId != null) {
        final selectedBallId = bestBallId;
        final b = currentFrame.getBallById(selectedBallId);
        points = b?.pathPoints;
      }
    } else {
      points = _pathPointsForLabel(labelToUse);
    }

    final pathPoints = points;
    if (pathPoints == null) return false;

    // Determine the actual entity ID for history tracking
    // For balls, use the ball ID instead of "BALL" label
    final String entityIdForHistory = (labelToUse == "BALL" && bestBallId != null) ? bestBallId : labelToUse;

    // Store the initial state for undo/redo
    final fromPoints = List<Offset>.from(pathPoints);

    setState(() {
      if (pathPoints.isEmpty) {
        pathPoints.add(snappedPoint);
      } else {
        pathPoints[0] = snappedPoint;
      }
      _pathRevision++;
      _activePathDragId = labelToUse;
      _activePathDragIndex = 0;
      _dragStartLogical["PATH-$labelToUse-0"] = pathPoints[0];
      _dragStartScreen["PATH-$labelToUse-0"] = localPos;
      if (labelToUse == "BALL" && bestBallId != null) {
        _activeBallId = bestBallId;
      }
      _showModifierMenu = false;
    });

    final idx = widget.project.frames.indexOf(currentFrame);
    if (idx >= 0) {
      widget.project.frames[idx] = currentFrame;
      PathEngine.invalidateCacheFor(idx, labelToUse);
    }

    // Store the initial path state for this drag operation using entity ID
    _pathDragStartPoints[entityIdForHistory] = fromPoints;

    return true;
  }

  void _updatePathDrag(Offset localPos, Size size) {
    final label = _activePathDragId;
    final index = _activePathDragIndex;
    if (label == null || index == null) return;
    final points = _pathPointsForLabel(label);
    if (points == null || points.isEmpty || index >= points.length) return;
    final startLogical = _dragStartLogical["PATH-$label-$index"] ?? points[index];
    final startScreen = _dragStartScreen["PATH-$label-$index"] ?? localPos;
    final scalePerCm = _cmToLogical(1.0, size);
    if (scalePerCm == 0) return;

    setState(() {
      final deltaScreen = localPos - startScreen;
      points[index] = startLogical + deltaScreen / scalePerCm;
      _pathRevision++;
    });

    final frameIdx = widget.project.frames.indexOf(currentFrame);
    if (frameIdx >= 0) PathEngine.invalidateCacheFor(frameIdx, label);
  }

  void _endPathDrag() {
    bool changed = false;
    final label = _activePathDragId;
    final index = _activePathDragIndex;
    if (label != null && index != null) {
      final frameIdx = widget.project.frames.indexOf(currentFrame);
      if (frameIdx >= 0) {
        widget.project.frames[frameIdx] = currentFrame;
        PathEngine.invalidateCacheFor(frameIdx, label);

        // Determine the actual entity ID for history (use ball ID if label is "BALL")
        final entityIdForHistory = (label == "BALL" && _activeBallId != null) ? _activeBallId! : label;

        // Save to history if path points changed
        final fromPoints = _pathDragStartPoints[entityIdForHistory];
        if (fromPoints != null) {
          final currentPoints = _pathPointsForLabel(label);
          if (currentPoints != null) {
            final toPoints = List<Offset>.from(currentPoints);
            // Only add to history if points actually changed
            if (fromPoints.length != toPoints.length || !_offsetListsEqual(fromPoints, toPoints)) {
              _history.push(
                EditPathControlPointsAction(
                  frameIndex: frameIdx,
                  entityId: entityIdForHistory,
                  fromPoints: fromPoints,
                  toPoints: toPoints,
                ),
              );
              changed = true;
            }
          }
          _pathDragStartPoints.remove(entityIdForHistory);
        }
      }
      _dragStartLogical.remove("PATH-$label-$index");
      _dragStartScreen.remove("PATH-$label-$index");
      _saveProject();
    }
    setState(() {
      _activePathDragId = null;
      _activePathDragIndex = null;
      if (changed) _pathRevision++;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH TRACKING DURING PLAYBACK
  // ══════════════════════════════════════════════════════════════════════════
  // Handles toggling full path display for players/balls during playback
  // Shows past path as solid line and future path as dashed line

  String _resolveTrackedEntityId(String trackedEntityId, Frame frame) {
    final directPlayer = frame.getPlayerById(trackedEntityId);
    if (directPlayer != null) return directPlayer.id;

    switch (trackedEntityId) {
      case 'P1':
        return frame.players.isNotEmpty ? frame.players[0].id : trackedEntityId;
      case 'P2':
        return frame.players.length > 1 ? frame.players[1].id : trackedEntityId;
      case 'P3':
        return frame.players.length > 2 ? frame.players[2].id : trackedEntityId;
      case 'P4':
        return frame.players.length > 3 ? frame.players[3].id : trackedEntityId;
      default:
        return trackedEntityId;
    }
  }

  String? _legacyPlayerAliasForIndex(int index) {
    switch (index) {
      case 0:
        return 'P1';
      case 1:
        return 'P2';
      case 2:
        return 'P3';
      case 3:
        return 'P4';
      default:
        return null;
    }
  }

  void _toggleTrackedEntityId(String canonicalEntityId, {String? legacyAlias}) {
    setState(() {
      final hasCanonical = _trackedEntityIds.contains(canonicalEntityId);
      final hasLegacy = legacyAlias != null && _trackedEntityIds.contains(legacyAlias);
      if (hasCanonical || hasLegacy) {
        _trackedEntityIds.remove(canonicalEntityId);
        if (legacyAlias != null) {
          _trackedEntityIds.remove(legacyAlias);
        }
      } else {
        _trackedEntityIds.add(canonicalEntityId);
      }
    });
  }

  /// Toggle path tracking for the entity (player or ball) at the tap position
  void _togglePathTracking(Offset tapPos, Size size) {
    final tapCm = _screenToCm(tapPos, size);
    const hitRadiusCm = 30.0; // Tap radius for detecting objects

    // Get the interpolated playback frame
    final displayFrame = _animatedFrame;
    if (displayFrame == null) return;

    // Check players
    for (int i = 0; i < displayFrame.players.length; i++) {
      final player = displayFrame.players[i];
      if ((player.position - tapCm).distance < hitRadiusCm) {
        _toggleTrackedEntityId(player.id, legacyAlias: _legacyPlayerAliasForIndex(i));
        return;
      }
    }

    // Check balls
    for (final ball in displayFrame.balls) {
      if ((ball.position - tapCm).distance < hitRadiusCm) {
        _toggleTrackedEntityId(ball.id);
        return;
      }
    }
  }

  /// Build full path visualization widgets for tracked entities during playback
  List<Widget> _buildTrackedPaths(Size size) {
    // Show paths whenever playback is active, paused, or ended-at-last-frame and tracking is enabled
    if ((!_isPlaying && !_isPaused && !_endedAtLastFrame) || _trackedEntityIds.isEmpty) {
      return [];
    }

    final widgets = <Widget>[];
    final currentPlaybackIndex = _playbackFrameIndex.clamp(0, widget.project.frames.length - 1);
    final frames = widget.project.frames;

    final referenceFrame = frames[currentPlaybackIndex];
    final renderedEntityIds = <String>{};

    for (final trackedEntityId in _trackedEntityIds) {
      final entityId = _resolveTrackedEntityId(trackedEntityId, referenceFrame);
      if (!renderedEntityIds.add(entityId)) continue;

      // Helper: append sampled segment (curved if control point exists)
      void appendSegment({
        required List<Offset> out,
        required Offset start,
        required Offset end,
        required List<Offset> pathPoints,
        required double tStart,
        required double tEnd,
      }) {
        final samples = math.max(6, ((tEnd - tStart) * 40).ceil());
        if (pathPoints.isNotEmpty) {
          final engine = PathEngine.fromTwoQuadratics(
            start: start,
            control: pathPoints.first,
            end: end,
            resolution: 400,
          );
          for (int i = 0; i <= samples; i++) {
            final t = tStart + (tEnd - tStart) * (i / samples);
            out.add(_toScreenPosition(engine.sample(t), size));
          }
        } else {
          for (int i = 0; i <= samples; i++) {
            final t = tStart + (tEnd - tStart) * (i / samples);
            out.add(_toScreenPosition(Offset.lerp(start, end, t)!, size));
          }
        }
      }

      Offset? entityPos(Frame f) => _getEntityPosition(f, entityId);
      List<Offset> entityPath(Frame f) {
        final player = f.getPlayerById(entityId);
        if (player != null) return player.pathPoints;
        final ball = f.getBallById(entityId);
        if (ball != null) return ball.pathPoints;
        return const [];
      }

      // Build past path (solid): full segments up to currentPlaybackIndex, plus partial current segment to _playbackT
      final pastPathPoints = <Offset>[];
      for (int i = 0; i < currentPlaybackIndex; i++) {
        final a = entityPos(frames[i]);
        final b = entityPos(frames[i + 1]);
        if (a == null || b == null) continue;
        appendSegment(out: pastPathPoints, start: a, end: b, pathPoints: entityPath(frames[i + 1]), tStart: 0, tEnd: 1);
      }
      // Partial segment into current playback frame
      if (_isPlaying && currentPlaybackIndex < frames.length - 1) {
        final a = entityPos(frames[currentPlaybackIndex]);
        final b = entityPos(frames[currentPlaybackIndex + 1]);
        if (a != null && b != null) {
          appendSegment(
            out: pastPathPoints,
            start: a,
            end: b,
            pathPoints: entityPath(frames[currentPlaybackIndex + 1]),
            tStart: 0,
            tEnd: _playbackT.clamp(0.0, 1.0),
          );
        }
      }

      // Build future path (dashed): from current playback position to end
      final futurePathPoints = <Offset>[];
      if (_isPlaying && currentPlaybackIndex < frames.length - 1) {
        // Remainder of current segment
        final a = entityPos(frames[currentPlaybackIndex]);
        final b = entityPos(frames[currentPlaybackIndex + 1]);
        if (a != null && b != null) {
          appendSegment(
            out: futurePathPoints,
            start: a,
            end: b,
            pathPoints: entityPath(frames[currentPlaybackIndex + 1]),
            tStart: _playbackT.clamp(0.0, 1.0),
            tEnd: 1,
          );
        }
      }
      for (int i = currentPlaybackIndex + 1; i < frames.length - 1; i++) {
        final a = entityPos(frames[i]);
        final b = entityPos(frames[i + 1]);
        if (a == null || b == null) continue;
        appendSegment(
          out: futurePathPoints,
          start: a,
          end: b,
          pathPoints: entityPath(frames[i + 1]),
          tStart: 0,
          tEnd: 1,
        );
      }

      // Render past path (solid)
      if (pastPathPoints.length > 1) {
        widgets.add(
          CustomPaint(
            painter: _TrackedPathPainter(points: pastPathPoints, color: _getEntityColor(entityId), isDashed: false),
            size: size,
          ),
        );
      }

      // Render future path (dashed)
      if (futurePathPoints.length > 1) {
        widgets.add(
          CustomPaint(
            painter: _TrackedPathPainter(points: futurePathPoints, color: _getEntityColor(entityId), isDashed: true),
            size: size,
          ),
        );
      }
    }

    return widgets;
  }

  /// Get position of an entity (player or ball) from a frame
  Offset? _getEntityPosition(Frame frame, String entityId) {
    final player = frame.getPlayerById(entityId);
    if (player != null) {
      return player.position;
    }

    final ball = frame.getBallById(entityId);
    if (ball != null) {
      return ball.position;
    }

    switch (entityId) {
      case 'P1':
        return frame.players.isNotEmpty ? frame.players[0].position : null;
      case 'P2':
        return frame.players.length > 1 ? frame.players[1].position : null;
      case 'P3':
        return frame.players.length > 2 ? frame.players[2].position : null;
      case 'P4':
        return frame.players.length > 3 ? frame.players[3].position : null;
      default:
        return null;
    }
  }

  /// Get color of an entity for path rendering
  Color _getEntityColor(String entityId) {
    final normalizedEntityId = _resolveTrackedEntityId(entityId, currentFrame);

    // For players, use their color from current frame
    final player = currentFrame.getPlayerById(normalizedEntityId);
    if (player != null) {
      return player.color;
    }

    // For balls, use their color from current frame
    final ball = currentFrame.getBallById(normalizedEntityId);
    if (ball != null) {
      return ball.color;
    }

    switch (entityId) {
      case 'P1':
        return currentFrame.players.isNotEmpty ? currentFrame.players[0].color : Colors.grey;
      case 'P2':
        return currentFrame.players.length > 1 ? currentFrame.players[1].color : Colors.grey;
      case 'P3':
        return currentFrame.players.length > 2 ? currentFrame.players[2].color : Colors.grey;
      case 'P4':
        return currentFrame.players.length > 3 ? currentFrame.players[3].color : Colors.grey;
    }

    return Colors.grey;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OBJECT RENDERING & VISUAL BUILDERS
  // ══════════════════════════════════════════════════════════════════════════
  // Renders players, balls, hit/set markers, and decorative elements
  // Includes selection highlighting (cyan glow) for active objects

  /// Build hit markers for all balls in the current frame during editing
  List<Widget> _buildAllHitMarkersForEditing(Size size) {
    if (_isPlaying || _endedAtLastFrame) return [];
    final prev = _getPreviousFrame();
    if (prev == null) return [];

    final widgets = <Widget>[];
    for (final ball in currentFrame.balls) {
      final t = ball.hitT;
      if (t == null) continue;

      final prevBall = prev.getBallById(ball.id) ?? (prev.balls.isNotEmpty ? prev.balls.first : null);
      if (prevBall == null) continue;

      final hasCtrl = ball.pathPoints.isNotEmpty;
      final posCm = hasCtrl
          ? PathEngine.fromTwoQuadratics(
              start: prevBall.position,
              control: ball.pathPoints.first,
              end: ball.position,
              resolution: 400,
            ).sample(t)
          : Offset.lerp(prevBall.position, ball.position, t)!;
      final pos = _toScreenPosition(posCm, size);

      // Check if hit marker overlaps with ball position (within 30px on screen)
      final ballPos = _toScreenPosition(ball.position, size);
      final distanceToBall = (pos - ballPos).distance;
      final isOnBall = distanceToBall < 30;

      widgets.add(
        Positioned(
          left: pos.dx - 14,
          top: pos.dy - 14,
          child: IgnorePointer(
            ignoring: isOnBall, // Ignore pointer when on ball so ball is draggable
            child: GestureDetector(
              onPanStart: (details) {
                // Start dragging the hit marker immediately when the user pans on it
                setState(() {
                  _pendingBallMark = 'hit';
                  _activeBallId = ball.id;
                });
              },
              onPanUpdate: (details) {
                if (_pendingBallMark == 'hit') {
                  // Convert global coordinates to local coordinates relative to the board
                  final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
                  final localPos = box.globalToLocal(details.globalPosition);
                  final newT = _nearestTOnBallPath(localPos, size);
                  setState(() {
                    final targetBall = currentFrame.getBallById(ball.id);
                    if (targetBall != null) targetBall.hitT = newT;
                  });
                  _saveProject();
                }
              },
              onPanEnd: (_) => setState(() => _pendingBallMark = null),
              child: Opacity(
                opacity: 0.72,
                child: CustomPaint(size: const Size(28, 28), painter: _StarPainter()),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Build set preview indicators for all balls with set marker during editing
  List<Widget> _buildAllSetPreviewsForEditing(Size size) {
    if (_isPlaying || _endedAtLastFrame) return [];
    final prev = _getPreviousFrame();
    if (prev == null) return [];

    final widgets = <Widget>[];
    for (final ball in currentFrame.balls) {
      if (!(ball.isSet ?? false)) continue;

      final prevBall = prev.getBallById(ball.id) ?? (prev.balls.isNotEmpty ? prev.balls.first : null);
      if (prevBall == null) continue;

      final hasCtrl = ball.pathPoints.isNotEmpty;
      late Offset midCm;
      if (hasCtrl) {
        final engine = PathEngine.fromTwoQuadratics(
          start: prevBall.position,
          control: ball.pathPoints.first,
          end: ball.position,
          resolution: 200,
        );
        // Position at 50% of arc length, not 50% of parametric range
        final totalLength = _calculatePathArcLength(engine);
        final tAtHalf = _tForArcLength(engine, totalLength * 0.5);
        midCm = engine.sample(tAtHalf);
      } else {
        midCm = (prevBall.position + ball.position) / 2;
      }
      final pos = _toScreenPosition(midCm, size);
      final double scale = 1.75;

      widgets.add(
        Positioned(
          left: pos.dx - 16 * scale,
          top: pos.dy - 16 * scale,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.58,
              child: CustomPaint(size: Size(32 * scale, 32 * scale), painter: _SetMarkerPainter()),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  // (moved painter classes to top-level after the widget class)

  /// Build control points for path editing (draggable dots)
  List<Widget> _buildPathControlPoints(List<Offset> points, Offset startCm, Offset endCm, Size size, String label) {
    final widgets = <Widget>[];
    for (int i = 0; i < points.length; i++) {
      final screenPos = _toScreenPosition(points[i], size);
      widgets.add(
        Positioned(
          left: screenPos.dx - 8,
          top: screenPos.dy - 8,
          child: GestureDetector(
            onDoubleTap: () {
              _removeControlPoint(points, i, startCm, endCm, size);
              _saveProject();
            },
            onPanStart: (details) {
              _dragStartLogical["$label-$i"] = points[i];
              final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
              _dragStartScreen["$label-$i"] = box.globalToLocal(details.globalPosition);
            },
            onPanUpdate: (details) {
              setState(() {
                final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
                final localPos = box.globalToLocal(details.globalPosition);
                final deltaScreen = localPos - (_dragStartScreen["$label-$i"] ?? localPos);
                final scalePerCm = _cmToLogical(1.0, size);
                points[i] = (_dragStartLogical["$label-$i"] ?? points[i]) + deltaScreen / scalePerCm;
              });
            },
            onPanEnd: (_) {
              _dragStartLogical.remove("$label-$i");
              _dragStartScreen.remove("$label-$i");
              _saveProject();
            },
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Remove a control point with animation
  void _removeControlPoint(List<Offset> points, int index, Offset startCm, Offset endCm, Size size) {
    if (index < 0 || index >= points.length) return;

    // Store initial state for undo/redo
    final fromPoints = List<Offset>.from(points);
    final frameIdx = widget.project.frames.indexOf(currentFrame);

    // Find which entity this belongs to
    String? entityId;
    for (final player in currentFrame.players) {
      if (player.pathPoints == points) {
        entityId = player.id;
        break;
      }
    }
    if (entityId == null) {
      for (final ball in currentFrame.balls) {
        if (ball.pathPoints == points) {
          entityId = ball.id;
          break;
        }
      }
    }

    final removedPoint = points[index];
    final target = (startCm + endCm) / 2;
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    late final Animation<Offset> animation;
    animation =
        Tween<Offset>(
          begin: removedPoint,
          end: target,
        ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut))..addListener(() {
          setState(() {
            if (index < points.length) points[index] = animation.value;
          });
        });
    controller.forward().then((_) {
      setState(() {
        points.removeAt(index);
        controller.dispose();
        if (frameIdx >= 0) {
          widget.project.frames[frameIdx] = currentFrame;

          // Save to history
          if (entityId != null) {
            final toPoints = List<Offset>.from(points);
            _history.push(
              EditPathControlPointsAction(
                frameIndex: frameIdx,
                entityId: entityId,
                fromPoints: fromPoints,
                toPoints: toPoints,
              ),
            );
          }
        }
        _pathRevision++;
        _saveProject();
      });
    });
  }

  /// Helper to compare two lists of Offsets for equality
  bool _offsetListsEqual(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i].dx - b[i].dx).abs() > 0.01 || (a[i].dy - b[i].dy).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }

  /// Calculate perceived brightness of a color (0.0 = dark, 1.0 = light)
  double _getColorBrightness(Color color) {
    return color.computeLuminance();
  }

  /// Build player widgets with drag handling
  Widget _buildPlayer(Offset posCm, double rotation, Color color, String playerId, Size size, {String? label}) {
    final screenPos = _toScreenPosition(posCm, size);
    final playerScale = _settings.objectScaleMultiplier;
    final basePlayerRadius = _cmToLogical(AppConstants.playerRadiusCm, size);
    final playerRadiusPx = (basePlayerRadius * playerScale).clamp(14.0 * playerScale, 64.0 * playerScale);
    final playerDiameterPx = playerRadiusPx * 2;
    final borderWidth = math.max(2.0, playerRadiusPx * 0.12);
    final shadowBlur = math.max(6.0, playerRadiusPx * 0.24);
    final bool isSelected = _showPlayerMenu && _activePlayerId == playerId;
    final labelTextColor = _getColorBrightness(color) > 0.5 ? Colors.black : Colors.white;
    return Positioned(
      left: screenPos.dx - playerRadiusPx,
      top: screenPos.dy - playerRadiusPx,
      child: IgnorePointer(
        ignoring: _annotationsMenuOpen,
        child: GestureDetector(
          onTap: () {
            if (_isPlaying) {
              _togglePathTracking(screenPos, size);
              return;
            }
            if (_isPlaying || _endedAtLastFrame) return;
            setState(() => _lastTappedPlayerColor = color);
            final togglingSame = _showPlayerMenu && _activePlayerId == playerId;
            setState(() {
              if (togglingSame) {
                _activeMenu = BoardMenu.none;
                _closeObjectMenusAndSelection();
                return;
              }

              if (_activeMenu == BoardMenu.none) {
                _activeMenu = BoardMenu.objects;
              }
              _showPlayerMenu = true;
              _activePlayerId = playerId;
              _showModifierMenu = false;
              _activeBallId = null;
            });
          },
          onPanStart: (details) {
            if (_isPlaying || _endedAtLastFrame) return;
            _dragStartLogical[playerId] = posCm;
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            final localPos = box.globalToLocal(details.globalPosition);
            _dragStartScreen[playerId] = _clampToInteractionBounds(localPos, size);
          },
          onPanUpdate: (details) {
            if (_isPlaying || _endedAtLastFrame) return;
            setState(() {
              final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              final clampedPos = _clampToInteractionBounds(localPos, size);
              final deltaScreen = clampedPos - (_dragStartScreen[playerId] ?? clampedPos);
              final scalePerCm = _cmToLogical(1.0, size);
              _updateFramePosition(playerId, (_dragStartLogical[playerId] ?? posCm) + deltaScreen / scalePerCm);
            });
          },
          onPanEnd: (_) {
            if (_isPlaying || _endedAtLastFrame) return;
            final from = _dragStartLogical[playerId] ?? posCm;
            final player = currentFrame.getPlayerById(playerId);
            final to = player?.position ?? posCm;
            final idx = widget.project.frames.indexOf(currentFrame);
            final newIdx = _history.push(MoveEntityAction(frameIndex: idx, id: playerId, from: from, to: to));
            setState(() {
              currentFrame = widget.project.frames[newIdx];
            });
            _scrollToSelectedFrame();
            _dragStartLogical.remove(playerId);
            _dragStartScreen.remove(playerId);
          },
          child: Transform.rotate(
            angle: rotation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing sonar highlight - circular and extends beyond object
                if (isSelected)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _selectionPulseController,
                      builder: (context, _) {
                        final t = _selectionPulseController.value;
                        final scale = 1.0 + 0.6 * t;
                        final opacity = (1.0 - t) * 0.35;
                        return IgnorePointer(
                          child: CustomPaint(
                            painter: _PulseRingPainter(
                              radius: playerRadiusPx * scale,
                              color: Colors.cyanAccent.withValues(alpha: opacity.clamp(0.0, 1.0)),
                              strokeWidth: math.max(2.0, playerRadiusPx * 0.08),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                // Main player circle - centered, no size change from glow
                Container(
                  width: playerDiameterPx,
                  height: playerDiameterPx,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: shadowBlur,
                        spreadRadius: math.max(0.5, playerRadiusPx * 0.04),
                        offset: const Offset(0, 3),
                      ),
                      if (isSelected)
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.6),
                          blurRadius: shadowBlur,
                          spreadRadius: math.max(1.0, playerRadiusPx * 0.05),
                        ),
                    ],
                  ),
                ),
                if (label != null && label.isNotEmpty)
                  Transform.rotate(
                    angle: -rotation,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: playerRadiusPx * 0.9,
                        fontWeight: FontWeight.w700,
                        color: labelTextColor,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 0))],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the ball widget with optional scale and star opacity
  Widget _buildBall(
    Offset posCm,
    Size size, {
    double scale = 1.0,
    double starOpacity = 0.0,
    String? ballId,
    Color? color,
  }) {
    final screenPos = _toScreenPosition(posCm, size);
    final ballScale = _settings.objectScaleMultiplier;
    final baseBallRadius = _cmToLogical(AppConstants.ballRadiusCm, size);
    final ballRadiusPx = (baseBallRadius * ballScale).clamp(9.0 * ballScale, 48.0 * ballScale);
    final ballDiameterPx = ballRadiusPx * 2;
    final borderWidth = math.max(2.0, ballRadiusPx * 0.14);
    final shadowBlur = math.max(5.0, ballRadiusPx * 0.22);
    final bool isSelected = ballId != null && _showModifierMenu && _activeBallId == ballId;
    // Get the actual ball color from the current frame if not provided
    final ballColor = Colors.white;
    return Positioned(
      left: screenPos.dx - ballRadiusPx * scale,
      top: screenPos.dy - ballRadiusPx * scale,
      child: IgnorePointer(
        ignoring: _annotationsMenuOpen,
        child: GestureDetector(
          onTap: () {
            if (_isPlaying) {
              // Toggle path tracking for this ball during playback
              _togglePathTracking(screenPos, size);
              return;
            }
            if (!_isPlaying && !_endedAtLastFrame) {
              final togglingSame = _showModifierMenu && _activeBallId == ballId;

              if (togglingSame) {
                setState(() {
                  _activeMenu = BoardMenu.none;
                  _closeObjectMenusAndSelection();
                });
                return;
              }

              if (_activeMenu == BoardMenu.none) {
                setState(() {
                  _activeMenu = BoardMenu.objects;
                });
              }
              setState(() {
                _showModifierMenu = true;
                _activeBallId = ballId; // Store which ball was tapped
                _showPlayerMenu = false; // Close player menu if open
                _activePlayerId = null;
              });
            }
          },
          onPanStart: (details) {
            if (_isPlaying || _endedAtLastFrame) return;
            if (ballId != null) {
              _activeBallId = ballId; // Set active ball for dragging
            }
            _dragStartLogical[ballId ?? "BALL"] = posCm;
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            final localPos = box.globalToLocal(details.globalPosition);
            _dragStartScreen[ballId ?? "BALL"] = _clampToInteractionBounds(localPos, size);
          },
          onPanUpdate: (details) {
            if (_isPlaying || _endedAtLastFrame) return;
            setState(() {
              final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              final clampedPos = _clampToInteractionBounds(localPos, size);
              final deltaScreen = clampedPos - (_dragStartScreen[ballId ?? "BALL"] ?? clampedPos);
              final scalePerCm = _cmToLogical(1.0, size);
              _updateFramePosition(
                ballId ?? "BALL",
                (_dragStartLogical[ballId ?? "BALL"] ?? posCm) + deltaScreen / scalePerCm,
              );
            });
          },
          onPanEnd: (_) {
            if (_isPlaying || _endedAtLastFrame) return;
            final from = _dragStartLogical[ballId ?? "BALL"] ?? posCm;
            final ball = ballId != null ? currentFrame.getBallById(ballId) : null;
            final to = ball?.position ?? posCm;
            final idx = widget.project.frames.indexOf(currentFrame);
            final newIdx = _history.push(MoveEntityAction(frameIndex: idx, id: ballId ?? "BALL", from: from, to: to));
            setState(() {
              currentFrame = widget.project.frames[newIdx];
            });
            _scrollToSelectedFrame();
            _dragStartLogical.remove(ballId ?? "BALL");
            _dragStartScreen.remove(ballId ?? "BALL");
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing sonar highlight - circular and extends beyond object
              if (isSelected)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _selectionPulseController,
                    builder: (context, _) {
                      final t = _selectionPulseController.value;
                      final scale = 1.0 + 0.6 * t;
                      final opacity = (1.0 - t) * 0.35;
                      return IgnorePointer(
                        child: CustomPaint(
                          painter: _PulseRingPainter(
                            radius: ballRadiusPx * scale,
                            color: Colors.cyanAccent.withValues(alpha: opacity.clamp(0.0, 1.0)),
                            strokeWidth: math.max(2.0, ballRadiusPx * 0.1),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Main ball circle - centered, no size change from glow
              Container(
                width: ballDiameterPx * scale,
                height: ballDiameterPx * scale,
                decoration: BoxDecoration(
                  color: ballColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: shadowBlur,
                      spreadRadius: math.max(0.4, ballRadiusPx * 0.035),
                      offset: const Offset(0, 3),
                    ),
                    if (isSelected)
                      BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 1),
                  ],
                ),
              ),
              if (starOpacity > 0)
                Transform.translate(
                  offset: Offset(0, (ballRadiusPx + 1) * scale), // draw below the ball
                  child: Opacity(
                    opacity: starOpacity,
                    child: CustomPaint(
                      size: Size(ballDiameterPx * 0.75 * scale, ballDiameterPx * 0.75 * scale),
                      painter: _StarPainter(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggle object placement mode for players
  void _startAddPlayer() {
    if (widget.project.projectType != ProjectType.training) return;
    setState(() {
      _addingObjectType = (_addingObjectType == 'player') ? null : 'player';
    });
  }

  /// Toggle object placement mode for balls
  void _startAddBall() {
    if (widget.project.projectType != ProjectType.training) return;
    setState(() {
      _addingObjectType = (_addingObjectType == 'ball') ? null : 'ball';
    });
  }

  /// Create a new player at the tapped location and add to all frames
  void _createPlayerAtLocation(Offset cmPos) {
    if (_addingObjectType != 'player') return;

    // Use the last tapped player color, or alternate between blue/red based on count
    final fallbackIndex = currentFrame.players.length % AppTheme.playerColors.length;
    final Color color = _lastTappedPlayerColor ?? AppTheme.playerColors[fallbackIndex];
    final newPlayer = Player(position: cmPos, color: color);

    // Track in history and update UI (push inside setState for instant visibility)
    setState(() {
      _history.push(CreatePlayerAction(player: newPlayer));
      // Update currentFrame to reflect the new player immediately
      final idx = widget.project.frames.indexOf(currentFrame);
      if (idx >= 0) currentFrame = widget.project.frames[idx];
      // Immediately activate and show the player menu for the new player
      _activePlayerId = newPlayer.id;
      _showPlayerMenu = true;
      _showModifierMenu = false;
      _activeMenu = BoardMenu.objects;
      _deactivateAnnotationTools();
      _addingObjectType = null;
      _saveProject();
    });
  }

  /// Create a new ball at the tapped location and add to all frames
  void _createBallAtLocation(Offset cmPos) {
    if (_addingObjectType != 'ball') return;

    // Use the color of the last tapped ball, or default to light grey
    Color ballColor = Colors.white;
    if (_activeBallId != null) {
      final lastBall = currentFrame.getBallById(_activeBallId!);
      if (lastBall != null) {
        ballColor = lastBall.color;
      }
    } else if (currentFrame.balls.isNotEmpty) {
      ballColor = currentFrame.balls.last.color;
    }

    final newBall = Ball(position: cmPos, color: ballColor);

    // Track in history and update UI (push inside setState for instant visibility)
    setState(() {
      _history.push(CreateBallAction(ball: newBall));
      // Update currentFrame to reflect the new ball immediately
      final idx = widget.project.frames.indexOf(currentFrame);
      if (idx >= 0) currentFrame = widget.project.frames[idx];
      // Immediately activate and show the ball modifier menu for the new ball
      _activeBallId = newBall.id;
      _showModifierMenu = true;
      _showPlayerMenu = false;
      _activeMenu = BoardMenu.objects;
      _deactivateAnnotationTools();
      _addingObjectType = null;
      _saveProject();
    });
  }

  /// Cascade delete player from all frames (undoable)
  void _undoableDeletePlayerFromAllFrames(String playerId) {
    final action = RemovePlayerFromAllFramesAction(id: playerId);
    setState(() {
      _history.push(action);
      _activePlayerId = null;
      _showPlayerMenu = false;
    });
  }

  /// Cascade delete ball from all frames (undoable)
  void _undoableDeleteBallFromAllFrames(String ballId) {
    final action = RemoveBallFromAllFramesAction(id: ballId);
    setState(() {
      _history.push(action);
      _activeBallId = null;
      _showModifierMenu = false;
    });
  }

  // During playback we render the persisted hit star at its exact path position
  // (may persist across frame boundary for up to 0.5 frames). This helper
  // returns the star opacity and screen position if active for a specific ball.
  Map<String, dynamic> _playbackHitStarInfo(Size size, {String? ballId}) {
    if (!_isPlaying) return {};
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return {};
    final fAIndex = _playbackFrameIndex;
    final fBIndex = _playbackFrameIndex + 1;
    final fA = frames[fAIndex];
    final fB = frames[fBIndex];

    // Get the specific ball by ID, or first ball if no ID provided
    Ball? ballB;
    Ball? ballA;
    if (ballId != null) {
      ballB = fB.getBallById(ballId);
      ballA = fA.getBallById(ballId);
    } else if (fB.balls.isNotEmpty) {
      ballB = fB.balls.first;
      ballA = fA.balls.isNotEmpty ? fA.balls.first : null;
    }

    if (ballB == null || ballA == null || ballB.hitT == null) return {};

    final globalNow = _playbackFrameIndex + _playbackT;
    final hitGlobal = _playbackFrameIndex + ballB.hitT!;
    const double hold = 0.5;
    if (!(globalNow >= hitGlobal && globalNow <= hitGlobal + hold)) return {};
    // compute hit position along the path (use two-quad engine if control point exists)
    final hasCtrl = ballB.pathPoints.isNotEmpty;
    final posCm = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: ballA.position,
            control: ballB.pathPoints.first,
            end: ballB.position,
            resolution: 400,
          ).sample(ballB.hitT!)
        : Offset.lerp(ballA.position, ballB.position, ballB.hitT!)!;
    final pos = _toScreenPosition(posCm, size);
    final fadeT = ((globalNow - hitGlobal) / hold).clamp(0.0, 1.0);
    final opacity = (0.9 - (fadeT * 0.75)).clamp(0.12, 0.9);
    return {'pos': pos, 'opacity': opacity};
  }

  // control handles are drawn via widgets so this helper is unused and removed

  @override
  Widget build(BuildContext context) {
    final screenSize = _effectiveScreenSize(context);
    final isPlayback = _isPlaying && _animatedFrame != null;
    final prev = _getPreviousFrame();
    final inPlaybackView = _isPlaying || _endedAtLastFrame;
    // During playback or when scrubbing in ended state, show interpolated frame
    final frameToShow = (inPlaybackView && _animatedFrame != null) ? _animatedFrame! : currentFrame;
    final renderZoomFactor = _resolveRenderZoomFactor(frameToShow, inPlaybackView, screenSize);
    _activeRenderZoomFactor = renderZoomFactor;
    final renderSettings = _settings.copy()..serveZoneFactor = renderZoomFactor;
    final editingFrameIndex = widget.project.frames.indexOf(currentFrame);
    final renderFrameIndex = inPlaybackView
        ? _playbackDisplayFrameIndex()
        : (editingFrameIndex < 0 ? 0 : editingFrameIndex.clamp(0, widget.project.frames.length - 1));
    final savedAnnotationsToRender = widget.project.frames[renderFrameIndex].annotations;
    final sessionPlaybackAnnotationsToRender =
        (isPlayback && !_isPaused && _playbackFrameIndex < widget.project.frames.length - 1)
        ? _interpolatePlaybackSessionAnnotations(_playbackFrameIndex, _playbackFrameIndex + 1, _playbackT)
        : _playbackSessionAnnotationsForFrame(renderFrameIndex);
    final tempAnnotationsToRender = <Annotation>[...sessionPlaybackAnnotationsToRender, ..._stagedAnnotations];
    final showPlaybackTempShadow = inPlaybackView && sessionPlaybackAnnotationsToRender.isNotEmpty;
    // Timeline maintains consistent height during state transitions to avoid layout shifts
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackNavigationRequested();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.project.name),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Projects',
            onPressed: _handleBackNavigationRequested,
          ),
          actions: [
            if (!_isPlaying && !_endedAtLastFrame)
              IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/object_menu.svg',
                  colorFilter: ColorFilter.mode(_objectsMenuOpen ? Colors.white : AppTheme.lightGrey, BlendMode.srcIn),
                  width: 24,
                  height: 24,
                ),
                tooltip: _objectsMenuOpen ? 'Close Objects Menu' : 'Open Objects Menu',
                onPressed: () => _setActiveMenu(BoardMenu.objects),
                isSelected: _objectsMenuOpen,
              ),
            if ((!_isPlaying && !_endedAtLastFrame) || _isPausedPlayback)
              IconButton(
                key: _annotationModeButtonKey,
                icon: SvgPicture.asset(
                  'assets/icons/annotations_menu.svg',
                  colorFilter: ColorFilter.mode(
                    _annotationsMenuOpen ? Colors.white : AppTheme.lightGrey,
                    BlendMode.srcIn,
                  ),
                  width: 24,
                  height: 24,
                ),
                tooltip: _annotationsMenuOpen ? 'Close Annotations Menu' : 'Open Annotations Menu',
                onPressed: () => _setActiveMenu(BoardMenu.annotations),
                isSelected: _annotationsMenuOpen,
              ),
            // Edit Court button - only show for training projects
            if (widget.project.projectType == ProjectType.training && !_isPlaying && !_endedAtLastFrame)
              IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/court_editor.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                tooltip: 'Edit Court',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CourtEditingScreen(project: widget.project)),
                  );
                  // Refresh board after court editing
                  setState(() {});
                },
              ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(project: widget.project)),
                );
                // Reload settings after returning from settings screen so toggles take effect immediately
                setState(() {
                  _settings = widget.project.settings!;
                  _settingsRevision++; // Force repaint of court elements with new scaling
                });
              },
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: null, // Moved to app bar actions
        body: SafeArea(
          bottom: true, // Account for system navigation bars at bottom (Android)
          child: Stack(
            children: [
              // Layer 1 (bottom): Board - stays fixed
              Positioned.fill(
                bottom: _timelineHeight, // Leave room for timeline (no grey strip)
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final Size screenSize = constraints.biggest;
                    Settings.setScreenSize(screenSize);
                    return AbsorbPointer(
                      absorbing: _endedAtLastFrame,
                      child: Container(
                        key: _boardKey,
                        color: _settings.courtBackgroundColor,
                        child: Stack(
                          children: [
                            // ┌─────────────────────────────────────────────────────┐
                            // │ BOARD BACKGROUND (Expensive - wrapped in RepaintBoundary)
                            // │ Only repaints when settings change (rare)
                            // └─────────────────────────────────────────────────────┘
                            RepaintBoundary(
                              child: CustomPaint(
                                size: screenSize,
                                painter: BoardBackgroundPainter(
                                  screenSize: screenSize,
                                  settings: renderSettings,
                                  customElements: widget.project.customCourtElements,
                                  projectType: widget.project.projectType,
                                  settingsRevision: _settingsRevision,
                                ),
                              ),
                            ),
                            if (!(_isPlaying || _endedAtLastFrame))
                              // ┌─────────────────────────────────────────────────────┐
                              // │ PATH PAINTER (Repaints on every build for live update)
                              // │ Only drawn in edit mode, repaints continuously during
                              // │ drag for real-time path feedback
                              // └─────────────────────────────────────────────────────┘
                              CustomPaint(
                                size: screenSize,
                                painter: PathPainter(
                                  currentFrame: frameToShow,
                                  previousFrame: _getPreviousFrame(),
                                  twoFramesAgo: _getTwoFramesAgo(),
                                  screenSize: screenSize,
                                  settings: renderSettings,
                                  pathRevision: _pathRevision,
                                ),
                              ),
                            // Draw annotations below objects when toggled off
                            if (!_settings.annotationsAboveObjects)
                              IgnorePointer(
                                ignoring: true,
                                child: AnnotationPainter(
                                  annotations: savedAnnotationsToRender,
                                  tempAnnotations: tempAnnotationsToRender.isNotEmpty ? tempAnnotationsToRender : null,
                                  tempAnnotationsShadow: showPlaybackTempShadow,
                                  erasingAnnotations: _erasingAnnotations.isNotEmpty ? _erasingAnnotations : null,
                                  dragPreviewLine:
                                      _annotationsMenuOpen &&
                                          (_activeAnnotationTool == AnnotationTool.line ||
                                              _activeAnnotationTool == AnnotationTool.marker) &&
                                          _pendingAnnotationPoints.isNotEmpty &&
                                          _currentDragPos != null
                                      ? _activeAnnotationTool == AnnotationTool.marker
                                            ? [_currentDragPos!, _currentDragPos!]
                                            : [_pendingAnnotationPoints.first, _currentDragPos!]
                                      : null,
                                  dragPreviewLineStyle: _activeAnnotationTool == AnnotationTool.marker
                                      ? _annotationMarkerStyle
                                      : _annotationLineStyle,
                                  handDrawnStyle: _settings.handDrawnAnnotations,
                                  showCurvedControlHandles: false,
                                  selectedAnnotation: _selectedAnnotation,
                                  settings: renderSettings,
                                  screenSize: screenSize,
                                  strokeWidthCm: _annotationStrokeCm,
                                ),
                              ),
                            // Draw eraser circle when eraser is active (desktop/non-phone web only)
                            if (_shouldShowEraserOverlay(context))
                              IgnorePointer(
                                ignoring: true,
                                child: CustomPaint(
                                  size: screenSize,
                                  painter: _EraserCirclePainter(
                                    centerCm: _eraserPosCm!,
                                    radiusCm: _annotationEraserRadiusCm,
                                    screenSize: screenSize,
                                    settings: renderSettings,
                                  ),
                                ),
                              ),
                            // Draw transparent center cross (20cm x 20cm)
                            IgnorePointer(
                              ignoring: true,
                              child: CustomPaint(
                                size: screenSize,
                                  painter: _CenterCrossPainter(screenSize: screenSize, settings: renderSettings),
                              ),
                            ),
                            if (_lastSnapPointCm != null)
                              IgnorePointer(
                                ignoring: true,
                                child: CustomPaint(
                                  size: screenSize,
                                  painter: _SnapBurstPainter(
                                    centerCm: _lastSnapPointCm!,
                                    progress: _snapPulseController,
                                    settings: renderSettings,
                                    screenSize: screenSize,
                                  ),
                                ),
                              ),
                            // Draw sector zone outlines with pulsing glow during target selection
                            if (_sectorToolNeedsTargetSelection)
                              IgnorePointer(
                                ignoring: true,
                                child: CustomPaint(
                                  size: screenSize,
                                  painter: _SectorZoneOutlinePainter(
                                    settings: renderSettings,
                                    boardSize: screenSize,
                                    pulseAnimation: _selectionPulseController,
                                    highlightedZone: _selectedSectorTarget,
                                    attachmentType: _sectorAttachmentType,
                                    projectType: widget.project.projectType,
                                    customCourtElements: widget.project.customCourtElements,
                                    players: frameToShow.players,
                                    balls: frameToShow.balls,
                                  ),
                                ),
                              ),
                            // Draw subtle highlight on selected target zone during drawing phase
                            if (_sectorTargetHighlightActive &&
                                _selectedSectorCenterCm != null &&
                                _selectedSectorRadiusCm != null)
                              IgnorePointer(
                                ignoring: true,
                                child: CustomPaint(
                                  size: screenSize,
                                  painter: _SectorTargetHighlightPainter(
                                    centerCm: _selectedSectorCenterCm!,
                                    radiusCm: _selectedSectorRadiusCm!,
                                    screenSize: screenSize,
                                    settings: renderSettings,
                                  ),
                                ),
                              ),
                            // Full-board tap & drag handler
                            Positioned.fill(
                              child: GestureDetector(
                                onTapUp: (details) {
                                  // Handle path tracking toggle during paused playback when objects menu is open
                                  if (_isPausedPlayback && _objectsMenuOpen) {
                                    _togglePathTracking(details.localPosition, screenSize);
                                    return;
                                  }
                                  if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
                                  if (!(_isPlaying || _endedAtLastFrame) || _isPausedPlayback) {
                                    if (_pendingBallMark == 'hit') {
                                      _placeBallHitAt(details.localPosition, screenSize);
                                    } else {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _handleBoardTap(details.localPosition, screenSize);
                                      });
                                    }
                                  }
                                },
                                onDoubleTapDown: (details) {
                                  if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
                                  if (_annotationsMenuOpen) {
                                    final clampedTap = _clampToInteractionBounds(details.localPosition, screenSize);
                                    final tapCm = _screenToCm(clampedTap, screenSize);
                                    if (_activeAnnotationTool == AnnotationTool.move) {
                                      final target = _findAnnotationAt(tapCm, screenSize);
                                      if (target != null) {
                                        _editAnnotationStyle(target, screenSize);
                                      }
                                      return;
                                    }
                                    final target = _findTextAnnotationAt(tapCm, screenSize);
                                    if (target != null && _activeAnnotationTool == AnnotationTool.text) {
                                      _editTextAnnotation(target, screenSize);
                                    }
                                  }
                                },
                                onDoubleTap: () {
                                  // Close annotation menu on double-tap when no tool is selected
                                  // Helps teach users that objects can't be moved while in annotation mode
                                  if (_annotationsMenuOpen &&
                                      _activeAnnotationTool == AnnotationTool.none &&
                                      !_eraserMode) {
                                    setState(() {
                                      _activeMenu = BoardMenu.none;
                                      _pendingAnnotationPoints.clear();
                                      _deactivateAnnotationTools();
                                    });
                                  }
                                },
                                onPanStart: (details) {
                                  if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
                                  if (_annotationsMenuOpen) {
                                    _handleAnnotationDragStart(details, screenSize);
                                  } else if (!_isPausedPlayback) {
                                    _maybeStartPathDrag(details.localPosition, screenSize);
                                  }
                                },
                                onPanUpdate: (details) {
                                  if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
                                  if (_annotationsMenuOpen) {
                                    _handleAnnotationDragUpdate(details, screenSize);
                                  } else if (!_isPausedPlayback && _activePathDragId != null) {
                                    _updatePathDrag(details.localPosition, screenSize);
                                  }
                                },
                                onPanEnd: (details) {
                                  if ((_isPlaying && !_isPaused) || _endedAtLastFrame) return;
                                  if (_annotationsMenuOpen) {
                                    _handleAnnotationDragEnd(details, screenSize);
                                  } else if (!_isPausedPlayback && _activePathDragId != null) {
                                    _endPathDrag();
                                  }
                                },
                                behavior: HitTestBehavior.translucent,
                                child: Container(),
                              ),
                            ),
                            // Tracked paths (behind objects)
                            ..._buildTrackedPaths(screenSize),
                            if (widget.project.projectType == ProjectType.training) ...[
                              for (final player in frameToShow.players)
                                _buildPlayer(
                                  player.position,
                                  player.rotation,
                                  player.color,
                                  player.id,
                                  screenSize,
                                  label: player.label,
                                ),
                              for (final ball in frameToShow.balls)
                                _buildBall(
                                  ball.position,
                                  screenSize,
                                  scale: isPlayback ? _ballScaleAt(_playbackT, ballId: ball.id) : 1.0,
                                  starOpacity: 0.0,
                                  ballId: ball.id,
                                  color: ball.color,
                                ),
                            ] else ...[
                              for (final player in frameToShow.players)
                                _buildPlayer(
                                  player.position,
                                  player.rotation,
                                  player.color,
                                  player.id,
                                  screenSize,
                                  label: player.label,
                                ),
                              for (final ball in frameToShow.balls)
                                _buildBall(
                                  ball.position,
                                  screenSize,
                                  scale: isPlayback ? _ballScaleAt(_playbackT, ballId: ball.id) : 1.0,
                                  starOpacity: 0.0,
                                  ballId: ball.id,
                                  color: ball.color,
                                ),
                            ],
                            // Draw annotations above objects when toggled on
                            if (_settings.annotationsAboveObjects)
                              IgnorePointer(
                                ignoring: true,
                                child: AnnotationPainter(
                                  annotations: savedAnnotationsToRender,
                                  tempAnnotations: tempAnnotationsToRender.isNotEmpty ? tempAnnotationsToRender : null,
                                  tempAnnotationsShadow: showPlaybackTempShadow,
                                  erasingAnnotations: _erasingAnnotations.isNotEmpty ? _erasingAnnotations : null,
                                  dragPreviewLine:
                                      _annotationsMenuOpen &&
                                          (_activeAnnotationTool == AnnotationTool.line ||
                                              _activeAnnotationTool == AnnotationTool.marker) &&
                                          _pendingAnnotationPoints.isNotEmpty &&
                                          _currentDragPos != null
                                      ? _activeAnnotationTool == AnnotationTool.marker
                                            ? [_currentDragPos!, _currentDragPos!]
                                            : [_pendingAnnotationPoints.first, _currentDragPos!]
                                      : null,
                                  dragPreviewLineStyle: _activeAnnotationTool == AnnotationTool.marker
                                      ? _annotationMarkerStyle
                                      : _annotationLineStyle,
                                  handDrawnStyle: _settings.handDrawnAnnotations,
                                  showCurvedControlHandles: false,
                                  selectedAnnotation: _selectedAnnotation,
                                  settings: renderSettings,
                                  screenSize: screenSize,
                                  strokeWidthCm: _annotationStrokeCm,
                                ),
                              ),
                            if (isPlayback) ...[
                              // Render hit star for each ball that has hitT set
                              for (final ball in frameToShow.balls)
                                (() {
                                  final info = _playbackHitStarInfo(screenSize, ballId: ball.id);
                                  if (info.isNotEmpty) {
                                    final pos = info['pos'] as Offset;
                                    final opacity = (info['opacity'] as double?) ?? 1.0;
                                    return Positioned(
                                      left: pos.dx - 12,
                                      top: pos.dy - 12,
                                      child: Opacity(
                                        opacity: opacity,
                                        child: CustomPaint(size: const Size(24, 24), painter: _StarPainter()),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                })(),
                            ],
                            if (!isPlayback) ..._buildAllSetPreviewsForEditing(screenSize),
                            if (!(_isPlaying || _endedAtLastFrame)) ...[
                              // Show control points for all players by ID
                              ...(() {
                                final showControls = _activePathDragId != null;
                                if (!showControls) return <Widget>[];
                                final widgets = <Widget>[];
                                for (final player in currentFrame.players) {
                                  if (player.pathPoints.isNotEmpty) {
                                    final prevPlayer = prev?.getPlayerById(player.id);
                                    final prevPos = prevPlayer?.position ?? player.position;
                                    // If actively editing a specific path, only show its control points
                                    if (_activePathDragId == null || _activePathDragId == player.id) {
                                      widgets.addAll(
                                        _buildPathControlPoints(
                                          player.pathPoints,
                                          prevPos,
                                          player.position,
                                          screenSize,
                                          player.id,
                                        ),
                                      );
                                    }
                                  }
                                }
                                return widgets;
                              })(),
                              // For balls, show control points for all balls
                              ...(() {
                                final showControls = _activePathDragId != null;
                                if (!showControls) return <Widget>[];
                                final widgets = <Widget>[];
                                for (final ball in currentFrame.balls) {
                                  if (ball.pathPoints.isNotEmpty) {
                                    final prevBall = prev?.getBallById(ball.id);
                                    final prevPos = prevBall?.position ?? ball.position;
                                    // Show during active drag regardless of whether the internal label is "BALL" or the ball's ID
                                    if (_activePathDragId == null ||
                                        _activePathDragId == "BALL" ||
                                        _activePathDragId == ball.id) {
                                      widgets.addAll(
                                        _buildPathControlPoints(
                                          ball.pathPoints,
                                          prevPos,
                                          ball.position,
                                          screenSize,
                                          ball.id,
                                        ),
                                      );
                                    }
                                  }
                                }
                                return widgets;
                              })(),
                            ],
                            // Show hit markers for all balls
                            if (!(_isPlaying || _endedAtLastFrame)) ..._buildAllHitMarkersForEditing(screenSize),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Layer 2: Timeline - fixed at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _timelineHeight,
                child: AnimatedContainer(
                  height: _timelineHeight,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  color: AppTheme.timelineBackground,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Stack(
                    children: [
                      // Thumbnails ListView positioned at bottom
                      // In edit mode: show all frames (0 to N)
                      // In playback mode: skip first frame (1 to N)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 24,
                        height: (_timelineHeight - 40 - 28),
                        child: AbsorbPointer(
                          absorbing: inPlaybackView,
                          child: ListView.builder(
                            key: _timelineKey,
                            controller: _timelineController,
                            scrollDirection: Axis.horizontal,
                            itemCount: inPlaybackView ? widget.project.frames.length - 1 : widget.project.frames.length,
                            itemBuilder: (context, index) {
                              final frame = inPlaybackView
                                  ? widget.project.frames[index + 1]
                                  : widget.project.frames[index];
                              final frameIndex = widget.project.frames.indexOf(frame);
                              final isSelected = frame == currentFrame;
                              return GestureDetector(
                                onTap: () {
                                  if (!(_isPlaying || _endedAtLastFrame)) {
                                    setState(() {
                                      currentFrame = frame;
                                      _deleteFrameButtonIndex = null;
                                    });
                                    _scrollToSelectedFrame();
                                  }
                                },
                                onDoubleTap: () {
                                  if (_isPlaying || _endedAtLastFrame) return;
                                  setState(() {
                                    if (isSelected) {
                                      _deleteFrameButtonIndex = _deleteFrameButtonIndex == frameIndex
                                          ? null
                                          : frameIndex;
                                    } else {
                                      currentFrame = frame;
                                      _deleteFrameButtonIndex = null;
                                    }
                                  });
                                  _scrollToSelectedFrame();
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 40,
                                      margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall),
                                      decoration: BoxDecoration(
                                        color: inPlaybackView
                                            ? AppTheme.timelineInactive
                                            : (isSelected ? AppTheme.timelineActive : AppTheme.timelineInactive),
                                        borderRadius: BorderRadius.circular(24),
                                        border: (inPlaybackView)
                                            ? null
                                            : (isSelected ? Border.all(color: AppTheme.primaryBlue, width: 2.5) : null),
                                        boxShadow: isSelected && !inPlaybackView
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          "${inPlaybackView ? index + 1 : index}",
                                          style: TextStyle(
                                            fontWeight: isSelected && !inPlaybackView
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected && !inPlaybackView ? Colors.white : AppTheme.darkGrey,
                                          ),
                                        ),
                                      ), // Playback: starts at 1, Edit: starts at 0
                                    ),
                                    if (isSelected &&
                                        !(_isPlaying || _endedAtLastFrame) &&
                                        _deleteFrameButtonIndex == frameIndex)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            _confirmDeleteFrame(frame);
                                            setState(() => _deleteFrameButtonIndex = null);
                                          },
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: AppTheme.errorRed,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.2),
                                                  blurRadius: 2,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Symbols.delete, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Playback frame cursor overlay (shows current frame index during playback)
                      if (_isPlaying || _endedAtLastFrame)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 52,
                          height: (_timelineHeight - 40 - 52),
                          child: AbsorbPointer(
                            absorbing: false,
                            child: Container(
                              color: Colors.transparent,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final frameCount = widget.project.frames.length;
                                  if (frameCount < 2) return const SizedBox.shrink();
                                  // Calculate cursor position with interpolation and scroll offset
                                  // Skip first frame: timeline shows frames 1+ only
                                  // Frame i in timeline is at index i-1
                                  // Cursor at left of frame i when entering frame i (from frame i-1 animation ending)
                                  // Cursor at right of frame i when leaving frame i (entering frame i+1)
                                  final itemExtent = 72.0; // 56 width + 2*8 margin

                                  // Map playback frame index to timeline index (offset by -1 to skip first frame)
                                  // At frame 0, we're at the boundary before frame 1 (timeline index -1, clamped)
                                  // At frame 1, we're showing frame 1 (timeline index 0)
                                  final interpolatedPosition = _playbackFrameIndex + _playbackT;
                                  final timelineIndex = interpolatedPosition - 1.0;
                                  // Increase cursor X position by half the distance between frame midpoints
                                  final cursorWorldX =
                                      timelineIndex * itemExtent +
                                      itemExtent / 2 +
                                      (itemExtent / 2); // Added half itemExtent

                                  // Get scroll offset from timeline controller
                                  final scrollOffset = _timelineController.hasClients ? _timelineController.offset : 0;

                                  // Cursor position relative to the visible viewport
                                  final cursorX = cursorWorldX - scrollOffset;

                                  return Stack(
                                    children: [
                                      Positioned(
                                        left: cursorX - 2,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 4,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.primaryBlue.withValues(alpha: 0.5),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                      // Playback controls overlayed at top (playback slider / scrubber slider)
                      if (_isPlaying || _endedAtLastFrame)
                        Positioned(
                          top: 0,
                          left: 24,
                          right: 24,
                          height: 28,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) {
                              if (widget.project.frames.length < 2) return;
                              RenderBox? box = context.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final local = box.globalToLocal(details.globalPosition);
                              final leftPadding = 24.0;
                              final rightPadding = 24.0;
                              final available = box.size.width - leftPadding - rightPadding;
                              final dx = (local.dx - leftPadding).clamp(0.0, available);
                              final frac = (available <= 0) ? 0.0 : (dx / available);
                              setState(() {
                                // Mark that scrubber was manually moved
                                _scrubberMovedManually = true;
                                final total = (widget.project.frames.length - 1).toDouble();
                                final globalPos = frac * total;
                                _playbackFrameIndex = globalPos.floor();
                                _playbackT = globalPos - _playbackFrameIndex;

                                // If scrubber is moved away from the end, resume playback mode (paused)
                                if (_endedAtLastFrame && globalPos < total) {
                                  _isPlaying = true;
                                  _isPaused = true;
                                }
                              });
                              _scrollToPlaybackFrame();
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const scrubbersize = 20.0;
                                final leftPadding = 8.0;
                                final rightPadding = 8.0;
                                final width = constraints.maxWidth;
                                final available = (width - leftPadding - rightPadding).clamp(0.0, double.infinity);
                                final frac = widget.project.frames.length > 1
                                    ? ((_playbackFrameIndex + _playbackT) /
                                              (widget.project.frames.length - 1).toDouble())
                                          .clamp(0.0, 1.0)
                                    : 0.0;
                                final dotX = leftPadding + frac * available;
                                return SizedBox(
                                  height: 30,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: leftPadding,
                                        right: rightPadding,
                                        top: 8,
                                        child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: AppTheme.timelineInactive,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: dotX - scrubbersize / 2,
                                        top: 8 - (scrubbersize - 4) / 2,
                                        child: Container(
                                          width: scrubbersize,
                                          height: scrubbersize,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      // Playback controls at bottom (speed slider + buttons)
                      if (_isPlaying || _endedAtLastFrame)
                        Positioned(
                          bottom: 8,
                          left: 12,
                          right: 12,
                          height: 40,
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: _handleStopPlaybackPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.errorRed,
                                  minimumSize: const Size(40, 40),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Icon(Icons.stop, size: 20),
                              ),
                              const SizedBox(width: AppConstants.paddingSmall),
                              ElevatedButton(
                                onPressed: (_endedAtLastFrame && !_scrubberMovedManually)
                                    ? null
                                    : (_isPaused ? _resumePlayback : _pausePlayback),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isPaused ? Colors.green : AppTheme.warningAmber,
                                  minimumSize: const Size(48, 40),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 20),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 150,
                                child: Slider(
                                  value: _nearestZoomStageIndex(renderZoomFactor).toDouble(),
                                  min: 0,
                                  max: (_zoomStageFactors.length - 1).toDouble(),
                                  divisions: _zoomStageFactors.length - 1,
                                  label: 'Zoom S${_nearestZoomStageIndex(renderZoomFactor) + 1}',
                                  onChanged: (v) => _setZoomStageFromSlider(v, inPlaybackView: true),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  'S${_nearestZoomStageIndex(renderZoomFactor) + 1}',
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 200,
                                child: Slider(
                                  value: _playbackSpeed,
                                  min: 0.1,
                                  max: 2.0,
                                  divisions: 19,
                                  label: "${_playbackSpeed.toStringAsFixed(1)}x",
                                  onChanged: (v) => setState(() => _playbackSpeed = v),
                                ),
                              ),
                              const SizedBox(width: 2),
                              SizedBox(
                                width: 35,
                                child: Text(
                                  "${_playbackSpeed.toStringAsFixed(1)}x",
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),

                      // Edit controls (bottom, editing mode only)
                      if (!(_isPlaying || _endedAtLastFrame))
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 12,
                          height: 40,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    key: _playButtonKey,
                                    onPressed: (_isPlaying || _endedAtLastFrame) ? _stopPlayback : _startPlayback,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: (_isPlaying || _endedAtLastFrame)
                                          ? AppTheme.errorRed
                                          : Colors.green,
                                      minimumSize: const Size(48, 40),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Icon(
                                      (_isPlaying || _endedAtLastFrame) ? Icons.stop : Icons.play_arrow,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.paddingSmall),
                                  ElevatedButton(
                                    key: _frameAddButtonKey,
                                    onPressed: (_isPlaying || _endedAtLastFrame) ? null : _insertFrameAfterCurrent,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(48, 40),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Icon(Icons.add, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 145,
                                    child: Slider(
                                      value: _nearestZoomStageIndex(renderZoomFactor).toDouble(),
                                      min: 0,
                                      max: (_zoomStageFactors.length - 1).toDouble(),
                                      divisions: _zoomStageFactors.length - 1,
                                      label: 'Zoom S${_nearestZoomStageIndex(renderZoomFactor) + 1}',
                                      onChanged: (v) => _setZoomStageFromSlider(v, inPlaybackView: false),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 34,
                                    child: Text(
                                      'S${_nearestZoomStageIndex(renderZoomFactor) + 1}',
                                      style: const TextStyle(fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!(_isPlaying || _endedAtLastFrame))
                                    Expanded(
                                      flex: 0,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: IconButton(
                                          icon: const Icon(Icons.schedule),
                                          tooltip: "Set frame duration (${currentFrame.duration.toStringAsFixed(2)}s)",
                                          iconSize: 18,
                                          onPressed: () => _showDurationPicker(),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.undo),
                                    tooltip: "Undo",
                                    iconSize: 18,
                                    onPressed: (_isPlaying || _endedAtLastFrame)
                                        ? null
                                        : (_history.canUndo
                                              ? () {
                                                  final idx = _history.undo();
                                                  if (idx != null && idx >= 0 && idx < widget.project.frames.length) {
                                                    setState(() {
                                                      currentFrame = widget.project.frames[idx];
                                                      _activePathDragId = null;
                                                      _activePathDragIndex = null;
                                                      _pathRevision++;
                                                    });
                                                    _scrollToSelectedFrame();
                                                  } else {
                                                    setState(() {
                                                      _activePathDragId = null;
                                                      _activePathDragIndex = null;
                                                      _pathRevision++;
                                                    });
                                                  }
                                                }
                                              : null),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.redo),
                                    tooltip: "Redo",
                                    iconSize: 18,
                                    onPressed: (_isPlaying || _endedAtLastFrame)
                                        ? null
                                        : (_history.canRedo
                                              ? () {
                                                  final idx = _history.redo();
                                                  if (idx != null && idx >= 0 && idx < widget.project.frames.length) {
                                                    setState(() {
                                                      currentFrame = widget.project.frames[idx];
                                                      _activePathDragId = null;
                                                      _activePathDragIndex = null;
                                                      _pathRevision++;
                                                    });
                                                    _scrollToSelectedFrame();
                                                  } else {
                                                    setState(() {
                                                      _activePathDragId = null;
                                                      _activePathDragIndex = null;
                                                      _pathRevision++;
                                                    });
                                                  }
                                                }
                                              : null),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Layer 3 (top): Objects Menu - overlay at top
              if (_objectsMenuOpen)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _objectsMenuHeight,
                  child: Container(
                    color: AppTheme.lightGrey,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Builder(
                        builder: (context) {
                          final canEditObjects =
                              widget.project.projectType == ProjectType.training && !_isPlaying && !_endedAtLastFrame;
                          final isAddPlayerActive = _addingObjectType == 'player';
                          final isAddBallActive = _addingObjectType == 'ball';
                          final noObjectSelected =
                              !_showModifierMenu &&
                              !_showPlayerMenu &&
                              _activePlayerId == null &&
                              _activeBallId == null;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.project.projectType == ProjectType.training) ...[
                                _buildMenuButton(
                                  tooltip: 'Add Player',
                                  onPressed: _startAddPlayer,
                                  enabled: canEditObjects,
                                  backgroundColor: isAddPlayerActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
                                  iconColorOverride: _contrastIconColor(
                                    isAddPlayerActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
                                    Colors.white,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/add_player.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: ColorFilter.mode(
                                      _contrastIconColor(
                                        isAddPlayerActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
                                        Colors.white,
                                      ),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                _buildMenuButton(
                                  tooltip: 'Add Ball',
                                  onPressed: _startAddBall,
                                  enabled: canEditObjects,
                                  backgroundColor: isAddBallActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
                                  iconColorOverride: _contrastIconColor(
                                    isAddBallActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
                                    Colors.white,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/add_ball.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: ColorFilter.mode(
                                      _contrastIconColor(
                                        isAddBallActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
                                        Colors.white,
                                      ),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ],
                              if (noObjectSelected)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Opacity(
                                    opacity: 0.65,
                                    child: Text(
                                      'Select a Player or Ball',
                                      style: TextStyle(
                                        color: AppTheme.darkGrey,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_showModifierMenu)
                                _buildMenuButton(
                                  tooltip: 'Set',
                                  onPressed: () {
                                    setState(() {
                                      if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
                                        final ball = currentFrame.getBallById(_activeBallId!);
                                        if (ball != null) {
                                          if (ball.isSet ?? false) {
                                            ball.isSet = false;
                                          } else {
                                            ball.isSet = true;
                                            ball.hitT = null;
                                          }
                                        }
                                      } else if (currentFrame.balls.isNotEmpty) {
                                        final ball = currentFrame.balls.first;
                                        if (ball.isSet ?? false) {
                                          ball.isSet = false;
                                        } else {
                                          ball.isSet = true;
                                          ball.hitT = null;
                                        }
                                      }
                                    });
                                    _saveProject();
                                  },
                                  backgroundColor:
                                      (widget.project.projectType == ProjectType.training && _activeBallId != null
                                          ? (currentFrame.getBallById(_activeBallId!)?.isSet ?? false)
                                          : (currentFrame.balls.isNotEmpty &&
                                                (currentFrame.balls.first.isSet ?? false)))
                                      ? AppTheme.accentOrange
                                      : AppTheme.mediumGrey,
                                  child: CustomPaint(
                                    size: const Size(24, 24),
                                    painter: _SetIconPainter(
                                      active:
                                          widget.project.projectType == ProjectType.training && _activeBallId != null
                                          ? (currentFrame.getBallById(_activeBallId!)?.isSet ?? false)
                                          : (currentFrame.balls.isNotEmpty &&
                                                (currentFrame.balls.first.isSet ?? false)),
                                    ),
                                  ),
                                ),
                              if (_showModifierMenu)
                                _buildMenuButton(
                                  tooltip: 'Hit',
                                  onPressed: () {
                                    final prev = _getPreviousFrame();
                                    if (prev != null) {
                                      const tStart = 0.0;
                                      setState(() {
                                        if (widget.project.projectType == ProjectType.training &&
                                            _activeBallId != null) {
                                          final ball = currentFrame.getBallById(_activeBallId!);
                                          if (ball != null) {
                                            if (ball.hitT != null) {
                                              ball.hitT = null;
                                            } else {
                                              ball.hitT = tStart;
                                              ball.isSet = false;
                                            }
                                          }
                                        } else if (currentFrame.balls.isNotEmpty) {
                                          final ball = currentFrame.balls.first;
                                          if (ball.hitT != null) {
                                            ball.hitT = null;
                                          } else {
                                            ball.hitT = tStart;
                                            ball.isSet = false;
                                          }
                                        }
                                      });
                                      _saveProject();
                                    }
                                  },
                                  backgroundColor:
                                      (widget.project.projectType == ProjectType.training && _activeBallId != null
                                          ? (currentFrame.getBallById(_activeBallId!)?.hitT != null)
                                          : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.hitT != null)))
                                      ? AppTheme.warningAmber
                                      : AppTheme.mediumGrey,
                                  child: CustomPaint(
                                    size: const Size(24, 24),
                                    painter: _HitIconPainter(
                                      active:
                                          widget.project.projectType == ProjectType.training && _activeBallId != null
                                          ? (currentFrame.getBallById(_activeBallId!)?.hitT != null)
                                          : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.hitT != null)),
                                    ),
                                  ),
                                ),
                              if (_showModifierMenu &&
                                  ((widget.project.projectType == ProjectType.training && _activeBallId != null) ||
                                      (widget.project.projectType == ProjectType.play &&
                                          currentFrame.balls.isNotEmpty)))
                                _buildMenuButton(
                                  tooltip: 'Ball Color',
                                  onPressed: _showBallColorPicker,
                                  backgroundColor: AppTheme.mediumGrey,
                                  child: Icon(
                                    Icons.palette,
                                    size: 22,
                                    color: (widget.project.projectType == ProjectType.training && _activeBallId != null)
                                        ? (currentFrame.getBallById(_activeBallId!)?.color ?? AppTheme.lightGrey)
                                        : (currentFrame.balls.isNotEmpty
                                              ? currentFrame.balls.first.color
                                              : AppTheme.lightGrey),
                                  ),
                                ),
                              if (_showModifierMenu &&
                                  widget.project.projectType == ProjectType.training &&
                                  currentFrame.balls.length > 1 &&
                                  _activeBallId != null)
                                _buildMenuButton(
                                  tooltip: 'Delete Ball',
                                  onPressed: () => _undoableDeleteBallFromAllFrames(_activeBallId!),
                                  backgroundColor: AppTheme.errorRed,
                                  child: const Icon(Icons.delete, size: 22),
                                ),
                              if (_showPlayerMenu && _activePlayerId != null)
                                Builder(
                                  builder: (context) {
                                    final activePlayer = currentFrame.getPlayerById(_activePlayerId!);
                                    return Row(
                                      children: [
                                        _buildMenuButton(
                                          tooltip: 'Player Color',
                                          onPressed: _showPlayerColorPicker,
                                          backgroundColor: AppTheme.mediumGrey,
                                          child: Icon(
                                            Icons.palette,
                                            size: 22,
                                            color: activePlayer?.color ?? AppTheme.primaryBlue,
                                          ),
                                        ),
                                        _buildMenuButton(
                                          tooltip: 'Player Label',
                                          onPressed: _showPlayerLabelDialog,
                                          backgroundColor: AppTheme.mediumGrey,
                                          child: const Icon(Icons.text_fields, size: 22),
                                        ),
                                        if (widget.project.projectType == ProjectType.training &&
                                            currentFrame.players.length > 1)
                                          _buildMenuButton(
                                            tooltip: 'Delete Player',
                                            onPressed: () {
                                              if (_activePlayerId != null) {
                                                _undoableDeletePlayerFromAllFrames(_activePlayerId!);
                                              }
                                            },
                                            backgroundColor: AppTheme.errorRed,
                                            child: const Icon(Icons.delete, size: 22),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              // Layer 4 (top): Annotation Toolbar - overlay at top
              if (_annotationsMenuOpen)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _annotationMenuHeight,
                  child: Container(
                    color: AppTheme.lightGrey,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildMenuButton(
                                tooltip: _lineStyleLabel(_annotationLineStyle),
                                onPressed: () => setState(() => _setAnnotationTool(AnnotationTool.line)),
                                onDoubleTap: () => _toggleAnnotationLineStyleMenu(forceOpen: true),
                                buttonKey: _annotationLineStyleButtonKey,
                                backgroundColor: _activeAnnotationTool == AnnotationTool.line
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGrey,
                                child: Icon(_iconForLineStyle(_annotationLineStyle), size: 20),
                              ),
                              _buildMenuButton(
                                tooltip: 'Freehand Tool (double-tap for line style)',
                                onPressed: () => setState(() => _setAnnotationTool(AnnotationTool.freehand)),
                                onDoubleTap: () => _toggleFreehandLineStyleMenu(forceOpen: true),
                                buttonKey: _freehandLineStyleButtonKey,
                                backgroundColor: _activeAnnotationTool == AnnotationTool.freehand
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGrey,
                                child: const Icon(Icons.gesture, size: 20),
                              ),
                              _buildMenuButton(
                                tooltip: 'Circle Tool (double-tap to set fill)',
                                onPressed: () {
                                  setState(() {
                                    _setAnnotationTool(AnnotationTool.circle);
                                  });
                                },
                                onDoubleTap: () => _toggleCircleFillMenu(forceOpen: true),
                                buttonKey: _circleFillButtonKey,
                                backgroundColor: _activeAnnotationTool == AnnotationTool.circle
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGrey,
                                child: Icon(_circleFilled ? Icons.circle : Icons.circle_outlined, size: 20),
                              ),
                              _buildMenuButton(
                                tooltip: 'Rectangle Tool (double-tap to set fill)',
                                onPressed: () {
                                  setState(() {
                                    _setAnnotationTool(AnnotationTool.rectangle);
                                  });
                                },
                                onDoubleTap: () => _toggleRectangleFillMenu(forceOpen: true),
                                buttonKey: _rectangleFillButtonKey,
                                backgroundColor: _activeAnnotationTool == AnnotationTool.rectangle
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGrey,
                                child: Icon(_rectangleFilled ? Icons.stop : Icons.crop_square, size: 20),
                              ),
                              _buildMenuButton(
                                tooltip: 'Text Tool (double-tap to set size)',
                                onPressed: () {
                                  setState(() {
                                    _setAnnotationTool(AnnotationTool.text);
                                  });
                                },
                                onDoubleTap: () => _toggleAnnotationTextSizeMenu(forceOpen: true),
                                buttonKey: _annotationTextButtonKey,
                                backgroundColor: _activeAnnotationTool == AnnotationTool.text
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGrey,
                                child: Icon(Icons.text_fields, size: 20),
                              ),
                              _buildMenuButton(
                                tooltip: '${_lineStyleLabel(_annotationMarkerStyle)} (double-tap for style)',
                                onPressed: () {
                                  setState(() {
                                    _setAnnotationTool(AnnotationTool.marker);
                                  });
                                },
                                onDoubleTap: () => _toggleAnnotationMarkerStyleMenu(forceOpen: true),
                                buttonKey: _annotationMarkerStyleButtonKey,
                                backgroundColor: _activeAnnotationTool == AnnotationTool.marker
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGrey,
                                child: Icon(_iconForLineStyle(_annotationMarkerStyle), size: 20),
                              ),
                              _buildMenuButton(
                                tooltip:
                                    'Circle Sector Tool (${_labelForSectorAttachment(_sectorAttachmentType)}; double-tap to select)',
                                onPressed: () => setState(() => _setAnnotationTool(AnnotationTool.sector)),
                                onDoubleTap: () => _toggleSectorAttachmentMenu(forceOpen: true),
                                buttonKey: _sectorAttachmentButtonKey,
                                backgroundColor: _activeAnnotationTool == AnnotationTool.sector
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGrey,
                                iconColorOverride: _contrastIconColor(
                                  _activeAnnotationTool == AnnotationTool.sector
                                      ? AppTheme.primaryBlue
                                      : AppTheme.mediumGrey,
                                  Colors.white,
                                ),
                                child: SvgPicture.asset(
                                  'assets/icons/circle_sector.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                    _contrastIconColor(
                                      _activeAnnotationTool == AnnotationTool.sector
                                          ? AppTheme.primaryBlue
                                          : AppTheme.mediumGrey,
                                      Colors.white,
                                    ),
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final canDuplicateAnnotation = _isTemporaryPlaybackAnnotationMode
                                ? _playbackSessionAnnotationsForFrame(_playbackDisplayFrameIndex()).isNotEmpty
                                : currentFrame.annotations.isNotEmpty;
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildMenuButton(
                                    tooltip: 'Move Tool',
                                    onPressed: () => setState(() => _setAnnotationTool(AnnotationTool.move)),
                                    backgroundColor: _activeAnnotationTool == AnnotationTool.move
                                        ? AppTheme.primaryBlue
                                        : AppTheme.mediumGrey,
                                    child: Icon(Icons.pan_tool_alt, size: 20),
                                  ),
                                  _buildMenuButton(
                                    tooltip: 'Duplicate last annotation',
                                    onPressed: canDuplicateAnnotation ? _duplicateLastAnnotation : null,
                                    enabled: canDuplicateAnnotation,
                                    backgroundColor: AppTheme.mediumGrey,
                                    child: Icon(Icons.content_copy, size: 20),
                                  ),
                                  _buildMenuButton(
                                    tooltip: 'Eraser (double-tap for size)',
                                    onPressed: () {
                                      setState(() {
                                        if (!_eraserMode) {
                                          _eraserMode = true;
                                          _activeAnnotationTool = AnnotationTool.none;
                                          _clearSectorSelectionVisuals();
                                        }
                                      });
                                    },
                                    onDoubleTap: () => _toggleAnnotationEraserMenu(forceOpen: true),
                                    buttonKey: _annotationEraserButtonKey,
                                    backgroundColor: _eraserMode ? AppTheme.errorRed : AppTheme.mediumGrey,
                                    child: Icon(Symbols.ink_eraser, size: 20),
                                  ),
                                  _buildMenuButton(
                                    tooltip: 'Delete All Annotations',
                                    onPressed: _clearCurrentFrameAnnotations,
                                    backgroundColor: AppTheme.errorRed,
                                    child: const Icon(Symbols.delete, size: 20),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final snapBg = _annotationSnappingEnabled
                                          ? AppTheme.primaryBlue
                                          : AppTheme.mediumGrey;
                                      final snapIconColor = _contrastIconColor(snapBg, Colors.white);
                                      return _buildMenuButton(
                                        tooltip: _annotationSnappingEnabled ? 'Snapping On' : 'Snapping Off',
                                        onPressed: () =>
                                            setState(() => _annotationSnappingEnabled = !_annotationSnappingEnabled),
                                        backgroundColor: snapBg,
                                        iconColorOverride: snapIconColor,
                                        child: SvgPicture.asset(
                                          'assets/icons/snap_nodes.svg',
                                          width: 20,
                                          height: 20,
                                          colorFilter: ColorFilter.mode(snapIconColor, BlendMode.srcIn),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildMenuButton(
                                    tooltip: 'Annotation stroke width (double-tap to adjust)',
                                    onPressed: null,
                                    onDoubleTap: () => _toggleAnnotationStrokeMenu(forceOpen: true),
                                    buttonKey: _annotationStrokeButtonKey,
                                    backgroundColor: AppTheme.mediumGrey,
                                    child: const Icon(Symbols.line_weight, size: 20),
                                  ),
                                  _buildMenuButton(
                                    tooltip: 'Annotation color',
                                    onPressed: _showColorPicker,
                                    backgroundColor: AppTheme.mediumGrey,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: _annotationColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.darkGrey, width: 2),
                                      ),
                                      child: const Icon(Icons.palette, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final innerR = outerR * 0.44;
    const points = 8;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final isOuter = i % 2 == 0;
      final r = isOuter ? outerR : innerR;
      final angle = (math.pi / points) * i - math.pi / 2;
      final p = center + Offset(r * math.cos(angle), r * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    final glow = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    final fill = Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.9);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFFB45309).withValues(alpha: 0.9);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SetMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    final thickArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE65100).withValues(alpha: 0.62);

    final thinArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.065
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFA726).withValues(alpha: 0.88);

    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.72);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi * 0.78, math.pi * 0.94, false, thickArc);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi * 0.72, math.pi * 0.98, false, thinArc);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      math.pi * 0.86,
      math.pi * 0.58,
      false,
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple ring painter used for pulsing selection highlights without affecting layout.
class _PulseRingPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double strokeWidth;

  _PulseRingPainter({required this.radius, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

// Set icon painter (arc + endpoint circle)
class _SetIconPainter extends CustomPainter {
  final bool active;
  _SetIconPainter({required this.active});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = active ? Colors.orange : Colors.grey;
    final path = Path();
    path.moveTo(size.width * 0.05, size.height * 0.9);
    path.quadraticBezierTo(size.width * 0.45, size.height * 0.05, size.width * 0.75, size.height * 0.85);
    canvas.drawPath(path, paint);
    final c = Offset(size.width * 0.85, size.height * 0.85);
    canvas.drawCircle(c, size.height * 0.12, paint);
  }

  @override
  bool shouldRepaint(covariant _SetIconPainter oldDelegate) => oldDelegate.active != active;
}

// Hit icon painter (V shape + endpoint circle)
class _HitIconPainter extends CustomPainter {
  final bool active;
  _HitIconPainter({required this.active});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = active ? Colors.yellow[700]! : Colors.grey;
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.2);
    path.lineTo(size.width * 0.5, size.height * 0.8);
    path.lineTo(size.width * 0.85, size.height * 0.3);
    canvas.drawPath(path, paint);
    final c = Offset(size.width * 0.9, size.height * 0.28);
    canvas.drawCircle(c, size.height * 0.12, paint);
  }

  @override
  bool shouldRepaint(covariant _HitIconPainter oldDelegate) => oldDelegate.active != active;
}

/// Eraser circle painter - shows a transparent circle with stroke when eraser is active
class _EraserCirclePainter extends CustomPainter {
  final Offset centerCm;
  final double radiusCm;
  final Size screenSize;
  final Settings settings;

  _EraserCirclePainter({
    required this.centerCm,
    required this.radiusCm,
    required this.screenSize,
    required this.settings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Convert cm center to screen coordinates
    final boardCenter = Offset(screenSize.width / 2, screenSize.height / 2);

    final screenCenter =
        boardCenter +
        Offset(settings.cmToLogical(centerCm.dx, screenSize), settings.cmToLogical(centerCm.dy, screenSize));

    // Convert radius from cm to screen pixels
    final screenRadiusPx = settings.cmToLogical(radiusCm, screenSize).abs();

    // Draw semi-transparent filled circle
    final fillPaint = Paint()
      ..color = AppTheme.errorRed.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(screenCenter, screenRadiusPx, fillPaint);

    // Draw stroke circle
    final strokePaint = Paint()
      ..color = AppTheme.errorRed.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(screenCenter, screenRadiusPx, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _EraserCirclePainter oldDelegate) =>
      oldDelegate.centerCm != centerCm || oldDelegate.radiusCm != radiusCm;
}

/// Painter for center screen transparent cross (20cm x 20cm)
class _CenterCrossPainter extends CustomPainter {
  final Size screenSize;
  final Settings settings;

  _CenterCrossPainter({required this.screenSize, required this.settings});

  @override
  void paint(Canvas canvas, Size size) {
    // Board center in screen coordinates
    final boardCenter = Offset(screenSize.width / 2, screenSize.height / 2);

    // Cross dimensions: 20cm x 20cm (10cm in each direction from center)
    final halfLengthPx = settings.cmToLogical(10, screenSize).abs();

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
      oldDelegate.screenSize != screenSize || oldDelegate.settings != settings;
}

class _SnapBurstPainter extends CustomPainter {
  _SnapBurstPainter({required this.centerCm, required this.progress, required this.settings, required this.screenSize})
    : super(repaint: progress);

  final Offset centerCm;
  final Animation<double> progress;
  final Settings settings;
  final Size screenSize;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress.value.clamp(0.0, 1.0));
    if (t <= 0.0) return;

    final boardCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    final center =
        boardCenter +
        Offset(settings.cmToLogical(centerCm.dx, screenSize), settings.cmToLogical(centerCm.dy, screenSize));
    const rays = 8;
    // Scale burst radius to court size: 50cm on mobile (shorter side < 700px), 25cm on desktop
    final isMobile = screenSize.shortestSide < 700;
    final radiusCm = isMobile ? 50.0 : 25.0;
    final baseRadiusPx = settings.cmToLogical(radiusCm, screenSize).abs().clamp(30.0, 250.0);
    final rayLength = baseRadiusPx * t;
    final rayStart = rayLength * 0.22;
    final alpha = (1.0 - t).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.82 * alpha)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < rays; i++) {
      final angle = (2 * math.pi * i) / rays;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final from = center + dir * rayStart;
      final to = center + dir * rayLength;
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnapBurstPainter oldDelegate) {
    return oldDelegate.centerCm != centerCm ||
        oldDelegate.settings != settings ||
        oldDelegate.screenSize != screenSize ||
        oldDelegate.progress.value != progress.value;
  }
}

/// Painter for tracked entity paths during paused playback
/// Shows past path as solid line and future path as dashed line
class _TrackedPathPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final bool isDashed;

  _TrackedPathPainter({required this.points, required this.color, required this.isDashed});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isDashed) {
      // Draw dashed line with phase anchored to the path end
      const dashLength = 10.0;
      const gapLength = 5.0;
      const pattern = dashLength + gapLength;

      // Build a polyline path from sampled points
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      final metrics = path.computeMetrics().toList();
      final totalLength = metrics.fold<double>(0.0, (sum, metric) => sum + metric.length);
      final endAnchoredOffset = (pattern - (totalLength % pattern)) % pattern;

      double globalPos = endAnchoredOffset; // keeps phase fixed at path end
      for (final metric in metrics) {
        double local = 0.0;
        while (local < metric.length) {
          final phase = globalPos % pattern;
          final take = phase < dashLength ? (dashLength - phase) : (pattern - phase);
          final segStart = local;
          final segEnd = (local + take).clamp(0.0, metric.length);

          if (phase < dashLength && segStart < segEnd) {
            canvas.drawPath(metric.extractPath(segStart, segEnd), paint);
          }

          local += take;
          globalPos += take;
        }
      }
    } else {
      // Draw solid line for past path
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackedPathPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color || oldDelegate.isDashed != isDashed;
}

/// Painter for sector tool zone outlines with blue transparent overlay
/// Draws zone circle boundaries and ball overlays for sector tool selection
class _SectorZoneOutlinePainter extends CustomPainter {
  final Settings settings;
  final Size boardSize;
  final Animation<double> pulseAnimation; // 0.0 to 1.0, controlled by AnimationController
  final String? highlightedZone; // Zone to highlight
  final _SectorAttachmentType attachmentType;
  final ProjectType projectType;
  final List<CourtElement>? customCourtElements;
  final List<Player> players;
  final List<Ball> balls;

  _SectorZoneOutlinePainter({
    required this.settings,
    required this.boardSize,
    required this.pulseAnimation,
    this.highlightedZone,
    required this.attachmentType,
    required this.projectType,
    this.customCourtElements,
    required this.players,
    required this.balls,
  }) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final overlayWidthPx = settings.cmToLogical(30.0, boardSize).abs(); // 30cm width for zones
    final t = pulseAnimation.value;
    final pulseRadiusBoost = 6.0 + 10.0 * t;
    final pulseOpacity = (0.35 + 0.55 * (1.0 - t)).clamp(0.0, 1.0);

    if (attachmentType == _SectorAttachmentType.zone) {
      // Draw zone overlays based on project type
      if (projectType == ProjectType.play) {
        final innerRadiusPx = settings.cmToLogical(settings.innerCircleRadiusCm, boardSize).abs();
        final outerRadiusPx = settings.cmToLogical(settings.outerCircleRadiusCm, boardSize).abs();
        final boundsRadiusPx = settings.cmToLogical(settings.outerBoundsRadiusCm, boardSize).abs();

        final zones = [
          ('innerCircle', center, innerRadiusPx),
          ('outerCircle', center, outerRadiusPx),
          ('outerBounds', center, boundsRadiusPx),
        ];

        for (final (zoneType, zoneCenter, radiusPx) in zones) {
          _drawZoneOverlay(
            canvas,
            zoneCenter,
            radiusPx,
            overlayWidthPx,
            zoneType == highlightedZone,
            pulseRadiusBoost,
            pulseOpacity,
          );
        }
      } else {
        if (customCourtElements != null) {
          for (final element in customCourtElements!) {
            if (element.type == CourtElementType.innerCircle ||
                element.type == CourtElementType.outerCircle ||
                element.type == CourtElementType.customCircle) {
              final elementCenter =
                  center +
                  Offset(
                    settings.cmToLogical(element.position.dx, boardSize),
                    settings.cmToLogical(element.position.dy, boardSize),
                  );
              final radiusPx = settings.cmToLogical(element.radius ?? 0, boardSize).abs();
              final zoneId =
                  '${element.type.toString().split('.').last}_${element.position.dx.toStringAsFixed(0)}_${element.position.dy.toStringAsFixed(0)}';
              _drawZoneOverlay(
                canvas,
                elementCenter,
                radiusPx,
                overlayWidthPx,
                zoneId == highlightedZone,
                pulseRadiusBoost,
                pulseOpacity,
              );
            }
          }
        }
      }
    } else if (attachmentType == _SectorAttachmentType.ball) {
      for (final ball in balls) {
        final ballCenter =
            center +
            Offset(
              settings.cmToLogical(ball.position.dx, boardSize),
              settings.cmToLogical(ball.position.dy, boardSize),
            );
        final ballRadiusPx = settings.cmToLogical(AppConstants.ballRadiusCm * 2.0, boardSize).abs();
        final ballId = 'ball_${ball.id}';
        final isHighlighted = ballId == highlightedZone;
        _drawObjectOverlay(canvas, ballCenter, ballRadiusPx, isHighlighted, pulseRadiusBoost, pulseOpacity);
      }
    } else {
      for (final player in players) {
        final playerCenter =
            center +
            Offset(
              settings.cmToLogical(player.position.dx, boardSize),
              settings.cmToLogical(player.position.dy, boardSize),
            );
        final playerRadiusPx = settings
            .cmToLogical(AppConstants.playerRadiusCm * settings.objectScaleMultiplier * 1.2, boardSize)
            .abs();
        final playerId = 'player_${player.id}';
        final isHighlighted = playerId == highlightedZone;
        _drawObjectOverlay(canvas, playerCenter, playerRadiusPx, isHighlighted, pulseRadiusBoost, pulseOpacity);
      }
    }
  }

  void _drawObjectOverlay(
    Canvas canvas,
    Offset center,
    double radiusPx,
    bool isHighlighted,
    double pulseRadiusBoost,
    double pulseOpacity,
  ) {
    final overlayPaint = Paint()
      ..color = const Color.fromARGB(80, 100, 150, 255)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radiusPx, overlayPaint);

    final pulseRingPaint = Paint()
      ..color = const Color.fromARGB(200, 120, 190, 255).withValues(alpha: pulseOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radiusPx + pulseRadiusBoost, pulseRingPaint);

    if (isHighlighted) {
      final accentPaint = Paint()
        ..color = const Color.fromARGB(120, 150, 200, 255)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radiusPx, accentPaint);
    }
  }

  void _drawZoneOverlay(
    Canvas canvas,
    Offset center,
    double radiusPx,
    double overlayWidthPx,
    bool isHighlighted,
    double pulseRadiusBoost,
    double pulseOpacity,
  ) {
    // Blue transparent overlay (10cm width)
    final overlayPaint = Paint()
      ..color =
          const Color.fromARGB(80, 100, 150, 255) // Blue transparent overlay
      ..strokeWidth = overlayWidthPx
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radiusPx, overlayPaint);

    // Pulsating ring around zone outline
    final pulsePaint = Paint()
      ..color = const Color.fromARGB(200, 120, 190, 255).withValues(alpha: pulseOpacity)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radiusPx + pulseRadiusBoost, pulsePaint);

    // If highlighted, add a brighter accent
    if (isHighlighted) {
      final accentPaint = Paint()
        ..color =
            const Color.fromARGB(120, 150, 200, 255) // Brighter blue
        ..strokeWidth = overlayWidthPx
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radiusPx, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SectorZoneOutlinePainter oldDelegate) =>
      oldDelegate.highlightedZone != highlightedZone ||
      oldDelegate.attachmentType != attachmentType ||
      oldDelegate.settings != settings ||
      oldDelegate.boardSize != boardSize ||
      oldDelegate.projectType != projectType ||
      oldDelegate.customCourtElements != customCourtElements ||
      oldDelegate.players != players ||
      oldDelegate.balls != balls;
}

// ══════════════════════════════════════════════════════════════════════════
// Sector Target Highlight Painter
// ══════════════════════════════════════════════════════════════════════════
class _SectorTargetHighlightPainter extends CustomPainter {
  final Offset centerCm;
  final double radiusCm;
  final Size screenSize;
  final Settings settings;

  _SectorTargetHighlightPainter({
    required this.centerCm,
    required this.radiusCm,
    required this.screenSize,
    required this.settings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw semi-transparent fill on selected zone
    final centerPx = Offset(size.width / 2, size.height / 2) + (centerCm * settings.cmToLogical(1, size));
    final radiusPx = settings.cmToLogical(radiusCm, size).abs();

    final fillPaint = Paint()
      ..color =
          const Color.fromARGB(20, 100, 200, 255) // Light cyan, very transparent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerPx, radiusPx, fillPaint);

    // Draw accent ring around selected zone
    final accentPaint = Paint()
      ..color =
          const Color.fromARGB(60, 100, 200, 255) // Slightly more visible cyan ring
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(centerPx, radiusPx, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _SectorTargetHighlightPainter oldDelegate) =>
      oldDelegate.centerCm != centerCm ||
      oldDelegate.radiusCm != radiusCm ||
      oldDelegate.settings != settings ||
      oldDelegate.screenSize != screenSize;
}
