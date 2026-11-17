import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

void main() {
  group('parsing', () {
    test('search response becomes a page of wallpapers', () {
      final page = WallhavenSource.parseSearch(fixture('wallhaven/search.json'));

      expect(page.items, hasLength(3));
      expect(page.nextCursor, '2');
      expect(page.total, greaterThan(0));

      final first = page.items.first;
      expect(first.sourceId, 'wallhaven');
      expect(first.id, isNotEmpty);
      expect(first.key, 'wallhaven:${first.id}');
      expect(first.fullUrl.host, 'w.wallhaven.cc');
      expect(first.thumbnailUrl.host, 'th.wallhaven.cc');
      expect(first.pageUrl.toString(), startsWith('https://wallhaven.cc/w/'));
      expect(first.width, greaterThanOrEqualTo(3840));
      expect(first.orientation, WallpaperOrientation.landscape);
      expect(first.colours, isNotEmpty);
      expect(first.colours.first >> 24, 0xFF, reason: 'colours are opaque ARGB');
    });

    test('random sorting keeps its seed in the cursor', () {
      final page = WallhavenSource.parseSearch({
        'data': const [],
        'meta': {'current_page': 1, 'last_page': 9, 'seed': 'abc123'},
      });
      expect(page.nextCursor, '2:abc123');
      expect(WallhavenSource.parseCursor('2:abc123'), (2, 'abc123'));
      expect(WallhavenSource.parseCursor(null), (1, null));
    });

    test('last page has no next cursor, and per_page as a string is fine', () {
      final page = WallhavenSource.parseSearch({
        'data': const [],
        'meta': {'current_page': '3', 'last_page': '3', 'per_page': '24'},
      });
      expect(page.nextCursor, isNull);
    });

    test('malformed items are skipped, not fatal', () {
      final page = WallhavenSource.parseSearch({
        'data': [
          {'id': 'no-path'},
          fixture('wallhaven/search.json')['data']! as List,
        ].expand((e) => e is List ? e : [e]).toList(),
        'meta': const {'current_page': 1, 'last_page': 1},
      });
      expect(page.items, hasLength(3));
    });

    test('details add uploader credit and tags', () {
      final base = WallhavenSource.parseSearch(fixture('wallhaven/search.json')).items.first;
      final merged = WallhavenSource.mergeDetails(base, fixture('wallhaven/detail.json'));

      expect(merged.tags, isNotEmpty);
      expect(merged.attribution.authorName, isNotEmpty);
      expect(merged.attribution.authorUrl, startsWith('https://wallhaven.cc/user/'));
      expect(merged.attribution.creditLine, startsWith('Uploaded to Wallhaven by '));
    });
  });

  group('requests', () {
    test('search sends safe-for-work filters, resolution and orientation', () async {
      final dio = fakeDio((_) async => jsonBody(fixture('wallhaven/search.json')));
      final source = WallhavenSource(dio: dio);

      await source.search(
        const SearchQuery(
          text: '  mountains ',
          sort: SortMode.relevance,
          orientation: WallpaperOrientation.landscape,
          minResolution: (width: 3840, height: 2160),
        ),
        cursor: '3:seed',
      );

      final params = adapterOf(dio).requests.single.queryParameters;
      expect(params, containsPair('q', 'mountains'));
      expect(params, containsPair('purity', '100'));
      expect(params, containsPair('sorting', 'relevance'));
      expect(params, containsPair('atleast', '3840x2160'));
      expect(params, containsPair('ratios', 'landscape'));
      expect(params, containsPair('page', '3'));
      expect(params, containsPair('seed', 'seed'));
      expect(params, isNot(contains('topRange')));
      expect(params, isNot(contains('apikey')));
    });

    test('relevance without text falls back to toplist', () {
      final source = WallhavenSource(dio: fakeDio((_) async => jsonBody({})));
      final params = source.buildSearchParams(const SearchQuery(sort: SortMode.relevance), page: 1);
      expect(params['sorting'], 'toplist');
      expect(params['topRange'], isNull);
    });

    test('prepareDownload fetches details and keeps the file extension', () async {
      final dio = fakeDio((options) async => jsonBody(fixture('wallhaven/detail.json')));
      final source = WallhavenSource(dio: dio);
      final wallpaper = WallhavenSource.parseSearch(fixture('wallhaven/search.json')).items.first;

      final ticket = await source.prepareDownload(wallpaper);

      expect(adapterOf(dio).requests.single.path, endsWith('/w/${wallpaper.id}'));
      expect(ticket.url, wallpaper.fullUrl);
      expect(ticket.fileExtension, 'jpg');
      expect(ticket.wallpaper.tags, isNotEmpty);
    });

    test('prepareDownload still works when details fail', () async {
      final dio = fakeDio((_) async => jsonBody({'error': 'nope'}, status: 404));
      final wallpaper = WallhavenSource.parseSearch(fixture('wallhaven/search.json')).items.first;

      final ticket = await WallhavenSource(dio: dio).prepareDownload(wallpaper);

      expect(ticket.wallpaper.tags, isEmpty);
      expect(ticket.wallpaper.attribution.creditLine, 'From Wallhaven');
    });

    test('rate limiting becomes a friendly SourceException', () async {
      final dio = fakeDio((_) async => jsonBody({}, status: 429));
      expect(
        () => WallhavenSource(dio: dio).search(const SearchQuery()),
        throwsA(
          isA<SourceException>()
              .having((e) => e.isRateLimited, 'isRateLimited', isTrue)
              .having((e) => e.message, 'message', contains('Try again in a minute')),
        ),
      );
    });
  });
}
