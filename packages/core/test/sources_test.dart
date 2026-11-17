import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

List<Object?> fixtureList(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as List<Object?>;

void main() {
  group('Wallhaven categories and colours', () {
    final source = WallhavenSource(dio: fakeDio((_) async => jsonBody({})));

    test('defaults to General only', () {
      expect(source.buildSearchParams(const SearchQuery(), page: 1)['categories'], '100');
      expect(source.capabilities.defaultCategories, {'general'});
    });

    test('chosen categories become Wallhaven flags; empty falls back to the default', () {
      expect(WallhavenSource.categoryBits({'anime', 'people'}), '011');
      expect(WallhavenSource.categoryBits({'general', 'anime', 'people'}), '111');
      expect(WallhavenSource.categoryBits(const {}), '100');
    });

    test('colour goes in the colors parameter', () {
      final params = source.buildSearchParams(const SearchQuery(colour: '0066cc'), page: 1);
      expect(params['colors'], '0066cc');
      expect(source.buildSearchParams(const SearchQuery(), page: 1), isNot(contains('colors')));
      expect(WallhavenSource.colours.map((c) => c.id), contains('0066cc'));
    });
  });

  group('Unsplash', () {
    late ApiKeys keys;
    setUp(() => keys = ApiKeys({'unsplash': 'test-key'}));

    test('without a key, asks for one', () async {
      final source = UnsplashSource(dio: fakeDio((_) async => jsonBody([])), keys: ApiKeys());
      await expectLater(
        source.search(const SearchQuery()),
        throwsA(isA<SourceException>().having((e) => e.needsApiKey, 'needsApiKey', isTrue)),
      );
    });

    test('no search text browses the Wallpapers topic, with the key in the header', () async {
      final dio = fakeDio((_) async => jsonBody(fixtureList('unsplash/topic.json')));
      final page = await UnsplashSource(dio: dio, keys: keys).search(
        const SearchQuery(orientation: WallpaperOrientation.landscape),
      );

      final request = adapterOf(dio).requests.single;
      expect(request.path, 'https://api.unsplash.com/topics/wallpapers/photos');
      expect(request.headers['Authorization'], 'Client-ID test-key');
      expect(request.queryParameters, containsPair('order_by', 'popular'));
      expect(request.queryParameters, containsPair('orientation', 'landscape'));
      // The portrait cat doesn't match the landscape filter; only 2 of 30 came back.
      expect(page.items.map((w) => w.id), ['eOLpJytrbsQ']);
      expect(page.nextCursor, isNull);
    });

    test('search text and colour use the search endpoint', () async {
      final dio = fakeDio((_) async => jsonBody(fixture('unsplash/search.json')));
      final page = await UnsplashSource(dio: dio, keys: keys).search(
        const SearchQuery(text: 'mountains', sort: SortMode.relevance, colour: 'blue'),
        cursor: '2',
      );

      final params = adapterOf(dio).requests.single.queryParameters;
      expect(adapterOf(dio).requests.single.path, endsWith('/search/photos'));
      expect(params, containsPair('query', 'mountains'));
      expect(params, containsPair('color', 'blue'));
      expect(params, containsPair('order_by', 'relevant'));
      expect(params, containsPair('page', '2'));
      expect(page.nextCursor, '3');
      expect(page.total, 133);
      expect(page.items, hasLength(2));
    });

    test('minimum size filters results', () async {
      final dio = fakeDio((_) async => jsonBody(fixture('unsplash/search.json')));
      final page = await UnsplashSource(dio: dio, keys: keys).search(
        const SearchQuery(text: 'x', minResolution: (width: 3840, height: 2160)),
      );
      expect(page.items.map((w) => w.id), ['eOLpJytrbsQ']);
    });

    test('parsing: credits with UTM links, resized thumbnails that keep ixid', () {
      final w = UnsplashSource.parsePhoto(
        (fixture('unsplash/search.json')['results']! as List).first as Map<String, Object?>,
      );
      expect(w.title, 'Misty mountains at sunrise');
      expect(w.width, 6000);
      expect(w.colours, [0xFFA7A2A1]);
      expect(w.attribution.creditLine, 'Photo by Jeff Sheldon on Unsplash');
      expect(w.attribution.authorUrl, 'https://unsplash.com/@ugmonk?utm_source=wallpaper_fetcher&utm_medium=referral');
      expect(w.pageUrl!.queryParameters, containsPair('utm_medium', 'referral'));
      expect(w.thumbnailUrl.queryParameters, allOf(containsPair('ixid', 'abc123'), containsPair('w', '640')));
      expect(w.fullUrl.queryParameters, containsPair('fm', 'jpg'));
    });

    test('prepareDownload reports the download to Unsplash first', () async {
      final dio = fakeDio((_) async => jsonBody({'url': 'https://example'}));
      final source = UnsplashSource(dio: dio, keys: keys);
      final withLocation = UnsplashSource.parsePhoto(
        (fixture('unsplash/search.json')['results']! as List)[1] as Map<String, Object?>,
      );
      final without = UnsplashSource.parsePhoto(
        (fixture('unsplash/search.json')['results']! as List)[0] as Map<String, Object?>,
      );

      final ticket = await source.prepareDownload(withLocation);
      await source.prepareDownload(without);

      final requests = adapterOf(dio).requests;
      expect(requests[0].uri.toString(), startsWith('https://api.unsplash.com/photos/smallPortrait1/download?ixid=def456'));
      expect(requests[0].headers['Authorization'], 'Client-ID test-key');
      expect(requests[1].uri.toString(), 'https://api.unsplash.com/photos/eOLpJytrbsQ/download');
      expect(ticket.fileExtension, 'jpg');
      expect(ticket.url, withLocation.fullUrl);
    });

    test("Unsplash's 403 rate-limit reply becomes a rate-limit message", () async {
      final dio = fakeDio(
        (_) async => ResponseBody.fromString('Rate Limit Exceeded', 403, headers: {
          Headers.contentTypeHeader: ['text/plain'],
        }),
      );
      await expectLater(
        UnsplashSource(dio: dio, keys: keys).search(const SearchQuery()),
        throwsA(
          isA<SourceException>()
              .having((e) => e.isRateLimited, 'isRateLimited', isTrue)
              .having((e) => e.message, 'message', contains('50 requests an hour')),
        ),
      );
    });

    test('a rejected key asks for a new one', () async {
      final dio = fakeDio((_) async => jsonBody({'errors': ['OAuth error: The access token is invalid']}, status: 401));
      await expectLater(
        UnsplashSource(dio: dio, keys: keys).search(const SearchQuery()),
        throwsA(isA<SourceException>().having((e) => e.needsApiKey, 'needsApiKey', isTrue)),
      );
    });
  });

  group('Bing', () {
    test('parses the archive into 4K landscape wallpapers with credits', () {
      final items = BingSource.parseArchive(fixture('bing/archive.json'));
      expect(items, hasLength(8));
      final first = items.first;
      expect(first.id, matches(RegExp(r'^\d{8}_[A-Za-z0-9]+$')));
      expect(first.fullUrl.toString(), allOf(startsWith('https://www.bing.com/th?id=OHR.'), endsWith('_UHD.jpg')));
      expect(first.thumbnailUrl.toString(), endsWith('_400x240.jpg'));
      expect((first.width, first.height), (3840, 2160));
      expect(first.date, isNotNull);
      expect(first.attribution.creditLine, contains('©'));
      expect(first.attribution.licence, 'Personal use only');
      expect(first.attribution.authorName, isNotNull);
    });

    test('portrait uses the phone crop and a separate id', () {
      final landscape = BingSource.parseArchive(fixture('bing/archive.json')).first;
      final portrait = BingSource.parseArchive(fixture('bing/archive.json'), portrait: true).first;
      expect(portrait.fullUrl.toString(), endsWith('_1080x1920.jpg'));
      expect(portrait.orientation, WallpaperOrientation.portrait);
      expect(portrait.id, '${landscape.id}_portrait');
    });

    test('two pages: the last 8 days, then the 7 before', () async {
      final dio = fakeDio((_) async => jsonBody(fixture('bing/archive.json')));
      final source = BingSource(dio: dio, market: 'en-GB');

      final first = await source.search(const SearchQuery());
      final second = await source.search(const SearchQuery(), cursor: first.nextCursor);

      final params = adapterOf(dio).requests.map((r) => r.queryParameters).toList();
      expect(params[0], allOf(containsPair('idx', '0'), containsPair('n', '8'), containsPair('mkt', 'en-GB')));
      expect(params[1], containsPair('idx', '7'));
      expect(first.nextCursor, '2');
      expect(second.nextCursor, isNull);
    });
  });

  group('Wikimedia Picture of the Day', () {
    test('parses a day with size, credits and licence', () {
      final w = WikimediaSource.parseFeed(fixture('wikimedia/2026-11-16.json'), DateTime.utc(2026, 11, 16))!;
      expect(w.id, '2026-11-16');
      expect((w.width, w.height), (3332, 4792));
      expect(w.orientation, WallpaperOrientation.portrait);
      expect(w.fullUrl.host, 'upload.wikimedia.org');
      expect(w.attribution.licence, 'CC BY-SA 3.0');
      expect(w.attribution.authorName, isNotEmpty);
      expect(w.attribution.creditLine, contains('Wikimedia Commons'));
      expect(w.pageUrl.toString(), startsWith('https://commons.wikimedia.org/wiki/File:'));
      expect(w.title, isNotEmpty);
    });

    test('skips formats that make poor wallpapers', () {
      final svg = jsonDecode(File('test/fixtures/wikimedia/2026-11-16.json').readAsStringSync()) as Map<String, Object?>;
      ((svg['image']! as Map)['image']! as Map)['source'] = 'https://upload.wikimedia.org/x/Diagram.svg';
      expect(WikimediaSource.parseFeed(svg, DateTime.utc(2026, 11, 16)), isNull);
    });

    Dio feedDio() => fakeDio((options) async {
      final m = RegExp(r'(\d{4})/(\d{2})/(\d{2})$').firstMatch(options.uri.path)!;
      final file = File('test/fixtures/wikimedia/${m[1]}-${m[2]}-${m[3]}.json');
      return file.existsSync() ? jsonBody(jsonDecode(file.readAsStringSync()) as Object) : jsonBody({}, status: 404);
    });

    test('a page covers several days back from today and skips missing days', () async {
      final dio = feedDio();
      final source = WikimediaSource(dio: dio, today: () => DateTime.utc(2026, 11, 16, 9), daysPerPage: 3);

      final page = await source.search(const SearchQuery());

      expect(adapterOf(dio).requests, hasLength(3));
      expect(page.items.map((w) => w.id), ['2026-11-16', '2026-11-15']);
      expect(page.nextCursor, '2026-11-13');
    });

    test('filters apply to the page, which can come back empty with more to load', () async {
      final source = WikimediaSource(dio: feedDio(), today: () => DateTime.utc(2026, 11, 16), daysPerPage: 3);
      final page = await source.search(const SearchQuery(orientation: WallpaperOrientation.landscape));
      expect(page.items, isEmpty, reason: 'both fixtures are portrait');
      expect(page.nextCursor, isNotNull);
    });

    test('only fails when every day fails', () async {
      final dio = fakeDio((_) async => jsonBody({}, status: 503));
      await expectLater(
        WikimediaSource(dio: dio, today: () => DateTime.utc(2026, 11, 16), daysPerPage: 2).search(const SearchQuery()),
        throwsA(isA<SourceException>()),
      );
    });
  });

  test('SearchQuery.accepts checks size and shape, letting unknown sizes through', () {
    RemoteWallpaper w(int? width, int? height) => RemoteWallpaper(
      sourceId: 's',
      id: '$width',
      fullUrl: Uri.parse('https://x/y.jpg'),
      thumbnailUrl: Uri.parse('https://x/t.jpg'),
      width: width,
      height: height,
    );
    const q = SearchQuery(orientation: WallpaperOrientation.landscape, minResolution: (width: 3840, height: 2160));
    expect(q.accepts(w(3840, 2160)), isTrue);
    expect(q.accepts(w(1920, 1080)), isFalse);
    expect(q.accepts(w(2160, 3840)), isFalse);
    expect(q.accepts(w(null, null)), isTrue);
  });
}
