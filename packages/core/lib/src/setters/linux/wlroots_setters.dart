import 'dart:convert';

import '../../models/display_target.dart';
import '../wallpaper_setter.dart';
import 'kde_setter.dart' show ProcessRunner;
import 'tools.dart';

/// Sway: `swaymsg output <name> bg <file> <mode>` per output.
class SwaySetter implements WallpaperSetter {
  SwaySetter({ProcessRunner? runProcess}) : _tools = ToolRunner(runProcess);

  final ToolRunner _tools;

  @override
  String get name => 'Sway';

  @override
  Future<SetterCapabilities> capabilities() async => const SetterCapabilities(
    perTarget: true,
    lockScreen: false,
    fitModes: FitMode.perScreen,
    note: 'Lasts until Sway reloads its config.',
  );

  static List<Output> parseOutputs(String json) {
    final outputs = <Output>[];
    for (final o in (jsonDecode(json) as List).cast<Map<String, Object?>>()) {
      if (o['active'] != true) continue;
      final rect = (o['rect'] as Map).cast<String, Object?>();
      final mode = (o['current_mode'] as Map?)?.cast<String, Object?>() ?? rect;
      var (w, h) = (mode['width']! as int, mode['height']! as int);
      if (o['transform'] case '90' || '270' || 'flipped-90' || 'flipped-270') (w, h) = (h, w);
      outputs.add((
        name: o['name']! as String,
        x: rect['x']! as int,
        y: rect['y']! as int,
        width: w,
        height: h,
        primary: o['focused'] == true,
      ));
    }
    return outputs;
  }

  static String modeFor(FitMode fit) => switch (fit) {
    FitMode.fill => 'fill',
    FitMode.fit => 'fit',
    FitMode.stretch => 'stretch',
    FitMode.centre => 'center',
    FitMode.span => 'fill',
  };

  @override
  Future<List<DisplayTarget>> targets() async =>
      monitorTargets(parseOutputs(await _tools.call('swaymsg', ['-t', 'get_outputs', '-r'])));

  @override
  Future<void> apply(List<Assignment> assignments) async {
    for (final a in assignments.where((a) => a.target.surface == TargetSurface.home)) {
      await _tools.call('swaymsg', ['output', a.target.id, 'bg', a.imagePath, modeFor(a.fit)]);
    }
  }
}

/// Hyprland, through whichever wallpaper daemon is running: swww (or its
/// successor awww), else hyprpaper via hyprctl.
class HyprlandSetter implements WallpaperSetter {
  HyprlandSetter({ProcessRunner? runProcess}) : _tools = ToolRunner(runProcess);

  final ToolRunner _tools;

  @override
  String get name => 'Hyprland';

  @override
  Future<SetterCapabilities> capabilities() async => const SetterCapabilities(
    perTarget: true,
    lockScreen: false,
    fitModes: [FitMode.fill, FitMode.fit, FitMode.centre],
    note: 'Needs swww or hyprpaper running.',
  );

  static List<Output> parseMonitors(String json) => [
    for (final m in (jsonDecode(json) as List).cast<Map<String, Object?>>())
      if (m['disabled'] != true)
        () {
          var (w, h) = (m['width']! as int, m['height']! as int);
          // Odd transforms are 90° or 270° rotations.
          if ((m['transform'] as int? ?? 0).isOdd) (w, h) = (h, w);
          return (
            name: m['name']! as String,
            x: m['x']! as int,
            y: m['y']! as int,
            width: w,
            height: h,
            primary: m['focused'] == true,
          );
        }(),
  ];

  @override
  Future<List<DisplayTarget>> targets() async =>
      monitorTargets(parseMonitors(await _tools.call('hyprctl', ['monitors', '-j'])));

  @override
  Future<void> apply(List<Assignment> assignments) async {
    final home = assignments.where((a) => a.target.surface == TargetSurface.home).toList();
    if (home.isEmpty) return;
    for (final swww in const ['awww', 'swww']) {
      if (await _tools.succeeds(swww, ['query'])) {
        for (final a in home) {
          final resize = switch (a.fit) {
            FitMode.fit => 'fit',
            FitMode.centre => 'no',
            FitMode.fill || FitMode.stretch || FitMode.span => 'crop',
          };
          await _tools.call(swww, ['img', '-o', a.target.id, '--resize', resize, a.imagePath]);
        }
        return;
      }
    }
    if (!await _tools.succeeds('hyprctl', ['hyprpaper', 'listloaded'])) {
      throw WallpaperSetterException(
        'No wallpaper daemon found. Start swww-daemon or hyprpaper (e.g. exec-once in hyprland.conf).',
      );
    }
    for (final a in home) {
      await _tools.call('hyprctl', ['hyprpaper', 'preload', a.imagePath]);
      final path = a.fit == FitMode.fit ? 'contain:${a.imagePath}' : a.imagePath;
      await _tools.call('hyprctl', ['hyprpaper', 'wallpaper', '${a.target.id},$path']);
    }
    await _tools.succeeds('hyprctl', ['hyprpaper', 'unload', 'unused']);
  }
}
