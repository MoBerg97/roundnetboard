abstract class VersionReloader {
  void reload();
}

class _NoopReloader implements VersionReloader {
  @override
  void reload() {}
}

VersionReloader createVersionReloader() => _NoopReloader();
