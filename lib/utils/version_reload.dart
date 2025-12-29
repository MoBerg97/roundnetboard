import 'version_reload_stub.dart'
    if (dart.library.html) 'version_reload_web.dart';

final VersionReloader versionReloader = createVersionReloader();
