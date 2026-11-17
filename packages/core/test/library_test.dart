import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

void main() {
  late Directory temp;
  late AppDatabase db;
  late WallpaperLibrary library;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wf_library_');
    db = AppDatabase(NativeDatabase.memory());
    library = WallpaperLibrary(db, SettingsStore(db));
    await library.setRoot(p.join(temp.path, 'library'));
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  /// Writes an image into the library folder and returns its relative path.
  Future<String> addFile(String relative, {int width = 3840, int height = 2160, int seed = 0}) async {
    final file = File(library.absoluteFor(relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fakePng(width, height, seed: seed));
    return relative;
  }

  test('root persists in settings', () async {
    final reopened = WallpaperLibrary(db, SettingsStore(db));
    await reopened.load();
    expect(reopened.root, library.root);
  });

  test('rescan adds new files, using sidecars when present', () async {
    await addFile('loose.png', seed: 1);
    final rel = await addFile('wallhaven/wallhaven_abc.png', seed: 2);
    await const Sidecar(
      source: 'wallhaven',
      sourceId: 'abc',
      tags: ['mountains'],
      attribution: Attribution(authorName: 'alice', creditLine: 'Uploaded to Wallhaven by alice'),
    ).write(LibraryLayout.sidecarFor(library.absoluteFor(rel)));

    final result = await library.rescan();

    expect(result.added, 2);
    final items = await library.watch().first;
    final fromWallhaven = items.singleWhere((i) => i.source == 'wallhaven');
    expect(fromWallhaven.sourceId, 'abc');
    expect(fromWallhaven.tags, ['mountains']);
    expect(fromWallhaven.authorName, 'alice');
    expect(fromWallhaven.width, 3840);
    expect(fromWallhaven.orientation, WallpaperOrientation.landscape);
    final loose = items.singleWhere((i) => i.source == Sidecar.localSource);
    expect(loose.sourceId, hasLength(16));
    expect(loose.relativePath, 'loose.png');
  });

  test('rescan follows moved files and drops deleted ones', () async {
    await addFile('a.png', seed: 1);
    await addFile('b.png', seed: 2);
    await library.rescan();
    final before = await library.watch().first;
    final a = before.singleWhere((i) => i.relativePath == 'a.png');

    await File(library.absoluteFor('a.png')).rename(library.absoluteFor('moved.png'));
    await File(library.absoluteFor('b.png')).delete();
    final result = await library.rescan();

    expect(result.moved, 1);
    expect(result.removed, 1);
    final after = await library.watch().first;
    expect(after.single.id, a.id, reason: 'moved file keeps its entry and history');
    expect(after.single.relativePath, 'moved.png');
  });

  test('rescan skips duplicates, hidden folders and non-images', () async {
    await addFile('one.png', seed: 7);
    await addFile('copy/one.png', seed: 7);
    await addFile('.thumbs/x.png', seed: 8);
    await File(library.absoluteFor('notes.txt')).writeAsString('hi');

    final result = await library.rescan();

    expect(result.added, 1);
    expect(result.skipped, 1);
  });

  test('recordApplied updates counts and sorts by most used', () async {
    await addFile('a.png', seed: 1);
    await addFile('b.png', seed: 2);
    await library.rescan();
    final b = (await library.watch().first).singleWhere((i) => i.relativePath == 'b.png');

    await library.recordApplied(b, ['DP-1', 'DP-2']);

    final mostUsed = await library.watch(sort: LibrarySort.mostUsed).first;
    expect(mostUsed.first.relativePath, 'b.png');
    expect(mostUsed.first.applyCount, 1);
    expect(mostUsed.first.lastAppliedAt, isNotNull);
    final history = await db.select(db.applyHistory).get();
    expect(history.map((h) => h.target), ['DP-1', 'DP-2']);
  });

  test('delete removes file, sidecar and entry; history survives', () async {
    final rel = await addFile('wallhaven/wallhaven_x.png');
    final sidecar = LibraryLayout.sidecarFor(library.absoluteFor(rel));
    await const Sidecar(source: 'wallhaven', sourceId: 'x').write(sidecar);
    await library.rescan();
    final item = (await library.watch().first).single;
    await library.recordApplied(item, ['DP-1']);

    await library.delete(item);

    expect(File(library.absoluteFor(rel)).existsSync(), isFalse);
    expect(File(sidecar).existsSync(), isFalse);
    expect(await library.watch().first, isEmpty);
    expect((await db.select(db.applyHistory).get()).single.wallpaperId, isNull);
  });

  test('moveTo moves files and sidecars and switches root', () async {
    final rel = await addFile('wallhaven/wallhaven_x.png');
    await const Sidecar(source: 'wallhaven', sourceId: 'x')
        .write(LibraryLayout.sidecarFor(library.absoluteFor(rel)));
    await library.rescan();
    final newRoot = p.join(temp.path, 'elsewhere');

    await library.moveTo(newRoot);

    expect(library.root, newRoot);
    expect(File(p.join(newRoot, 'wallhaven', 'wallhaven_x.png')).existsSync(), isTrue);
    expect(File(p.join(newRoot, 'wallhaven', 'wallhaven_x.json')).existsSync(), isTrue);
    expect((await library.rescan()).changed, isFalse);
  });

  test('moveTo refuses a folder inside the current library', () {
    expect(() => library.moveTo(p.join(library.root!, 'inner')), throwsA(isA<LibraryException>()));
  });

  test('downloaded keys stream', () async {
    final rel = await addFile('wallhaven/wallhaven_k.png');
    await const Sidecar(source: 'wallhaven', sourceId: 'k')
        .write(LibraryLayout.sidecarFor(library.absoluteFor(rel)));
    await library.rescan();
    expect(await library.watchDownloadedKeys().first, {'wallhaven:k'});
  });
}
