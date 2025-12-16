import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TutorialType { home, board, annotation }

class TutorialService extends ChangeNotifier {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  TutorialType? _pendingTutorial;
  bool _isActive = false;

  TutorialType? get pendingTutorial => _pendingTutorial;
  bool get isActive => _isActive;

  void requestTutorial(TutorialType type) {
    print('🎯 TutorialService: Requesting ${type.name} tutorial');
    _pendingTutorial = type;
    print('🎯 TutorialService: Pending tutorial set to ${_pendingTutorial?.name}');
    notifyListeners();
    print('🎯 TutorialService: Listeners notified (${hasListeners ? 'has listeners' : 'no listeners'})');
  }

  void startTutorial(TutorialType type) {
    print('▶️ TutorialService: Starting ${type.name} tutorial');
    _pendingTutorial = null;
    _isActive = true;
    notifyListeners();
  }

  void finishTutorial() {
    print('⏹️ TutorialService: Finishing tutorial');
    _isActive = false;
    notifyListeners();
  }

  void clearPendingTutorial() {
    print('🗑️ TutorialService: Clearing pending tutorial');
    _pendingTutorial = null;
    notifyListeners();
  }

  Future<bool> hasCompletedTutorial(TutorialType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('tutorial_${type.name}_completed') ?? false;
  }

  Future<void> markTutorialCompleted(TutorialType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_${type.name}_completed', true);
  }

  Future<void> resetTutorial(TutorialType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tutorial_${type.name}_completed');
  }

  Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    for (final type in TutorialType.values) {
      await prefs.remove('tutorial_${type.name}_completed');
    }
  }
}
