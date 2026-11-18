import 'dart:io';

import '../../settings/settings_store.dart';
import '../wallpaper_setter.dart';
import 'desktop_environment.dart';
import 'feh_setter.dart';
import 'gnome_setter.dart';
import 'kde_setter.dart';
import 'tools.dart';
import 'wlroots_setters.dart';
import 'xfce_setter.dart';

/// Picks the setter for the running Linux desktop. Only KDE Plasma has been
/// tried on a real desktop; the others follow each tool's documentation and
/// are covered by tests against sample output. [settings] supplies options
/// some setters read when applying (KDE's blurred wallpaper).
WallpaperSetter createLinuxSetter({Map<String, String>? environment, SettingsStore? settings}) {
  final env = environment ?? Platform.environment;
  final linux = detectLinuxEnvironment(env);
  return switch (linux.desktop) {
    LinuxDesktop.kde => KdeSetter(
      preferBlur: settings == null
          ? null
          : () async => await settings.get(SettingsKeys.kdeBlurredWallpaper) == 'true',
    ),
    LinuxDesktop.gnome => GnomeSetter(GnomeFlavour.gnome),
    LinuxDesktop.cinnamon => GnomeSetter(GnomeFlavour.cinnamon),
    LinuxDesktop.mate => GnomeSetter(GnomeFlavour.mate),
    LinuxDesktop.xfce => XfceSetter(),
    LinuxDesktop.sway => SwaySetter(),
    LinuxDesktop.hyprland => HyprlandSetter(),
    LinuxDesktop.unknown when linux.session == SessionType.x11 && onPath('feh', env) => FehSetter(),
    LinuxDesktop.unknown => const UnsupportedSetter(
      "Setting wallpapers on this desktop isn't supported. On a plain X11 window manager, "
      'installing feh makes it work.',
      name: 'Unknown desktop',
    ),
  };
}
