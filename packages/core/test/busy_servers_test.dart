import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

/// Behaviour when servers push back with 429s (seen live from Wikimedia).
void main() {
  ResponseBody busy({String? retryAfter}) => ResponseBody.fromString('{}', 429, headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    'retry-after': ?(retryAfter == null ? null : [retryAfter]),
  });

  test('Wikimedia fetches each day once; changing filters re-uses them', () async {
    final dio = fakeDio((options) async {
      final m = RegExp(r'(\d{4})/(\d{2})/(\d{2})$').firstMatch(options.uri.path)!;
      final file = File('test/fixtures/wikimedia/${m[1]}-${m[2]}-${m[3]}.json');
      return file.existsSync() ? jsonBody(jsonDecode(file.readAsStringSync()) as Object) : jsonBody({}, status: 404);
    });
    final source = WikimediaSource(dio: dio, today: () => DateTime.utc(2026, 11, 16), daysPerPage: 3);

    await source.search(const SearchQuery());
    final afterFirst = adapterOf(dio).requests.length;
    final portrait = await source.search(const SearchQuery(orientation: WallpaperOrientation.portrait));
    final landscape = await source.search(const SearchQuery(orientation: WallpaperOrientation.landscape));

    expect(afterFirst, 3);
    expect(adapterOf(dio).requests, hasLength(3), reason: 'no new requests for the same days');
    expect(portrait.items, hasLength(2));
    expect(landscape.items, isEmpty);
  });

  test("Wikimedia doesn't remember a missing today (it may appear later)", () async {
    var calls = 0;
    final dio = fakeDio((_) async {
      calls++;
      return jsonBody({}, status: 404);
    });
    final source = WikimediaSource(dio: dio, today: () => DateTime.utc(2026, 11, 16), daysPerPage: 1);
    await source.search(const SearchQuery());
    await source.search(const SearchQuery());
    expect(calls, 2);
  });

  test('retries give up straight away when asked to wait too long', () async {
    final sleeps = <Duration>[];
    final dio = fakeDio((_) async => busy(retryAfter: '60'));
    dio.interceptors.add(RetryInterceptor(dio, sleep: (d) async => sleeps.add(d)));

    await expectLater(dio.get<Object?>('https://example.test/'), throwsA(isA<DioException>()));
    expect(sleeps, isEmpty);
  });

  group('downloads from a busy server', () {
    late Directory temp;
    late AppDatabase db;
    late WallpaperLibrary library;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('wf_busy_');
      db = AppDatabase(NativeDatabase.memory());
      library = WallpaperLibrary(db, SettingsStore(db));
      await library.setRoot(temp.path);
    });

    tearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });

    RemoteWallpaper potd() => RemoteWallpaper(
      sourceId: 'wikimedia',
      id: '2026-11-17',
      fullUrl: Uri.parse('https://upload.wikimedia.org/x/Big.jpg'),
      thumbnailUrl: Uri.parse('https://upload.wikimedia.org/x/thumb.jpg'),
    );

    test('wait as asked, then download', () async {
      var calls = 0;
      final dio = fakeDio((_) async => ++calls == 1 ? busy(retryAfter: '3') : bytesBody(fakePng(4000, 3000)));
      final sleeps = <Duration>[];
      final downloads = DownloadManager(dio: dio, library: library, sleep: (d) async => sleeps.add(d));
      addTearDown(downloads.dispose);

      final item = await downloads.download(WikimediaSource(dio: dio), potd());

      expect(sleeps, [const Duration(seconds: 3)]);
      expect((item.width, item.height), (4000, 3000));
    });

    test('give up after two retries with a readable message', () async {
      final dio = fakeDio((_) async => busy());
      final sleeps = <Duration>[];
      final downloads = DownloadManager(dio: dio, library: library, sleep: (d) async => sleeps.add(d));
      addTearDown(downloads.dispose);

      await expectLater(downloads.download(WikimediaSource(dio: dio), potd()), throwsA(isA<DioException>()));

      expect(sleeps, [const Duration(seconds: 2), const Duration(seconds: 4)]);
      expect(downloads.current['wikimedia:2026-11-17']?.error, contains('Try again in a minute'));
    });
  });
}
