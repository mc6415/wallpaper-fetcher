import '../../models/display_target.dart';
import '../wallpaper_setter.dart';
import 'kde_setter.dart' show ProcessRunner;
import 'tools.dart';

/// Xfce keeps a wallpaper per monitor and workspace in xfconf
/// (`/backdrop/screen0/monitor<NAME>/workspace<N>/last-image`).
class XfceSetter implements WallpaperSetter {
  XfceSetter({ProcessRunner? runProcess}) : _tools = ToolRunner(runProcess);

  final ToolRunner _tools;

  @override
  String get name => 'Xfce';

  @override
  Future<SetterCapabilities> capabilities() async =>
      const SetterCapabilities(perTarget: true, lockScreen: false, fitModes: FitMode.values);

  /// `last-image` properties grouped by monitor name.
  static Map<String, List<String>> imageProperties(String listing) {
    final byMonitor = <String, List<String>>{};
    for (final m in RegExp(r'^(/backdrop/screen\d+/monitor([^/\s]+)/workspace\d+/last-image)$', multiLine: true)
        .allMatches(listing)) {
      (byMonitor[m[2]!] ??= []).add(m[1]!);
    }
    return byMonitor;
  }

  /// Xfce's `image-style`: 1 centred, 3 stretched, 4 scaled, 5 zoomed.
  static int styleFor(FitMode fit) => switch (fit) {
    FitMode.centre => 1,
    FitMode.stretch => 3,
    FitMode.fit => 4,
    FitMode.fill => 5,
  };

  @override
  Future<List<DisplayTarget>> targets() async {
    final monitors = imageProperties(await _list()).keys.toList();
    var outputs = <Output>[];
    try {
      outputs = parseXrandrMonitors(await _tools.call('xrandr', ['--listactivemonitors']));
    } on WallpaperSetterException {
      // Sizes fall back below.
    }
    final known = {for (final o in outputs) o.name: o};
    return monitorTargets([
      for (final (i, name) in monitors.indexed)
        known[name] ?? (name: name, x: i * 1920, y: 0, width: 1920, height: 1080, primary: i == 0),
    ]);
  }

  @override
  Future<void> apply(List<Assignment> assignments) async {
    final listing = await _list();
    final existing = {for (final line in listing.split('\n')) line.trim()};
    final properties = imageProperties(listing);
    for (final a in assignments.where((a) => a.target.surface == TargetSurface.home)) {
      final paths = properties[a.target.id] ??
          (throw WallpaperSetterException('${a.target.label} is no longer connected.'));
      for (final imageProperty in paths) {
        await _xfconf(['-p', imageProperty, '-s', a.imagePath]);
        final styleProperty = imageProperty.replaceFirst(RegExp(r'last-image$'), 'image-style');
        await _xfconf([
          '-p', styleProperty,
          // Create it if Xfce hasn't yet.
          if (!existing.contains(styleProperty)) ...['-n', '-t', 'int'],
          '-s', '${styleFor(a.fit)}',
        ]);
      }
    }
  }

  Future<String> _list() => _xfconf(['-l']);

  Future<String> _xfconf(List<String> args) => _tools.call(
    'xfconf-query',
    ['-c', 'xfce4-desktop', ...args],
    missing: "Couldn't find xfconf-query.",
  );
}
