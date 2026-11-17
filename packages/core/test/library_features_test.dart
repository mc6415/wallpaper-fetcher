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
    temp = await Directory.systemTemp.createTemp('wf_features_');
    db = AppDatabase(NativeDatabase.memory());
    library = WallpaperLibrary(db, SettingsStore(db));
    await library.setRoot(p.join(temp.path, 'library'));
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<void> writeImage(String path, {int width = 3840, int height = 2160, int seed = 0}) async {
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(fakePng(width, height, seed: seed));
  }

  /// Adds an image with a sidecar and returns its library entry.
  Future<LibraryItem> add(
    String source,
    String id, {
    int width = 3840,
    int height = 2160,
    List<String> tags = const [],
    String? title,
    String? author,
  }) async {
    final rel = LibraryLayout.relativePathFor(source, id, 'png');
    await writeImage(library.absoluteFor(rel), width: width, height: height, seed: id.hashCode);
    await Sidecar(
      source: source,
      sourceId: id,
      title: title,
      tags: tags,
      attribution: Attribution(authorName: author),
    ).write(LibraryLayout.sidecarFor(library.absoluteFor(rel)));
    await library.rescan();
    return (await library.bySource(source, id))!;
  }

  group('filters', () {
    setUp(() async {
      await add('wallhaven', 'a', tags: ['Mountains', 'snow'], title: 'Alpine lake');
      await add('unsplash', 'b', width: 2000, height: 3000, author: 'Jeff Sheldon', tags: ['city']);
      await add('bing', 'c', title: 'Trail of the Cedars', tags: ['mountains']);
    });

    Future<List<String>> ids(LibraryFilter f) async =>
        [for (final i in await library.watch(filter: f).first) i.sourceId]..sort();

    test('by source and orientation', () async {
      expect(await ids(const LibraryFilter(source: 'unsplash')), ['b']);
      expect(await ids(const LibraryFilter(orientation: WallpaperOrientation.landscape)), ['a', 'c']);
    });

    test('by tag, ignoring case', () async {
      expect(await ids(const LibraryFilter(tag: 'mountains')), ['a', 'c']);
    });

    test('text matches title, author, tags and source; every word must match', () async {
      expect(await ids(const LibraryFilter(text: 'cedars')), ['c']);
      expect(await ids(const LibraryFilter(text: 'jeff')), ['b']);
      expect(await ids(const LibraryFilter(text: 'snow')), ['a']);
      expect(await ids(const LibraryFilter(text: 'bing mountains')), ['c']);
      expect(await ids(const LibraryFilter(text: 'bing city')), isEmpty);
    });

    test('favourites and hidden', () async {
      final a = (await library.bySource('wallhaven', 'a'))!;
      await library.setFavourite(a, true);
      final b = (await library.bySource('unsplash', 'b'))!;
      await library.setHidden(b, true);
      expect(await ids(const LibraryFilter(favouritesOnly: true)), ['a']);
      expect(await ids(const LibraryFilter(hiddenOnly: true)), ['b']);
      expect(const LibraryFilter().isEmpty, isTrue);
      expect(const LibraryFilter(favouritesOnly: true).isEmpty, isFalse);
    });

    test('tag counts and source list', () async {
      final tags = await library.watchTags().first;
      expect(tags.first, (tag: 'Mountains', count: 2), reason: 'Mountains and mountains merge');
      expect(tags.map((t) => t.tag), ['Mountains', 'city', 'snow']);
      expect(await library.watchSourceIds().first, ['bing', 'unsplash', 'wallhaven']);
    });
  });

  test('favourite, hidden and tags are saved to the sidecar and survive a rebuild', () async {
    final item = await add('wallhaven', 'keep', tags: ['old']);
    await library.setFavourite(item, true);
    await library.setHidden(item, true);
    await library.setTags(item, [' sunset ', 'Sunset', '', 'beach']);

    final updated = (await library.byId(item.id))!;
    expect(updated.tags, ['sunset', 'beach'], reason: 'trimmed, blanks and repeats dropped');

    // Simulate losing the database: a fresh one rebuilt from the folder.
    final rebuiltDb = AppDatabase(NativeDatabase.memory());
    addTearDown(rebuiltDb.close);
    final rebuilt = WallpaperLibrary(rebuiltDb, SettingsStore(rebuiltDb));
    await rebuilt.setRoot(library.root!);
    await rebuilt.rescan();
    final restored = (await rebuilt.bySource('wallhaven', 'keep'))!;
    expect(restored.isFavourite, isTrue);
    expect(restored.isHidden, isTrue);
    expect(restored.tags, ['sunset', 'beach']);
  });

  test('editing a local image creates a sidecar for it', () async {
    await writeImage(library.absoluteFor('mine.png'), seed: 3);
    await library.rescan();
    final item = (await library.watch().first).single;

    await library.setFavourite(item, true);

    final sidecar = await Sidecar.read(LibraryLayout.sidecarFor(library.absolutePath(item)));
    expect(sidecar?.source, Sidecar.localSource);
    expect(sidecar?.favourite, isTrue);
  });

  group('importFolder', () {
    late String outside;

    setUp(() async {
      outside = p.join(temp.path, 'Old Wallpapers');
      await writeImage(p.join(outside, 'a.png'), seed: 1);
      await writeImage(p.join(outside, 'nested', 'b.png'), seed: 2);
      await writeImage(p.join(outside, '.hidden', 'c.png'), seed: 3);
      await File(p.join(outside, 'notes.txt')).writeAsString('not an image');
    });

    test('copies images into local/<folder>/, keeping sub-folders', () async {
      final result = await library.importFolder(outside);

      expect(result.imported, 2);
      final paths = [for (final i in await library.watch().first) i.relativePath]..sort();
      expect(paths, ['local/Old Wallpapers/a.png', 'local/Old Wallpapers/nested/b.png']);
      expect(File(p.join(outside, 'a.png')).existsSync(), isTrue, reason: 'copy leaves originals');
      expect((await library.watch().first).every((i) => i.source == Sidecar.localSource), isTrue);
    });

    test('move removes the originals', () async {
      await library.importFolder(outside, move: true);
      expect(File(p.join(outside, 'a.png')).existsSync(), isFalse);
      expect(File(p.join(outside, 'nested', 'b.png')).existsSync(), isFalse);
    });

    test('skips images already in the library and avoids name clashes', () async {
      await library.importFolder(outside);
      await writeImage(p.join(outside, 'a.png'), seed: 9); // same name, new picture

      final again = await library.importFolder(outside);

      expect(again.duplicates, 1, reason: 'nested/b.png is unchanged');
      expect(again.imported, 1);
      final paths = [for (final i in await library.watch().first) i.relativePath];
      expect(paths, contains('local/Old Wallpapers/a (2).png'));
    });

    test('refuses folders inside the library or containing it', () async {
      expect(() => library.importFolder(p.join(library.root!, 'x')), throwsA(isA<LibraryException>()));
      expect(() => library.importFolder(temp.path), throwsA(isA<LibraryException>()));
    });
  });

  test('downloads measure the real image size rather than trusting the source', () async {
    final dio = fakeDio((options) async {
      if (options.uri.host == 'wallhaven.cc') return jsonBody(fixture('wallhaven/detail.json'));
      return bytesBody(fakePng(2560, 1440, seed: 4));
    });
    final downloads = DownloadManager(dio: dio, library: library);
    addTearDown(downloads.dispose);
    final wrong = RemoteWallpaper(
      sourceId: 'wallhaven',
      id: 'z',
      fullUrl: Uri.parse('https://w.wallhaven.cc/full/zz/wallhaven-z.png'),
      thumbnailUrl: Uri.parse('https://th.wallhaven.cc/lg/zz/z.jpg'),
      width: 3840,
      height: 2160,
    );

    final item = await downloads.download(WallhavenSource(dio: dio), wrong);

    expect((item.width, item.height), (2560, 1440));
  });
}
