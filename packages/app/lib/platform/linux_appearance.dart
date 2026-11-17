import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

final _log = Logger('Appearance');

/// The desktop's accent colour and light/dark preference.
final class Appearance {
  const Appearance({this.accent, this.prefersDark});

  final Color? accent;

  /// Null when the desktop has no preference.
  final bool? prefersDark;
}

/// Reads the accent colour and colour scheme from the XDG desktop portal
/// (`org.freedesktop.appearance`) and follows changes. KDE and GNOME both
/// provide it.
class LinuxAppearanceWatcher {
  final _client = DBusClient.session();
  late final _portal = DBusRemoteObject(
    _client,
    name: 'org.freedesktop.portal.Desktop',
    path: DBusObjectPath('/org/freedesktop/portal/desktop'),
  );
  StreamSubscription<DBusSignal>? _subscription;
  Color? _accent;
  bool? _prefersDark;

  Future<void> start(void Function(Appearance) onChange) async {
    try {
      _accent = parseAccent(await _read('accent-color'));
      _prefersDark = parseColorScheme(await _read('color-scheme'));
      onChange(Appearance(accent: _accent, prefersDark: _prefersDark));
    } on Object catch (e) {
      _log.info('Desktop appearance not available: $e');
      return;
    }
    _subscription = DBusRemoteObjectSignalStream(
      object: _portal,
      interface: 'org.freedesktop.portal.Settings',
      name: 'SettingChanged',
      signature: DBusSignature('ssv'),
    ).listen((signal) {
      if (signal.values[0].asString() != 'org.freedesktop.appearance') return;
      final value = signal.values[2].asVariant();
      switch (signal.values[1].asString()) {
        case 'accent-color':
          _accent = parseAccent(value);
        case 'color-scheme':
          _prefersDark = parseColorScheme(value);
        default:
          return;
      }
      onChange(Appearance(accent: _accent, prefersDark: _prefersDark));
    });
  }

  Future<DBusValue> _read(String key) async {
    final result = await _portal.callMethod(
      'org.freedesktop.portal.Settings',
      'ReadOne',
      [DBusString('org.freedesktop.appearance'), DBusString(key)],
      replySignature: DBusSignature('v'),
    );
    return result.returnValues.first.asVariant();
  }

  /// `(ddd)` in 0..1; anything out of range means "no accent".
  static Color? parseAccent(DBusValue value) {
    if (value is! DBusStruct || value.children.length != 3) return null;
    final rgb = [for (final c in value.children) c is DBusDouble ? c.value : -1.0];
    if (rgb.any((c) => c < 0 || c > 1)) return null;
    return Color.from(alpha: 1, red: rgb[0], green: rgb[1], blue: rgb[2]);
  }

  /// 0 = no preference, 1 = dark, 2 = light.
  static bool? parseColorScheme(DBusValue value) => switch (value) {
    DBusUint32(value: 1) => true,
    DBusUint32(value: 2) => false,
    _ => null,
  };

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _client.close();
  }
}
