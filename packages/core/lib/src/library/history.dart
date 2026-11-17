import 'dart:async';

import 'package:drift/drift.dart';

import '../models/display_target.dart';
import '../settings/settings_store.dart';
import 'database.dart';

final class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.target,
    required this.appliedAt,
    required this.viaHistory,
    this.item,
    this.fit,
  });

  final int id;

  /// [DisplayTarget.id].
  final String target;
  final DateTime appliedAt;
  final bool viaHistory;

  /// Null if the image has since been deleted.
  final LibraryItem? item;
  final FitMode? fit;
}

/// What a target shows now (as far as this app knows) and whether Previous /
/// Next have anywhere to go.
final class NowShowing {
  const NowShowing({
    required this.targetId,
    this.item,
    this.appliedAt,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  final String targetId;
  final LibraryItem? item;
  final DateTime? appliedAt;
  final bool canGoBack;
  final bool canGoForward;
}

final class HistoryStep {
  const HistoryStep(this.item, this.fit, this.position);

  final LibraryItem item;
  final FitMode? fit;

  /// Index into the target's timeline (0 = most recent).
  final int position;
}

/// Previous/next through what each screen has shown.
///
/// Each target has a timeline of the images applied to it normally, newest
/// first. Stepping back and forth moves a cursor along that timeline (saved in
/// settings, so the command line shares it) and doesn't add to it. A normal
/// apply resets the cursor to the newest end.
class WallpaperHistory {
  WallpaperHistory(this._db, this._settings);

  final AppDatabase _db;
  final SettingsStore _settings;

  static String _cursorKey(String targetId) => 'history.cursor.$targetId';

  Stream<List<HistoryEntry>> watchRecent({int limit = 200}) {
    final h = _db.applyHistory;
    final w = _db.wallpapers;
    final query = _db.select(h).join([leftOuterJoin(w, w.id.equalsExp(h.wallpaperId))])
      ..orderBy([OrderingTerm.desc(h.appliedAt), OrderingTerm.desc(h.id)])
      ..limit(limit);
    return query.watch().map(
      (rows) => [for (final r in rows) _entry(r.readTable(h), r.readTableOrNull(w))],
    );
  }

  /// Images normally applied to [targetId], newest first, with consecutive
  /// repeats collapsed and deleted images left out.
  Future<List<HistoryEntry>> timeline(String targetId) async {
    final h = _db.applyHistory;
    final w = _db.wallpapers;
    final rows = await (_db.select(h).join([innerJoin(w, w.id.equalsExp(h.wallpaperId))])
          ..where(h.target.equals(targetId) & h.viaHistory.equals(false))
          ..orderBy([OrderingTerm.desc(h.appliedAt), OrderingTerm.desc(h.id)])
          ..limit(500))
        .get();
    final timeline = <HistoryEntry>[];
    for (final row in rows) {
      final entry = _entry(row.readTable(h), row.readTable(w));
      if (timeline.isNotEmpty && timeline.last.item!.id == entry.item!.id) continue;
      timeline.add(entry);
    }
    return timeline;
  }

  Future<int> cursor(String targetId) async =>
      int.tryParse(await _settings.get(_cursorKey(targetId)) ?? '') ?? 0;

  Future<void> setCursor(String targetId, int position) =>
      _settings.set(_cursorKey(targetId), position <= 0 ? null : '$position');

  Future<void> resetCursors(Iterable<String> targetIds) async {
    for (final id in targetIds) {
      await setCursor(id, 0);
    }
  }

  /// The image one step older ([back]) or newer from where [targetId] is now,
  /// or null at either end. Doesn't move the cursor; the applier does that
  /// once the wallpaper is actually set.
  Future<HistoryStep?> step(String targetId, {required bool back}) async {
    final timeline = await this.timeline(targetId);
    if (timeline.isEmpty) return null;
    final current = (await cursor(targetId)).clamp(0, timeline.length - 1);
    final next = back ? current + 1 : current - 1;
    if (next < 0 || next >= timeline.length) return null;
    return HistoryStep(timeline[next].item!, timeline[next].fit, next);
  }

  Future<Map<String, NowShowing>> nowShowing() async {
    final h = _db.applyHistory;
    final w = _db.wallpapers;
    final targets = await (_db.selectOnly(h, distinct: true)..addColumns([h.target])).get();
    final result = <String, NowShowing>{};
    for (final target in targets.map((r) => r.read(h.target)!)) {
      final latest = await (_db.select(h).join([leftOuterJoin(w, w.id.equalsExp(h.wallpaperId))])
            ..where(h.target.equals(target))
            ..orderBy([OrderingTerm.desc(h.appliedAt), OrderingTerm.desc(h.id)])
            ..limit(1))
          .getSingle();
      final timeline = await this.timeline(target);
      final position = timeline.isEmpty ? 0 : (await cursor(target)).clamp(0, timeline.length - 1);
      result[target] = NowShowing(
        targetId: target,
        item: latest.readTableOrNull(w),
        appliedAt: latest.readTable(h).appliedAt,
        canGoBack: position + 1 < timeline.length,
        canGoForward: position > 0,
      );
    }
    return result;
  }

  /// [nowShowing], recomputed whenever history, the library or settings
  /// change. (Not an `async*` generator: one parked in `await for` can't be
  /// cancelled until the next database change arrives.)
  Stream<Map<String, NowShowing>> watchNowShowing() {
    late final StreamController<Map<String, NowShowing>> controller;
    StreamSubscription<Set<TableUpdate>>? changes;
    var queue = Future<void>.value();

    void refresh() {
      // One computation at a time, in order.
      queue = queue.then((_) async {
        try {
          final value = await nowShowing();
          if (!controller.isClosed) controller.add(value);
        } on Object catch (e, stack) {
          if (!controller.isClosed) controller.addError(e, stack);
        }
      });
    }

    controller = StreamController(
      onListen: () {
        refresh();
        changes = _db
            .tableUpdates(TableUpdateQuery.onAllTables([_db.applyHistory, _db.wallpapers, _db.settings]))
            .listen((_) => refresh());
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  static HistoryEntry _entry(ApplyHistoryData row, LibraryItem? item) => HistoryEntry(
    id: row.id,
    target: row.target,
    appliedAt: row.appliedAt,
    viaHistory: row.viaHistory,
    item: item,
    fit: row.fit,
  );
}
