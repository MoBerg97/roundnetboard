import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/animation_project.dart';
import '../models/frame.dart';
import '../widgets/path_painter.dart';
import '../widgets/board_background_painter.dart';
import '../models/annotation.dart';
import '../widgets/annotation_painter.dart';
import '../models/settings.dart';
import '../utils/path_engine.dart';
import '../services/tutorial_service.dart';
import 'settings_screen.dart';
import '../utils/history.dart';
import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../widgets/board_tutorial_overlay.dart';
import '../widgets/tutorial_target_indicator.dart';

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
enum AnnotationTool { none, line, circle }

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
  String? _activePathDragLabel; // Which path control is being dragged
  int? _activePathDragIndex; // Index of the control point being dragged (currently first only)

  // ──────────────────────────────────────────────────────────────────────────
  // TUTORIAL STATE
  // ──────────────────────────────────────────────────────────────────────────
  bool _showTutorialTarget = false; // Should tutorial target indicator be shown?
  final Set<String> _tutorialMovedObjects = {}; // Track objects moved in step 7

  // ──────────────────────────────────────────────────────────────────────────
  // UI REFERENCES
  // ──────────────────────────────────────────────────────────────────────────
  final GlobalKey _boardKey = GlobalKey(debugLabel: 'board'); // Key for board RenderBox (coordinate conversion)
  final GlobalKey _timelineKey = GlobalKey(debugLabel: 'timeline'); // Key for timeline widget
  final GlobalKey _playButtonKey = GlobalKey(debugLabel: 'playback_play'); // Key for play button
  final GlobalKey _frameAddButtonKey = GlobalKey(debugLabel: 'timeline_add'); // Key for frame add button
  final GlobalKey _annotationModeButtonKey = GlobalKey(debugLabel: 'annotation_menu'); // Key for annotation mode toggle
  late final ScrollController _timelineController; // Scroll controller for timeline

  // ──────────────────────────────────────────────────────────────────────────
  // TUTORIAL KEYS
  // ──────────────────────────────────────────────────────────────────────────
  final GlobalKey _timelineAreaKey = GlobalKey(debugLabel: 'timeline_area');
  final GlobalKey _player1Key = GlobalKey(debugLabel: 'player1');
  final GlobalKey _player2Key = GlobalKey(debugLabel: 'player2');
  final GlobalKey _ballKey = GlobalKey(debugLabel: 'ball');
  final GlobalKey _frameAddKey = GlobalKey(debugLabel: 'frame_add');
  final GlobalKey _durationKey = GlobalKey(debugLabel: 'duration');
  final GlobalKey _playKey = GlobalKey(debugLabel: 'play');
  final GlobalKey _stopKey = GlobalKey(debugLabel: 'stop');
  final GlobalKey _firstThumbnailKey = GlobalKey(debugLabel: 'first_thumbnail');
  final GlobalKey _undoKey = GlobalKey(debugLabel: 'undo');
  final GlobalKey _redoKey = GlobalKey(debugLabel: 'redo');
  final GlobalKey _setButtonKey = GlobalKey(debugLabel: 'set_button');
  final GlobalKey _hitButtonKey = GlobalKey(debugLabel: 'hit_button');

  @override
  void initState() {
    super.initState();
    print('🎲 BoardScreen: initState called');

    // Listen for tutorial requests and step changes
    TutorialService().addListener(_checkForPendingTutorial);
    TutorialService().addListener(_updateTutorialTarget);
    print('🎲 BoardScreen: Listeners added to TutorialService');

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
      final defaultFrame = Frame(
        p1: Offset(0, -r),
        p2: Offset(r, 0),
        p3: Offset(0, r),
        p4: Offset(-r, 0),
        ball: Offset.zero,
        p1Rotation: 0,
        p2Rotation: 0,
        p3Rotation: 0,
        p4Rotation: 0,
        p1PathPoints: [],
        p2PathPoints: [],
        p3PathPoints: [],
        p4PathPoints: [],
        ballPathPoints: [],
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
      'timeline_area': _timelineAreaKey,
      'play_button': _playKey,
      'frame_add_button': _frameAddKey,
      'annotation_button': _annotationModeButtonKey,
      'undo_button': _undoKey,
      'redo_button': _redoKey,
      'duration_button': _durationKey,
      'stop_button': _stopKey,
    };
    widget.onProvideTutorialKeys?.call(keys);
  }

  @override
  void dispose() {
    print('🎲 BoardScreen: dispose called');
    TutorialService().removeListener(_checkForPendingTutorial);
    _ticker.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🎲 BoardScreen: didChangeDependencies called');

    // Check for pending tutorial trigger on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🎲 BoardScreen: Post-frame callback from didChangeDependencies');
      _checkForPendingTutorial();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TUTORIAL METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Update tutorial target visibility based on current step
  void _updateTutorialTarget() {
    final tutorialService = TutorialService();
    if (!tutorialService.isActive) {
      setState(() => _showTutorialTarget = false);
      return;
    }

    final step = tutorialService.currentStep;
    final shouldShow = step != null && step.requiresDrag && step.targetPosition != null && step.targetProximity != null;

    if (_showTutorialTarget != shouldShow) {
      setState(() => _showTutorialTarget = shouldShow);
    }
  }

  /// Check if tutorial is currently active
  bool _isTutorialActive() => TutorialService().isActive;

  void _checkForPendingTutorial() {
    final tutorialService = TutorialService();

    // Only start if there's a pending tutorial AND it's not already active
    if (tutorialService.pendingTutorial == TutorialType.board && !tutorialService.isActive) {
      // Use post-frame callback to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Ensure keys are provided before starting
          _provideTutorialKeys();
          _startBoardTutorial();
          tutorialService.clearPendingTutorial();
        }
      });
    }
  }

  /// Validate if a drag gesture completes the current tutorial step
  void _validateTutorialDrag(String label, Offset from, Offset to, Size size) {
    final tutorial = TutorialService();
    if (!tutorial.isActive) return;

    final step = tutorial.currentStep;
    if (step?.id == 'board_drag') {
      _tutorialMovedObjects.add(label);
      tutorial.setMovedObjectsCount(_tutorialMovedObjects.length);
      if (_tutorialMovedObjects.length >= 2) {
        tutorial.nextStep();
      }
      return;
    }

    // Check if this drag completes the current step
    if (tutorial.validateDragForCurrentStep(label, to)) {
      tutorial.nextStep();
    }
  }

  void _startBoardTutorial() {
    final steps = [
      TutorialStep(
        id: 'board',
        title: 'Welcome to the Board!',
        description: 'This is where you create your animations. Players and the ball can be moved around.',
        targetKey: _boardKey,
      ),
      TutorialStep(
        id: 'timeline',
        title: 'Timeline',
        description: 'Frames capture positions at different moments. Add frames to create movement.',
        targetKey: _timelineAreaKey,
      ),
      TutorialStep(
        id: 'player1',
        title: 'Position Player 1',
        description: 'Drag this player to the blue target zone in the top-left area.',
        targetKey: null, // Don't highlight the player, show the zone
        requiresDrag: true,
        dragTargetId: 'P1',
        targetPosition: const Offset(-150, -150),
        targetProximity: 100,
        showSuccess: true,
      ),
      TutorialStep(
        id: 'player2',
        title: 'Position Player 2',
        description: 'Drag this player to the blue target zone in the top-right area.',
        targetKey: null,
        requiresDrag: true,
        dragTargetId: 'P2',
        targetPosition: const Offset(150, -150),
        targetProximity: 100,
        showSuccess: true,
      ),
      TutorialStep(
        id: 'ball',
        title: 'Position the Ball',
        description: 'Drag the ball to the blue target zone near Player 1.',
        targetKey: _ballKey,
        requiresDrag: true,
        dragTargetId: 'BALL',
        // Dynamic target: near P1
        targetPosition: currentFrame.p1 + const Offset(40, 40),
        targetProximity: 80,
        showSuccess: true,
      ),
      TutorialStep(
        id: 'frame_add',
        title: 'Add a Frame',
        description: 'Tap this button to add a new frame and capture the current positions.',
        targetKey: _frameAddKey,
        isConditional: true,
        showSuccess: true,
        autoPerformAction: () => _insertFrameAfterCurrent(),
      ),
      TutorialStep(
        id: 'board_drag_long',
        title: 'Long Movement',
        description: 'Drag the ball across at least half the court to see how paths are created.',
        targetKey: _ballKey,
        requiresDrag: true,
        dragTargetId: 'BALL',
        targetPosition: currentFrame.ball.dx > 0 ? const Offset(-150, 0) : const Offset(150, 0),
        targetProximity: 150, // Large proximity but requires distance
        showSuccess: true,
      ),
      TutorialStep(
        id: 'board_drag',
        title: 'Create Movement',
        description: 'Drag any player or ball to a new position to show movement between frames.',
        targetKey: null,
        requiresDrag: true,
        showSuccess: true,
      ),
      TutorialStep(
        id: 'multi_frame',
        title: 'Build Your Play',
        description: 'Add at least 3 frames to create a complete sequence of movement.',
        targetKey: _frameAddKey,
        isConditional: true,
        showSuccess: true,
        autoPerformAction: () {
          // Add frames until we have at least 3
          while (widget.project.frames.length < 3) {
            _insertFrameAfterCurrent();
          }
        },
      ),
      TutorialStep(
        id: 'ball_modifier',
        title: 'Ball Modifiers',
        description: 'Tap the ball to open the modifier menu. You can set "Hit" or "Set" effects.',
        targetKey: _ballKey,
        isConditional: true,
        showSuccess: true,
        autoPerformAction: () {
          setState(() {
            _showModifierMenu = true;
          });
        },
      ),
      TutorialStep(
        id: 'ball_hit',
        title: 'Set a Hit',
        description: 'Select "Hit" and then tap anywhere on the ball path to mark where the ball was hit.',
        targetKey: _hitButtonKey,
        isConditional: true,
        showSuccess: true,
        autoPerformAction: () {
          setState(() {
            currentFrame.ballHitT = 0.5;
            _showModifierMenu = false;
          });
        },
      ),
      TutorialStep(
        id: 'hit_marker_move',
        title: 'Move Hit Marker',
        description: 'You can drag the hit marker along the path to adjust the timing of the hit.',
        targetKey: null, // The hit marker is dynamic, so no fixed key
        isConditional: true,
        showSuccess: true,
        autoPerformAction: () {
          setState(() {
            currentFrame.ballHitT = 0.75;
          });
        },
      ),
      TutorialStep(
        id: 'duration',
        title: 'Frame Duration',
        description: 'Tap frames to select them and adjust their duration.',
        targetKey: _durationKey,
        isConditional: true,
        showSuccess: true,
        autoPerformAction: () => _showDurationPicker(),
      ),
      TutorialStep(
        id: 'undo_redo',
        title: 'Undo & Redo',
        description: 'Made a mistake? Use undo to go back or redo to restore your changes.',
        targetKey: _undoKey,
        isConditional: true,
        showSuccess: true,
        autoPerformAction: () {
          if (_history.canUndo) {
            final idx = _history.undo();
            if (idx != null && idx >= 0 && idx < widget.project.frames.length) {
              setState(() => currentFrame = widget.project.frames[idx]);
              _scrollToSelectedFrame();
            }
          }
        },
      ),
      TutorialStep(
        id: 'play',
        title: 'Play Animation',
        description: 'Press play to see your animation in action!',
        targetKey: _playKey,
        isConditional: true,
        showSuccess: true,
        autoPerformAction: () => _startPlayback(),
      ),
      TutorialStep(
        id: 'stop',
        title: 'Stop Playback',
        description: 'Use stop to return to editing mode.',
        targetKey: _stopKey,
        isConditional: true,
        autoPerformAction: () => _stopPlayback(),
      ),
      TutorialStep(
        id: 'final',
        title: 'You\'re All Set!',
        description: 'You now know the basics. Experiment with paths, annotations, and more!',
        targetKey: null,
      ),
    ];

    TutorialService().startTutorial(TutorialType.board, steps);
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

    // Stop at last frame
    if (_playbackFrameIndex >= frames.length - 1) {
      setState(() {
        _endedAtLastFrame = true;
        _isPlaying = false;
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

    // Tutorial progression
    final tutorial = TutorialService();
    if (tutorial.isActive && tutorial.currentStep?.id == 'play') {
      tutorial.nextStep();
    }
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

    // Tutorial progression
    final tutorial = TutorialService();
    if (tutorial.isActive && tutorial.currentStep?.id == 'stop') {
      tutorial.nextStep();
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

                // Tutorial progression
                final tutorial = TutorialService();
                if (tutorial.isActive && tutorial.currentStep?.id == 'duration') {
                  tutorial.nextStep();
                }
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

  /// Generate interpolated frame between two keyframes during playback
  Frame? get _animatedFrame {
    if (!_isPlaying) return null;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return null;

    final fA = frames[_playbackFrameIndex];
    final fB = frames[_playbackFrameIndex + 1];
    final t = _playbackT;

    // Helper to interpolate along path or linearly
    Offset getPathOrLinear(String entity, Offset start, Offset end, List<Offset> pathPoints) {
      if (pathPoints.isNotEmpty) {
        final engine = PathEngine.fromTwoQuadratics(start: start, control: pathPoints.first, end: end, resolution: 400);
        return engine.sample(t);
      } else {
        return Offset.lerp(start, end, t)!;
      }
    }

    return Frame(
      p1: getPathOrLinear('P1', fA.p1, fB.p1, fB.p1PathPoints),
      p2: getPathOrLinear('P2', fA.p2, fB.p2, fB.p2PathPoints),
      p3: getPathOrLinear('P3', fA.p3, fB.p3, fB.p3PathPoints),
      p4: getPathOrLinear('P4', fA.p4, fB.p4, fB.p4PathPoints),
      ball: getPathOrLinear('BALL', fA.ball, fB.ball, fB.ballPathPoints),
      p1Rotation: _interpolateRotation(fA.p1Rotation, fB.p1Rotation, t),
      p2Rotation: _interpolateRotation(fA.p2Rotation, fB.p2Rotation, t),
      p3Rotation: _interpolateRotation(fA.p3Rotation, fB.p3Rotation, t),
      p4Rotation: _interpolateRotation(fA.p4Rotation, fB.p4Rotation, t),
      p1PathPoints: [],
      p2PathPoints: [],
      p3PathPoints: [],
      p4PathPoints: [],
      ballPathPoints: [],
      annotations: fB.annotations,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BALL EFFECT ANIMATIONS (Set swell, Hit shrink)
  // ══════════════════════════════════════════════════════════════════════════

  /// Calculate ball scale during playback based on set/hit effects
  double _ballScaleAt(double t) {
    const double base = 1.0;
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return base;
    final fB = frames[_playbackFrameIndex + 1];

    // Set animation: subtle swell when set is enabled
    if ((fB.ballSet ?? false) && fB.ballHitT == null) {
      final quad = 1.0 + (1.0 - 4.0 * (t - 0.5) * (t - 0.5));
      return quad.clamp(0.5, 2.0);
    }

    // Hit modifier: shrink to minimum 0.25 at hit time, easing back to 1.0
    if (fB.ballHitT != null && !(fB.ballSet ?? false)) {
      final th = fB.ballHitT!.clamp(0.0, 1.0);
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

  /// Update the position of a player or ball in the current frame
  void _updateFramePosition(String label, Offset newPos) {
    if (_isPlaying) return;
    setState(() {
      switch (label) {
        case "P1":
          currentFrame.p1 = newPos;
          // Update ball target if it's the current tutorial step
          final tutorial = TutorialService();
          if (tutorial.isActive && tutorial.currentStep?.id == 'ball') {
            tutorial.updateStepTarget('ball', newPos + const Offset(40, 40));
          }
          break;
        case "P2":
          currentFrame.p2 = newPos;
          break;
        case "P3":
          currentFrame.p3 = newPos;
          break;
        case "P4":
          currentFrame.p4 = newPos;
          break;
        case "BALL":
          currentFrame.ball = newPos;
          break;
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
    // Deep-copy current frame so all positions, settings, and annotations carry over
    final newFrame = currentFrame.copy();
    final newIdx = _history.push(InsertFrameAction(frameIndex: index, inserted: newFrame));
    setState(() {
      currentFrame = widget.project.frames[newIdx + 1];
    });
    _scrollToSelectedFrame();

    // Tutorial progression
    final tutorial = TutorialService();
    if (tutorial.isActive) {
      if (tutorial.currentStep?.id == 'frame_add') {
        // Use a small delay to ensure the frame is actually added and UI updated
        Future.delayed(const Duration(milliseconds: 50), () {
          tutorial.nextStep();
        });
      } else if (tutorial.currentStep?.id == 'multi_frame' && widget.project.frames.length >= 3) {
        Future.delayed(const Duration(milliseconds: 50), () {
          tutorial.nextStep();
        });
      }
    }
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
          final defaultFrame = Frame(
            p1: Offset(0, -r),
            p2: Offset(r, 0),
            p3: Offset(0, r),
            p4: Offset(-r, 0),
            ball: Offset.zero,
            p1Rotation: 0,
            p2Rotation: 0,
            p3Rotation: 0,
            p4Rotation: 0,
            p1PathPoints: [],
            p2PathPoints: [],
            p3PathPoints: [],
            p4PathPoints: [],
            ballPathPoints: [],
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

  /// Save the project to Hive database
  void _saveProject() {
    widget.project.save();
    debugPrint("Project saved with ${widget.project.frames.length} frames");
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

  // ══════════════════════════════════════════════════════════════════════════
  // BOARD TAP HANDLER
  // ══════════════════════════════════════════════════════════════════════════
  // Handles taps on the board for placing ball modifiers or adding annotations

  void _handleBoardTap(Offset tapPos, Size size) {
    if (_isPlaying) return;

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
    if (tryAdd("BALL", prev.ball, currentFrame.ball, currentFrame.ballPathPoints)) return;
  }

  /// Handle drag start for line drawing
  void _handleAnnotationDragStart(DragStartDetails details, Size size) {
    if (_isPlaying) return;
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
    if (_activeAnnotationTool != AnnotationTool.line) return;

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
    });
  }

  /// Handle drag update for live line preview and erasing
  void _handleAnnotationDragUpdate(DragUpdateDetails details, Size size) {
    if (_isPlaying) return;
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
    } else if (_activeAnnotationTool == AnnotationTool.line && _pendingAnnotationPoints.isNotEmpty) {
      // Update preview position for line drag
      setState(() {
        _currentDragPos = cmPos;
      });
    }
  }

  /// Clear all annotations on the current frame
  void _clearCurrentFrameAnnotations() {
    if (_isPlaying) return;
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
    if (_isPlaying) return;
    if (_eraserMode) {
      // Erasing already happened during drag, clear eraser position
      setState(() {
        _erasingAnnotations.clear();
        _eraserPosCm = null;
      });
      return;
    }

    if (_activeAnnotationTool == AnnotationTool.line &&
        _pendingAnnotationPoints.isNotEmpty &&
        _currentDragPos != null) {
      final start = _pendingAnnotationPoints[0];
      final end = _currentDragPos!;

      if ((end - start).distance > 10) {
        // Only create if drag distance > 10cm
        final ann = Annotation(type: AnnotationType.line, color: _annotationColor, points: [start, end]);
        setState(() {
          currentFrame.annotations.add(ann);
          _pendingAnnotationPoints.clear();
          _currentDragPos = null;
        });
        _saveProject();
      } else {
        // Drag too short, discard
        setState(() {
          _pendingAnnotationPoints.clear();
          _currentDragPos = null;
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

    // Check if ball path distance is >= 30cm
    final pathDistance = _calculateBallPathDistance(prev);
    if (pathDistance < 30.0) {
      // Silently ignore - path too short for hit
      return;
    }
    // Build samples along path from prev.ball to currentFrame.ball
    final hasCtrl = currentFrame.ballPathPoints.isNotEmpty;
    final engine = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: prev.ball,
            control: currentFrame.ballPathPoints.first,
            end: currentFrame.ball,
            resolution: 200,
          )
        : null;
    double bestT = 0.5;
    double bestD = double.infinity;
    const int res = 200;
    for (int i = 0; i <= res; i++) {
      final t = i / res;
      final posCm = hasCtrl ? engine!.sample(t) : Offset.lerp(prev.ball, currentFrame.ball, t)!;
      final posScreen = _toScreenPosition(posCm, size);
      final d = (tapPos - posScreen).distance;
      if (d < bestD) {
        bestD = d;
        bestT = t;
      }
    }
    if (bestD < 40) {
      setState(() {
        currentFrame.ballHitT = bestT;
        _pendingBallMark = null;
      });
      _saveProject();
    } else {
      // ignore if too far from path
    }
  }

  /// Calculate the straight-line distance from prev.ball to currentFrame.ball (in cm)
  double _calculateBallPathDistance(Frame prev) {
    return (currentFrame.ball - prev.ball).distance;
  }

  /// Find the nearest t value on the ball path to the tap position
  double _nearestTOnBallPath(Offset tapPos, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return 0.5;
    final hasCtrl = currentFrame.ballPathPoints.isNotEmpty;
    final engine = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: prev.ball,
            control: currentFrame.ballPathPoints.first,
            end: currentFrame.ball,
            resolution: 400,
          )
        : null;
    const int res = 400;
    double bestT = 0.5;
    double bestD = double.infinity;
    for (int i = 0; i <= res; i++) {
      final t = i / res;
      final posCm = hasCtrl ? engine!.sample(t) : Offset.lerp(prev.ball, currentFrame.ball, t)!;
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
  double _avoidControlPointOverlap(Frame prev, double t) {
    if (currentFrame.ballPathPoints.isEmpty) return t;
    final ctrlT = 0.5; // control is midpoint in our 2-quad approx
    final cmOffset = 150.0;
    if ((t - ctrlT).abs() < 0.02) {
      // approximate mapping: shift t by distance in cm over estimated path length
      final pathLen = (currentFrame.ball - prev.ball).distance;
      final frac = (pathLen > 0) ? (cmOffset / pathLen) : 0.1;
      return (t + frac).clamp(0.0, 1.0);
    }
    return t;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PATH CONTROL DRAG HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  List<Offset>? _pathPointsForLabel(String label) {
    switch (label) {
      case "P1":
        return currentFrame.p1PathPoints;
      case "P2":
        return currentFrame.p2PathPoints;
      case "P3":
        return currentFrame.p3PathPoints;
      case "P4":
        return currentFrame.p4PathPoints;
      case "BALL":
        return currentFrame.ballPathPoints;
      default:
        return null;
    }
  }

  Offset? _pathStartForLabel(String label, Frame prev) {
    switch (label) {
      case "P1":
        return prev.p1;
      case "P2":
        return prev.p2;
      case "P3":
        return prev.p3;
      case "P4":
        return prev.p4;
      case "BALL":
        return prev.ball;
      default:
        return null;
    }
  }

  Offset? _pathEndForLabel(String label) {
    switch (label) {
      case "P1":
        return currentFrame.p1;
      case "P2":
        return currentFrame.p2;
      case "P3":
        return currentFrame.p3;
      case "P4":
        return currentFrame.p4;
      case "BALL":
        return currentFrame.ball;
      default:
        return null;
    }
  }

  /// Locate the nearest path under a touch and snap/create a control point for drag.
  bool _maybeStartPathDrag(Offset localPos, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return false;

    const double bufferCm = 20.0;
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

    final candidates = ["P1", "P2", "P3", "P4", "BALL"];
    for (final label in candidates) {
      final start = _pathStartForLabel(label, prev);
      final end = _pathEndForLabel(label);
      final points = _pathPointsForLabel(label);
      if (start == null || end == null || points == null) continue;
      scanPath(label, start, end, points);
    }

    if (bestLabel == null || bestPointCm == null) return false;
    if (bestDistPx > bufferPx) return false;

    final points = _pathPointsForLabel(bestLabel!);
    if (points == null) return false;

    setState(() {
      if (points.isEmpty) {
        points.add(bestPointCm!);
      } else {
        points[0] = bestPointCm!;
      }
      _activePathDragLabel = bestLabel;
      _activePathDragIndex = 0;
      _dragStartLogical["PATH-$bestLabel-0"] = points[0];
      _dragStartScreen["PATH-$bestLabel-0"] = localPos;
      _showModifierMenu = false;
    });

    final idx = widget.project.frames.indexOf(currentFrame);
    if (idx >= 0) {
      widget.project.frames[idx] = currentFrame;
      PathEngine.invalidateCacheFor(idx, bestLabel!);
    }
    return true;
  }

  void _updatePathDrag(Offset localPos, Size size) {
    final label = _activePathDragLabel;
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
    final label = _activePathDragLabel;
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
      _activePathDragLabel = null;
      _activePathDragIndex = null;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILD HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Build the hit marker widget for ball hit indication
  Widget _buildHitMarker(double t, Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return const SizedBox.shrink();
    final hasCtrl = currentFrame.ballPathPoints.isNotEmpty;
    final posCm = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: prev.ball,
            control: currentFrame.ballPathPoints.first,
            end: currentFrame.ball,
            resolution: 400,
          ).sample(t)
        : Offset.lerp(prev.ball, currentFrame.ball, t)!;
    final pos = _toScreenPosition(posCm, size);
    return Positioned(
      left: pos.dx - 16,
      top: pos.dy - 16,
      child: GestureDetector(
        onPanStart: (details) {
          // Start dragging the hit marker immediately when the user pans on it
          setState(() => _pendingBallMark = 'hit');
        },
        onPanUpdate: (details) {
          if (_pendingBallMark == 'hit') {
            // Convert global coordinates to local coordinates relative to the board
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            final localPos = box.globalToLocal(details.globalPosition);
            final newT = _nearestTOnBallPath(localPos, size);
            setState(() => currentFrame.ballHitT = newT);
            _saveProject();
          }
        },
        onPanEnd: (_) {
          setState(() => _pendingBallMark = null);
          _saveProject();

          // Tutorial progression
          final tutorial = TutorialService();
          if (tutorial.isActive && tutorial.currentStep?.id == 'hit_marker_move') {
            tutorial.nextStep();
          }
        },
        child: CustomPaint(size: const Size(32, 32), painter: _StarPainter()),
      ),
    );
  }

  /// Build the set preview indicator (circle) at the midpoint of the ball path
  Widget _buildSetPreview(Size size) {
    final prev = _getPreviousFrame();
    if (prev == null) return const SizedBox.shrink();
    final hasCtrl = currentFrame.ballPathPoints.isNotEmpty;
    final midCm = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: prev.ball,
            control: currentFrame.ballPathPoints.first,
            end: currentFrame.ball,
            resolution: 200,
          ).sample(0.5)
        : (prev.ball + currentFrame.ball) / 2;
    final pos = _toScreenPosition(midCm, size);
    final double scale = 2.0; // max size for set
    return Positioned(
      left: pos.dx - 15 * scale,
      top: pos.dy - 15 * scale,
      child: Opacity(
        opacity: 0.35,
        child: Container(
          width: 30 * scale,
          height: 30 * scale,
          decoration: BoxDecoration(color: AppTheme.accentOrange.withValues(alpha: 0.35), shape: BoxShape.circle),
        ),
      ),
    );
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
              // store screen position relative to board
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
              width: 24,
              height: 24,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Container(
                width: 18,
                height: 18,
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

  /// Build player widgets (P1, P2, P3, P4) with drag handling
  Widget _buildPlayer(Offset posCm, double rotation, Color color, String label, Size size, {GlobalKey? key}) {
    final screenPos = _toScreenPosition(posCm, size);
    
    // Check if this player is the current drag target in a tutorial step
    final tutorial = TutorialService();
    final isCurrentDragTarget = tutorial.isActive &&
        tutorial.currentStep?.requiresDrag == true &&
        tutorial.currentStep?.dragTargetId == label;

    return Positioned(
      key: key,
      left: screenPos.dx - 20,
      top: screenPos.dy - 20,
      child: IgnorePointer(
        ignoring: _annotationMode && !_isTutorialActive(),
        child: GestureDetector(
          onPanStart: (details) {
            _dragStartLogical[label] = posCm;
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            _dragStartScreen[label] = box.globalToLocal(details.globalPosition);
          },
          onPanUpdate: (details) {
            setState(() {
              final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              final deltaScreen = localPos - (_dragStartScreen[label] ?? localPos);
              final scalePerCm = _settings.cmToLogical(1.0, size);
              _updateFramePosition(label, (_dragStartLogical[label] ?? posCm) + deltaScreen / scalePerCm);
            });
          },
          onPanEnd: (_) {
            final from = _dragStartLogical[label] ?? posCm;
            final to = switch (label) {
              "P1" => currentFrame.p1,
              "P2" => currentFrame.p2,
              "P3" => currentFrame.p3,
              "P4" => currentFrame.p4,
              _ => currentFrame.ball,
            };

            // Validate tutorial drag before committing to history
            _validateTutorialDrag(label, from, to, size);

            final idx = widget.project.frames.indexOf(currentFrame);
            final newIdx = _history.push(MoveEntityAction(frameIndex: idx, label: label, from: from, to: to));
            setState(() {
              currentFrame = widget.project.frames[newIdx];
            });
            _scrollToSelectedFrame();
            _dragStartLogical.remove(label);
            _dragStartScreen.remove(label);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsating glow when this player is the tutorial drag target
              if (isCurrentDragTarget)
                TutorialPulseGlow(
                  size: 50,
                  glowColor: Colors.cyan,
                ),
              // Player circle
              Transform.rotate(
                angle: rotation,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the ball widget with optional scale and star opacity
  Widget _buildBall(Offset posCm, Size size, {double scale = 1.0, double starOpacity = 0.0, GlobalKey? key}) {
    final screenPos = _toScreenPosition(posCm, size);
    
    // Check if ball is the current drag target in a tutorial step
    final tutorial = TutorialService();
    final isCurrentDragTarget = tutorial.isActive &&
        tutorial.currentStep?.requiresDrag == true &&
        tutorial.currentStep?.dragTargetId == "BALL";

    return Positioned(
      key: key,
      left: screenPos.dx - 15 * scale,
      top: screenPos.dy - 15 * scale,
      child: IgnorePointer(
        ignoring: _annotationMode && !_isTutorialActive(),
        child: GestureDetector(
          onTap: () {
            if (!_isPlaying && !_endedAtLastFrame) {
              // If modifier menu is open, close it; otherwise open it
              if (_showModifierMenu) {
                setState(() {
                  _showModifierMenu = false;
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
                });
              }
            }
          },
          onPanStart: (details) {
            _dragStartLogical["BALL"] = posCm;
            final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
            _dragStartScreen["BALL"] = box.globalToLocal(details.globalPosition);
          },
          onPanUpdate: (details) {
            setState(() {
              final box = (_boardKey.currentContext?.findRenderObject() ?? context.findRenderObject()) as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              final deltaScreen = localPos - (_dragStartScreen["BALL"] ?? localPos);
              final scalePerCm = _settings.cmToLogical(1.0, size);
              _updateFramePosition("BALL", (_dragStartLogical["BALL"] ?? posCm) + deltaScreen / scalePerCm);
            });
          },
          onPanEnd: (_) {
            final from = _dragStartLogical["BALL"] ?? posCm;
            final to = currentFrame.ball;

            // Validate tutorial drag before committing to history
            _validateTutorialDrag("BALL", from, to, size);

            final idx = widget.project.frames.indexOf(currentFrame);
            final newIdx = _history.push(MoveEntityAction(frameIndex: idx, label: "BALL", from: from, to: to));
            setState(() {
              currentFrame = widget.project.frames[newIdx];
            });
            _scrollToSelectedFrame();
            _dragStartLogical.remove("BALL");
            _dragStartScreen.remove("BALL");
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsating glow when ball is the tutorial drag target
              if (isCurrentDragTarget)
                TutorialPulseGlow(
                  size: 50 * scale,
                  glowColor: Colors.cyan,
                ),
              // Ball circle
              Container(
                width: 30 * scale,
                height: 30 * scale,
                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
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

  // During playback we render the persisted hit star at its exact path position
  // (may persist across frame boundary for up to 0.5 frames). This helper
  // returns the star opacity and screen position if active.
  Map<String, dynamic> _playbackHitStarInfo(Size size) {
    if (!_isPlaying) return {};
    final frames = widget.project.frames;
    if (_playbackFrameIndex >= frames.length - 1) return {};
    final fAIndex = _playbackFrameIndex;
    final fBIndex = _playbackFrameIndex + 1;
    final fA = frames[fAIndex];
    final fB = frames[fBIndex];
    if (fB.ballHitT == null) return {};
    final globalNow = _playbackFrameIndex + _playbackT;
    final hitGlobal = _playbackFrameIndex + fB.ballHitT!;
    const double hold = 0.5;
    if (!(globalNow >= hitGlobal && globalNow <= hitGlobal + hold)) return {};
    // compute hit position along the path (use two-quad engine if control point exists)
    final hasCtrl = fB.ballPathPoints.isNotEmpty;
    final posCm = hasCtrl
        ? PathEngine.fromTwoQuadratics(
            start: fA.ball,
            control: fB.ballPathPoints.first,
            end: fB.ball,
            resolution: 400,
          ).sample(fB.ballHitT!)
        : Offset.lerp(fA.ball, fB.ball, fB.ballHitT!)!;
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
    final frameToShow = _endedAtLastFrame ? widget.project.frames.last : (isPlayback ? _animatedFrame! : currentFrame);
    // Timeline maintains consistent height during state transitions to avoid layout shifts
    // Playback: 160px (more space for timeline), End-state: 120px (with stop button), Editing: 120px (full controls)
    final double timelineHeight = 140.0;
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
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
        body: Stack(
          children: [
            // Layer 1 (bottom): Board - stays fixed
            Positioned.fill(
              bottom: 140, // Leave room for timeline
              child: AbsorbPointer(
                absorbing: _isPlaying || _endedAtLastFrame,
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
                          painter: BoardBackgroundPainter(screenSize: screenSize, settings: _settings),
                        ),
                      ),
                      // Tutorial target indicator for drag-required steps
                      if (_showTutorialTarget)
                        (() {
                          final step = TutorialService().currentStep;
                          if (step == null || step.targetPosition == null || step.targetProximity == null) {
                            return const SizedBox.shrink();
                          }
                          final centerPx = _toScreenPosition(step.targetPosition!, screenSize);
                          final radiusPx = _settings.cmToLogical(step.targetProximity!, screenSize).abs();
                          return Positioned(
                            left: 0,
                            top: 0,
                            right: 0,
                            bottom: 0,
                            child: TutorialTargetIndicator(center: centerPx, radiusPx: radiusPx),
                          );
                        })(),
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
                            } else if (_activePathDragLabel != null) {
                              _updatePathDrag(details.localPosition, screenSize);
                            }
                          },
                          onPanEnd: (details) {
                            if (_isPlaying || _endedAtLastFrame) return;
                            if (_annotationMode) {
                              _handleAnnotationDragEnd(details, screenSize);
                            } else if (_activePathDragLabel != null) {
                              _endPathDrag();
                            }
                          },
                          behavior: HitTestBehavior.translucent,
                          child: Container(),
                        ),
                      ),
                      _buildPlayer(
                        frameToShow.p1,
                        frameToShow.p1Rotation,
                        Colors.blue,
                        "P1",
                        screenSize,
                        key: _player1Key,
                      ),
                      _buildPlayer(
                        frameToShow.p2,
                        frameToShow.p2Rotation,
                        Colors.blue,
                        "P2",
                        screenSize,
                        key: _player2Key,
                      ),
                      _buildPlayer(frameToShow.p3, frameToShow.p3Rotation, Colors.red, "P3", screenSize),
                      _buildPlayer(frameToShow.p4, frameToShow.p4Rotation, Colors.red, "P4", screenSize),
                      _buildBall(
                        frameToShow.ball,
                        screenSize,
                        scale: isPlayback ? _ballScaleAt(_playbackT) : 1.0,
                        starOpacity: 0.0,
                        key: _ballKey,
                      ),
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
                        (() {
                          final info = _playbackHitStarInfo(screenSize);
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
                      if (!isPlayback && (currentFrame.ballSet ?? false)) _buildSetPreview(screenSize),
                      if (!(_isPlaying || _endedAtLastFrame)) ...[
                        if (currentFrame.p1PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.p1PathPoints,
                            prev != null ? prev.p1 : currentFrame.p1,
                            currentFrame.p1,
                            screenSize,
                            "P1",
                          ),
                        if (currentFrame.p2PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.p2PathPoints,
                            prev != null ? prev.p2 : currentFrame.p2,
                            currentFrame.p2,
                            screenSize,
                            "P2",
                          ),
                        if (currentFrame.p3PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.p3PathPoints,
                            prev != null ? prev.p3 : currentFrame.p3,
                            currentFrame.p3,
                            screenSize,
                            "P3",
                          ),
                        if (currentFrame.p4PathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.p4PathPoints,
                            prev != null ? prev.p4 : currentFrame.p4,
                            currentFrame.p4,
                            screenSize,
                            "P4",
                          ),
                        if (currentFrame.ballPathPoints.isNotEmpty)
                          ..._buildPathControlPoints(
                            currentFrame.ballPathPoints,
                            prev != null ? prev.ball : currentFrame.ball,
                            currentFrame.ball,
                            screenSize,
                            "BALL",
                          ),
                      ],
                      if (currentFrame.ballHitT != null && !(_isPlaying || _endedAtLastFrame))
                        _buildHitMarker(currentFrame.ballHitT!, screenSize),
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
                key: _timelineAreaKey,
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
                        absorbing: _isPlaying || _endedAtLastFrame,
                        child: ListView.builder(
                          key: _timelineKey,
                          controller: _timelineController,
                          scrollDirection: Axis.horizontal,
                          itemCount: _isPlaying ? widget.project.frames.length - 1 : widget.project.frames.length,
                          itemBuilder: (context, index) {
                            final frame = _isPlaying ? widget.project.frames[index + 1] : widget.project.frames[index];
                            final isSelected = frame == currentFrame;
                            return GestureDetector(
                              key: index == 0 ? _firstThumbnailKey : null,
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
                                      color: _isPlaying
                                          ? AppTheme.timelineInactive
                                          : (isSelected ? AppTheme.timelineActive : AppTheme.timelineInactive),
                                      borderRadius: BorderRadius.circular(24),
                                      border: (_isPlaying)
                                          ? null
                                          : (isSelected ? Border.all(color: AppTheme.primaryBlue, width: 2.5) : null),
                                      boxShadow: isSelected && !_isPlaying
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${_isPlaying ? index + 1 : index}",
                                        style: TextStyle(
                                          fontWeight: isSelected && !_isPlaying ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected && !_isPlaying ? Colors.white : AppTheme.darkGrey,
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
                                                color: Colors.black.withOpacity(0.2),
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
                          absorbing: true,
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
                                              color: AppTheme.primaryBlue.withOpacity(0.5),
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
                              // If user scrubs back from end, pause the playback
                              if (_endedAtLastFrame) {
                                _isPaused = true;
                                _endedAtLastFrame = false;
                              }
                              final total = (widget.project.frames.length - 1).toDouble();
                              final globalPos = frac * total;
                              _playbackFrameIndex = globalPos.floor();
                              _playbackT = globalPos - _playbackFrameIndex;
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
                              key: _stopKey,
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              key: _playKey,
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
                              key: _frameAddKey,
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
                                    key: _durationKey,
                                    icon: const Icon(Icons.schedule),
                                    tooltip: "Set frame duration (${currentFrame.duration.toStringAsFixed(2)}s)",
                                    iconSize: 18,
                                    onPressed: () => _showDurationPicker(),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 12),
                            IconButton(
                              key: _undoKey,
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

                                            // Tutorial progression
                                            final tutorial = TutorialService();
                                            if (tutorial.isActive && tutorial.currentStep?.id == 'undo_redo') {
                                              tutorial.nextStep();
                                            }
                                          }
                                        : null),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              key: _redoKey,
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

                                            // Tutorial progression
                                            final tutorial = TutorialService();
                                            if (tutorial.isActive && tutorial.currentStep?.id == 'undo_redo') {
                                              tutorial.nextStep();
                                            }
                                          }
                                        : null),
                            ),
                          ],
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
                        key: _setButtonKey,
                        onTap: () {
                          setState(() {
                            // Toggle Set: if already set, unset it; otherwise set it and clear Hit
                            if (currentFrame.ballSet ?? false) {
                              currentFrame.ballSet = false;
                            } else {
                              currentFrame.ballSet = true;
                              currentFrame.ballHitT = null; // Clear Hit when setting Set
                            }
                          });
                          _saveProject();

                          // Tutorial progression
                          final tutorial = TutorialService();
                          if (tutorial.isActive && tutorial.currentStep?.id == 'ball_modifier') {
                            tutorial.nextStep();
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: (currentFrame.ballSet ?? false)
                                ? AppTheme.accentOrange.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: (currentFrame.ballSet ?? false) ? AppTheme.accentOrange : AppTheme.mediumGrey,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(24, 24),
                                painter: _SetIconPainter(active: currentFrame.ballSet ?? false),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Set',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: (currentFrame.ballSet ?? false) ? AppTheme.accentOrange : AppTheme.mediumGrey,
                                  fontWeight: (currentFrame.ballSet ?? false) ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Hit button - toggle, mutually exclusive with Set
                      GestureDetector(
                        key: _hitButtonKey,
                        onTap: () {
                          final prev = _getPreviousFrame();
                          if (prev != null) {
                            final tMid = 0.5;
                            final tAdjusted = _avoidControlPointOverlap(prev, tMid);
                            setState(() {
                              // Toggle Hit: if already set, clear it; otherwise set it and clear Set
                              if (currentFrame.ballHitT != null) {
                                currentFrame.ballHitT = null;
                              } else {
                                currentFrame.ballHitT = tAdjusted;
                                currentFrame.ballSet = false; // Clear Set when setting Hit
                              }
                            });
                            _saveProject();

                            // Tutorial progression
                            final tutorial = TutorialService();
                            if (tutorial.isActive && tutorial.currentStep?.id == 'ball_hit') {
                              tutorial.nextStep();
                            }
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: (currentFrame.ballHitT != null)
                                ? AppTheme.warningAmber.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: (currentFrame.ballHitT != null) ? AppTheme.warningAmber : AppTheme.mediumGrey,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(24, 24),
                                painter: _HitIconPainter(active: currentFrame.ballHitT != null),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hit',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: (currentFrame.ballHitT != null) ? AppTheme.warningAmber : AppTheme.mediumGrey,
                                  fontWeight: (currentFrame.ballHitT != null) ? FontWeight.bold : FontWeight.normal,
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
            // Layer 4 (top): Annotation Toolbar - overlay at top
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
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          _annotationMode = false;
                          _activeAnnotationTool = AnnotationTool.none;
                          _eraserMode = false;
                        }),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            // Tutorial overlay (on top of everything)
            if (TutorialService().isActive)
              Positioned.fill(
                child: BoardTutorialOverlay(
                  steps: TutorialService().steps,
                  boardKey: _boardKey,
                  onFinish: () {
                    TutorialService().markTutorialCompleted(TutorialType.board);
                  },
                ),
              ),
          ],
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
      ..color = AppTheme.errorRed.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(screenCenter, screenRadiusPx, fillPaint);

    // Draw stroke circle
    final strokePaint = Paint()
      ..color = AppTheme.errorRed.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(screenCenter, screenRadiusPx, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _EraserCirclePainter oldDelegate) =>
      oldDelegate.centerCm != centerCm || oldDelegate.radiusCm != radiusCm;
}

/// Pulsating glow widget for highlighting draggable tutorial elements
class TutorialPulseGlow extends StatefulWidget {
  final double size;
  final Color glowColor;

  const TutorialPulseGlow({
    super.key,
    this.size = 50,
    this.glowColor = Colors.cyan,
  });

  @override
  State<TutorialPulseGlow> createState() => _TutorialPulseGlowState();
}

class _TutorialPulseGlowState extends State<TutorialPulseGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Pulse from 0.6 to 1.0 and back
        final scale = 0.6 + (_controller.value * 0.4);
        final opacity = 0.8 - (_controller.value * 0.6);

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(opacity),
                blurRadius: 15,
                spreadRadius: scale * 5,
              ),
            ],
          ),
        );
      },
    );
  }
}
