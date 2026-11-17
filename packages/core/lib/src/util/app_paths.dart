import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the app keeps its files, for code that runs without Flutter (the
/// command line). Matches Flutter's path_provider on Linux.
abstract final class AppPaths {
  static const appId = 'dev.mcoombes.wallpaperfetcher';

  static String dataDirectory([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    if (Platform.isWindows) {
      return p.join(env['APPDATA'] ?? '.', appId);
    }
    final dataHome = env['XDG_DATA_HOME'];
    final base = dataHome != null && dataHome.isNotEmpty
        ? dataHome
        : p.join(env['HOME'] ?? '.', '.local', 'share');
    return p.join(base, appId);
  }

  /// drift_flutter names the file after the database (`library`).
  static String database([Map<String, String>? environment]) =>
      p.join(dataDirectory(environment), 'library.sqlite');

  static String logs([Map<String, String>? environment]) => p.join(dataDirectory(environment), 'logs');

  /// The app's command socket. `$XDG_RUNTIME_DIR` is private to the user.
  static String socket([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final runtime = env['XDG_RUNTIME_DIR'];
    return runtime != null && runtime.isNotEmpty
        ? p.join(runtime, 'wallpaper-fetcher.sock')
        : p.join(dataDirectory(env), 'wallpaper-fetcher.sock');
  }
}
