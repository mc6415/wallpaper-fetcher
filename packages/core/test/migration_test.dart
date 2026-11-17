import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:wallpaper_core/src/library/database.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

/// The schema as Phase 1 (version 1) created it, copied from a real database.
const _v1 = [
  'CREATE TABLE "wallpapers" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "source" TEXT NOT NULL, "source_id" TEXT NOT NULL, "source_page_url" TEXT NULL, "download_url" TEXT NULL, "relative_path" TEXT NOT NULL UNIQUE, "width" INTEGER NOT NULL, "height" INTEGER NOT NULL, "orientation" TEXT NOT NULL, "file_size" INTEGER NOT NULL, "sha256" TEXT NOT NULL, "title" TEXT NULL, "author_name" TEXT NULL, "author_url" TEXT NULL, "licence" TEXT NULL, "credit_line" TEXT NULL, "tags" TEXT NOT NULL DEFAULT \'[]\', "dominant_colour" INTEGER NULL, "added_at" INTEGER NOT NULL, "last_applied_at" INTEGER NULL, "apply_count" INTEGER NOT NULL DEFAULT 0, "is_favourite" INTEGER NOT NULL DEFAULT 0 CHECK ("is_favourite" IN (0, 1)), "is_hidden" INTEGER NOT NULL DEFAULT 0 CHECK ("is_hidden" IN (0, 1)), UNIQUE ("source", "source_id"))',
  'CREATE TABLE "apply_history" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "wallpaper_id" INTEGER NULL REFERENCES wallpapers (id) ON DELETE SET NULL, "applied_at" INTEGER NOT NULL, "target" TEXT NOT NULL)',
  'CREATE TABLE "settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"))',
  'CREATE INDEX wallpapers_sha256 ON wallpapers (sha256)',
];

void main() {
  test('a Phase 1 database upgrades to version 2 and keeps its data', () async {
    final temp = await Directory.systemTemp.createTemp('wf_migration_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File(p.join(temp.path, 'library.sqlite'));

    final old = sqlite3.open(file.path);
    for (final statement in _v1) {
      old.execute(statement);
    }
    old
      ..execute(
        "INSERT INTO wallpapers (source, source_id, relative_path, width, height, orientation, file_size, sha256, added_at) "
        "VALUES ('wallhaven', 'abc', 'wallhaven/wallhaven_abc.jpg', 3840, 2160, 'landscape', 100, 'hash', 1763400000)",
      )
      ..execute("INSERT INTO apply_history (wallpaper_id, applied_at, target) VALUES (1, 1763400100, 'DP-1')")
      ..execute("INSERT INTO settings (key, value) VALUES ('library.root', '/home/me/Pictures/Wallpapers')")
      ..execute('PRAGMA user_version = 1');
    old.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final history = await db.select(db.applyHistory).get();

    expect(history.single.target, 'DP-1');
    expect(history.single.viaHistory, isFalse);
    expect(history.single.fit, isNull);
    expect((await db.select(db.wallpapers).get()).single.sourceId, 'abc');
    expect(await SettingsStore(db).get(SettingsKeys.libraryRoot), '/home/me/Pictures/Wallpapers');

    // New columns are writable.
    await db.into(db.applyHistory).insert(
      ApplyHistoryCompanion.insert(appliedAt: DateTime(2026), target: 'lock', fit: const Value(FitMode.fit)),
    );
    expect((await db.select(db.applyHistory).get()).last.fit, FitMode.fit);
  });
}
