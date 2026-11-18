import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';

/// Start on login, hidden in the tray: an XDG autostart entry on Linux (KDE,
/// GNOME and most others read `~/.config/autostart`), the per-user `Run`
/// registry key on Windows.
abstract final class Autostart {
  static bool get supported => Platform.isLinux || Platform.isWindows;

  static const windowsRunKey = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const windowsValueName = 'Wallpaper Fetcher';

  static File get _entry {
    final env = Platform.environment;
    final config = env['XDG_CONFIG_HOME']?.isNotEmpty == true
        ? env['XDG_CONFIG_HOME']!
        : p.join(env['HOME'] ?? '.', '.config');
    return File(p.join(config, 'autostart', '${AppPaths.appId}.desktop'));
  }

  static Future<bool> isEnabled() async {
    if (Platform.isWindows) return UserRegistry.readString(windowsRunKey, windowsValueName) != null;
    return Platform.isLinux && await _entry.exists();
  }

  static Future<void> setEnabled(bool enabled, {String? executable}) async {
    // From an AppImage, the AppImage file: the executable inside it lives in
    // a mount that changes every run.
    final appImage = Platform.environment['APPIMAGE'];
    final exe = executable ?? (appImage != null && appImage.isNotEmpty ? appImage : Platform.resolvedExecutable);
    if (Platform.isWindows) {
      enabled
          ? UserRegistry.writeString(windowsRunKey, windowsValueName, windowsCommand(exe))
          : UserRegistry.delete(windowsRunKey, windowsValueName);
      return;
    }
    if (!Platform.isLinux) return;
    final entry = _entry;
    if (!enabled) {
      if (await entry.exists()) await entry.delete();
      return;
    }
    await entry.parent.create(recursive: true);
    await entry.writeAsString(desktopEntry(exe));
  }

  /// What the `Run` key holds: the quoted program, started in the tray.
  static String windowsCommand(String executable) => '"$executable" --hidden';

  static String desktopEntry(String executable) => '''
[Desktop Entry]
Type=Application
Name=Wallpaper Fetcher
Comment=Keeps your wallpaper rotating from the system tray
Exec="${executable.replaceAll('"', r'\"')}" --hidden
Icon=preferences-desktop-wallpaper
Terminal=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
''';
}
