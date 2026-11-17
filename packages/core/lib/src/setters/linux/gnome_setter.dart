import 'package:logging/logging.dart';

import '../../models/display_target.dart';
import '../wallpaper_setter.dart';
import 'kde_setter.dart' show ProcessRunner;
import 'tools.dart';

final _log = Logger('GnomeSetter');

enum GnomeFlavour {
  gnome('GNOME', 'org.gnome.desktop.background'),
  cinnamon('Cinnamon', 'org.cinnamon.desktop.background'),
  mate('MATE', 'org.mate.background');

  const GnomeFlavour(this.label, this.schema);
  final String label;
  final String schema;
}

/// GNOME and its relatives set one wallpaper for all monitors through
/// gsettings. GNOME also has a lock screen picture.
class GnomeSetter implements WallpaperSetter {
  GnomeSetter(this.flavour, {ProcessRunner? runProcess}) : _tools = ToolRunner(runProcess);

  static const desktopId = 'desktop';
  static const lockId = 'lock';

  final GnomeFlavour flavour;
  final ToolRunner _tools;

  @override
  String get name => flavour.label;

  bool get _hasLock => flavour == GnomeFlavour.gnome;

  @override
  Future<SetterCapabilities> capabilities() async => SetterCapabilities(
    perTarget: false,
    lockScreen: _hasLock,
    fitModes: FitMode.values,
    note: '${flavour.label} shows one wallpaper across all monitors.',
  );

  @override
  Future<List<DisplayTarget>> targets() async {
    // Only used for sizes and shape hints; xrandr also works under XWayland.
    var (width, height) = (1920, 1080);
    try {
      final outputs = parseXrandrMonitors(await _tools.call('xrandr', ['--listactivemonitors']));
      if (outputs.isNotEmpty) {
        final biggest = outputs.reduce((a, b) => a.width * a.height >= b.width * b.height ? a : b);
        (width, height) = (biggest.width, biggest.height);
      }
    } on WallpaperSetterException catch (e) {
      _log.fine('No screen sizes from xrandr: $e');
    }
    return [
      DisplayTarget(id: desktopId, label: 'All monitors', width: width, height: height, isPrimary: true),
      if (_hasLock)
        DisplayTarget(id: lockId, label: 'Lock screen', width: width, height: height, surface: TargetSurface.lock),
    ];
  }

  static String optionFor(FitMode fit) => switch (fit) {
    FitMode.fill => 'zoom',
    FitMode.fit => 'scaled',
    FitMode.stretch => 'stretched',
    FitMode.centre => 'centered',
  };

  @override
  Future<void> apply(List<Assignment> assignments) async {
    final home = assignments.where((a) => a.target.surface == TargetSurface.home).firstOrNull;
    final lock = assignments.where((a) => a.target.surface == TargetSurface.lock).firstOrNull;
    if (home != null) {
      final uri = Uri.file(home.imagePath).toString();
      if (flavour == GnomeFlavour.mate) {
        await _set(flavour.schema, 'picture-filename', home.imagePath);
      } else {
        await _set(flavour.schema, 'picture-uri', uri);
        // GNOME 42+ keeps a separate picture for dark mode.
        if (flavour == GnomeFlavour.gnome) await _set(flavour.schema, 'picture-uri-dark', uri);
      }
      await _set(flavour.schema, 'picture-options', optionFor(home.fit));
    }
    if (lock != null && _hasLock) {
      await _set('org.gnome.desktop.screensaver', 'picture-uri', Uri.file(lock.imagePath).toString());
      await _set('org.gnome.desktop.screensaver', 'picture-options', optionFor(lock.fit));
    }
  }

  Future<void> _set(String schema, String key, String value) =>
      _tools.call('gsettings', ['set', schema, key, value], missing: "Couldn't find gsettings.");
}
