import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/display_target.dart';
import '../models/orientation.dart';

part 'database.g.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// One image in the library.
@DataClassName('LibraryItem')
@TableIndex(name: 'wallpapers_sha256', columns: {#sha256})
class Wallpapers extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Source id (`wallhaven`, `local`, ...).
  TextColumn get source => text()();

  /// The image's id at its source. For local files, the start of its hash.
  TextColumn get sourceId => text()();
  TextColumn get sourcePageUrl => text().nullable()();
  TextColumn get downloadUrl => text().nullable()();

  /// Relative to the library folder, always with `/` separators.
  TextColumn get relativePath => text().unique()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  TextColumn get orientation => textEnum<WallpaperOrientation>()();
  IntColumn get fileSize => integer()();
  TextColumn get sha256 => text()();
  TextColumn get title => text().nullable()();
  TextColumn get authorName => text().nullable()();
  TextColumn get authorUrl => text().nullable()();
  TextColumn get licence => text().nullable()();
  TextColumn get creditLine => text().nullable()();
  TextColumn get tags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  /// 0xAARRGGBB.
  IntColumn get dominantColour => integer().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastAppliedAt => dateTime().nullable()();
  IntColumn get applyCount => integer().withDefault(const Constant(0))();
  BoolColumn get isFavourite => boolean().withDefault(const Constant(false))();

  /// Kept in the library but left out of rotation.
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {source, sourceId},
  ];
}

class ApplyHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wallpaperId => integer().nullable().references(
    Wallpapers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get appliedAt => dateTime()();

  /// [DisplayTarget.id], e.g. `DP-1` or `lock`.
  TextColumn get target => text()();

  /// Applied by stepping back/forward through history; such entries don't
  /// become new history positions themselves.
  BoolColumn get viaHistory => boolean().withDefault(const Constant(false))();
  TextColumn get fit => textEnum<FitMode>().nullable()();
}

@DataClassName('SettingEntry')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Wallpapers, ApplyHistory, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(applyHistory, applyHistory.viaHistory);
        await m.addColumn(applyHistory, applyHistory.fit);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
