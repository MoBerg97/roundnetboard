import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';

import '../models/animation_project.dart';
import '../models/player.dart';
import '../models/ball.dart';
import '../utils/export_import.dart';
import '../models/frame.dart';
import '../models/settings.dart';
import '../widgets/board_background_painter.dart';
import '../widgets/path_painter.dart';
import '../widgets/annotation_painter.dart';
import '../config/app_constants.dart';
import '../utils/path_engine.dart';
// Use web-specific download implementation on web builds
import '../utils/web_download.dart' if (dart.library.html) '../utils/web_download_web.dart' as web_download;

/// Supported video export formats.
enum ExportVideoFormat { mp4, gif }

/// Layout options for sprite sheet exports.
enum SpriteSheetLayout { horizontal, vertical }

/// Service for handling project export and import operations.
///
/// Manages file I/O, format conversion, and user file selection
/// for sharing and backing up animation projects.
class ExportService {
  /// Export a project to JSON format with file picker dialog.
  ///
  /// Opens a save file dialog for the user to choose location.
  /// Returns the file path if successful, null if cancelled.
  /// Throws exception on errors.
  Future<String?> exportToJson(AnimationProject project) async {
    try {
      final file = await ProjectIO.exportToJsonWithPicker(project);
      return file?.path;
    } catch (e) {
      throw Exception('Failed to export project: $e');
    }
  }

