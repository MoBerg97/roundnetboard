import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/animation_project.dart';
import '../utils/export_import.dart';

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
