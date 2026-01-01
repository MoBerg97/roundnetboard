import 'package:web/web.dart' as html;

/// Web-specific download implementation
/// This file is only compiled on web platform
void performWebDownload(String dataUrl, String filename) {
  html.HTMLAnchorElement()
    ..href = dataUrl
    ..download = filename
    ..click();
}

/// Copy text to clipboard on web
void copyToClipboard(String text) {
  try {
    html.window.navigator.clipboard.writeText(text);
  } catch (_) {
    // Clipboard API might not be available
  }
}
