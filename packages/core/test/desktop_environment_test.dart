import 'dart:io';

import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

void main() {
  LinuxDesktop detect(Map<String, String> env) => detectLinuxEnvironment(env).desktop;

  test('recognises the common desktops from XDG_CURRENT_DESKTOP', () {
    expect(detect({'XDG_CURRENT_DESKTOP': 'KDE'}), LinuxDesktop.kde);
    expect(detect({'XDG_CURRENT_DESKTOP': 'GNOME'}), LinuxDesktop.gnome);
    expect(detect({'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME'}), LinuxDesktop.gnome);
    expect(detect({'XDG_CURRENT_DESKTOP': 'X-Cinnamon'}), LinuxDesktop.cinnamon);
    expect(detect({'XDG_CURRENT_DESKTOP': 'MATE'}), LinuxDesktop.mate);
    expect(detect({'XDG_CURRENT_DESKTOP': 'XFCE'}), LinuxDesktop.xfce);
    expect(detect({'XDG_CURRENT_DESKTOP': 'Hyprland'}), LinuxDesktop.hyprland);
    expect(detect({'XDG_CURRENT_DESKTOP': 'sway'}), LinuxDesktop.sway);
  });

  test('compositor variables win over XDG_CURRENT_DESKTOP', () {
    expect(
      detect({'XDG_CURRENT_DESKTOP': 'GNOME', 'HYPRLAND_INSTANCE_SIGNATURE': 'x'}),
      LinuxDesktop.hyprland,
    );
    expect(detect({'SWAYSOCK': '/run/user/1000/sway.sock'}), LinuxDesktop.sway);
  });

  test('falls back to DESKTOP_SESSION, then unknown', () {
    expect(detect({'DESKTOP_SESSION': 'plasma'}), LinuxDesktop.kde);
    expect(detect({'XDG_CURRENT_DESKTOP': 'i3'}), LinuxDesktop.unknown);
    expect(detect(const {}), LinuxDesktop.unknown);
  });

  test('works out the session type', () {
    expect(detectLinuxEnvironment({'XDG_SESSION_TYPE': 'wayland'}).session, SessionType.wayland);
    expect(detectLinuxEnvironment({'DISPLAY': ':0'}).session, SessionType.x11);
    expect(detectLinuxEnvironment(const {}).session, SessionType.unknown);
  });

  test('each desktop gets its setter; unknown X11 uses feh only if installed', () {
    Type setterFor(Map<String, String> env) => createLinuxSetter(environment: env).runtimeType;
    expect(setterFor({'XDG_CURRENT_DESKTOP': 'KDE'}), KdeSetter);
    expect(setterFor({'XDG_CURRENT_DESKTOP': 'GNOME'}), GnomeSetter);
    expect(createLinuxSetter(environment: {'XDG_CURRENT_DESKTOP': 'X-Cinnamon'}).name, 'Cinnamon');
    expect(createLinuxSetter(environment: {'XDG_CURRENT_DESKTOP': 'MATE'}).name, 'MATE');
    expect(setterFor({'XDG_CURRENT_DESKTOP': 'XFCE'}), XfceSetter);
    expect(setterFor({'SWAYSOCK': '/run/sway'}), SwaySetter);
    expect(setterFor({'HYPRLAND_INSTANCE_SIGNATURE': 'x'}), HyprlandSetter);
    expect(setterFor({'XDG_SESSION_TYPE': 'x11', 'PATH': '/nonexistent'}), UnsupportedSetter);
  }, skip: Platform.isWindows ? 'looks for feh on a Linux PATH' : null);
}
