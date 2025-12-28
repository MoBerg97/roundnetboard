import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../models/animation_project.dart';
import 'export_import.dart';
import 'web_download.dart' if (dart.library.html) 'web_download_web.dart' as web_download;

/// Helper class for sharing project files
class ShareHelper {
  /// Share a project as a JSON file via the system share sheet
  /// On web, triggers a file download instead of using the share sheet
  static Future<void> shareProject(AnimationProject project) async {
    try {
      if (kIsWeb) {
        // On web, download the file instead of using share sheet
        _shareProjectWeb(project);
      } else {
        // On native platforms, export and share
        final file = await ProjectIO.exportToJson(project);
        
        // Share the file using the platform share sheet
        final result = await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'RoundnetBoard Project: ${project.name}',
          text: 'Check out my RoundnetBoard animation project!',
        );
        
        // Optional: Clean up temp file if share was successful
        if (result.status == ShareResultStatus.success) {
          // File can be kept for export history or deleted
          // await file.delete();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Share project on web by downloading the JSON file
  static void _shareProjectWeb(AnimationProject project) {
    try {
      final map = project.toMap();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
      final safeName = project.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
      
      final bytes = utf8.encode(jsonStr);
      final base64 = base64Encode(bytes);
      final dataUrl = 'data:application/json;base64,$base64';
      
      // Call the conditional web-specific implementation
      web_download.performWebDownload(dataUrl, '$safeName.json');
    } catch (e) {
      rethrow;
    }
  }

  /// Export project to JSON and return the file path
  /// On web, returns null since files are downloaded instead
  static Future<String?> exportProject(AnimationProject project) async {
    try {
      if (kIsWeb) {
        // On web, trigger download and return null
        _shareProjectWeb(project);
        return null;
      } else {
        final file = await ProjectIO.exportToJson(project);
        return file.path;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Share a text message with file info
  static Future<void> shareText(String text) async {
    if (kIsWeb) {
      // On web, copy to clipboard instead
      try {
        web_download.copyToClipboard(text);
      } catch (_) {
        // Clipboard API might not be available
      }
    } else {
      await Share.share(text);
    }
  }
}
