import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../../models/display_target.dart';
import '../wallpaper_setter.dart';
import 'plasma_shell.dart';

final _log = Logger('KdeSetter');

typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// A screen as Plasma's scripting API sees it (logical coordinates).
typedef PlasmaGeometry = ({int index, int x, int y, int width, int height});

/// A monitor as `kscreen-doctor -j` reports it.
final class KScreenOutput {
  const KScreenOutput({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isPrimary = false,
  });

  /// Connector name, e.g. `DP-1`.
  final String name;

  /// Logical position, matching Plasma's screen geometry.
  final int x;
  final int y;

  /// Physical pixels of the current mode, rotation applied.
  final int width;
  final int height;
  final bool isPrimary;
}

/// A Plasma screen index paired with the monitor it shows on.
final class PlasmaScreen {
  const PlasmaScreen({required this.index, required this.target});

  final int index;
  final DisplayTarget target;
}

/// Sets wallpapers on KDE Plasma 6: each monitor through Plasma's scripting
/// API over D-Bus, the lock screen through `kscreenlockerrc`.
class KdeSetter implements WallpaperSetter {
  KdeSetter({PlasmaShell? shell, ProcessRunner? runProcess})
    : _shell = shell ?? DBusPlasmaShell(),
      _run = runProcess ?? Process.run;

  static const lockTargetId = 'lock';

  final PlasmaShell _shell;
  final ProcessRunner _run;

  @override
  String get name => 'KDE Plasma';

  @override
  Future<SetterCapabilities> capabilities() async => const SetterCapabilities(
    perTarget: true,
    lockScreen: true,
    fitModes: FitMode.perScreen,
  );

  @override
  Future<List<DisplayTarget>> targets() async {
    final monitors = [for (final s in await screens()) s.target];
    if (monitors.isEmpty) return const [];
    final primary = monitors.firstWhere((m) => m.isPrimary, orElse: () => monitors.first);
    return [
      ...monitors,
      DisplayTarget(
        id: lockTargetId,
        label: 'Lock screen',
        width: primary.width,
        height: primary.height,
        surface: TargetSurface.lock,
      ),
    ];
  }

  Future<List<PlasmaScreen>> screens() async =>
      matchScreens(await _plasmaScreens(), await _kscreenOutputs());

  @override
  Future<void> apply(List<Assignment> assignments) async {
    if (assignments.isEmpty) return;
    for (final a in assignments) {
      if (!File(a.imagePath).existsSync()) {
        throw WallpaperSetterException('The image file is missing: ${a.imagePath}');
      }
    }
    final home = [for (final a in assignments) if (a.target.surface == TargetSurface.home) a];
    final lock = [for (final a in assignments) if (a.target.surface == TargetSurface.lock) a];

    if (home.isNotEmpty) {
      final byId = {for (final s in await screens()) s.target.id: s.index};
      final perScreen = <int, Assignment>{};
      for (final a in home) {
        final index = byId[a.target.id] ??
            (throw WallpaperSetterException('${a.target.label} is no longer connected.'));
        perScreen[index] = a;
      }
      final output = await _eval(buildApplyScript(perScreen));
      final applied = _decodeObject(output)['applied'];
      if (applied is! int || applied < perScreen.length) {
        throw WallpaperSetterException(
          'Plasma only updated ${applied ?? 0} of ${perScreen.length} screens.',
        );
      }
      _log.info('Set wallpaper on screens ${perScreen.keys.join(', ')}');
    }
    if (lock.isNotEmpty) await _applyLockScreen(lock.last);
  }

  /// Plasma's image wallpaper `FillMode` values (Qt's Image.FillMode).
  static int fillModeFor(FitMode fit) => switch (fit) {
    FitMode.stretch => 0,
    FitMode.fit => 1,
    FitMode.fill => 2,
    FitMode.centre => 6,
    FitMode.span => 2,
  };

  /// A Plasma script that sets each listed screen's wallpaper. Every desktop
  /// on that screen is updated (one per activity). Prints how many screens it
  /// updated.
  static String buildApplyScript(Map<int, Assignment> perScreen) {
    final config = {
      for (final MapEntry(key: index, value: a) in perScreen.entries)
        '$index': {
          'image': Uri.file(a.imagePath).toString(),
          'fill': fillModeFor(a.fit),
        },
    };
    return '''
var assignments = ${jsonEncode(config)};
var desktopList = desktops();
var updated = {};
for (var i = 0; i < desktopList.length; i++) {
  var d = desktopList[i];
  var a = assignments[String(d.screen)];
  if (!a) continue;
  d.wallpaperPlugin = "org.kde.image";
  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  d.writeConfig("Image", a.image);
  d.writeConfig("FillMode", a.fill);
  updated[d.screen] = true;
}
print(JSON.stringify({applied: Object.keys(updated).length}));
''';
  }

  static const screensScript = '''
var s = [];
for (var i = 0; i < screenCount; i++) {
  var g = screenGeometry(i);
  s.push({i: i, x: g.x, y: g.y, w: g.width, h: g.height});
}
print(JSON.stringify(s));
''';

