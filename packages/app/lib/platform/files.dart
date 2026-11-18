import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

final _log = Logger('Files');

/// `~/Pictures/Wallpapers`, using the desktop's own Pictures folder on Linux.
Future<String> defaultLibraryDirectory() async {
  if (Platform.isLinux) {
    try {
      final result = await Process.run('xdg-user-dir', ['PICTURES']);
      final pictures = (result.stdout as String).trim();
      if (result.exitCode == 0 && pictures.isNotEmpty) return p.join(pictures, 'Wallpapers');
    } on ProcessException {
      // Fall through to ~/Pictures.
    }
    return p.join(Platform.environment['HOME'] ?? '.', 'Pictures', 'Wallpapers');
  }
  if (Platform.isWindows) {
    // The real Pictures folder, which may have moved (OneDrive, another drive).
    final pictures = Win32Desktop.picturesFolder() ??
        p.join(Platform.environment['USERPROFILE'] ?? '.', 'Pictures');
    return p.join(pictures, 'Wallpapers');
  }
  if (Platform.isAndroid) {
    // The app's own folder on shared storage: no permissions needed, visible
    // over USB, but removed when the app is uninstalled.
    final external = await getExternalStorageDirectory();
    if (external != null) return p.join(external.path, 'Wallpapers');
  }
  return p.join((await getApplicationDocumentsDirectory()).path, 'Wallpapers');
}

/// Opening folders and revealing files is for desktops; phones have no
/// general file manager to hand them to.
bool get canOpenFolders => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

Future<void> openFolder(String path) async {
  if (!await launchUrl(Uri.file(path))) _log.warning("Couldn't open $path");
}

/// Opens the file manager with the file selected where possible (Dolphin,
/// Nautilus and others implement org.freedesktop.FileManager1).
Future<void> showInFolder(String filePath) async {
  if (Platform.isLinux) {
    final client = DBusClient.session();
    try {
      await DBusRemoteObject(
        client,
        name: 'org.freedesktop.FileManager1',
        path: DBusObjectPath('/org/freedesktop/FileManager1'),
      ).callMethod(
        'org.freedesktop.FileManager1',
        'ShowItems',
        [DBusArray.string([Uri.file(filePath).toString()]), const DBusString('')],
        replySignature: DBusSignature.empty,
      );
      return;
    } on Object catch (e) {
      _log.info('FileManager1 unavailable, opening the folder instead: $e');
    } finally {
      await client.close();
    }
  }
  if (Platform.isWindows) {
    try {
      await Process.start('explorer.exe', ['/select,', filePath]);
      return;
    } on ProcessException catch (e) {
      _log.info("Couldn't open Explorer at the file, opening the folder instead: $e");
    }
  }
  await openFolder(p.dirname(filePath));
}

Future<void> openWebPage(String url) async {
  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
    _log.warning("Couldn't open $url");
  }
}
