import 'dart:io';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../models/attribution.dart';
import '../models/display_target.dart';
import '../models/orientation.dart';
import '../settings/settings_store.dart';
import 'database.dart';
import 'hashing.dart';
import 'image_header.dart';
import 'library_layout.dart';
import 'sidecar.dart';

final _log = Logger('Library');

enum LibrarySort {
  newest('Newest first'),
  oldest('Oldest first'),
  lastUsed('Recently used'),
  mostUsed('Most used'),
  resolution('Highest resolution');

  const LibrarySort(this.label);
  final String label;
}

final class RescanResult {
  const RescanResult({
    this.added = 0,
    this.moved = 0,
    this.removed = 0,
    this.skipped = 0,
  });

  /// New images found in the folder.
  final int added;

  /// Known images found at a different path.
  final int moved;

  /// Entries whose file has gone.
  final int removed;

  /// Unreadable images and duplicates of images already in the library.
  final int skipped;

  bool get changed => added + moved + removed > 0;

  @override
  String toString() =>
      'RescanResult(added: $added, moved: $moved, removed: $removed, skipped: $skipped)';
}

class LibraryException implements Exception {
  LibraryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// What the library grid shows. Text matches title, credits, source and tags.
final class LibraryFilter {
  const LibraryFilter({
    this.text = '',
    this.source,
    this.orientation,
    this.favouritesOnly = false,
    this.hiddenOnly = false,
    this.tag,
  });

  static const _unset = Object();

  final String text;
  final String? source;
  final WallpaperOrientation? orientation;
  final bool favouritesOnly;
  final bool hiddenOnly;
  final String? tag;

  bool get isEmpty =>
      text.trim().isEmpty &&
      source == null &&
      orientation == null &&
      !favouritesOnly &&
      !hiddenOnly &&
      tag == null;

  LibraryFilter copyWith({
    String? text,
    Object? source = _unset,
    Object? orientation = _unset,
    bool? favouritesOnly,
    bool? hiddenOnly,
    Object? tag = _unset,
  }) => LibraryFilter(
    text: text ?? this.text,
    source: identical(source, _unset) ? this.source : source as String?,
    orientation: identical(orientation, _unset)
        ? this.orientation
        : orientation as WallpaperOrientation?,
    favouritesOnly: favouritesOnly ?? this.favouritesOnly,
    hiddenOnly: hiddenOnly ?? this.hiddenOnly,
    tag: identical(tag, _unset) ? this.tag : tag as String?,
  );

  /// The parts that can't be done in SQL: tag and free-text matching.
  bool matches(LibraryItem item) {
    if (tag case final wanted?) {
      final lower = wanted.toLowerCase();
      if (!item.tags.any((t) => t.toLowerCase() == lower)) return false;
    }
    final words = text.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final haystack = [
      item.title,
      item.authorName,
      item.creditLine,
      item.source,
      item.sourceId,
      ...item.tags,
    ].whereType<String>().join('\n').toLowerCase();
    return words.every(haystack.contains);
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      other.text == text &&
      other.source == source &&
      other.orientation == orientation &&
      other.favouritesOnly == favouritesOnly &&
      other.hiddenOnly == hiddenOnly &&
      other.tag == tag;

  @override
  int get hashCode => Object.hash(text, source, orientation, favouritesOnly, hiddenOnly, tag);
}

final class ImportResult {
  const ImportResult({this.imported = 0, this.duplicates = 0, this.failed = 0});

  final int imported;

  /// Already in the library (same file contents).
  final int duplicates;

  /// Unreadable images or files that couldn't be copied.
  final int failed;

  @override
  String toString() =>
      'ImportResult(imported: $imported, duplicates: $duplicates, failed: $failed)';
}

/// The downloaded wallpapers: files in the library folder plus their rows in
/// the database. Paths are stored relative to the folder.
class WallpaperLibrary {
  WallpaperLibrary(this._db, this._settings);

  final AppDatabase _db;
  final SettingsStore _settings;
  String? _root;

  /// The library folder, or null before the user has chosen one.
  String? get root => _root;

