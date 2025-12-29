import 'dart:html' as html;

abstract class VersionReloader {
  void reload();
}

class _WebReloader implements VersionReloader {
  @override
  void reload() => html.window.location.reload();
}

VersionReloader createVersionReloader() => _WebReloader();
