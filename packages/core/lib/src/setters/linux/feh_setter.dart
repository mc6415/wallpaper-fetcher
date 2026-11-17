import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/display_target.dart';
import '../wallpaper_setter.dart';
import 'kde_setter.dart' show ProcessRunner;
import 'tools.dart';

/// Plain X11 window managers (i3, bspwm, Openbox...) through `feh`. feh sets
/// every monitor at once, so the images of monitors we aren't changing are
/// read back from `~/.fehbg`.
class FehSetter implements WallpaperSetter {
  FehSetter({ProcessRunner? runProcess, String? fehbgPath})
    : _tools = ToolRunner(runProcess),
      _fehbg = fehbgPath ?? p.join(Platform.environment['HOME'] ?? '.', '.fehbg');

  final ToolRunner _tools;
  final String _fehbg;

  @override
  String get name => 'feh (X11)';

  @override
  Future<SetterCapabilities> capabilities() async => const SetterCapabilities(
    perTarget: true,
    lockScreen: false,
    fitModes: FitMode.values,
    note: 'All monitors share one fit mode.',
  );

  @override
  Future<List<DisplayTarget>> targets() async =>
      monitorTargets(parseXrandrMonitors(await _tools.call('xrandr', ['--listactivemonitors'])));

  static String optionFor(FitMode fit) => switch (fit) {
    FitMode.fill => '--bg-fill',
    FitMode.fit => '--bg-max',
    FitMode.stretch => '--bg-scale',
    FitMode.centre => '--bg-center',
  };

  /// The image paths in a `~/.fehbg` script, in monitor order.
  static List<String> parseFehbg(String script) => [
    for (final m in RegExp(r"'((?:[^']|'\\'')*)'").allMatches(script.split('\n').lastWhere((l) => l.contains('feh'), orElse: () => '')))
      m[1]!.replaceAll(r"'\''", "'"),
  ];

  @override
  Future<void> apply(List<Assignment> assignments) async {
    final home = assignments.where((a) => a.target.surface == TargetSurface.home).toList();
    if (home.isEmpty) return;
    final screens = await targets();
    final file = File(_fehbg);
    final current = await file.exists() ? parseFehbg(await file.readAsString()) : const <String>[];
    final byId = {for (final a in home) a.target.id: a.imagePath};
    final images = [
      for (final (i, screen) in screens.indexed)
        byId[screen.id] ?? (i < current.length ? current[i] : home.first.imagePath),
    ];
    await _tools.call('feh', [optionFor(home.first.fit), ...images], missing: "Couldn't find feh.");
  }
}