  String get _requireRoot =>
      _root ?? (throw LibraryException('No library folder has been chosen yet.'));

  Future<void> load() async {
    _root = await _settings.get(SettingsKeys.libraryRoot);
  }

  /// Points the library at [path] without moving anything. Run [rescan] after.
  Future<void> setRoot(String path) async {
    final normalised = p.normalize(p.absolute(path));
    await Directory(normalised).create(recursive: true);
    await _settings.set(SettingsKeys.libraryRoot, normalised);
    _root = normalised;
  }

  String absolutePath(LibraryItem item) => absoluteFor(item.relativePath);

  String absoluteFor(String relativePath) =>
      p.joinAll([_requireRoot, ...p.posix.split(relativePath)]);

  Stream<List<LibraryItem>> watch({
    LibrarySort sort = LibrarySort.newest,
    LibraryFilter filter = const LibraryFilter(),
  }) {
    final query = _db.select(_db.wallpapers)
      ..where((t) {
        Expression<bool> condition = const Constant(true);
        if (filter.source case final s?) condition &= t.source.equals(s);
        if (filter.orientation case final o?) condition &= t.orientation.equalsValue(o);
        if (filter.favouritesOnly) condition &= t.isFavourite.equals(true);
        if (filter.hiddenOnly) condition &= t.isHidden.equals(true);
        return condition;
      })
      ..orderBy(_ordering(sort));
    return query.watch().map(
      (items) => [
        for (final item in items)
          if (filter.matches(item)) item,
      ],
    );
  }

  /// Every tag in the library and how many images have it, most used first.
  /// Tags differing only in case count as one (shown as first seen).
  Stream<List<({String tag, int count})>> watchTags() =>
      _db.select(_db.wallpapers).watch().map((items) {
        final counts = <String, int>{};
        final labels = <String, String>{};
        for (final item in items) {
          for (final tag in item.tags) {
            final key = tag.toLowerCase();
            labels.putIfAbsent(key, () => tag);
            counts.update(key, (c) => c + 1, ifAbsent: () => 1);
          }
        }
        return [for (final e in counts.entries) (tag: labels[e.key]!, count: e.value)]..sort(
          (a, b) => a.count != b.count
              ? b.count.compareTo(a.count)
              : a.tag.toLowerCase().compareTo(b.tag.toLowerCase()),
        );
      });

  /// Source ids present in the library.
  Stream<List<String>> watchSourceIds() {
    final w = _db.wallpapers;
    final query = _db.selectOnly(w, distinct: true)..addColumns([w.source]);
    return query.watch().map((rows) => [for (final r in rows) r.read(w.source)!]..sort());
  }

  List<OrderClauseGenerator<$WallpapersTable>> _ordering(LibrarySort sort) =>
      switch (sort) {
        LibrarySort.newest => [
          (t) => OrderingTerm.desc(t.addedAt),
          (t) => OrderingTerm.desc(t.id),
        ],
        LibrarySort.oldest => [
          (t) => OrderingTerm.asc(t.addedAt),
          (t) => OrderingTerm.asc(t.id),
        ],
        LibrarySort.lastUsed => [
          (t) => OrderingTerm(
            expression: t.lastAppliedAt,
            mode: OrderingMode.desc,
            nulls: NullsOrder.last,
          ),
          (t) => OrderingTerm.desc(t.addedAt),
        ],
        LibrarySort.mostUsed => [
          (t) => OrderingTerm.desc(t.applyCount),
          (t) => OrderingTerm.desc(t.addedAt),
        ],
        LibrarySort.resolution => [
          (t) => OrderingTerm.desc(t.width * t.height),
          (t) => OrderingTerm.desc(t.addedAt),
        ],
      };

  /// `source:sourceId` of everything in the library, for "already downloaded"
  /// badges.
  Stream<Set<String>> watchDownloadedKeys() {
    final w = _db.wallpapers;
    final query = _db.selectOnly(w)..addColumns([w.source, w.sourceId]);
    return query.watch().map(
      (rows) => {for (final r in rows) '${r.read(w.source)}:${r.read(w.sourceId)}'},
    );
  }

