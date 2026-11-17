enum LinuxDesktop {
  kde('KDE Plasma'),
  gnome('GNOME'),
  cinnamon('Cinnamon'),
  mate('MATE'),
  xfce('Xfce'),
  hyprland('Hyprland'),
  sway('Sway'),
  unknown('this desktop');

  const LinuxDesktop(this.label);
  final String label;
}

enum SessionType { wayland, x11, unknown }

final class LinuxEnvironment {
  const LinuxEnvironment(this.desktop, this.session);

  final LinuxDesktop desktop;
  final SessionType session;

  @override
  String toString() => '${desktop.label} (${session.name})';
}

/// Works out the desktop from environment variables.
LinuxEnvironment detectLinuxEnvironment(Map<String, String> env) {
  final session = switch (env['XDG_SESSION_TYPE']?.toLowerCase()) {
    'wayland' => SessionType.wayland,
    'x11' => SessionType.x11,
    _ when env.containsKey('WAYLAND_DISPLAY') => SessionType.wayland,
    _ when env.containsKey('DISPLAY') => SessionType.x11,
    _ => SessionType.unknown,
  };

  // Compositor-specific variables are the most reliable signal.
  if (env.containsKey('HYPRLAND_INSTANCE_SIGNATURE')) {
    return LinuxEnvironment(LinuxDesktop.hyprland, session);
  }
  if (env.containsKey('SWAYSOCK')) {
    return LinuxEnvironment(LinuxDesktop.sway, session);
  }

  final names = [
    ...?env['XDG_CURRENT_DESKTOP']?.split(':'),
    ?env['XDG_SESSION_DESKTOP'],
    ?env['DESKTOP_SESSION'],
  ];
  for (final name in names) {
    final desktop = _match(name.trim().toLowerCase());
    if (desktop != LinuxDesktop.unknown) return LinuxEnvironment(desktop, session);
  }
  return LinuxEnvironment(LinuxDesktop.unknown, session);
}

LinuxDesktop _match(String name) {
  if (name.isEmpty) return LinuxDesktop.unknown;
  if (name.contains('kde') || name.contains('plasma')) return LinuxDesktop.kde;
  // Before GNOME: Cinnamon reports "X-Cinnamon".
  if (name.contains('cinnamon')) return LinuxDesktop.cinnamon;
  if (name.contains('gnome') || name == 'ubuntu' || name == 'unity') {
    return LinuxDesktop.gnome;
  }
  if (name == 'mate') return LinuxDesktop.mate;
  if (name.contains('xfce')) return LinuxDesktop.xfce;
  if (name.contains('hyprland')) return LinuxDesktop.hyprland;
  if (name.contains('sway')) return LinuxDesktop.sway;
  return LinuxDesktop.unknown;
}