  static List<PlasmaGeometry> parsePlasmaScreens(String json) => [
    for (final s in (jsonDecode(json) as List).cast<Map<String, Object?>>())
      (
        index: s['i']! as int,
        x: s['x']! as int,
        y: s['y']! as int,
        width: s['w']! as int,
        height: s['h']! as int,
      ),
  ];

  static List<KScreenOutput> parseKScreenOutputs(String json) {
    final data = jsonDecode(json) as Map<String, Object?>;
    final outputs = <KScreenOutput>[];
    for (final o in (data['outputs'] as List? ?? const []).cast<Map<String, Object?>>()) {
      if (o['enabled'] != true || o['connected'] != true) continue;
      final pos = (o['pos'] as Map).cast<String, Object?>();
      final size = (o['size'] as Map).cast<String, Object?>();
      var (w, h) = (size['width']! as int, size['height']! as int);
      // Rotated 90° (2 = left, 8 = right): the screen is taller than wide.
      if (o['rotation'] == 2 || o['rotation'] == 8) (w, h) = (h, w);
      outputs.add(
        KScreenOutput(
          name: o['name']! as String,
          x: pos['x']! as int,
          y: pos['y']! as int,
          width: w,
          height: h,
          isPrimary: o['priority'] == 1,
        ),
      );
    }
    return outputs;
  }

  /// Pairs Plasma's screens with kscreen's monitors by position, and names
  /// them by where they sit ("Left monitor (DP-1)").
  static List<PlasmaScreen> matchScreens(
    List<PlasmaGeometry> plasma,
    List<KScreenOutput> outputs,
  ) {
    final sorted = [...plasma]
      ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    final stackedVertically = sorted.length == 2 && sorted[0].x == sorted[1].x;
    final positions = switch (sorted.length) {
      1 => const [''],
      2 when stackedVertically => const ['Top ', 'Bottom '],
      2 => const ['Left ', 'Right '],
      3 => const ['Left ', 'Centre ', 'Right '],
      _ => null,
    };
    return [
      for (final (i, s) in sorted.indexed)
        _screen(
          s,
          outputs.where((o) => o.x == s.x && o.y == s.y).firstOrNull,
          positions == null ? 'Monitor ${i + 1}' : '${positions[i]}monitor',
        ),
    ];
  }

  static PlasmaScreen _screen(PlasmaGeometry s, KScreenOutput? out, String place) {
    final label = place[0].toUpperCase() + place.substring(1);
    return PlasmaScreen(
      index: s.index,
      target: DisplayTarget(
        id: out?.name ?? 'screen-${s.index}',
        label: out == null ? label : '$label (${out.name})',
        width: out?.width ?? s.width,
        height: out?.height ?? s.height,
        isPrimary: out?.isPrimary ?? s.index == 0,
      ),
    );
  }

  Future<List<PlasmaGeometry>> _plasmaScreens() async {
    final output = await _eval(screensScript);
    try {
      return parsePlasmaScreens(output);
    } on Object catch (e) {
      throw WallpaperSetterException('Plasma sent an unexpected screen list.', cause: e);
    }
  }

  /// Monitor names and physical sizes. Empty if kscreen-doctor isn't
  /// available; screens then get generic names and logical sizes.
  Future<List<KScreenOutput>> _kscreenOutputs() async {
    try {
      final result = await _run('kscreen-doctor', ['-j']);
      if (result.exitCode != 0) {
        _log.warning('kscreen-doctor failed: ${result.stderr}');
        return const [];
      }
      return parseKScreenOutputs(result.stdout as String);
    } on ProcessException catch (e) {
      _log.warning('kscreen-doctor not available: $e');
    } on Object catch (e) {
      _log.warning('Unreadable kscreen-doctor output: $e');
    }
    return const [];
  }

  Future<void> _applyLockScreen(Assignment a) async {
    final url = Uri.file(a.imagePath).toString();
    const greeter = ['--file', 'kscreenlockerrc', '--group', 'Greeter'];
    const image = [...greeter, '--group', 'Wallpaper', '--group', 'org.kde.image', '--group', 'General'];
    await _kwrite([...greeter, '--key', 'WallpaperPlugin', 'org.kde.image']);
    await _kwrite([...image, '--key', 'Image', url]);
    await _kwrite([...image, '--key', 'PreviewImage', url]);
    await _kwrite([...image, '--key', 'FillMode', '${fillModeFor(a.fit)}']);
    _log.info('Set lock screen wallpaper');
  }

  Future<void> _kwrite(List<String> args) async {
    final ProcessResult result;
    try {
      result = await _run('kwriteconfig6', args);
    } on ProcessException catch (e) {
      throw WallpaperSetterException(
        "Couldn't find kwriteconfig6, which is needed to set the lock screen.",
        cause: e,
      );
    }
    if (result.exitCode != 0) {
      throw WallpaperSetterException('kwriteconfig6 failed: ${result.stderr}'.trim());
    }
  }

  Future<String> _eval(String script) async {
    try {
      return await _shell.evaluateScript(script);
    } on Object catch (e) {
      throw WallpaperSetterException(
        "Couldn't talk to Plasma. Is plasmashell running?",
        cause: e,
      );
    }
  }

  static Map<String, Object?> _decodeObject(String json) {
    try {
      final value = jsonDecode(json);
      return value is Map ? value.cast<String, Object?>() : const {};
    } on FormatException {
      return const {};
    }
  }
}
