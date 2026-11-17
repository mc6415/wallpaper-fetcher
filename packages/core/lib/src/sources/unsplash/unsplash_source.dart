import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../../models/attribution.dart';
import '../../models/orientation.dart';
import '../../models/remote_wallpaper.dart';
import '../../net/rate_limiter.dart';
import '../api_keys.dart';
import '../wallpaper_source.dart';

final _log = Logger('Unsplash');

/// https://unsplash.com/documentation
///
/// Needs a free access key. Terms that shape this class:
/// - images are shown from the URLs the API returns (hotlinking);
/// - every download (setting a wallpaper counts) is reported through the
///   photo's `download_location`;
/// - the photographer and Unsplash are credited, with links back.
class UnsplashSource implements WallpaperSource {
  UnsplashSource({
    required this._dio,
    required this._keys,
    RateLimiter? limiter,
    this.appName = 'wallpaper_fetcher',
  }) : // Demo keys allow 50 requests an hour.
       _limiter = limiter ?? RateLimiter(maxRequests: 48, window: const Duration(hours: 1));

  static const apiBase = 'https://api.unsplash.com';
  static const sourceId = 'unsplash';
  static const perPage = 30;

  /// Unsplash's own "Wallpapers" topic, used when there's no search text.
  static const wallpaperTopic = 'wallpapers';

  final Dio _dio;
  final ApiKeys _keys;
  final RateLimiter _limiter;

  /// Used in `utm_source` on links back to Unsplash, as their guidelines ask.
  final String appName;

  @override
  String get id => sourceId;

  @override
  String get name => 'Unsplash';

  @override
  SourceCapabilities get capabilities => SourceCapabilities(
    supportsSearch: true,
    supportsOrientation: true,
    supportsMinResolution: true,
    sortModes: const [SortMode.toplist, SortMode.latest, SortMode.relevance],
    colours: colours,
    requiresApiKey: true,
    apiKeyUrl: 'https://unsplash.com/oauth/applications',
    attributionText: 'Photos from Unsplash',
    attributionUrl: _withUtm('https://unsplash.com/'),
    creditOnDisplay: true,
  );

  static const colours = [
    SourceColour('black_and_white', 'Black & white', 0xFF808080),
    SourceColour('black', 'Black', 0xFF000000),
    SourceColour('white', 'White', 0xFFFFFFFF),
    SourceColour('yellow', 'Yellow', 0xFFFFD600),
    SourceColour('orange', 'Orange', 0xFFFF8F00),
    SourceColour('red', 'Red', 0xFFD32F2F),
    SourceColour('purple', 'Purple', 0xFF7B1FA2),
    SourceColour('magenta', 'Magenta', 0xFFD81B60),
    SourceColour('green', 'Green', 0xFF388E3C),
    SourceColour('teal', 'Teal', 0xFF00897B),
    SourceColour('blue', 'Blue', 0xFF1976D2),
  ];

  @override
  Future<SourcePage> search(SearchQuery query, {String? cursor}) async {
    final page = int.tryParse(cursor ?? '') ?? 1;
    var text = query.text.trim();
    // The topic endpoint has no colour filter, so a colour on its own becomes
    // a search for wallpapers in that colour.
    if (text.isEmpty && query.colour != null) text = 'wallpaper';

    final List<Object?> results;
    final bool more;
    int? total;
    if (text.isEmpty) {
      final data = await _get('/topics/$wallpaperTopic/photos', {
        'page': '$page',
        'per_page': '$perPage',
        'order_by': query.sort == SortMode.latest ? 'latest' : 'popular',
        'orientation': ?_orientation(query.orientation),
      });
      results = data as List? ?? const [];
      more = results.length >= perPage;
    } else {
      final data = _map(
        await _get('/search/photos', {
          'query': text,
          'page': '$page',
          'per_page': '$perPage',
          'order_by': query.sort == SortMode.latest ? 'latest' : 'relevant',
          'orientation': ?_orientation(query.orientation),
          'color': ?query.colour,
        }),
      );
      results = data['results'] as List? ?? const [];
      total = data['total'] as int?;
      more = page < (data['total_pages'] as int? ?? page);
    }

    final items = <RemoteWallpaper>[];
    for (final r in results) {
      try {
        final w = parsePhoto(_map(r), appName: appName);
        if (query.accepts(w)) items.add(w);
      } on FormatException catch (e) {
        _log.warning('Skipping unreadable Unsplash result: $e');
      }
    }
    return SourcePage(items: items, total: total, nextCursor: more ? '${page + 1}' : null);
  }

