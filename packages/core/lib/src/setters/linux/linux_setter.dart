import 'dart:io';

import '../wallpaper_setter.dart';
import 'desktop_environment.dart';
import 'kde_setter.dart';

/// Picks the setter for the running Linux desktop.
WallpaperSetter createLinuxSetter({Map<String, String>? environment}) {
  final env = detectLinuxEnvironment(environment ?? Platform.environment);
  return switch (env.desktop) {
    LinuxDesktop.kde => KdeSetter(),
    final desktop => UnsupportedSetter(
      "Setting wallpapers on ${desktop.label} isn't supported yet. "
      'KDE Plasma is the only Linux desktop supported so far.',
      name: desktop.label,
    ),
  };
}
