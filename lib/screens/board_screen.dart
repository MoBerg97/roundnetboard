import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/animation_project.dart';
import '../models/frame.dart';
import '../models/player.dart';
import '../models/ball.dart';
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
enum AnnotationTool { none, line, circle, rectangle }

class _BoardScreenState extends State<BoardScreen> with TickerProviderStateMixin {
  // ──────────────────────────────────────────────────────────────────────────
  // STATE VARIABLES
  // ──────────────────────────────────────────────────────────────────────────

  // Current frame being edited
  late Frame currentFrame;

  // Project settings (court dimensions, visual preferences)
  late Settings _settings;

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
  bool _annotationMode = false; // Is annotation mode active?
  AnnotationTool _activeAnnotationTool = AnnotationTool.none; // Current drawing tool
  bool _eraserMode = false; // Is eraser active?
  Offset? _eraserPosCm; // Current eraser position in cm coordinates
  final double _eraserRadiusCm = 20; // Eraser radius in cm (40cm diameter)
  bool _annotationsAboveObjects = false; // Layer order for annotations
  final List<Offset> _pendingAnnotationPoints = []; // Points being drawn (not committed)
  Color _annotationColor = Colors.red; // Current annotation color
  final List<Annotation> _stagedAnnotations = []; // Annotations staged for preview
  final List<Annotation> _erasingAnnotations = []; // Annotations being erased (preview)
  Offset? _currentDragPos; // Current drag position for live preview

  // ──────────────────────────────────────────────────────────────────────────
  // DRAG STATE (for moving objects and control points)
  // ──────────────────────────────────────────────────────────────────────────
  final Map<String, Offset> _dragStartLogical = {}; // Starting position in cm coordinates
  final Map<String, Offset> _dragStartScreen = {}; // Starting position in screen pixels
  String? _activePathDragId; // Which entity ID's path control is being dragged
  int? _activePathDragIndex; // Index of the control point being dragged (currently first only)

  // ──────────────────────────────────────────────────────────────────────────
  // TRAINING MODE STATE (for dynamic player/ball management)
  // ──────────────────────────────────────────────────────────────────────────
  Color? _lastTappedPlayerColor; // Last tapped player color (for new player color inheritance)
  String? _activeBallId; // Which ball ID is currently selected for modifier menu (training mode only)
  String? _addingObjectType; // Indicates "player" or "ball" when user is in place-object mode, null otherwise

