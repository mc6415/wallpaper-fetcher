import '../library/database.dart';

abstract final class SettingsKeys {
  static const libraryRoot = 'library.root';

  /// `3840x2160`, or `any`.
  static const minResolution = 'browse.minResolution';

  /// `system`, `light` or `dark`.
  static const themeMode = 'ui.themeMode';
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
