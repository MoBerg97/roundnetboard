// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

abstract class VersionReloader {
  void reload();
}

class _WebReloader implements VersionReloader {
  @override
  void reload() => html.window.location.reload();
}

VersionReloader createVersionReloader() => _WebReloader();
