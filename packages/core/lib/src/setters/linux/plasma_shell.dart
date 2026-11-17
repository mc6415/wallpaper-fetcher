import 'package:dbus/dbus.dart';

/// Runs Plasma desktop scripts, like
/// `qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript '...'`.
abstract interface class PlasmaShell {
  /// Returns whatever the script `print()`s.
  Future<String> evaluateScript(String script);
}

class DBusPlasmaShell implements PlasmaShell {
  DBusPlasmaShell({DBusClient? client}) : _client = client ?? DBusClient.session();

  final DBusClient _client;

  late final _shell = DBusRemoteObject(
    _client,
    name: 'org.kde.plasmashell',
    path: DBusObjectPath('/PlasmaShell'),
  );

  @override
  Future<String> evaluateScript(String script) async {
    final result = await _shell.callMethod(
      'org.kde.PlasmaShell',
      'evaluateScript',
      [DBusString(script)],
      replySignature: DBusSignature('s'),
    );
    return result.returnValues.first.asString();
  }

  Future<void> close() => _client.close();
}
