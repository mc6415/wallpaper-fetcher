import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';

/// Start on login, via an XDG autostart entry (KDE, GNOME and most other
/// Linux desktops read `~/.config/autostart`). The app starts hidden in the
/// tray.
abstract final class Autostart {
  static bool get supported => Platform.isLinux;

  static File get _entry {
    final env = Platform.environment;
    final config = env['XDG_CONFIG_HOME']?.isNotEmpty == true
        ? env['XDG_CONFIG_HOME']!
        : p.join(env['HOME'] ?? '.', '.config');
    return File(p.join(config, 'autostart', '${AppPaths.appId}.desktop'));
  }

  static Future<bool> isEnabled() async => supported && await _entry.exists();

  static Future<void> setEnabled(bool enabled, {String? executable}) async {
    if (!supported) return;
    final entry = _entry;
    if (!enabled) {
      if (await entry.exists()) await entry.delete();
      return;
    }
    await entry.parent.create(recursive: true);
    await entry.writeAsString(desktopEntry(executable ?? Platform.resolvedExecutable));
  }

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