  Future<LibraryItem?> byId(int id) =>
      (_db.select(_db.wallpapers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<LibraryItem?> watchById(int id) =>
      (_db.select(_db.wallpapers)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<LibraryItem?> bySource(String source, String sourceId) =>
      (_db.select(_db.wallpapers)
            ..where((t) => t.source.equals(source) & t.sourceId.equals(sourceId)))
          .getSingleOrNull();

  Future<LibraryItem?> byHash(String sha256) =>
      (_db.select(_db.wallpapers)
            ..where((t) => t.sha256.equals(sha256))
            ..limit(1))
          .getSingleOrNull();

  Future<LibraryItem> insert(
    Sidecar meta, {
    required String relativePath,
    required int width,
    required int height,
    required int fileSize,
    required String sha256,
  }) async {
    final a = meta.attribution;
    final id = await _db
        .into(_db.wallpapers)
        .insert(
          WallpapersCompanion.insert(
            source: meta.source,
            sourceId: meta.sourceId,
            relativePath: relativePath,
            width: width,
            height: height,
            orientation: WallpaperOrientation.of(width, height),
            fileSize: fileSize,
            sha256: sha256,
            addedAt: meta.downloadedAt ?? DateTime.now(),
            sourcePageUrl: Value(meta.pageUrl),
            downloadUrl: Value(meta.downloadUrl),
            title: Value(meta.title),
            authorName: Value(a.authorName),
            authorUrl: Value(a.authorUrl),
            licence: Value(a.licence),
            creditLine: Value(a.creditLine),
            tags: Value(meta.tags),
            dominantColour: Value(meta.dominantColour),
            isFavourite: Value(meta.favourite),
            isHidden: Value(meta.hidden),
          ),
        );
    return (await byId(id))!;
  }

  /// Deletes the image, its sidecar and its database entry.
  Future<void> delete(LibraryItem item) async {
    final path = absolutePath(item);
    try {
      final image = File(path);
      if (await image.exists()) await image.delete();
    } on FileSystemException catch (e) {
      throw LibraryException("Couldn't delete ${p.basename(path)}.", cause: e);
    }
    try {
      final sidecar = File(LibraryLayout.sidecarFor(path));
      if (await sidecar.exists()) await sidecar.delete();
    } on FileSystemException catch (e) {
      _log.warning('Left a sidecar behind for $path: $e');
    }
    await (_db.delete(_db.wallpapers)..where((t) => t.id.equals(item.id))).go();
  }

  Future<void> setFavourite(LibraryItem item, bool favourite) =>
      _update(item, WallpapersCompanion(isFavourite: Value(favourite)));

  /// Hidden images stay in the library but are left out of rotation.
  Future<void> setHidden(LibraryItem item, bool hidden) =>
      _update(item, WallpapersCompanion(isHidden: Value(hidden)));

  /// Replaces the tags, dropping blanks and case-insensitive repeats.
  Future<void> setTags(LibraryItem item, List<String> tags) {
    final seen = <String>{};
    final clean = [
      for (final t in tags.map((t) => t.trim()))
        if (t.isNotEmpty && seen.add(t.toLowerCase())) t,
    ];
    return _update(item, WallpapersCompanion(tags: Value(clean)));
  }

  Future<void> _update(LibraryItem item, WallpapersCompanion changes) async {
    await (_db.update(_db.wallpapers)..where((t) => t.id.equals(item.id))).write(changes);
    final updated = await byId(item.id);
    if (updated != null) await _writeSidecar(updated);
  }

  /// Keeps the sidecar in step with the library state (tags, favourite,
  /// hidden) so a rescan restores it. Creates one for local images.
  Future<void> _writeSidecar(LibraryItem item) async {
    final path = LibraryLayout.sidecarFor(absolutePath(item));
    final base = await Sidecar.read(path) ??
        Sidecar(
          source: item.source,
          sourceId: item.sourceId,
          pageUrl: item.sourcePageUrl,
          downloadUrl: item.downloadUrl,
          title: item.title,
          attribution: Attribution(
            authorName: item.authorName,
            authorUrl: item.authorUrl,
            licence: item.licence,
            creditLine: item.creditLine,
          ),
          dominantColour: item.dominantColour,
          downloadedAt: item.addedAt,
        );
    try {
      await base
          .copyWith(tags: item.tags, favourite: item.isFavourite, hidden: item.isHidden)
          .write(path);
    } on FileSystemException catch (e) {
      _log.warning("Couldn't update the sidecar for ${item.relativePath}: $e");
    }
  }

  Future<void> recordApplied(
    LibraryItem item,
    Iterable<String> targetIds, {
    bool viaHistory = false,
    FitMode? fit,
  }) =>
      _db.transaction(() async {
        final now = DateTime.now();
        for (final target in targetIds) {
          await _db
              .into(_db.applyHistory)
              .insert(
                ApplyHistoryCompanion.insert(
                  wallpaperId: Value(item.id),
                  appliedAt: now,
                  target: target,
                  viaHistory: Value(viaHistory),
                  fit: Value(fit),
                ),
              );
        }
        await (_db.update(_db.wallpapers)..where((t) => t.id.equals(item.id)))
            .write(
              WallpapersCompanion.custom(
                lastAppliedAt: Variable(now),
                applyCount: _db.wallpapers.applyCount + const Constant(1),
              ),
            );
      });

  /// Brings the database in line with the folder: adds images that appeared,
  /// follows images that moved, and drops entries whose file is gone.
  Future<RescanResult> rescan() async {
    final root = _requireRoot;
    final dir = Directory(root);
    if (!await dir.exists()) {
      throw LibraryException('The library folder $root no longer exists.');
    }

    final rows = await _db.select(_db.wallpapers).get();
    final byPath = {for (final r in rows) r.relativePath: r};
    final seen = <String>{};
    final newFiles = <String>[];

    final entities = dir
        .list(recursive: true, followLinks: false)
        .handleError((Object e) => _log.warning('Skipping during rescan: $e'));
    await for (final entity in entities) {
      if (entity is! File || !LibraryLayout.isImage(entity.path)) continue;
      final relative = LibraryLayout.toStored(p.relative(entity.path, from: root));
      if (relative.split('/').any((part) => part.startsWith('.'))) continue;
      if (byPath.containsKey(relative)) {
        seen.add(relative);
      } else {
        newFiles.add(relative);
      }
    }

    final missingByHash = {
      for (final r in rows)
        if (!seen.contains(r.relativePath)) r.sha256: r,
    };
    var added = 0, moved = 0, skipped = 0;

    for (final relative in newFiles..sort()) {
      final path = absoluteFor(relative);
      try {
        final hash = await hashFile(path);
        final movedRow = missingByHash.remove(hash);
        if (movedRow != null) {
          await (_db.update(_db.wallpapers)..where((t) => t.id.equals(movedRow.id)))
              .write(WallpapersCompanion(relativePath: Value(relative)));
          moved++;
          continue;
        }
        if (await byHash(hash) != null) {
          skipped++; // a copy of something already in the library
          continue;
        }
        final size = await readImageSizeFromFile(path);
        if (size == null) {
          _log.warning("Can't read image size of $relative; skipping");
          skipped++;
          continue;
        }
        var meta = await Sidecar.read(LibraryLayout.sidecarFor(path));
        if (meta == null || await bySource(meta.source, meta.sourceId) != null) {
          meta = Sidecar.local(hash);
        }
        await insert(
          meta,
          relativePath: relative,
          width: size.width,
          height: size.height,
          fileSize: await File(path).length(),
          sha256: hash,
        );
        added++;
      } on FileSystemException catch (e) {
        _log.warning('Skipping $relative: $e');
        skipped++;
      }
    }

    for (final gone in missingByHash.values) {
      await (_db.delete(_db.wallpapers)..where((t) => t.id.equals(gone.id))).go();
    }

    final result = RescanResult(
      added: added,
      moved: moved,
      removed: missingByHash.length,
      skipped: skipped,
    );
    _log.info('Rescanned $root: $result');
    return result;
  }

  /// Moves every image (and its sidecar) to [newRoot] and switches to it.
  Future<void> moveTo(String newRoot) async {
    final oldRoot = _requireRoot;
    final target = p.normalize(p.absolute(newRoot));
    if (p.equals(oldRoot, target)) return;
    if (p.isWithin(oldRoot, target)) {
      throw LibraryException("The new folder can't be inside the current library folder.");
    }
    await Directory(target).create(recursive: true);
    for (final item in await _db.select(_db.wallpapers).get()) {
      final from = absolutePath(item);
      final to = p.joinAll([target, ...p.posix.split(item.relativePath)]);
      await _moveFile(from, to);
      await _moveFile(LibraryLayout.sidecarFor(from), LibraryLayout.sidecarFor(to));
    }
    await setRoot(target);
  }

  /// Copies (or moves) every image in [folder], including sub-folders, into
  /// `local/<folder name>/` in the library. Images already in the library are
  /// skipped.
  Future<ImportResult> importFolder(String folder, {bool move = false}) async {
    final root = _requireRoot;
    final source = p.normalize(p.absolute(folder));
    if (p.equals(source, root) || p.isWithin(root, source)) {
      throw LibraryException('That folder is already part of your library.');
    }
    if (p.isWithin(source, root)) {
      throw LibraryException(
        "Your library is inside that folder, so it can't be imported. "
        "Pick a folder that doesn't contain the library.",
      );
    }
    final dir = Directory(source);
    if (!await dir.exists()) throw LibraryException('$source no longer exists.');

    final files = <String>[];
    final entities = dir
        .list(recursive: true, followLinks: false)
        .handleError((Object e) => _log.warning('Skipping during import: $e'));
    await for (final entity in entities) {
      if (entity is! File || !LibraryLayout.isImage(entity.path)) continue;
      final relative = p.relative(entity.path, from: source);
      if (p.split(relative).any((part) => part.startsWith('.'))) continue;
      files.add(entity.path);
    }
    files.sort();

    final folderName = p.basename(source).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    var imported = 0, duplicates = 0, failed = 0;
    for (final file in files) {
      try {
        final hash = await hashFile(file);
        if (await byHash(hash) != null) {
          duplicates++;
          continue;
        }
        final size = await readImageSizeFromFile(file);
        if (size == null) {
          _log.warning("Can't read image size of $file; not importing it");
          failed++;
          continue;
        }
        final relative = await _freeRelativePath(
          p.posix.join(Sidecar.localSource, folderName, LibraryLayout.toStored(p.relative(file, from: source))),
        );
        final destination = absoluteFor(relative);
        await File(destination).parent.create(recursive: true);
        if (move) {
          await _moveFile(file, destination);
        } else {
          await File(file).copy(destination);
        }
        await insert(
          Sidecar.local(hash),
          relativePath: relative,
          width: size.width,
          height: size.height,
          fileSize: await File(destination).length(),
          sha256: hash,
        );
        imported++;
      } on FileSystemException catch (e) {
        _log.warning('Import of $file failed: $e');
        failed++;
      }
    }
    final result = ImportResult(imported: imported, duplicates: duplicates, failed: failed);
    _log.info('Imported from $source: $result');
    return result;
  }

  /// [relative], or `name (2).ext`, `name (3).ext`... if it's taken.
  Future<String> _freeRelativePath(String relative) async {
    var candidate = relative;
    for (var n = 2; ; n++) {
      final inDb = await (_db.select(_db.wallpapers)
            ..where((t) => t.relativePath.equals(candidate)))
          .getSingleOrNull();
      if (inDb == null && !await File(absoluteFor(candidate)).exists()) return candidate;
      candidate = '${p.posix.withoutExtension(relative)} ($n)${p.posix.extension(relative)}';
    }
  }

  static Future<void> _moveFile(String from, String to) async {
    final file = File(from);
    if (!await file.exists()) return;
    await File(to).parent.create(recursive: true);
    try {
      await file.rename(to);
    } on FileSystemException {
      // Different drive: rename can't cross file systems.
      await file.copy(to);
      await file.delete();
    }
  }
}