  @override
  Future<DownloadTicket> prepareDownload(RemoteWallpaper wallpaper) async {
    // Required by Unsplash: report the download. It's a tracking call only.
    final tracking = wallpaper.extra['downloadLocation'] ??
        '$apiBase/photos/${Uri.encodeComponent(wallpaper.id)}/download';
    try {
      await _get(tracking, const {});
    } on SourceException catch (e) {
      if (e.needsApiKey) rethrow;
      _log.warning('Unsplash download tracking failed for ${wallpaper.id}: $e');
    }
    return DownloadTicket(url: wallpaper.fullUrl, wallpaper: wallpaper, fileExtension: 'jpg');
  }

  static String? _orientation(WallpaperOrientation? o) => switch (o) {
    WallpaperOrientation.landscape => 'landscape',
    WallpaperOrientation.portrait => 'portrait',
    WallpaperOrientation.square => 'squarish',
    null => null,
  };

  static RemoteWallpaper parsePhoto(Map<String, Object?> j, {String appName = 'wallpaper_fetcher'}) {
    final id = j['id'] as String? ?? (throw const FormatException('no id'));
    final urls = _map(j['urls']);
    final links = _map(j['links']);
    final user = _map(j['user']);
    final raw = urls['raw'] as String?;
    final full = urls['full'] as String? ?? raw ?? (throw FormatException('no image url for $id'));
    final userName = (user['name'] as String?)?.trim();
    final profile = _map(user['links'])['html'] as String?;
    final title = ((j['description'] ?? j['alt_description']) as String?)?.trim();
    final colour = _hexColour(j['color']);
    return RemoteWallpaper(
      sourceId: sourceId,
      id: id,
      fullUrl: Uri.parse(full),
      // Resized from the raw URL; Unsplash's CDN keeps the required ixid.
      thumbnailUrl: Uri.parse(raw == null ? urls['small']! as String : '$raw&w=640&q=75&fm=jpg&fit=max'),
      previewUrl: raw == null ? null : Uri.parse('$raw&w=2560&q=85&fm=jpg&fit=max'),
      pageUrl: switch (links['html']) {
        final String html => Uri.parse(_withUtm(html, appName)),
        _ => null,
      },
      width: j['width'] as int?,
      height: j['height'] as int?,
      title: title == null || title.isEmpty ? null : title[0].toUpperCase() + title.substring(1),
      colours: [?colour],
      attribution: Attribution(
        authorName: userName,
        authorUrl: profile == null ? null : _withUtm(profile, appName),
        creditLine: userName == null ? 'From Unsplash' : 'Photo by $userName on Unsplash',
        licence: 'Unsplash License',
      ),
      extra: {'downloadLocation': ?links['download_location'] as String?},
    );
  }

  static String _withUtm(String url, [String appName = 'wallpaper_fetcher']) {
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'utm_source': appName,
      'utm_medium': 'referral',
    }).toString();
  }

  Future<Object?> _get(String pathOrUrl, Map<String, String> params) async {
    final key = _keys[sourceId];
    if (key == null) throw SourceException.missingKey(name);
    await _limiter.acquire();
    try {
      final response = await _dio.get<Object?>(
        pathOrUrl.startsWith('http') ? pathOrUrl : '$apiBase$pathOrUrl',
        queryParameters: params,
        options: Options(headers: {'Authorization': 'Client-ID $key', 'Accept-Version': 'v1'}),
      );
      return response.data;
    } on DioException catch (e) {
      // Unsplash answers 403 "Rate Limit Exceeded" rather than 429.
      final body = '${e.response?.data}';
      if (e.response?.statusCode == 403 && body.contains('Rate Limit')) {
        throw SourceException(
          'Unsplash allows 50 requests an hour on a new key, and that limit has been '
          'reached. Try again later.',
          statusCode: 429,
          cause: e,
        );
      }
      if (e.response?.statusCode == 401) {
        throw SourceException(
          'Unsplash rejected the API key. Check it in Settings.',
          statusCode: 401,
          cause: e,
          needsApiKey: true,
        );
      }
      throw SourceException.fromDio(name, e);
    }
  }

  static Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

  static int? _hexColour(Object? v) {
    if (v is! String) return null;
    final rgb = int.tryParse(v.replaceFirst('#', ''), radix: 16);
    return rgb == null || v.replaceFirst('#', '').length != 6 ? null : 0xFF000000 | rgb;
  }
}
