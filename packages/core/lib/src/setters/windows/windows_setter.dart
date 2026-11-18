import 'package:logging/logging.dart';

import '../../models/display_target.dart';
import '../linux/tools.dart' show monitorLabels;
import '../wallpaper_setter.dart';

final _log = Logger('WindowsSetter');

/// A monitor as Windows' wallpaper service (`IDesktopWallpaper`) sees it.
final class WindowsMonitor {
  const WindowsMonitor({
    required this.path,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.displayName,
    this.primary = false,
  });

  /// The monitor's device path, which `IDesktopWallpaper` uses as its id.
  final String path;

  /// `DISPLAY1`, `DISPLAY2`... (the `\\.\DISPLAYn` adapter output it's on).
  final String? displayName;

  /// Position on the desktop and size, in physical pixels.
  final int left;
  final int top;
  final int width;
  final int height;
  final bool primary;

  @override
  String toString() => 'WindowsMonitor(${displayName ?? path}, ${width}x$height at $left,$top)';
}

/// Windows' `DESKTOP_WALLPAPER_POSITION`, which applies to every monitor.
enum WindowsPosition {
  center(0),
  tile(1),
  stretch(2),
  fit(3),
  fill(4),
  span(5);

  const WindowsPosition(this.value);
  final int value;

  static WindowsPosition of(FitMode fit) => switch (fit) {
    FitMode.fill => fill,
    FitMode.fit => WindowsPosition.fit,
    FitMode.stretch => stretch,
    FitMode.centre => center,
    FitMode.span => span,
  };
}

/// The Windows calls [WindowsSetter] needs. [Win32Desktop] makes them for
/// real; tests use a fake.
abstract interface class WindowsDesktop {
  /// Null when the per-monitor wallpaper service isn't available (then only
  /// [setClassic] works).
  Future<List<WindowsMonitor>?> monitors();

  /// Sets each monitor's wallpaper (by [WindowsMonitor.path]), with one
  /// position for all of them.
  Future<void> setWallpapers(Map<String, String> imageByMonitor, WindowsPosition position);

  /// One image on every monitor at once ([WindowsPosition.span] spreads it
  /// across them).
  Future<void> setEverywhere(String image, WindowsPosition position);

  /// The old single-wallpaper API (`SystemParametersInfo`), for when the
  /// per-monitor service fails.
  Future<void> setClassic(String image, WindowsPosition position);

  Future<void> setLockScreen(String image);
}

/// Sets wallpapers on Windows 10/11: a different image per monitor through
/// `IDesktopWallpaper`, the lock screen through the Windows Runtime
/// `LockScreen` API.
///
/// Windows has one fit ("position") for all monitors, so the last one chosen
/// applies to every monitor. [FitMode.span] puts one image across them all.
class WindowsSetter implements WallpaperSetter {
  WindowsSetter(this._desktop);

  static const lockId = 'lock';

  final WindowsDesktop _desktop;

  /// Whether the per-monitor service answered last time we asked.
  bool? _perMonitor;

  @override
  String get name => 'Windows';

  @override
  Future<List<DisplayTarget>> targets() async {
    final monitors = await _monitors();
    if (monitors == null || monitors.isEmpty) {
      // Without the per-monitor service there's only "the desktop".
      return const [
        DisplayTarget(id: 'desktop', label: 'Desktop', width: 1920, height: 1080, isPrimary: true),
        DisplayTarget(id: lockId, label: 'Lock screen', width: 1920, height: 1080, surface: TargetSurface.lock),
      ];
    }
    final labels = monitorLabels([for (final m in monitors) (x: m.left, y: m.top)]);
    final anyPrimary = monitors.any((m) => m.primary);
    final targets = [
      for (final (i, m) in monitors.indexed)
        DisplayTarget(
          id: m.displayName ?? 'monitor${i + 1}',
          label: m.displayName == null ? labels[i] : '${labels[i]} (${m.displayName})',
          width: m.width,
          height: m.height,
          isPrimary: anyPrimary ? m.primary : i == 0,
        ),
    ];
    final primary = targets.firstWhere((t) => t.isPrimary);
    return [
      ...targets,
      DisplayTarget(
        id: lockId,
        label: 'Lock screen',
        width: primary.width,
        height: primary.height,
        surface: TargetSurface.lock,
      ),
    ];
  }

  Future<List<WindowsMonitor>?> _monitors() async {
    try {
      final monitors = await _desktop.monitors();
      _perMonitor = monitors != null;
      return monitors;
    } on Object catch (e) {
      _log.warning('Per-monitor wallpaper service unavailable: $e');
      _perMonitor = false;
      return null;
    }
  }

  @override
  Future<SetterCapabilities> capabilities() async {
    final perMonitor = _perMonitor ?? (await _monitors()) != null;
    return SetterCapabilities(
      perTarget: perMonitor,
      lockScreen: true,
      fitModes: const [...FitMode.perScreen, FitMode.span],
      note: perMonitor
          ? null
          : "Windows' per-monitor wallpaper service isn't available, so every monitor shows the same image.",
    );
  }

  @override
  Future<void> apply(List<Assignment> assignments) async {
    final home = [for (final a in assignments) if (a.target.surface == TargetSurface.home) a];
    final lock = [for (final a in assignments) if (a.target.surface == TargetSurface.lock) a];

    if (home.isNotEmpty) {
      // One position covers every monitor; the last choice wins.
      final position = WindowsPosition.of(home.last.fit);
      final monitors = await _monitors();
      if (monitors == null) {
        await _desktop.setClassic(home.first.imagePath, position);
      } else if (position == WindowsPosition.span) {
        await _desktop.setEverywhere(home.first.imagePath, position);
      } else {
        final byId = {
          for (final (i, m) in monitors.indexed) m.displayName ?? 'monitor${i + 1}': m,
        };
        final images = <String, String>{};
        for (final a in home) {
          if (a.target.id == 'desktop') {
            await _desktop.setEverywhere(a.imagePath, position);
            continue;
          }
          final monitor = byId[a.target.id] ??
              (throw WallpaperSetterException('${a.target.label} is no longer connected.'));
          images[monitor.path] = a.imagePath;
        }
        if (images.isNotEmpty) await _desktop.setWallpapers(images, position);
      }
    }
    for (final a in lock) {
      await _desktop.setLockScreen(a.imagePath);
    }
  }
}
