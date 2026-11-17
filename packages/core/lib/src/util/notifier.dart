import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

final _log = Logger('Notify');

/// Desktop notifications (org.freedesktop.Notifications), used when there's
/// nowhere else to show a message: tray actions, and commands run from a
/// keyboard shortcut. Each new one replaces the last, so repeated key presses
/// don't stack up.
class DesktopNotifier {
  int _lastId = 0;

  Future<void> notify(String summary, String body, {String icon = 'preferences-desktop-wallpaper'}) async {
    if (!Platform.isLinux) return;
    final client = DBusClient.session();
    try {
      final result = await DBusRemoteObject(
        client,
        name: 'org.freedesktop.Notifications',
        path: DBusObjectPath('/org/freedesktop/Notifications'),
      ).callMethod(
        'org.freedesktop.Notifications',
        'Notify',
        [
          const DBusString('Wallpaper Fetcher'),
          DBusUint32(_lastId),
          DBusString(icon),
          DBusString(summary),
          DBusString(body),
          DBusArray.string(const []),
          DBusDict.stringVariant(const {}),
          const DBusInt32(4000),
        ],
        replySignature: DBusSignature('u'),
      );
      _lastId = result.returnValues.first.asUint32();
    } on Object catch (e) {
      _log.info('Notification not shown: $e');
    } finally {
      await client.close();
    }
  }
}