  /// Import a project from a JSON file with file picker dialog.
  ///
  /// Opens a file picker for the user to select a JSON file.
  /// Returns the imported project if successful, null if cancelled.
  /// Throws exception on invalid files or parse errors.
  Future<AnimationProject?> importFromJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);

      if (result == null || result.files.single.path == null) {
        return null; // User cancelled
      }

      final file = File(result.files.single.path!);
      final project = await ProjectIO.importFromJsonFile(file);
      return project;
    } catch (e) {
      throw Exception('Failed to import project: $e');
    }
  }

  /// Create a temporary file for sharing.
  ///
  /// Exports project to JSON and saves to temporary directory.
  /// Returns the temporary file path.
  /// Caller is responsible for cleanup.
  Future<String> createTemporaryExportFile(AnimationProject project) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = '${_sanitizeFileName(project.name)}.json';
      final filePath = '${tempDir.path}/$fileName';

      // Export to JSON
      final map = project.toMap();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(map);

      // Write to temporary file
      final file = File(filePath);
      await file.writeAsString(jsonStr);

      return filePath;
    } catch (e) {
      throw Exception('Failed to create temporary export file: $e');
    }
  }

  /// Delete a temporary export file.
  ///
  /// Safely removes a file if it exists.
  /// Logs errors but doesn't throw.
  Future<void> deleteTemporaryFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log but don't throw - file cleanup is not critical
      debugPrint('Warning: Failed to delete temporary file: $e');
    }
  }

  /// Validate if a file is a valid project JSON.
  ///
  /// Checks file extension and attempts to parse.
  /// Returns true if valid, false otherwise.
  Future<bool> isValidProjectFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      if (!filePath.endsWith('.json')) return false;

      // Try to parse the file
      await ProjectIO.importFromJsonFile(file);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sanitize a filename by removing invalid characters.
  ///
  /// Removes or replaces characters that are invalid in filenames.
  String _sanitizeFileName(String name) {
    // Replace invalid characters with underscores
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  /// Export the animation as a video using the selected format.
  ///
  /// The playbackSpeed should reflect the last selected speed by the user.
  Future<void> exportVideo(
    AnimationProject project, {
    required double playbackSpeed,
    required ExportVideoFormat format,
    Function(double progress, String status)? onProgress,
  }) async {
    final frames = project.frames;
    if (frames.isEmpty) return;

    debugPrint(
      '[EXPORT_VIDEO] Starting export: format=$format, frameCount=${frames.length}, playbackSpeed=$playbackSpeed',
    );

    // Build exact playback using 60 FPS ticks with interpolation between frames
    const fps = 60.0;
    final settings = project.settings ?? Settings();
    Settings.setScreenSize(const Size(1080, 1080));

    // Compute total ticks for progress accounting
    int totalTicks = 0;
    for (var i = 0; i < frames.length - 1; i++) {
      final dur = frames[i + 1].duration > 0 ? frames[i + 1].duration : 0.5;
      totalTicks += (dur * fps / playbackSpeed).ceil();
    }

    final rendered = <img.Image>[];
    int tickCounter = 0;
    onProgress?.call(5, 'Rendering video 0/$totalTicks...');
    debugPrint('[EXPORT_VIDEO] Rendering with interpolation at ${fps}fps, total ticks=$totalTicks');

    for (var i = 0; i < frames.length - 1; i++) {
      final fA = frames[i];
      final fB = frames[i + 1];
      final segDur = fB.duration > 0 ? fB.duration : 0.5;
      final ticks = (segDur * fps / playbackSpeed).ceil().clamp(1, 1000000);
      for (var tIdx = 0; tIdx < ticks; tIdx++) {
        final localT = ticks == 1 ? 1.0 : (tIdx / (ticks - 1)).clamp(0.0, 1.0);
        final uiImage = await _renderInterpolatedImage(
          project: project,
          baseIndex: i,
          t: localT,
          settings: settings,
          targetSize: const Size(1080, 1080),
        );
        final png = await _uiImageToPng(uiImage);
        final decoded = img.decodePng(png);
        if (decoded != null) {
          rendered.add(decoded);
        }
        tickCounter++;
        if (tickCounter % 3 == 0) {
          final p = (5.0 + (tickCounter / totalTicks * 75.0)).clamp(5.0, 80.0) as double;
          onProgress?.call(p, 'Rendering video $tickCounter/$totalTicks...');
        }
      }
    }

    if (format == ExportVideoFormat.gif) {
      // Assemble GIF with uniform frame duration at target FPS
      final anim = img.Image(width: rendered.first.width, height: rendered.first.height)
        ..frameType = img.FrameType.animation
        ..loopCount = 0;

      final perFrameMs = (1000.0 / fps).round();
      for (var i = 0; i < rendered.length; i++) {
        final frameCopy = img.Image.from(rendered[i], noAnimation: true)..frameDuration = perFrameMs;
        if (i == 0) {
          img.compositeImage(anim, frameCopy, dstX: 0, dstY: 0);
          anim.frameDuration = perFrameMs;
        } else {
          anim.addFrame(frameCopy);
        }
      }

      onProgress?.call(90, 'Encoding GIF...');
      debugPrint('[EXPORT_VIDEO] Encoding GIF animation with ${anim.frames.length} frames...');
      final gifBytes = Uint8List.fromList(img.encodeGif(anim));
      debugPrint('[EXPORT_VIDEO] GIF encoded: ${gifBytes.length} bytes');
      onProgress?.call(95, 'Saving file...');
      await _saveBytes(
        bytes: gifBytes,
        suggestedName: '${_sanitizeFileName(project.name)}.gif',
        mimeType: 'image/gif',
        extensions: ['gif'],
      );
      onProgress?.call(100, 'Export complete');
      debugPrint('[EXPORT_VIDEO] Video export complete');
      return;
    }

    // MP4 export placeholder
    if (format == ExportVideoFormat.mp4) {
      debugPrint('[EXPORT_VIDEO] MP4 format not implemented');
      throw UnimplementedError(
        'MP4 export requires platform-specific video encoding. '
        'Please use GIF format instead, which provides good quality and cross-platform support.',
      );
    }
  }

  /// Render a single image at an interpolated time t (0..1) between baseIndex and baseIndex+1.
  Future<ui.Image> _renderInterpolatedImage({
    required AnimationProject project,
    required int baseIndex,
    required double t,
    required Settings settings,
    Size targetSize = const Size(1080, 1080),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final frames = project.frames;
    final twoAgo = baseIndex > 0 ? frames[baseIndex - 1] : null;
    final prev = frames[baseIndex];
    final next = frames[baseIndex + 1];

    // Background
    BoardBackgroundPainter(
      screenSize: targetSize,
      settings: settings,
      customElements: project.customCourtElements,
      projectType: project.projectType,
    ).paint(canvas, targetSize);

    // Paths between prev and next
    PathPainter(
      twoFramesAgo: twoAgo,
      previousFrame: prev,
      currentFrame: next,
      screenSize: targetSize,
      settings: settings,
    ).paint(canvas, targetSize);

    // Interpolated synthetic frame (objects), annotations from next
    final interp = _interpolateFrame(prev, next, t);

    AnnotationCanvasPainter(
      annotations: next.annotations,
      tempAnnotations: null,
      erasingAnnotations: null,
      dragPreviewLine: null,
      settings: settings,
      screenSize: targetSize,
      boardCenter: _boardCenter(targetSize),
      strokeWidthCm: AppConstants.annotationStrokeWidthCm,
    ).paint(canvas, targetSize);

    _paintPlayers(canvas, interp, targetSize, settings);
    _paintBalls(canvas, interp, targetSize, settings);

    final picture = recorder.endRecording();
    return picture.toImage(targetSize.width.toInt(), targetSize.height.toInt());
  }

  /// Build an interpolated frame similar to BoardScreen._animatedFrame
  Frame _interpolateFrame(Frame fA, Frame fB, double t) {
    Offset pathOrLinear(String id, Offset start, Offset end, List<Offset> pathPoints) {
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
        final pos = pathOrLinear(pB.id, pA.position, pB.position, pB.pathPoints);
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
        final pos = pathOrLinear(bB.id, bA.position, bB.position, bB.pathPoints);
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

  /// Export each frame as individual PNG images.
  ///
  /// If [startFrame] and [endFrame] are provided, only exports frames in that range (inclusive).
  Future<void> exportFramesAsPngSequence(
    AnimationProject project, {
    int startFrame = 0,
    int? endFrame,
    Function(double progress, String status)? onProgress,
  }) async {
    if (project.frames.isEmpty) return;

    final end = endFrame ?? project.frames.length - 1;
    final start = startFrame.clamp(0, project.frames.length - 1);
    final frameCount = end - start + 1;

    debugPrint('[EXPORT_FRAMES] Starting PNG frame export: frames $start-$end ($frameCount frames)');

    final rendered = <Uint8List>[];
    for (var i = start; i <= end && i < project.frames.length; i++) {
      onProgress?.call(((i - start) / frameCount * 80).clamp(0, 80), 'Rendering frame ${i - start + 1}/$frameCount...');

      final settings = project.settings ?? Settings();
      Settings.setScreenSize(const Size(1080, 1080));
      final frameImage = await _renderFrame(
        project: project,
        frameIndex: i,
        settings: settings,
        targetSize: const Size(1080, 1080),
      );
      final pngBytes = await _uiImageToPng(frameImage);
      rendered.add(pngBytes);
      debugPrint('[EXPORT_FRAMES] Frame ${i + 1} rendered: ${pngBytes.length} bytes');
    }

    if (rendered.isEmpty) return;

    final safeName = _sanitizeFileName(project.name);

    if (kIsWeb) {
      // Package frames into a zip for single download on web
      onProgress?.call(85, 'Packaging frames into ZIP...');
      debugPrint('[EXPORT_FRAMES] Web platform: packaging ${rendered.length} frames into ZIP');
      final archive = Archive();
      for (var i = 0; i < rendered.length; i++) {
        final name = '${safeName}_frame_${(i + 1).toString().padLeft(3, '0')}.png';
        archive.addFile(ArchiveFile(name, rendered[i].length, rendered[i]));
      }
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      debugPrint('[EXPORT_FRAMES] ZIP created: ${zipBytes.length} bytes');
      onProgress?.call(95, 'Downloading...');
      final dataUrl = _bytesToDataUrl(zipBytes, 'application/zip');
      web_download.performWebDownload(dataUrl, '${safeName}_frames.zip');
      onProgress?.call(100, 'Download started');
      return;
    }

    onProgress?.call(85, 'Selecting export folder...');
    final dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select export folder');
    if (dirPath == null) {
      debugPrint('[EXPORT_FRAMES] User cancelled folder selection');
      return; // user cancelled
    }

    debugPrint('[EXPORT_FRAMES] Native platform: saving ${rendered.length} frames to $dirPath');
    for (var i = 0; i < rendered.length; i++) {
      onProgress?.call(85 + (i / rendered.length * 15).clamp(0, 15), 'Saving frame ${i + 1}/${rendered.length}...');

      final name = '${safeName}_frame_${(i + 1).toString().padLeft(3, '0')}.png';
      final file = File('$dirPath/$name');
      await file.writeAsBytes(rendered[i]);
      debugPrint('[EXPORT_FRAMES] Saved frame ${i + 1}/${rendered.length}');
    }
    debugPrint('[EXPORT_FRAMES] Frame export complete: saved to $dirPath');
    onProgress?.call(100, 'Export complete');
  }

  /// Export all frames stitched into a single sprite sheet image.
  ///
  /// If [startFrame] and [endFrame] are provided, only includes frames in that range (inclusive).
  Future<void> exportFramesAsSpriteSheet(
    AnimationProject project, {
    SpriteSheetLayout layout = SpriteSheetLayout.vertical,
    int startFrame = 0,
    int? endFrame,
    Function(double progress, String status)? onProgress,
  }) async {
    if (project.frames.isEmpty) return;

    final end = endFrame ?? project.frames.length - 1;
    final start = startFrame.clamp(0, project.frames.length - 1);
    final frameCount = end - start + 1;

    debugPrint(
      '[EXPORT_SPRITESHEET] Starting sprite sheet export: frames $start-$end ($frameCount frames), layout=${layout.name}',
    );

    final rendered = <Uint8List>[];
    final settings = project.settings ?? Settings();
    Settings.setScreenSize(const Size(1080, 1080));

    for (var i = start; i <= end && i < project.frames.length; i++) {
      onProgress?.call(((i - start) / frameCount * 50).clamp(0, 50), 'Rendering frame ${i - start + 1}/$frameCount...');

      final frameImage = await _renderFrame(
        project: project,
        frameIndex: i,
        settings: settings,
        targetSize: const Size(1080, 1080),
      );
      final pngBytes = await _uiImageToPng(frameImage);
      rendered.add(pngBytes);
      debugPrint('[EXPORT_SPRITESHEET] Frame ${i + 1} rendered: ${pngBytes.length} bytes');
    }

    if (rendered.isEmpty) return;

    final decoded = rendered.map((bytes) => img.decodePng(bytes)).whereType<img.Image>().toList();

    if (decoded.isEmpty) return;

    onProgress?.call(60, 'Adding borders to frames...');
    debugPrint('[EXPORT_SPRITESHEET] Decoded ${decoded.length} PNG images');

    const borderWidth = 2;
    final isVertical = layout == SpriteSheetLayout.vertical;

    // Add borders to each frame
    final withBorders = decoded.map((f) {
      final bordered = img.Image(width: f.width + 2 * borderWidth, height: f.height + 2 * borderWidth);
      // Draw border
      for (int x = 0; x < bordered.width; x++) {
        for (int y = 0; y < bordered.height; y++) {
          if (y < borderWidth ||
              y >= bordered.height - borderWidth ||
              x < borderWidth ||
              x >= bordered.width - borderWidth) {
            bordered.setPixelRgba(x, y, 0, 0, 0, 255); // Black
          }
        }
      }
      // Composite frame in center
      img.compositeImage(bordered, f, dstX: borderWidth, dstY: borderWidth);
      return bordered;
    }).toList();

    final sheetWidth = isVertical
        ? withBorders.map((f) => f.width).reduce(math.max)
        : withBorders.map((f) => f.width).fold<int>(0, (a, b) => a + b);
    final sheetHeight = isVertical
        ? withBorders.map((f) => f.height).fold<int>(0, (a, b) => a + b)
        : withBorders.map((f) => f.height).reduce(math.max);

    onProgress?.call(70, 'Compositing frames...');
    final sheet = img.Image(width: sheetWidth, height: sheetHeight);
    debugPrint('[EXPORT_SPRITESHEET] Creating sprite sheet: $sheetWidth x $sheetHeight pixels');
    var offsetX = 0;
    var offsetY = 0;

    for (var i = 0; i < withBorders.length; i++) {
      final frame = withBorders[i];
      img.compositeImage(sheet, frame, dstX: offsetX, dstY: offsetY);

      // Draw frame number in top-left corner of frame
      _drawFrameNumber(sheet, i + 1, offsetX + borderWidth + 4, offsetY + borderWidth + 4);

      if (isVertical) {
        offsetY += frame.height;
      } else {
        offsetX += frame.width;
      }
    }

    onProgress?.call(80, 'Encoding PNG...');
    final pngBytes = Uint8List.fromList(img.encodePng(sheet));
    debugPrint('[EXPORT_SPRITESHEET] PNG encoded: ${pngBytes.length} bytes, $sheetWidth x $sheetHeight pixels');

    onProgress?.call(90, 'Saving file...');
    await _saveBytes(
      bytes: pngBytes,
      suggestedName: '${_sanitizeFileName(project.name)}_sheet.png',
      mimeType: 'image/png',
      extensions: ['png'],
    );
    onProgress?.call(100, 'Export complete');
    debugPrint('[EXPORT_SPRITESHEET] Sprite sheet export complete');
  }

  void _drawFrameNumber(img.Image image, int frameNum, int x, int y) {
    final text = frameNum.toString();

    // Draw white text with black outline for visibility
    for (int py = -1; py <= 1; py++) {
      for (int px = -1; px <= 1; px++) {
        _drawText(image, text, x + px, y + py, 0, 0, 0, 255); // Black outline
      }
    }
    _drawText(image, text, x, y, 255, 255, 255, 255); // White text
  }

  void _drawText(img.Image image, String text, int startX, int startY, int r, int g, int b, int a) {
    // Very simple single-pixel font for small labels
    // '0' = 0x30, '1' = 0x31, etc.
    int x = startX;

    for (final char in text.codeUnits) {
      _drawChar(image, char, x, startY, r, g, b, a, 2); // pixel size = 2
      x += 10; // 5 chars * 2 pixel size
    }
  }

  void _drawChar(img.Image image, int charCode, int x, int y, int r, int g, int b, int a, int size) {
    // Simple dot pattern for digits
    final patterns = {
      48: [
        [0, 0, 1, 0, 0],
        [0, 1, 0, 1, 0],
        [1, 0, 0, 0, 1],
        [1, 0, 0, 0, 1],
        [0, 1, 0, 1, 0],
        [0, 0, 1, 0, 0],
      ], // 0
      49: [
        [0, 0, 1, 0, 0],
        [0, 1, 1, 0, 0],
        [0, 0, 1, 0, 0],
        [0, 0, 1, 0, 0],
        [0, 0, 1, 0, 0],
        [1, 1, 1, 1, 1],
      ], // 1
      50: [
        [0, 1, 1, 1, 0],
        [1, 0, 0, 0, 1],
        [0, 0, 0, 1, 0],
        [0, 0, 1, 0, 0],
        [0, 1, 0, 0, 0],
        [1, 1, 1, 1, 1],
      ], // 2
      51: [
        [1, 1, 1, 1, 0],
        [0, 0, 0, 0, 1],
        [1, 1, 1, 1, 0],
        [0, 0, 0, 0, 1],
        [0, 0, 0, 0, 1],
        [1, 1, 1, 1, 0],
      ], // 3
      52: [
        [1, 0, 0, 0, 1],
        [1, 0, 0, 0, 1],
        [1, 0, 0, 1, 1],
        [1, 1, 1, 1, 1],
        [0, 0, 0, 1, 0],
        [0, 0, 0, 1, 0],
      ], // 4
      53: [
        [1, 1, 1, 1, 1],
        [1, 0, 0, 0, 0],
        [1, 1, 1, 1, 0],
        [0, 0, 0, 0, 1],
        [1, 0, 0, 0, 1],
        [0, 1, 1, 1, 0],
      ], // 5
      54: [
        [0, 0, 1, 1, 0],
        [0, 1, 0, 0, 0],
        [1, 0, 0, 0, 0],
        [1, 1, 1, 1, 0],
        [1, 0, 0, 0, 1],
        [0, 1, 1, 1, 0],
      ], // 6
      55: [
        [1, 1, 1, 1, 1],
        [0, 0, 0, 0, 1],
        [0, 0, 0, 1, 0],
        [0, 0, 1, 0, 0],
        [0, 1, 0, 0, 0],
        [1, 0, 0, 0, 0],
      ], // 7
      56: [
        [0, 1, 1, 1, 0],
        [1, 0, 0, 0, 1],
        [0, 1, 1, 1, 0],
        [1, 0, 0, 0, 1],
        [1, 0, 0, 0, 1],
        [0, 1, 1, 1, 0],
      ], // 8
      57: [
        [0, 1, 1, 1, 0],
        [1, 0, 0, 0, 1],
        [0, 1, 1, 1, 1],
        [0, 0, 0, 0, 1],
        [0, 0, 0, 0, 1],
        [0, 1, 1, 1, 0],
      ], // 9
    };

    final pattern = patterns[charCode];
    if (pattern == null) return;

    for (int row = 0; row < pattern.length; row++) {
      final cols = pattern[row];
      for (int col = 0; col < cols.length; col++) {
        if (cols[col] == 1) {
          for (int dy = 0; dy < size; dy++) {
            for (int dx = 0; dx < size; dx++) {
              final px = x + col * size + dx;
              final py = y + row * size + dy;
              if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
                image.setPixelRgba(px, py, r, g, b, a);
              }
            }
          }
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Rendering Helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Render all frames to PNG byte lists using the board painters.
  Future<List<Uint8List>> _renderAllFrames(AnimationProject project, {Size targetSize = const Size(1080, 1080)}) async {
    final settings = project.settings ?? Settings();
    Settings.setScreenSize(targetSize);
    final result = <Uint8List>[];
    for (var i = 0; i < project.frames.length; i++) {
      final uiImage = await _renderFrame(project: project, frameIndex: i, settings: settings, targetSize: targetSize);
      final bytes = await _uiImageToPng(uiImage);
      result.add(bytes);
    }
    return result;
  }

  Future<ui.Image> _renderFrame({
    required AnimationProject project,
    required int frameIndex,
    required Settings settings,
    Size targetSize = const Size(1080, 1080),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final frames = project.frames;
    final current = frames[frameIndex];
    final prev = frameIndex > 0 ? frames[frameIndex - 1] : null;
    final twoAgo = frameIndex > 1 ? frames[frameIndex - 2] : null;

    // Background
    BoardBackgroundPainter(
      screenSize: targetSize,
      settings: settings,
      customElements: project.customCourtElements,
      projectType: project.projectType,
    ).paint(canvas, targetSize);

    // Paths (only when we have a previous frame)
    if (prev != null) {
      PathPainter(
        twoFramesAgo: twoAgo,
        previousFrame: prev,
        currentFrame: current,
        screenSize: targetSize,
        settings: settings,
      ).paint(canvas, targetSize);
    }

    // Annotations (below objects by default)
    AnnotationCanvasPainter(
      annotations: current.annotations,
      tempAnnotations: null,
      erasingAnnotations: null,
      dragPreviewLine: null,
      settings: settings,
      screenSize: targetSize,
      boardCenter: _boardCenter(targetSize),
      strokeWidthCm: AppConstants.annotationStrokeWidthCm,
    ).paint(canvas, targetSize);

    // Players and balls
    _paintPlayers(canvas, current, targetSize, settings);
    _paintBalls(canvas, current, targetSize, settings);

    final picture = recorder.endRecording();
    return picture.toImage(targetSize.width.toInt(), targetSize.height.toInt());
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

      // Body
      final body = Paint()..color = player.color;
      canvas.drawCircle(screenPos, r, body);

      // Border
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = border;
      canvas.drawCircle(screenPos, r, borderPaint);

      // Direction indicator
      final dirPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = math.max(2.0, r * 0.08)
        ..strokeCap = StrokeCap.round;
      final len = r * 0.7;
      final end = Offset(
        screenPos.dx + len * math.sin(player.rotation),
        screenPos.dy - len * math.cos(player.rotation),
      );
      canvas.drawLine(screenPos, end, dirPaint);

      // Label
      if (player.label != null && player.label!.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: player.label,
            style: TextStyle(
              color: _isColorBright(player.color) ? Colors.black : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: r * 0.9,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 0))],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelOffset = screenPos - Offset(textPainter.width / 2, textPainter.height / 2);
        canvas.save();
        canvas.translate(screenPos.dx, screenPos.dy);
        canvas.rotate(-player.rotation);
        canvas.translate(-screenPos.dx, -screenPos.dy);
        textPainter.paint(canvas, labelOffset);
        canvas.restore();
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
      final r = (baseR * scale).clamp(9.0 * scale, 48.0 * scale);
      final border = math.max(2.0, r * 0.14);

      // Shadow
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(screenPos + const Offset(0, 2), r, shadow);

      // Body
      final body = Paint()..color = ball.color;
      canvas.drawCircle(screenPos, r, body);

      // Border
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = border;
      canvas.drawCircle(screenPos, r, borderPaint);

      // Hit marker (if hitT present)
      if (ball.hitT != null) {
        final hitPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        canvas.drawCircle(screenPos, r * 0.3, hitPaint);

        final hitBorder = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(screenPos, r * 0.3, hitBorder);
      }

      // Set marker (if isSet true)
      if (ball.isSet == true) {
        final arcPaint = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        final rect = Rect.fromCircle(center: screenPos, radius: r * 0.5);
        canvas.drawArc(rect, -1.57, 3.14, false, arcPaint);

        final endpointPaint = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.fill;
        canvas.drawCircle(screenPos + Offset(r * 0.5, 0), 2, endpointPaint);
      }
    }
  }

  bool _isColorBright(Color c) => c.computeLuminance() > 0.5;

  Future<Uint8List> _uiImageToPng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to encode image');
    return byteData.buffer.asUint8List();
  }

  Future<void> _saveBytes({
    required Uint8List bytes,
    required String suggestedName,
    required String mimeType,
    required List<String> extensions,
  }) async {
    if (kIsWeb) {
      final dataUrl = _bytesToDataUrl(bytes, mimeType);
      web_download.performWebDownload(dataUrl, suggestedName);
      return;
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save export',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: extensions,
      bytes: bytes,
    );

    if (outputPath == null) return; // cancelled

    final file = File(outputPath);
    if (!await file.exists()) {
      await file.writeAsBytes(bytes);
    }
  }

  String _bytesToDataUrl(Uint8List bytes, String mimeType) {
    final base64Str = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64Str';
  }

  /// Get the default export directory for the platform.
  ///
  /// Returns Downloads folder on most platforms.
  Future<Directory?> getDefaultExportDirectory() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, use app documents directory
        return await getApplicationDocumentsDirectory();
      } else {
        // On desktop, try to use Downloads folder
        return await getDownloadsDirectory();
      }
    } catch (e) {
      // Fallback to temp directory if downloads unavailable
      return await getTemporaryDirectory();
    }
  }

  /// Get file size in human-readable format.
  ///
  /// Converts bytes to KB, MB, etc.
  String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
