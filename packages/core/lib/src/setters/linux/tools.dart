import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/display_target.dart';
import '../wallpaper_setter.dart';
import 'kde_setter.dart' show ProcessRunner;

/// Runs desktop command-line tools, turning failures into
/// [WallpaperSetterException]s with useful messages.
class ToolRunner {
  ToolRunner([ProcessRunner? run]) : _run = run ?? Process.run;

  final ProcessRunner _run;

  Future<String> call(String executable, List<String> arguments, {String? missing}) async {
    final ProcessResult result;
    try {
      result = await _run(executable, arguments);
    } on ProcessException catch (e) {
      throw WallpaperSetterException(missing ?? "Couldn't run $executable. Is it installed?", cause: e);
    }
    if (result.exitCode != 0) {
      final detail = '${result.stderr}'.trim();
      throw WallpaperSetterException('$executable failed${detail.isEmpty ? '' : ': $detail'}');
    }
    return '${result.stdout}';
  }

  /// Whether the command runs successfully (e.g. a daemon is up).
  Future<bool> succeeds(String executable, List<String> arguments) async {
    try {
      await call(executable, arguments);
      return true;
    } on WallpaperSetterException {
      return false;
    }
  }
}

bool onPath(String executable, [Map<String, String>? environment]) {
  final path = (environment ?? Platform.environment)['PATH'] ?? '';
  return path.split(':').any((dir) => dir.isNotEmpty && File(p.join(dir, executable)).existsSync());
}

/// "Left monitor", "Right monitor", ... by position, in the same order as
/// [positions].
List<String> monitorLabels(List<({int x, int y})> positions) {
  final n = positions.length;
  final order = [for (var i = 0; i < n; i++) i]
    ..sort((a, b) => positions[a].x != positions[b].x
        ? positions[a].x.compareTo(positions[b].x)
        : positions[a].y.compareTo(positions[b].y));
  final stacked = n == 2 && positions[0].x == positions[1].x;
  final names = switch (n) {
    1 => const ['Monitor'],
    2 when stacked => const ['Top monitor', 'Bottom monitor'],
    2 => const ['Left monitor', 'Right monitor'],
    3 => const ['Left monitor', 'Centre monitor', 'Right monitor'],
    _ => [for (var i = 1; i <= n; i++) 'Monitor $i'],
  };
  final labels = List.filled(n, '');
  for (var rank = 0; rank < n; rank++) {
    labels[order[rank]] = names[rank];
  }
  return labels;
}

/// A monitor described by a desktop tool.
typedef Output = ({String name, int x, int y, int width, int height, bool primary});

/// Turns outputs into targets named by position: "Left monitor (DP-1)".
List<DisplayTarget> monitorTargets(List<Output> outputs) {
  final labels = monitorLabels([for (final o in outputs) (x: o.x, y: o.y)]);
  final anyPrimary = outputs.any((o) => o.primary);
  return [
    for (final (i, o) in outputs.indexed)
      DisplayTarget(
        id: o.name,
        label: '${labels[i]} (${o.name})',
        width: o.width,
        height: o.height,
        isPrimary: anyPrimary ? o.primary : i == 0,
      ),
  ];
}

/// Parses `xrandr --listactivemonitors`:
/// ` 0: +*DP-1 3840/600x2160/340+0+0  DP-1`
List<Output> parseXrandrMonitors(String text) => [
  for (final m in RegExp(
    r'^\s*\d+:\s+\+(\*?)(\S+)\s+(\d+)/\d+x(\d+)/\d+([+-]\d+)([+-]\d+)',
    multiLine: true,
  ).allMatches(text))
    (
      name: m[2]!,
      primary: m[1] == '*',
      width: int.parse(m[3]!),
      height: int.parse(m[4]!),
      x: int.parse(m[5]!),
      y: int.parse(m[6]!),
    ),
];