  // ──────────────────────────────────────────────────────────────────────────
  // UI REFERENCES
  // ──────────────────────────────────────────────────────────────────────────
  final GlobalKey _boardKey = GlobalKey(debugLabel: 'board'); // Key for board RenderBox (coordinate conversion)
  final GlobalKey _timelineKey = GlobalKey(debugLabel: 'timeline'); // Key for timeline widget
  final GlobalKey _playButtonKey = GlobalKey(debugLabel: 'playback_play'); // Key for play button
  final GlobalKey _frameAddButtonKey = GlobalKey(debugLabel: 'timeline_add'); // Key for frame add button
  final GlobalKey _annotationModeButtonKey = GlobalKey(debugLabel: 'annotation_menu'); // Key for annotation mode toggle
  late final ScrollController _timelineController; // Scroll controller for timeline

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
                Player(position: Offset(0, -r), color: Colors.blue, id: 'P1'),
                Player(position: Offset(r, 0), color: Colors.blue, id: 'P2'),
                Player(position: Offset(0, r), color: Colors.red, id: 'P3'),
                Player(position: Offset(-r, 0), color: Colors.red, id: 'P4'),
              ],
              balls: [Ball(position: Offset.zero, color: AppTheme.lightGrey, id: 'B1')],
            )
          : Frame(
              players: [
                Player(position: Offset(0, -r), color: Colors.blue),
                Player(position: Offset(r, 0), color: Colors.blue),
                Player(position: Offset(0, r), color: Colors.red),
                Player(position: Offset(-r, 0), color: Colors.red),
              ],
              balls: [Ball(position: Offset.zero, color: AppTheme.lightGrey)],
            );
      widget.project.frames.add(defaultFrame);
      currentFrame = defaultFrame;
      _saveProject();
    } else {
      currentFrame = widget.project.frames.first;
    }

    _ticker = createTicker(_onTick);
    _history = HistoryManager(widget.project);
    _timelineController = ScrollController();

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
    _timelineController.dispose();
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

  bool _isPhone(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    return shortest < 600; // heuristic for handset
  }

  bool _shouldShowEraserOverlay(BuildContext context) {
    if (!_eraserMode || _eraserPosCm == null) return false;
    if (kIsWeb) {
      return !_isPhone(context);
    }
    return !(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
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
    final scalePerCm = _settings.cmToLogical(1.0, size);
    if (scalePerCm == 0) return Offset.zero;
    return Offset(logical.dx / scalePerCm, logical.dy / scalePerCm);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PLAYBACK LOGIC
  // ══════════════════════════════════════════════════════════════════════════

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
      _isPlaying = true;
      _endedAtLastFrame = false;
      _scrubberMovedManually = false;
      _playbackFrameIndex = 0;
      _playbackT = 0.0;
    });
    _ticker.start();
    _scrollToPlaybackFrame();
  }

  /// Stop playback and return to edit mode
  void _stopPlayback() {
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _endedAtLastFrame = false;
      _scrubberMovedManually = false;
      _playbackFrameIndex = 0;
      _playbackT = 0.0;
    });
    _ticker.stop();
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
  // FRAME INTERPOLATION (for smooth playback animation)
  // ══════════════════════════════════════════════════════════════════════════

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

        interpPlayers.add(Player(position: interpPos, rotation: interpRot, color: pB.color, id: pB.id));
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
  // FRAME MANAGEMENT (Insert, Delete)
  // ══════════════════════════════════════════════════════════════════════════

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
        if (widget.project.frames.isEmpty) {
          // Create default frame if all frames deleted
          final r = _settings.outerCircleRadiusCm;
          final defaultFrame = widget.project.projectType == ProjectType.play
              ? Frame(
                  players: [
                    Player(position: Offset(0, -r), color: Colors.blue, id: 'P1'),
                    Player(position: Offset(r, 0), color: Colors.blue, id: 'P2'),
                    Player(position: Offset(0, r), color: Colors.red, id: 'P3'),
                    Player(position: Offset(-r, 0), color: Colors.red, id: 'P4'),
                  ],
                  balls: [Ball(position: Offset.zero, color: AppTheme.lightGrey, id: 'B1')],
                )
              : Frame(
                  players: [
                    Player(position: Offset(0, -r), color: Colors.blue),
                    Player(position: Offset(r, 0), color: Colors.blue),
                    Player(position: Offset(0, r), color: Colors.red),
                    Player(position: Offset(-r, 0), color: Colors.red),
                  ],
                  balls: [Ball(position: Offset.zero, color: AppTheme.lightGrey)],
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

  // ══════════════════════════════════════════════════════════════════════════
  // COLOR PICKER DIALOG
  // ══════════════════════════════════════════════════════════════════════════
  // Shows a dialog to select annotation color (grid of color circles)

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Color'),
        content: SizedBox(
          width: 280,
          height: 200,
          child: GridView.count(
            crossAxisCount: 4,
            children:
                [
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
                    ]
                    .map(
                      (color) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _annotationColor = color);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: _annotationColor == color ? Border.all(color: AppTheme.darkGrey, width: 2) : null,
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

  /// Shows color picker dialog for player
  void _showPlayerColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Player Color'),
        content: SizedBox(
          width: 280,
          height: 200,
          child: GridView.count(
            crossAxisCount: 4,
            children:
                [
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
                    ]
                    .map(
                      (color) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          if (_activePlayerId != null) {
                            final player = currentFrame.getPlayerById(_activePlayerId!);
                            if (player != null) {
                              final oldColor = player.color;
                              // Apply color change to all frames using history action
                              _history.push(
                                ChangePlayerColorAllFramesAction(id: _activePlayerId!, from: oldColor, to: color),
                              );
                              setState(() {
                                _lastTappedPlayerColor = color;
                              });
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border:
                                _activePlayerId != null && currentFrame.getPlayerById(_activePlayerId!)?.color == color
                                ? Border.all(color: AppTheme.darkGrey, width: 2)
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

  /// Shows color picker dialog for ball
  void _showBallColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Ball Color'),
        content: SizedBox(
          width: 280,
          height: 200,
          child: GridView.count(
            crossAxisCount: 4,
            children:
                [
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
                    ]
                    .map(
                      (color) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          if (_activeBallId != null) {
                            final ball = currentFrame.getBallById(_activeBallId!);
                            if (ball != null) {
                              final oldColor = ball.color;
                              // Apply color change to all frames using history action
                              _history.push(
                                ChangeBallColorAllFramesAction(id: _activeBallId!, from: oldColor, to: color),
                              );
                              setState(() {});
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: _activeBallId != null && currentFrame.getBallById(_activeBallId!)?.color == color
                                ? Border.all(color: AppTheme.darkGrey, width: 2)
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

  // ══════════════════════════════════════════════════════════════════════════
  // BOARD TAP HANDLER
  // ══════════════════════════════════════════════════════════════════════════
  // Handles taps on the board for placing ball modifiers or adding annotations

  void _handleBoardTap(Offset tapPos, Size size) {
    if (_isPlaying || _endedAtLastFrame) return;

    // Convert tap position to cm coordinates
    final tapCm = _screenToCm(tapPos, size);

    // If adding player/ball, place object at tap location
    if (_addingObjectType == 'player') {
      _createPlayerAtLocation(tapCm);
      return;
    }
    if (_addingObjectType == 'ball') {
      _createBallAtLocation(tapCm);
      return;
    }

    // If in annotation mode, ignore taps (drawing uses drag instead)
    if (_annotationMode) {
      return;
    }

    final prev = _getPreviousFrame();
    if (prev == null) return;

    // Check if tapping on ball - if annotations menu is open, close it and open ball menu
    if (_annotationMode && _pendingBallMark == null) {
      setState(() {
        _annotationMode = false;
        _activeAnnotationTool = AnnotationTool.none;
        _showModifierMenu = true;
      });
      return;
    }

    if (_pendingBallMark == 'hit') {
      _placeBallHitAt(tapPos, size);
      return;
    }
    bool tryAdd(String label, Offset startCm, Offset endCm, List<Offset> points) {
      if (points.isNotEmpty) return false;
      final pathLengthCm = (endCm - startCm).distance;
      if (pathLengthCm <= 50) return false;
      final midCm = (startCm + endCm) / 2;
      final midScreen = _toScreenPosition(midCm, size);
      if ((tapPos - midScreen).distance < 24) {
        setState(() {
          points.add(midCm);
          // ensure the project's frame list has the updated frame object
          final idx = widget.project.frames.indexOf(currentFrame);
          if (idx >= 0) widget.project.frames[idx] = currentFrame;
        });
        final idx = widget.project.frames.indexOf(currentFrame);
        PathEngine.invalidateCacheFor(idx, label);
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
  }

  /// Handle drag start for line drawing
  void _handleAnnotationDragStart(DragStartDetails details, Size size) {
    if (_isPlaying || _endedAtLastFrame) return;
    if (_eraserMode) {
      // Start eraser drag
      if (_showModifierMenu) {
        setState(() => _showModifierMenu = false);
      }
      final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
      final localPos = box.globalToLocal(details.globalPosition);
      final cmPos = _screenToCm(localPos, size);
      setState(() {
        _eraserPosCm = cmPos;
      });
      return;
    }
    if (_activeAnnotationTool == AnnotationTool.none) return;

    // Close ball modifier menu if open and annotations are being touched
    if (_showModifierMenu) {
      setState(() => _showModifierMenu = false);
    }

    // Get board position relative to the board widget to avoid coordinate offset
    final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    final cmPos = _screenToCm(localPos, size);
    setState(() {
      _pendingAnnotationPoints.clear();
      _pendingAnnotationPoints.add(cmPos);
      _currentDragPos = cmPos;
      _stagedAnnotations.clear();
    });
  }

  /// Handle drag update for live line preview and erasing
  void _handleAnnotationDragUpdate(DragUpdateDetails details, Size size) {
    if (_isPlaying || _endedAtLastFrame) return;
    final currentPos = details.globalPosition;
    // Get board position relative to the board widget
    final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
    final localPos = box.globalToLocal(currentPos);
    final cmPos = _screenToCm(localPos, size);

    if (_eraserMode) {
      // Close ball modifier menu if open and eraser is being used
      if (_showModifierMenu) {
        setState(() => _showModifierMenu = false);
      }

      // Update eraser position and instantly delete annotations touched by circle
      setState(() {
        _eraserPosCm = cmPos;
        currentFrame.annotations.removeWhere((ann) => _isAnnotationTouchedByCircle(ann, cmPos, _eraserRadiusCm));
      });
      _saveProject();
    } else if (_pendingAnnotationPoints.isNotEmpty && _activeAnnotationTool != AnnotationTool.none) {
      // Update preview position for active tool
      setState(() {
        _currentDragPos = cmPos;
        _stagedAnnotations.clear();
        if (_activeAnnotationTool == AnnotationTool.rectangle) {
          _stagedAnnotations.add(
            Annotation(
              type: AnnotationType.rectangle,
              color: _annotationColor,
              points: [_pendingAnnotationPoints.first, cmPos],
            ),
          );
        } else if (_activeAnnotationTool == AnnotationTool.circle) {
          _stagedAnnotations.add(
            Annotation(
              type: AnnotationType.circle,
              color: _annotationColor,
              points: [_pendingAnnotationPoints.first, cmPos],
            ),
          );
        }
      });
    }
  }

  /// Clear all annotations on the current frame
  void _clearCurrentFrameAnnotations() {
    if (_isPlaying || _endedAtLastFrame) return;
    setState(() {
      currentFrame.annotations.clear();
      _stagedAnnotations.clear();
      _erasingAnnotations.clear();
      _eraserPosCm = null;
      final idx = widget.project.frames.indexOf(currentFrame);
      if (idx >= 0) widget.project.frames[idx] = currentFrame;
    });
    _saveProject();
  }

  /// Check if an annotation intersects with the eraser circle
  bool _isAnnotationTouchedByCircle(Annotation ann, Offset eraserCenterCm, double eraserRadiusCm) {
    if (ann.type == AnnotationType.line && ann.points.length >= 2) {
      final start = ann.points[0];
      final end = ann.points[1];
      // Check if line segment intersects with eraser circle
      final dist = _distanceToLineSegment(eraserCenterCm, start, end);
      return dist <= eraserRadiusCm;
    } else if (ann.type == AnnotationType.circle && ann.points.length >= 2) {
      final center = ann.points[0];
      final radiusPoint = ann.points[1];
      final radius = (radiusPoint - center).distance;
      final distToCenter = (eraserCenterCm - center).distance;
      // Check if annotation circle overlaps with eraser circle
      final circleWidth = 10.0; // cm width of the circle line
      return distToCenter <= (eraserRadiusCm + radius + circleWidth / 2);
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

  /// Handle drag end for committing line or finishing erase
  void _handleAnnotationDragEnd(DragEndDetails details, Size size) {
    if (_isPlaying || _endedAtLastFrame) return;
    if (_eraserMode) {
      // Erasing already happened during drag, clear eraser position
      setState(() {
        _erasingAnnotations.clear();
        _eraserPosCm = null;
      });
      return;
    }

    if (_pendingAnnotationPoints.isNotEmpty && _currentDragPos != null) {
      final start = _pendingAnnotationPoints[0];
      final end = _currentDragPos!;

      final dist = (end - start).distance;
      if (dist > 10) {
        Annotation? ann;
        if (_activeAnnotationTool == AnnotationTool.line) {
          ann = Annotation(type: AnnotationType.line, color: _annotationColor, points: [start, end]);
        } else if (_activeAnnotationTool == AnnotationTool.circle) {
          ann = Annotation(type: AnnotationType.circle, color: _annotationColor, points: [start, end]);
        } else if (_activeAnnotationTool == AnnotationTool.rectangle) {
          ann = Annotation(type: AnnotationType.rectangle, color: _annotationColor, points: [start, end]);
        }
        if (ann != null) {
          setState(() {
            currentFrame.annotations.add(ann!);
            _pendingAnnotationPoints.clear();
            _currentDragPos = null;
            _stagedAnnotations.clear();
          });
          _saveProject();
        }
      } else {
        setState(() {
          _pendingAnnotationPoints.clear();
          _currentDragPos = null;
          _stagedAnnotations.clear();
        });
      }
    }
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

  // ──────────────────────────────────────────────────────────────────────────
  // PATH CONTROL DRAG HELPERS
  // ──────────────────────────────────────────────────────────────────────────

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

    const double bufferCm = 50.0;
    final bufferPx = _settings.cmToLogical(bufferCm, size).abs();

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

    setState(() {
      if (pathPoints.isEmpty) {
        pathPoints.add(snappedPoint);
      } else {
        pathPoints[0] = snappedPoint;
      }
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
    final scalePerCm = _settings.cmToLogical(1.0, size);
    if (scalePerCm == 0) return;

    setState(() {
      final deltaScreen = localPos - startScreen;
      points[index] = startLogical + deltaScreen / scalePerCm;
    });

    final frameIdx = widget.project.frames.indexOf(currentFrame);
    if (frameIdx >= 0) PathEngine.invalidateCacheFor(frameIdx, label);
  }

  void _endPathDrag() {
    final label = _activePathDragId;
    final index = _activePathDragIndex;
    if (label != null && index != null) {
      final frameIdx = widget.project.frames.indexOf(currentFrame);
      if (frameIdx >= 0) {
        widget.project.frames[frameIdx] = currentFrame;
        PathEngine.invalidateCacheFor(frameIdx, label);
      }
      _dragStartLogical.remove("PATH-$label-$index");
      _dragStartScreen.remove("PATH-$label-$index");
      _saveProject();
    }
    setState(() {
      _activePathDragId = null;
      _activePathDragIndex = null;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILD HELPERS
  // ══════════════════════════════════════════════════════════════════════════

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
          left: pos.dx - 16,
          top: pos.dy - 16,
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
              child: CustomPaint(size: const Size(32, 32), painter: _StarPainter()),
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
      final double scale = 2.0; // max size for set

      widgets.add(
        Positioned(
          left: pos.dx - 15 * scale,
          top: pos.dy - 15 * scale,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.35,
              child: Container(
                width: 30 * scale,
                height: 30 * scale,
                decoration: BoxDecoration(color: AppTheme.accentOrange.withValues(alpha: 0.35), shape: BoxShape.circle),
              ),
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
                final scalePerCm = _settings.cmToLogical(1.0, size);
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
        final idx = widget.project.frames.indexOf(currentFrame);
        if (idx >= 0) widget.project.frames[idx] = currentFrame;
        _saveProject();
      });
    });
  }

  /// Build player widgets with drag handling
  Widget _buildPlayer(Offset posCm, double rotation, Color color, String playerId, Size size) {
    final screenPos = _toScreenPosition(posCm, size);
    final bool isSelected = _activePlayerId == playerId;
    return Positioned(
      left: screenPos.dx - 20,
      top: screenPos.dy - 20,
      child: IgnorePointer(
        ignoring: _annotationMode,
        child: GestureDetector(
          onTap: () {
            if (!_isPlaying && !_endedAtLastFrame) {
              // Store color for new players
              setState(() => _lastTappedPlayerColor = color);

              // In training mode, open player menu
              if (widget.project.projectType == ProjectType.training) {
                if (_showPlayerMenu && _activePlayerId == playerId) {
                  // Close menu if already open for this player
                  setState(() {
                    _showPlayerMenu = false;
                    _activePlayerId = null;
                  });
                } else {
                  // Open menu and close ball menu if open
                  setState(() {
                    _showPlayerMenu = true;
                    _activePlayerId = playerId;
                    _showModifierMenu = false; // Close ball menu
                    _activeBallId = null;
                  });
                }
              }
            }
          },
          onLongPress: () {
            if (!_isPlaying && !_endedAtLastFrame) {
              setState(() {
                _activePlayerId = playerId;
              });
            }
          },
          onPanStart: (details) {
            _dragStartLogical[playerId] = posCm;
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            _dragStartScreen[playerId] = box.globalToLocal(details.globalPosition);
          },
          onPanUpdate: (details) {
            setState(() {
              final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              final deltaScreen = localPos - (_dragStartScreen[playerId] ?? localPos);
              final scalePerCm = _settings.cmToLogical(1.0, size);
              _updateFramePosition(playerId, (_dragStartLogical[playerId] ?? posCm) + deltaScreen / scalePerCm);
            });
          },
          onPanEnd: (_) {
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
                if (isSelected)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withOpacity(0.12),
                      boxShadow: [
                        BoxShadow(color: Colors.cyanAccent.withOpacity(0.35), blurRadius: 12, spreadRadius: 2),
                      ],
                    ),
                  ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: [
                      const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                      if (isSelected)
                        BoxShadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 10, spreadRadius: 1),
                    ],
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
    final bool isSelected = ballId != null && _activeBallId == ballId;
    // Get the actual ball color from the current frame if not provided
    final ballColor =
      color ?? (ballId != null ? (currentFrame.getBallById(ballId)?.color ?? AppTheme.lightGrey) : AppTheme.lightGrey);
    return Positioned(
      left: screenPos.dx - 15 * scale,
      top: screenPos.dy - 15 * scale,
      child: IgnorePointer(
        ignoring: _annotationMode,
        child: GestureDetector(
          onTap: () {
            if (!_isPlaying && !_endedAtLastFrame) {
              // If modifier menu is open, close it; otherwise open it
              if (_showModifierMenu) {
                setState(() {
                  _showModifierMenu = false;
                  _activeBallId = null;
                });
              } else {
                // Close annotation menu if open and ball is tapped
                if (_annotationMode) {
                  setState(() {
                    _annotationMode = false;
                    _activeAnnotationTool = AnnotationTool.none;
                    _pendingAnnotationPoints.clear();
                  });
                }
                setState(() {
                  _showModifierMenu = true;
                  _activeBallId = ballId; // Store which ball was tapped
                  _showPlayerMenu = false; // Close player menu if open
                  _activePlayerId = null;
                });
              }
            }
          },
          onPanStart: (details) {
            if (ballId != null) {
              _activeBallId = ballId; // Set active ball for dragging
            }
            _dragStartLogical[ballId ?? "BALL"] = posCm;
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            _dragStartScreen[ballId ?? "BALL"] = box.globalToLocal(details.globalPosition);
          },
          onPanUpdate: (details) {
            setState(() {
              final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              final deltaScreen = localPos - (_dragStartScreen[ballId ?? "BALL"] ?? localPos);
              final scalePerCm = _settings.cmToLogical(1.0, size);
              _updateFramePosition(
                ballId ?? "BALL",
                (_dragStartLogical[ballId ?? "BALL"] ?? posCm) + deltaScreen / scalePerCm,
              );
            });
          },
          onPanEnd: (_) {
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
              if (isSelected)
                Container(
                  width: 44 * scale,
                  height: 44 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyanAccent.withOpacity(0.12),
                    boxShadow: [
                      BoxShadow(color: Colors.cyanAccent.withOpacity(0.35), blurRadius: 12, spreadRadius: 2),
                    ],
                  ),
                ),
              Container(
                width: 30 * scale,
                height: 30 * scale,
                decoration: BoxDecoration(
                  color: ballColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: [
                    const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    if (isSelected)
                      BoxShadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 10, spreadRadius: 1),
                  ],
                ),
              ),
              if (starOpacity > 0)
                Transform.translate(
                  offset: Offset(0, 16 * scale), // draw below the ball
                  child: Opacity(
                    opacity: starOpacity,
                    child: CustomPaint(size: Size(24 * scale, 24 * scale), painter: _StarPainter()),
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
    final Color color = _lastTappedPlayerColor ?? ((currentFrame.players.length % 2 == 0) ? Colors.blue : Colors.red);
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
      _addingObjectType = null;
      _saveProject();
    });
  }

  /// Create a new ball at the tapped location and add to all frames
  void _createBallAtLocation(Offset cmPos) {
    if (_addingObjectType != 'ball') return;

    // Use the color of the last tapped ball, or default to light grey
    Color ballColor = AppTheme.lightGrey;
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
    return {'pos': pos, 'opacity': 1.0};
  }

  // control handles are drawn via widgets so this helper is unused and removed

  @override
  Widget build(BuildContext context) {
    final screenSize = _effectiveScreenSize(context);
    Settings.setScreenSize(screenSize);
    final isPlayback = _isPlaying && _animatedFrame != null;
    final prev = _getPreviousFrame();
    final inPlaybackView = _isPlaying || _endedAtLastFrame;
    // During playback or when scrubbing in ended state, show interpolated frame
    final frameToShow = (inPlaybackView && _animatedFrame != null) ? _animatedFrame! : currentFrame;
    // Timeline maintains consistent height during state transitions to avoid layout shifts
    // Playback: 160px (more space for timeline), End-state: 120px (with stop button), Editing: 120px (full controls)
    final double timelineHeight = 140.0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        // Handle back button press if needed
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.project.name),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Projects',
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // Add Player button - only in training mode
            if (widget.project.projectType == ProjectType.training && !_isPlaying && !_endedAtLastFrame)
              IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: 'Add Player (tap board to place)',
                onPressed: _startAddPlayer,
                isSelected: _addingObjectType == 'player',
              ),
            // Add Ball button - only in training mode
            if (widget.project.projectType == ProjectType.training && !_isPlaying && !_endedAtLastFrame)
              IconButton(
                icon: const Icon(Icons.control_point_duplicate),
                tooltip: 'Add Ball (tap board to place)',
                onPressed: _startAddBall,
                isSelected: _addingObjectType == 'ball',
              ),
            // Edit Court button - only show for training projects
            if (widget.project.projectType == ProjectType.training && !_isPlaying && !_endedAtLastFrame)
              IconButton(
                icon: const Icon(Icons.border_outer),
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
            if (!_isPlaying && !_endedAtLastFrame)
              IconButton(
                key: _annotationModeButtonKey,
                icon: Icon(Icons.draw, color: Colors.white),
                tooltip: _annotationMode ? 'Exit Annotation Mode' : 'Enter Annotation Mode',
                onPressed: () {
                  setState(() {
                    _annotationMode = !_annotationMode;
                    // Close ball modifier menu if annotation mode is opened
                    if (_annotationMode && _showModifierMenu) {
                      _showModifierMenu = false;
                    }
                    if (!_annotationMode) {
                      _activeAnnotationTool = AnnotationTool.none;
                      _pendingAnnotationPoints.clear();
                    }
                  });
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
              bottom: 120, // Leave room for timeline (no grey strip)
              child: AbsorbPointer(
                absorbing: inPlaybackView,
                child: Container(
                  key: _boardKey,
                  color: const Color.fromARGB(255, 55, 49, 120),
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
                            settings: _settings,
                            customElements: widget.project.customCourtElements,
                            projectType: widget.project.projectType,
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
                            settings: _settings,
                          ),
                        ),
                      // Draw annotations below objects when toggled off
                      if (!_annotationsAboveObjects)
                        IgnorePointer(
                          ignoring: true,
                          child: AnnotationPainter(
                            annotations: frameToShow.annotations,
                            tempAnnotations: _stagedAnnotations.isNotEmpty ? _stagedAnnotations : null,
                            erasingAnnotations: _erasingAnnotations.isNotEmpty ? _erasingAnnotations : null,
                            dragPreviewLine:
                                _annotationMode && _pendingAnnotationPoints.isNotEmpty && _currentDragPos != null
                                ? [_pendingAnnotationPoints.first, _currentDragPos!]
                                : null,
                            settings: _settings,
                            screenSize: screenSize,
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
                              radiusCm: _eraserRadiusCm,
                              screenSize: screenSize,
                              settings: _settings,
                            ),
                          ),
                        ),
                      // Draw transparent center cross (20cm x 20cm)
                      IgnorePointer(
                        ignoring: true,
                        child: CustomPaint(
                          size: screenSize,
                          painter: _CenterCrossPainter(screenSize: screenSize, settings: _settings),
                        ),
                      ),
                      // Full-board tap & drag handler
                      Positioned.fill(
                        child: GestureDetector(
                          onTapUp: (details) {
                            if (!(_isPlaying || _endedAtLastFrame)) {
                              if (_pendingBallMark == 'hit') {
                                _placeBallHitAt(details.localPosition, screenSize);
                              } else {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _handleBoardTap(details.localPosition, screenSize);
                                });
                              }
                            }
                          },
                          onDoubleTap: () {
                            // Close annotation menu on double-tap when no tool is selected
                            // Helps teach users that objects can't be moved while in annotation mode
                            if (_annotationMode && _activeAnnotationTool == AnnotationTool.none && !_eraserMode) {
                              setState(() {
                                _annotationMode = false;
                                _pendingAnnotationPoints.clear();
                              });
                            }
                          },
                          onPanStart: (details) {
                            if (_isPlaying || _endedAtLastFrame) return;
                            if (_annotationMode) {
                              _handleAnnotationDragStart(details, screenSize);
                            } else {
                              _maybeStartPathDrag(details.localPosition, screenSize);
                            }
                          },
                          onPanUpdate: (details) {
                            if (_isPlaying || _endedAtLastFrame) return;
                            if (_annotationMode) {
                              _handleAnnotationDragUpdate(details, screenSize);
                            } else if (_activePathDragId != null) {
                              _updatePathDrag(details.localPosition, screenSize);
                            }
                          },
                          onPanEnd: (details) {
                            if (_isPlaying || _endedAtLastFrame) return;
                            if (_annotationMode) {
                              _handleAnnotationDragEnd(details, screenSize);
                            } else if (_activePathDragId != null) {
                              _endPathDrag();
                            }
                          },
                          behavior: HitTestBehavior.translucent,
                          child: Container(),
                        ),
                      ),
                      if (widget.project.projectType == ProjectType.training) ...[
                        for (final player in frameToShow.players)
                          _buildPlayer(player.position, player.rotation, player.color, player.id, screenSize),
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
                          _buildPlayer(player.position, player.rotation, player.color, player.id, screenSize),
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
                      if (_annotationsAboveObjects)
                        IgnorePointer(
                          ignoring: true,
                          child: AnnotationPainter(
                            annotations: frameToShow.annotations,
                            tempAnnotations: _stagedAnnotations.isNotEmpty ? _stagedAnnotations : null,
                            erasingAnnotations: _erasingAnnotations.isNotEmpty ? _erasingAnnotations : null,
                            dragPreviewLine:
                                _annotationMode && _pendingAnnotationPoints.isNotEmpty && _currentDragPos != null
                                ? [_pendingAnnotationPoints.first, _currentDragPos!]
                                : null,
                            settings: _settings,
                            screenSize: screenSize,
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
                          final showControls = _settings.showPathControlPoints || _activePathDragId != null;
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
                          final showControls = _settings.showPathControlPoints || _activePathDragId != null;
                          if (!showControls) return <Widget>[];
                          final widgets = <Widget>[];
                          for (final ball in currentFrame.balls) {
                            if (ball.pathPoints.isNotEmpty) {
                              final prevBall = prev?.getBallById(ball.id);
                              final prevPos = prevBall?.position ?? ball.position;
                              // Show during active drag regardless of whether the internal label is "BALL" or the ball's ID
                              if (_activePathDragId == null || _activePathDragId == "BALL" || _activePathDragId == ball.id) {
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
              ),
            ),
            // Layer 2: Timeline - fixed at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: AnimatedContainer(
                height: 120,
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
                      height: (timelineHeight - 40 - 28),
                      child: AbsorbPointer(
                        absorbing: inPlaybackView,
                        child: ListView.builder(
                          key: _timelineKey,
                          controller: _timelineController,
                          scrollDirection: Axis.horizontal,
                          itemCount: inPlaybackView ? widget.project.frames.length - 1 : widget.project.frames.length,
                          itemBuilder: (context, index) {
                            final frame = inPlaybackView ? widget.project.frames[index + 1] : widget.project.frames[index];
                            final isSelected = frame == currentFrame;
                            return GestureDetector(
                              onTap: () {
                                if (!(_isPlaying || _endedAtLastFrame)) {
                                  setState(() => currentFrame = frame);
                                  _scrollToSelectedFrame();
                                }
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
                                          fontWeight: isSelected && !inPlaybackView ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected && !inPlaybackView ? Colors.white : AppTheme.darkGrey,
                                        ),
                                      ),
                                    ), // Playback: starts at 1, Edit: starts at 0
                                  ),
                                  if (isSelected && !(_isPlaying || _endedAtLastFrame))
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _confirmDeleteFrame(frame),
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
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
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
                        height: (timelineHeight - 40 - 52),
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
                                  ? ((_playbackFrameIndex + _playbackT) / (widget.project.frames.length - 1).toDouble())
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
                                            BoxShadow(color: Colors.black26, blurRadius: 2, offset: const Offset(0, 1)),
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
                              onPressed: _stopPlayback,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                key: _playButtonKey,
                                onPressed: (_isPlaying || _endedAtLastFrame) ? _stopPlayback : _startPlayback,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (_isPlaying || _endedAtLastFrame) ? AppTheme.errorRed : Colors.green,
                                  minimumSize: const Size(48, 40),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Icon((_isPlaying || _endedAtLastFrame) ? Icons.stop : Icons.play_arrow, size: 20),
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
                                                setState(() => currentFrame = widget.project.frames[idx]);
                                                _scrollToSelectedFrame();
                                              } else {
                                                setState(() {});
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
                                                setState(() => currentFrame = widget.project.frames[idx]);
                                                _scrollToSelectedFrame();
                                              } else {
                                                setState(() {});
                                              }
                                            }
                                          : null),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Layer 3 (top): Ball Modifier Menu - overlay at top
            if (_showModifierMenu && !_annotationMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 56,
                child: Container(
                  color: AppTheme.lightGrey,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Set button - toggle, mutually exclusive with Hit
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            // In training mode, use index-based access
                            if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
                              final ball = currentFrame.getBallById(_activeBallId!);
                              if (ball != null) {
                                if (ball.isSet ?? false) {
                                  ball.isSet = false;
                                } else {
                                  ball.isSet = true;
                                  ball.hitT = null; // Clear Hit when setting Set
                                }
                              }
                            } else if (currentFrame.balls.isNotEmpty) {
                              // Play mode: use first ball
                              final ball = currentFrame.balls.first;
                              if (ball.isSet ?? false) {
                                ball.isSet = false;
                              } else {
                                ball.isSet = true;
                                ball.hitT = null; // Clear Hit when setting Set
                              }
                            }
                          });
                          _saveProject();
                        },
                        child: Container(
                          width: 80,
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color:
                                (widget.project.projectType == ProjectType.training && _activeBallId != null
                                    ? (currentFrame.getBallById(_activeBallId!)?.isSet ?? false)
                                    : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.isSet ?? false)))
                                ? AppTheme.accentOrange.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  (widget.project.projectType == ProjectType.training && _activeBallId != null
                                      ? (currentFrame.getBallById(_activeBallId!)?.isSet ?? false)
                                      : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.isSet ?? false)))
                                  ? AppTheme.accentOrange
                                  : AppTheme.mediumGrey,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(24, 24),
                                painter: _SetIconPainter(
                                  active: widget.project.projectType == ProjectType.training && _activeBallId != null
                                      ? (currentFrame.getBallById(_activeBallId!)?.isSet ?? false)
                                      : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.isSet ?? false)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Set',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      (widget.project.projectType == ProjectType.training && _activeBallId != null
                                          ? (currentFrame.getBallById(_activeBallId!)?.isSet ?? false)
                                          : (currentFrame.balls.isNotEmpty &&
                                                (currentFrame.balls.first.isSet ?? false)))
                                      ? AppTheme.accentOrange
                                      : AppTheme.mediumGrey,
                                  fontWeight:
                                      (widget.project.projectType == ProjectType.training && _activeBallId != null
                                          ? (currentFrame.getBallById(_activeBallId!)?.isSet ?? false)
                                          : (currentFrame.balls.isNotEmpty &&
                                                (currentFrame.balls.first.isSet ?? false)))
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Hit button - toggle, mutually exclusive with Set
                      GestureDetector(
                        onTap: () {
                          final prev = _getPreviousFrame();
                          if (prev != null) {
                            // User requirement: Hit marker should be at beginning of path (t=0.0)
                            final tStart = 0.0;
                            setState(() {
                              // In training mode, use ID-based access
                              if (widget.project.projectType == ProjectType.training && _activeBallId != null) {
                                final ball = currentFrame.getBallById(_activeBallId!);
                                if (ball != null) {
                                  if (ball.hitT != null) {
                                    ball.hitT = null;
                                  } else {
                                    ball.hitT = tStart;
                                    ball.isSet = false; // Clear Set when setting Hit
                                  }
                                }
                              } else if (currentFrame.balls.isNotEmpty) {
                                // Play mode: use first ball
                                final ball = currentFrame.balls.first;
                                if (ball.hitT != null) {
                                  ball.hitT = null;
                                } else {
                                  ball.hitT = tStart;
                                  ball.isSet = false; // Clear Set when setting Hit
                                }
                              }
                            });
                            _saveProject();
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color:
                                (widget.project.projectType == ProjectType.training && _activeBallId != null
                                    ? (currentFrame.getBallById(_activeBallId!)?.hitT != null)
                                    : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.hitT != null)))
                                ? AppTheme.warningAmber.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  (widget.project.projectType == ProjectType.training && _activeBallId != null
                                      ? (currentFrame.getBallById(_activeBallId!)?.hitT != null)
                                      : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.hitT != null)))
                                  ? AppTheme.warningAmber
                                  : AppTheme.mediumGrey,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(24, 24),
                                painter: _HitIconPainter(
                                  active: widget.project.projectType == ProjectType.training && _activeBallId != null
                                      ? (currentFrame.getBallById(_activeBallId!)?.hitT != null)
                                      : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.hitT != null)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hit',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      (widget.project.projectType == ProjectType.training && _activeBallId != null
                                          ? (currentFrame.getBallById(_activeBallId!)?.hitT != null)
                                          : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.hitT != null)))
                                      ? AppTheme.warningAmber
                                      : AppTheme.mediumGrey,
                                  fontWeight:
                                      (widget.project.projectType == ProjectType.training && _activeBallId != null
                                          ? (currentFrame.getBallById(_activeBallId!)?.hitT != null)
                                          : (currentFrame.balls.isNotEmpty && (currentFrame.balls.first.hitT != null)))
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Color Picker button - only in training mode
                      if (widget.project.projectType == ProjectType.training && _activeBallId != null)
                        GestureDetector(
                          onTap: _showBallColorPicker,
                          child: Container(
                            width: 80,
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _activeBallId != null
                                    ? (currentFrame.getBallById(_activeBallId!)?.color ?? AppTheme.lightGrey)
                                    : AppTheme.lightGrey,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.palette,
                                  size: 24,
                                  color: _activeBallId != null
                                      ? (currentFrame.getBallById(_activeBallId!)?.color ?? AppTheme.lightGrey)
                                      : AppTheme.lightGrey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Color',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _activeBallId != null
                                        ? (currentFrame.getBallById(_activeBallId!)?.color ?? AppTheme.lightGrey)
                                        : AppTheme.lightGrey,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Delete button - only in training mode with multiple balls
                      if (widget.project.projectType == ProjectType.training &&
                          currentFrame.balls.length > 1 &&
                          _activeBallId != null)
                        GestureDetector(
                          onTap: () {
                            _undoableDeleteBallFromAllFrames(_activeBallId!);
                          },
                          child: Container(
                            width: 80,
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.errorRed, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete, size: 24, color: AppTheme.errorRed),
                                const SizedBox(height: 2),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.errorRed,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Layer 4 (top): Player Modifier Menu - overlay at top (only in training mode)
            if (_showPlayerMenu &&
                !_annotationMode &&
                widget.project.projectType == ProjectType.training &&
                _activePlayerId != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 56,
                child: Container(
                  color: AppTheme.lightGrey,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Color Picker button
                      GestureDetector(
                        onTap: _showPlayerColorPicker,
                        child: Container(
                          width: 80,
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _activePlayerId != null
                                  ? (currentFrame.getPlayerById(_activePlayerId!)?.color ?? AppTheme.primaryBlue)
                                  : AppTheme.primaryBlue,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.palette,
                                size: 24,
                                color: _activePlayerId != null
                                    ? (currentFrame.getPlayerById(_activePlayerId!)?.color ?? AppTheme.primaryBlue)
                                    : AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Color',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _activePlayerId != null
                                      ? (currentFrame.getPlayerById(_activePlayerId!)?.color ?? AppTheme.primaryBlue)
                                      : AppTheme.primaryBlue,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete button - only show if more than 1 player
                      if (currentFrame.players.length > 1)
                        GestureDetector(
                          onTap: () {
                            if (_activePlayerId != null) {
                              _undoableDeletePlayerFromAllFrames(_activePlayerId!);
                            }
                          },
                          child: Container(
                            width: 80,
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.errorRed, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete, size: 24, color: AppTheme.errorRed),
                                const SizedBox(height: 2),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.errorRed,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Layer 5 (top): Annotation Toolbar - overlay at top
            if (_annotationMode && !_showModifierMenu)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 56,
                child: Container(
                  color: AppTheme.lightGrey,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Symbols.diagonal_line),
                        tooltip: 'Line Tool',
                        color: _activeAnnotationTool == AnnotationTool.line ? _annotationColor : AppTheme.mediumGrey,
                        onPressed: () => setState(() {
                          _activeAnnotationTool = _activeAnnotationTool == AnnotationTool.line
                              ? AnnotationTool.none
                              : AnnotationTool.line;
                          _eraserMode = false;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.circle_outlined),
                        tooltip: 'Circle Tool',
                        color: _activeAnnotationTool == AnnotationTool.circle ? _annotationColor : AppTheme.mediumGrey,
                        onPressed: () => setState(() {
                          _activeAnnotationTool = _activeAnnotationTool == AnnotationTool.circle
                              ? AnnotationTool.none
                              : AnnotationTool.circle;
                          _eraserMode = false;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.crop_square),
                        tooltip: 'Rectangle Tool',
                        color: _activeAnnotationTool == AnnotationTool.rectangle
                            ? _annotationColor
                            : AppTheme.mediumGrey,
                        onPressed: () => setState(() {
                          _activeAnnotationTool = _activeAnnotationTool == AnnotationTool.rectangle
                              ? AnnotationTool.none
                              : AnnotationTool.rectangle;
                          _eraserMode = false;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Symbols.ink_eraser),
                        tooltip: 'Eraser',
                        color: _eraserMode ? AppTheme.errorRed : AppTheme.mediumGrey,
                        onPressed: () => setState(() {
                          _eraserMode = !_eraserMode;
                          if (_eraserMode) _activeAnnotationTool = AnnotationTool.none;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Symbols.delete),
                        tooltip: 'Delete All Annotations',
                        color: AppTheme.mediumGrey,
                        onPressed: _clearCurrentFrameAnnotations,
                      ),
                      IconButton(
                        icon: Icon(_annotationsAboveObjects ? Symbols.flip_to_front : Symbols.flip_to_back),
                        tooltip: _annotationsAboveObjects ? 'Annotations Above Objects' : 'Annotations Below Objects',
                        color: _annotationsAboveObjects ? AppTheme.mediumGrey : AppTheme.mediumGrey,
                        onPressed: () => setState(() {
                          _annotationsAboveObjects = !_annotationsAboveObjects;
                        }),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showColorPicker,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _annotationColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.darkGrey, width: 2),
                          ),
                          child: const Icon(Icons.palette, size: 16, color: Colors.white),
                        ),
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
    final innerR = outerR * 0.5;
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
    final fill = Paint()..color = Colors.yellow;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.redAccent;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 140;
    final usableHeight = screenSize.height - appBarHeight - timelineHeight;
    final boardCenter = Offset(screenSize.width / 2, appBarHeight + usableHeight / 2);

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
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 140;
    final usableHeight = screenSize.height - appBarHeight - timelineHeight;
    final boardCenter = Offset(screenSize.width / 2, appBarHeight + usableHeight / 2);

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
