import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'version_reload.dart';

class VersionCheck {
  // ⚠️ IMPORTANT: Keep this in sync with pubspec.yaml version!
  // Run check-version.ps1 to verify consistency before deploying
  static const String currentVersion = '0.1.0+7'; // Update this with each deployment
  static const String versionKey = 'app_version';

  static Future<bool> checkVersion(BuildContext context) async {
    if (!kIsWeb) return true; // Only for web

    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getString(versionKey);

    if (savedVersion != currentVersion) {
      // New version detected
      await prefs.setString(versionKey, currentVersion);
      
      if (savedVersion != null && context.mounted) {
        // Show update dialog only if there was a previous version
        _showUpdateDialog(context);
        return false;
      }
    }
    return true;
  }

  static void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('New Version Available'),
        content: const Text(
          'A new version of the app is available. Please refresh the page to get the latest features and fixes.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Force page reload
              if (kIsWeb) {
                versionReloader.reload();
              }
            },
            child: const Text('Refresh Now'),
          ),
        ],
      ),
    );
  }
}
