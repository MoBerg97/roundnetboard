import 'package:share_plus/share_plus.dart';
import '../models/animation_project.dart';
import 'export_import.dart';

/// Helper class for sharing project files
class ShareHelper {
  /// Share a project as a JSON file via the system share sheet
  static Future<void> shareProject(AnimationProject project) async {
    try {
      // Export project to JSON file
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
    } catch (e) {
      rethrow;
    }
  }

  /// Export project to JSON and return the file path
  static Future<String> exportProject(AnimationProject project) async {
    try {
      final file = await ProjectIO.exportToJson(project);
      return file.path;
    } catch (e) {
      rethrow;
    }
  }

  /// Share a text message with file info
  static Future<void> shareText(String text) async {
    await Share.share(text);
  }
}
