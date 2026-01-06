import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;

import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../models/animation_project.dart';
import '../models/settings.dart';
import '../models/player.dart';
import '../models/ball.dart';
import '../models/frame.dart';
import '../services/export_service.dart';
import '../widgets/board_background_painter.dart';
import '../widgets/path_painter.dart';
import '../widgets/annotation_painter.dart';
import '../utils/path_engine.dart';

/// Screen for selecting and exporting frames with two tabs: images and video.
class ExportScreen extends StatefulWidget {
  final AnimationProject project;

  const ExportScreen({super.key, required this.project});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> with TickerProviderStateMixin {
  late final ExportService _exportService;
  late final TabController _tabController;
  final Set<int> _selectedFrames = {};
  bool _isLoading = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';
  final List<ui.Image?> _thumbnails = [];
  bool _useSpriteSheet = true;
  double _videoPlaybackSpeed = 1.0;
  final ExportVideoFormat _videoFormat = ExportVideoFormat.gif;
  final SpriteSheetLayout _spriteLayout = SpriteSheetLayout.vertical;

  // Video preview
  late AnimationController _videoPreviewController;
  int _currentVideoFrame = 0;

  @override
  void initState() {
    super.initState();
    _exportService = ExportService();
    _tabController = TabController(length: 2, vsync: this);
    _videoPreviewController = AnimationController(duration: const Duration(milliseconds: 1), vsync: this);
    _generateThumbnails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoPreviewController.dispose();
    for (final thumb in _thumbnails) {
      thumb?.dispose();
    }
    super.dispose();
  }

  Future<void> _generateThumbnails() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      const thumbSize = Size(200, 200);
      final settings = widget.project.settings ?? Settings();
      Settings.setScreenSize(thumbSize);

      debugPrint('=== EXPORT SCREEN: Generating ${widget.project.frames.length} thumbnails ===');

      for (var i = 0; i < widget.project.frames.length; i++) {
        if (!mounted) return;

        final image = await _renderFrameFull(i, thumbSize, settings);
        _thumbnails.add(image);
        debugPrint('Generated thumbnail for frame ${i + 1}/${widget.project.frames.length}');
      }

      debugPrint('=== EXPORT SCREEN: Thumbnail generation complete ===');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('ERROR generating thumbnails: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate thumbnails: $e')));
      }
    }
  }

  Future<ui.Image> _renderFrameFull(int frameIndex, Size size, Settings settings) async {
    final frame = widget.project.frames[frameIndex];
    final prev = frameIndex > 0 ? widget.project.frames[frameIndex - 1] : null;
    final twoAgo = frameIndex > 1 ? widget.project.frames[frameIndex - 2] : null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background
    BoardBackgroundPainter(
      screenSize: size,
      settings: settings,
      customElements: widget.project.customCourtElements,
      projectType: widget.project.projectType,
    ).paint(canvas, size);

    // Paths
    if (prev != null) {
      PathPainter(
        twoFramesAgo: twoAgo,
        previousFrame: prev,
        currentFrame: frame,
        screenSize: size,
        settings: settings,
      ).paint(canvas, size);
    }

    // Annotations
    AnnotationCanvasPainter(
      annotations: frame.annotations,
      tempAnnotations: null,
      erasingAnnotations: null,
      dragPreviewLine: null,
      settings: settings,
      screenSize: size,
      boardCenter: _boardCenter(size),
      strokeWidthCm: AppConstants.annotationStrokeWidthCm,
    ).paint(canvas, size);

    // Players and balls
    _paintPlayers(canvas, frame, size, settings);
    _paintBalls(canvas, frame, size, settings);

    final picture = recorder.endRecording();
    return picture.toImage(size.width.toInt(), size.height.toInt());
  }

  Offset _boardCenter(Size size) {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 140;
    final usableHeight = size.height - appBarHeight - timelineHeight;
    final cx = size.width / 2;
    final cy = appBarHeight + usableHeight / 2;
    return Offset(cx, cy);
  }

  void _paintPlayers(Canvas canvas, Frame frame, Size size, Settings settings) {
    final center = _boardCenter(size);
    for (final player in frame.players) {
      final screenPos =
          center +
          Offset(settings.cmToLogical(player.position.dx, size), settings.cmToLogical(player.position.dy, size));
      final scale = settings.objectScaleMultiplier;
      final baseR = settings.cmToLogical(AppConstants.playerRadiusCm, size);
      final r = (baseR * scale).clamp(14.0 * scale, 64.0 * scale);
      final border = math.max(2.0, r * 0.12);

      // Shadow
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(screenPos + const Offset(0, 2), r, shadow);

      // Body circle
      final bodyPaint = Paint()..color = player.color;
      canvas.drawCircle(screenPos, r, bodyPaint);

      // Border
      final borderPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = border
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(screenPos, r, borderPaint);

      // Label (only if provided)
      if (player.label != null && player.label!.isNotEmpty) {
        final isBright = player.color.computeLuminance() > 0.5;
        final textPainter = TextPainter(
          text: TextSpan(
            text: player.label,
            style: TextStyle(
              color: isBright ? Colors.black : Colors.white,
              fontSize: r * 0.8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          screenPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
  }

  void _paintBalls(Canvas canvas, Frame frame, Size size, Settings settings) {
    final center = _boardCenter(size);
    for (final ball in frame.balls) {
      final screenPos =
          center + Offset(settings.cmToLogical(ball.position.dx, size), settings.cmToLogical(ball.position.dy, size));
      final scale = settings.objectScaleMultiplier;
      final baseR = settings.cmToLogical(AppConstants.ballRadiusCm, size);
      final r = (baseR * scale).clamp(8.0 * scale, 32.0 * scale);

      // Shadow
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(screenPos + const Offset(0, 2), r, shadow);

      // Ball
      final ballPaint = Paint()..color = ball.color;
      canvas.drawCircle(screenPos, r, ballPaint);

      // Border
      final borderPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = r * 0.1
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(screenPos, r, borderPaint);
    }
  }

  Future<void> _exportImages() async {
    if (_selectedFrames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one frame')));
      return;
    }

    final sortedFrames = _selectedFrames.toList()..sort();
    final startFrame = sortedFrames.first;
    final endFrame = sortedFrames.last;

    debugPrint('=== EXPORT IMAGES: Exporting frames $sortedFrames ===');

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportStatus = 'Preparing export...';
    });

    try {
      void onProgress(double progress, String status) {
        if (mounted) {
          setState(() {
            _exportProgress = progress;
            _exportStatus = status;
          });
        }
        debugPrint('[EXPORT PROGRESS] $progress% - $status');
      }

      if (_useSpriteSheet) {
        await _exportService.exportFramesAsSpriteSheet(
          widget.project,
          layout: _spriteLayout,
          startFrame: startFrame,
          endFrame: endFrame,
          onProgress: onProgress,
        );
      } else {
        await _exportService.exportFramesAsPngSequence(
          widget.project,
          startFrame: startFrame,
          endFrame: endFrame,
          onProgress: onProgress,
        );
      }

      debugPrint('=== IMAGE EXPORT COMPLETE ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image export complete')));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('ERROR during image export: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportVideo() async {
    debugPrint('=== EXPORT VIDEO: Starting GIF export with playback speed $_videoPlaybackSpeed ===');

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportStatus = 'Preparing export...';
    });

    try {
      void onProgress(double progress, String status) {
        if (mounted) {
          setState(() {
            _exportProgress = progress;
            _exportStatus = status;
          });
        }
        debugPrint('[EXPORT PROGRESS] $progress% - $status');
      }

      await _exportService.exportVideo(
        widget.project,
        playbackSpeed: _videoPlaybackSpeed,
        format: ExportVideoFormat.gif,
        onProgress: onProgress,
      );

      debugPrint('=== VIDEO EXPORT COMPLETE ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video export complete')));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('ERROR during video export: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: 'Images'),
            Tab(icon: Icon(Icons.movie), text: 'Video'),
          ],
        ),
      ),
      body: _isExporting
          ? _buildExportProgress()
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabController, children: [_buildImagesTab(), _buildVideoTab()]),
    );
  }

  void _updateVideoPreview() {
    if (widget.project.frames.isEmpty) return;
    final totalDuration = widget.project.frames.fold<double>(
      0,
      (sum, frame) => sum + (frame.duration > 0 ? frame.duration : 0.5),
    );
    final adjustedDuration = totalDuration / _videoPlaybackSpeed;
    _videoPreviewController.duration = Duration(milliseconds: (adjustedDuration * 1000).toInt());
    _videoPreviewController.forward(from: 0);
  }

  Widget _buildExportProgress() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Exporting...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppConstants.paddingLarge),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: _exportProgress / 100, minHeight: 8),
            ),
            const SizedBox(height: AppConstants.padding),
            Text('${_exportProgress.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppConstants.padding),
            Text(
              _exportStatus,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesTab() {
    return Column(
      children: [
        // Frame selection controls
        Padding(
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected: ${_selectedFrames.length}/${widget.project.frames.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: AppConstants.padding,
                children: [
                  OutlinedButton(onPressed: _selectAll, child: const Text('Select All')),
                  OutlinedButton(onPressed: _clearSelection, child: const Text('Clear')),
                ],
              ),
            ],
          ),
        ),
        // Thumbnails grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppConstants.padding),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1,
              crossAxisSpacing: AppConstants.padding,
              mainAxisSpacing: AppConstants.padding,
            ),
            itemCount: widget.project.frames.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedFrames.contains(index);
              final thumbnail = _thumbnails.length > index ? _thumbnails[index] : null;

              return GestureDetector(
                onTap: () => _toggleFrame(index),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryBlue : Colors.grey[400]!,
                      width: isSelected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumbnail != null)
                        CustomPaint(painter: _ThumbnailPainter(thumbnail))
                      else
                        const Center(
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      // Frame number
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(2)),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // Selection checkmark
                      if (isSelected)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Export controls
        Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Export format toggle
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(label: Text('Sprite Sheet'), value: true),
                        ButtonSegment(label: Text('Individual Images'), value: false),
                      ],
                      selected: {_useSpriteSheet},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _useSpriteSheet = selected.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.padding),
              // Export button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedFrames.isEmpty ? null : _exportImages,
                  child: const Text('Export Selected Frames'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoTab() {
    return Column(
      children: [
        // Video preview area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: widget.project.frames.isEmpty
                  ? const Center(child: Text('No frames available'))
                  : AnimatedBuilder(
                      animation: _videoPreviewController,
                      builder: (context, child) {
                        if (widget.project.frames.isEmpty) {
                          return const Center(child: Text('No frames'));
                        }

                        // Calculate current frame index based on animation progress
                        final totalDuration = widget.project.frames.fold<double>(
                          0,
                          (sum, frame) => sum + (frame.duration > 0 ? frame.duration : 0.5),
                        );
                        final adjustedDuration = totalDuration / _videoPlaybackSpeed;
                        final currentTime = _videoPreviewController.value * adjustedDuration;

                        var accumulatedTime = 0.0;
                        var frameIndex = 0;

                        for (var i = 0; i < widget.project.frames.length; i++) {
                          final frameDuration =
                              (widget.project.frames[i].duration > 0 ? widget.project.frames[i].duration : 0.5) /
                              _videoPlaybackSpeed;
                          if (currentTime < accumulatedTime + frameDuration) {
                            frameIndex = i;
                            break;
                          }
                          accumulatedTime += frameDuration;
                        }

                        _currentVideoFrame = frameIndex;
                        final thumbnail = _thumbnails.length > frameIndex ? _thumbnails[frameIndex] : null;

                        return Column(
                          children: [
                            // Video preview
                            Expanded(
                              child: Center(
                                child: thumbnail != null
                                    ? AspectRatio(
                                        aspectRatio: 1,
                                        child: CustomPaint(painter: _ThumbnailPainter(thumbnail)),
                                      )
                                    : const CircularProgressIndicator(),
                              ),
                            ),
                            // Playback controls
                            Padding(
                              padding: const EdgeInsets.all(AppConstants.padding),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Play/pause button
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        if (_videoPreviewController.isAnimating) {
                                          _videoPreviewController.stop();
                                        } else {
                                          _updateVideoPreview();
                                        }
                                      },
                                      icon: Icon(_videoPreviewController.isAnimating ? Icons.pause : Icons.play_arrow),
                                      label: Text(_videoPreviewController.isAnimating ? 'Pause' : 'Play'),
                                    ),
                                  ),
                                  const SizedBox(height: AppConstants.padding),
                                  // Progress bar
                                  LinearProgressIndicator(value: _videoPreviewController.value),
                                  const SizedBox(height: AppConstants.padding),
                                  // Frame info
                                  Text(
                                    'Frame ${_currentVideoFrame + 1}/${widget.project.frames.length}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
        // Video export controls
        Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Playback speed slider
              ListTile(
                title: const Text('Playback Speed'),
                subtitle: Slider(
                  value: _videoPlaybackSpeed,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  label: '${_videoPlaybackSpeed.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    setState(() {
                      _videoPlaybackSpeed = value;
                    });
                    _updateVideoPreview();
                  },
                ),
                trailing: Text(
                  '${_videoPlaybackSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: AppConstants.padding),
              // Format selection (GIF only for now)
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(label: Text('GIF'), value: 'gif'),
                        ButtonSegment(label: Text('MP4'), value: 'mp4', enabled: false),
                      ],
                      selected: {'gif'},
                      onSelectionChanged: (selected) {
                        // MP4 not implemented yet
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              // Export button
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _exportVideo, child: const Text('Export Video')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleFrame(int index) {
    setState(() {
      if (_selectedFrames.contains(index)) {
        _selectedFrames.remove(index);
      } else {
        _selectedFrames.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedFrames.clear();
      _selectedFrames.addAll(List.generate(widget.project.frames.length, (i) => i));
    });
  }

  void _clearSelection() {
    setState(() => _selectedFrames.clear());
  }
}

/// Custom painter for rendering thumbnails.
class _ThumbnailPainter extends CustomPainter {
  final ui.Image thumbnail;

  _ThumbnailPainter(this.thumbnail);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      thumbnail,
      Rect.fromLTWH(0, 0, thumbnail.width.toDouble(), thumbnail.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) => false;
}

/// Painter for live video preview with interpolated playback (60fps-like).
class _VideoPreviewPainter extends CustomPainter {
  final AnimationProject project;
  final Settings settings;
  final int baseIndex; // Interpolate between baseIndex and baseIndex+1
  final double t; // 0..1 within segment

  _VideoPreviewPainter({
    required this.project,
    required this.settings,
    required this.baseIndex,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (project.frames.length < 2) return;
    // Ensure painters scale correctly to the preview size
    Settings.setScreenSize(size);

    final twoAgo = baseIndex > 0 ? project.frames[baseIndex - 1] : null;
    final prev = project.frames[baseIndex];
    final next = project.frames[(baseIndex + 1).clamp(0, project.frames.length - 1)];

    // Background
    BoardBackgroundPainter(
      screenSize: size,
      settings: settings,
      customElements: project.customCourtElements,
      projectType: project.projectType,
    ).paint(canvas, size);

    // Paths (prev -> next)
    PathPainter(
      twoFramesAgo: twoAgo,
      previousFrame: prev,
      currentFrame: next,
      screenSize: size,
      settings: settings,
    ).paint(canvas, size);

    // Interpolated frame
    final interp = _interpolateFrame(prev, next, t);

    // Annotations from target (next)
    AnnotationCanvasPainter(
      annotations: next.annotations,
      tempAnnotations: null,
      erasingAnnotations: null,
      dragPreviewLine: null,
      settings: settings,
      screenSize: size,
      boardCenter: _boardCenter(size),
      strokeWidthCm: AppConstants.annotationStrokeWidthCm,
    ).paint(canvas, size);

    _paintPlayers(canvas, interp, size, settings);
    _paintBalls(canvas, interp, size, settings);
  }

  // Local copies of helpers to avoid depending on outer State
  Offset _boardCenter(Size size) {
    const double appBarHeight = kToolbarHeight;
    const double timelineHeight = 140;
    final usableHeight = size.height - appBarHeight - timelineHeight;
    final cx = size.width / 2;
    final cy = appBarHeight + usableHeight / 2;
    return Offset(cx, cy);
  }

  Frame _interpolateFrame(Frame fA, Frame fB, double t) {
    Offset pathOrLinear(Offset start, Offset end, List<Offset> pathPoints) {
      if (pathPoints.isNotEmpty) {
        final engine = PathEngine.fromTwoQuadratics(start: start, control: pathPoints.first, end: end, resolution: 400);
        return engine.sample(t);
      }
      return Offset.lerp(start, end, t)!;
    }

    final players = <Player>[];
    for (final pB in fB.players) {
      final pA = fA.getPlayerById(pB.id);
      if (pA == null) {
        players.add(pB.copy());
      } else {
        final pos = pathOrLinear(pA.position, pB.position, pB.pathPoints);
        final rot = _interpolateRotation(pA.rotation, pB.rotation, t);
        players.add(Player(position: pos, rotation: rot, color: pB.color, id: pB.id, label: pB.label));
      }
    }

    final balls = <Ball>[];
    for (final bB in fB.balls) {
      final bA = fA.getBallById(bB.id);
      if (bA == null) {
        balls.add(bB.copy());
      } else {
        final pos = pathOrLinear(bA.position, bB.position, bB.pathPoints);
        balls.add(Ball(position: pos, hitT: bB.hitT, isSet: bB.isSet, color: bB.color, id: bB.id));
      }
    }

    return Frame(players: players, balls: balls, duration: fB.duration, annotations: fB.annotations);
  }

  double _interpolateRotation(double a, double b, double t) {
    double delta = (b - a) % (2 * math.pi);
    if (delta > math.pi) delta -= 2 * math.pi;
    return a + delta * t;
  }

  void _paintPlayers(Canvas canvas, Frame frame, Size size, Settings settings) {
    final center = _boardCenter(size);
    for (final player in frame.players) {
      final screenPos = center + Offset(settings.cmToLogical(player.position.dx, size), settings.cmToLogical(player.position.dy, size));
      final scale = settings.objectScaleMultiplier;
      final baseR = settings.cmToLogical(AppConstants.playerRadiusCm, size);
      final r = (baseR * scale).clamp(14.0 * scale, 64.0 * scale);
      final border = math.max(2.0, r * 0.12);

      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(screenPos + const Offset(0, 2), r, shadow);

      final bodyPaint = Paint()..color = player.color;
      canvas.drawCircle(screenPos, r, bodyPaint);

      final borderPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = border
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(screenPos, r, borderPaint);

      if (player.label != null && player.label!.isNotEmpty) {
        final isBright = player.color.computeLuminance() > 0.5;
        final tp = TextPainter(
          text: TextSpan(
            text: player.label,
            style: TextStyle(
              color: isBright ? Colors.black : Colors.white,
              fontSize: r * 0.8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, screenPos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _paintBalls(Canvas canvas, Frame frame, Size size, Settings settings) {
    final center = _boardCenter(size);
    for (final ball in frame.balls) {
      final screenPos = center + Offset(settings.cmToLogical(ball.position.dx, size), settings.cmToLogical(ball.position.dy, size));
      final scale = settings.objectScaleMultiplier;
      final baseR = settings.cmToLogical(AppConstants.ballRadiusCm, size);
      final r = (baseR * scale).clamp(8.0 * scale, 32.0 * scale);

      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(screenPos + const Offset(0, 2), r, shadow);

      final ballPaint = Paint()..color = ball.color;
      canvas.drawCircle(screenPos, r, ballPaint);

      final borderPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = r * 0.1
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(screenPos, r, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VideoPreviewPainter oldDelegate) {
    return oldDelegate.baseIndex != baseIndex || (oldDelegate.t - t).abs() > 0.0001;
  }
}
