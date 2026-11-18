import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the app keeps its files, for code that runs without Flutter (the
/// command line). Matches Flutter's path_provider. [windows] defaults to the
/// platform this runs on; tests pass it to check the other one.
abstract final class AppPaths {
  static const appId = 'dev.mcoombes.wallpaperfetcher';

  /// path_provider on Windows uses `%APPDATA%\<company>\<product>` from the
  /// app's version resource: keep these in step with
  /// `packages/app/windows/runner/Runner.rc`.
  static const windowsCompany = 'dev.mcoombes';
  static const windowsProduct = 'Wallpaper Fetcher';

  static bool _windows(bool? windows) => windows ?? Platform.isWindows;

  static p.Context _paths(bool? windows) => _windows(windows) ? p.windows : p.posix;

  static String dataDirectory([Map<String, String>? environment, bool? windows]) {
    final env = environment ?? Platform.environment;
    if (_windows(windows)) {
      return p.windows.join(env['APPDATA'] ?? r'C:\', windowsCompany, windowsProduct);
    }
    final dataHome = env['XDG_DATA_HOME'];
    final base = dataHome != null && dataHome.isNotEmpty
        ? dataHome
        : p.posix.join(env['HOME'] ?? '.', '.local', 'share');
    return p.posix.join(base, appId);
  }

  /// drift_flutter names the file after the database (`library`).
  static String database([Map<String, String>? environment, bool? windows]) =>
      _paths(windows).join(dataDirectory(environment, windows), 'library.sqlite');

  static String logs([Map<String, String>? environment, bool? windows]) =>
      _paths(windows).join(dataDirectory(environment, windows), 'logs');

  /// The Unix socket the running app listens on for the command line.
  /// `$XDG_RUNTIME_DIR` on Linux and the app's data folder on Windows (which
  /// has Unix sockets since Windows 10 1803) are both private to the user.
  static String socket([Map<String, String>? environment, bool? windows]) {
    final env = environment ?? Platform.environment;
    if (_windows(windows)) return p.windows.join(dataDirectory(env, true), 'wallpaper-fetcher.sock');
    final runtime = env['XDG_RUNTIME_DIR'];
    return runtime != null && runtime.isNotEmpty
        ? p.posix.join(runtime, 'wallpaper-fetcher.sock')
        : p.posix.join(dataDirectory(env, false), 'wallpaper-fetcher.sock');
  }
}
