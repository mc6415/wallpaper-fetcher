import '../library/database.dart';

abstract final class SettingsKeys {
  static const libraryRoot = 'library.root';

  /// `3840x2160`, or `any`.
  static const minResolution = 'browse.minResolution';

  /// `system`, `light` or `dark`.
  static const themeMode = 'ui.themeMode';

  /// Comma-separated source ids shown in Browse. Missing means all.
  static const enabledSources = 'sources.enabled';

  /// Comma-separated source ids with a key in the system keyring, so the
  /// keyring is only touched (and possibly asks to be unlocked) when needed.
  static const savedApiKeys = 'apiKeys.saved';

  /// [RotationConfig] as JSON.
  static const rotationConfig = 'rotation.config';
  static const rotationPaused = 'rotation.paused';

  /// When rotation last changed the wallpaper (ISO 8601, UTC).
  static const rotationLastRun = 'rotation.lastRun';

  /// Key of the daily picture last applied, so it isn't applied twice.
  static const rotationDailyLast = 'rotation.daily.last';

  /// `false` to quit instead of hiding to the tray when the window closes.
  static const keepInTray = 'desktop.keepInTray';

  /// `true` to put wallpapers on KDE through the Blurred Wallpaper plugin
  /// (blurs while a window is active), when it's installed.
  static const kdeBlurredWallpaper = 'kde.blurredWallpaper';
}

/// String key/value settings stored in the library database.
class SettingsStore {
  SettingsStore(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<Map<String, String>> all() async => {
    for (final row in await _db.select(_db.settings).get()) row.key: row.value,
  };

  /// A null [value] removes the setting.
  Future<void> set(String key, String? value) async {
    if (value == null) {
      await (_db.delete(_db.settings)..where((t) => t.key.equals(key))).go();
    } else {
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
    }
  }
}
