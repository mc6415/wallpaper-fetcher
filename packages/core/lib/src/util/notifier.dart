import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../setters/windows/lock_screen.dart' show LockScreenSetter, PowerShellRunner;
import 'app_paths.dart';

final _log = Logger('Notify');

Future<ProcessResult> _run(String executable, List<String> arguments, {Map<String, String>? environment}) =>
    Process.run(executable, arguments, environment: environment);

/// Desktop notifications, used when there's nowhere else to show a message:
/// tray actions, and commands run from a keyboard shortcut. Each new one
/// replaces the last, so repeated key presses don't stack up.
///
/// Linux: org.freedesktop.Notifications. Windows: a toast, which Windows only
/// shows for an app id registered by a Start menu shortcut, so only once the
/// installer has run.
class DesktopNotifier {
  DesktopNotifier({PowerShellRunner run = _run}) : _runner = run;

  final PowerShellRunner _runner;
  int _lastId = 0;

  /// Builds the toast from environment variables, so nothing needs quoting.
  static const windowsScript = r'''
$ErrorActionPreference = 'Stop'
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
$escape = [System.Security.SecurityElement]
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$($escape::Escape($env:WALLPAPER_FETCHER_TITLE))</text><text>$($escape::Escape($env:WALLPAPER_FETCHER_BODY))</text></binding></visual></toast>")
$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
$toast.Tag = 'wallpaper-fetcher'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($env:WALLPAPER_FETCHER_APP_ID).Show($toast)
''';

  /// Whether the notification was handed to the desktop.
  Future<bool> notify(String summary, String body, {String icon = 'preferences-desktop-wallpaper'}) async {
    if (Platform.isWindows) return _windowsToast(summary, body);
    if (!Platform.isLinux) return false;
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
      return true;
    } on Object catch (e) {
      _log.info('Notification not shown: $e');
      return false;
    } finally {
      await client.close();
    }
  }

  Future<bool> _windowsToast(String summary, String body) async {
    try {
      final result = await _runner(
        LockScreenSetter.powerShell,
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-Command', windowsScript],
        environment: {
          'WALLPAPER_FETCHER_TITLE': summary,
          'WALLPAPER_FETCHER_BODY': body,
          'WALLPAPER_FETCHER_APP_ID': AppPaths.appId,
        },
      );
      if (result.exitCode == 0) return true;
      _log.info('Notification not shown: ${'${result.stderr}'.trim()}');
    } on ProcessException catch (e) {
      _log.info('Notification not shown: $e');
    }
    return false;
  }
}
