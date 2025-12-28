import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/animation_project.dart';
import 'web_download.dart' if (dart.library.html) 'web_download_web.dart' as web_download;

class ProjectIO {
  static Future<File> exportToJson(AnimationProject project) async {
    final map = project.toMap();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    final directory = await getApplicationDocumentsDirectory();
    final safeName = project.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final file = File('${directory.path}/$safeName.json');
    return file.writeAsString(jsonStr);
  }

  static Future<AnimationProject> importFromJsonFile(File file) async {
    final contents = await file.readAsString();
    final map = json.decode(contents) as Map<String, dynamic>;
    return AnimationProjectMap.fromMap(map);
  }

  /// Export project to JSON with user-selected save location
  /// Handles both native and web platforms
  static Future<File?> exportToJsonWithPicker(AnimationProject project) async {
    final map = project.toMap();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    final safeName = project.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    
    // Convert JSON string to bytes for Android/iOS compatibility
    final bytes = utf8.encode(jsonStr);
    
    // Handle web platform separately
    if (kIsWeb) {
      _downloadFileWeb('$safeName.json', jsonStr);
      return null; // Web downloads don't return a File object
    }
    
    // Let user choose save location on native platforms
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Project',
      fileName: '$safeName.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );

    if (outputPath == null) {
      // User cancelled
      return null;
    }

    // On desktop platforms, we still need to write the file
    // On mobile, the bytes parameter handles the writing
    final file = File(outputPath);
    if (!await file.exists()) {
      await file.writeAsBytes(bytes);
    }
    return file;
  }

  /// Download file on web platform
  static void _downloadFileWeb(String filename, String content) {
    if (kIsWeb) {
      // Use a data URI for web instead of Blob
      final bytes = utf8.encode(content);
      final base64 = base64Encode(bytes);
      final dataUrl = 'data:application/json;base64,$base64';
      
      // Call the conditional web-specific implementation
      web_download.performWebDownload(dataUrl, filename);
    }
  }
}


