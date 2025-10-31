import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/animation_project.dart';

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
}


