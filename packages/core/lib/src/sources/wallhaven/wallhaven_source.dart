import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../models/attribution.dart';
import '../../models/orientation.dart';
import '../../models/remote_wallpaper.dart';
import '../../net/rate_limiter.dart';
import '../wallpaper_source.dart';

final _log = Logger('Wallhaven');

/// https://wallhaven.cc/help/api
///
/// No key is needed for safe-for-work content, which is all this app asks for.
class WallhavenSource implements WallpaperSource {
  WallhavenSource({required this._dio, this.apiKey, RateLimiter? limiter})
    : // Wallhaven allows 45 requests a minute; stay a little under.
      _limiter =
          limiter ??
          RateLimiter(maxRequests: 40, window: const Duration(minutes: 1));

  static const apiBase = 'https://wallhaven.cc/api/v1';
  static const sourceId = 'wallhaven';

  final Dio _dio;
  final RateLimiter _limiter;
  final String? apiKey;

  @override
  String get id => sourceId;

  @override
  String get name => 'Wallhaven';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsOrientation: true,
    supportsMinResolution: true,
    supportsTopRange: true,
    sortModes: [
      SortMode.toplist,
      SortMode.latest,
      SortMode.random,
      SortMode.views,
      SortMode.favourites,
      SortMode.relevance,
    ],
  );

  @override
  Future<SourcePage> search(SearchQuery query, {String? cursor}) async {
    final (page, seed) = parseCursor(cursor);
    final json = await _get(
      '/search',
      buildSearchParams(query, page: page, seed: seed),
    );
    return parseSearch(json);
  }

  @override
  Future<DownloadTicket> prepareDownload(RemoteWallpaper wallpaper) async {
    var enriched = wallpaper;
    try {
      final details = await _get(
        '/w/${Uri.encodeComponent(wallpaper.id)}',
        const {},
      );
      enriched = mergeDetails(wallpaper, details);
    } on SourceException catch (e) {
      // Tags and uploader are nice to have; the download still works without.
      _log.warning('No details for ${wallpaper.id}, downloading anyway: $e');
    }
    final ext = p.extension(wallpaper.fullUrl.path).replaceFirst('.', '');
    return DownloadTicket(
      url: wallpaper.fullUrl,
      wallpaper: enriched,
      fileExtension: ext.isEmpty ? 'jpg' : ext.toLowerCase(),
    );
  }

  Map<String, String> buildSearchParams(
    SearchQuery query, {
    required int page,
    String? seed,
  }) {
    final text = query.text.trim();
    return {
      if (text.isNotEmpty) 'q': text,
      'categories': '111', // general, anime, people
      'purity': '100', // safe for work only
      'sorting': _sorting(query.sort, hasText: text.isNotEmpty),
      'order': 'desc',
      if (query.sort == SortMode.toplist) 'topRange': query.topRange.code,
      if (query.minResolution case final r?) 'atleast': formatResolution(r),
      'ratios': ?_ratios(query.orientation),
      'page': '$page',
      'seed': ?seed,
      if (apiKey case final key? when key.isNotEmpty) 'apikey': key,
    };
  }

  static String _sorting(SortMode sort, {required bool hasText}) =>
      switch (sort) {
        SortMode.toplist => 'toplist',
        SortMode.latest => 'date_added',
        SortMode.random => 'random',
        SortMode.views => 'views',
        SortMode.favourites => 'favorites',
        // Relevance means nothing without search text.
        SortMode.relevance => hasText ? 'relevance' : 'toplist',
      };

  static String? _ratios(WallpaperOrientation? o) => switch (o) {
    WallpaperOrientation.landscape => 'landscape',
    WallpaperOrientation.portrait => 'portrait',
    WallpaperOrientation.square => '1x1',
    null => null,
  };

  /// Cursors are `page` or `page:seed` (random sorting needs the seed to keep
  /// later pages consistent).
  static (int, String?) parseCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return (1, null);
    final [page, ...rest] = cursor.split(':');
    return (int.tryParse(page) ?? 1, rest.isEmpty ? null : rest.join(':'));
  }

  static SourcePage parseSearch(Map<String, Object?> json) {
    final data = json['data'] as List? ?? const [];
    final meta = _map(json['meta']);
    final current = _int(meta['current_page']) ?? 1;
    final last = _int(meta['last_page']) ?? current;
    final seed = meta['seed'] as String?;
    final items = <RemoteWallpaper>[];
    for (final entry in data) {
      try {
        items.add(parseWallpaper(_map(entry)));
      } on FormatException catch (e) {
        _log.warning('Skipping unreadable Wallhaven result: $e');
      }
    }
    final next = current + 1;
    return SourcePage(
      items: items,
      total: _int(meta['total']),
      nextCursor: current < last ? (seed == null ? '$next' : '$next:$seed') : null,
    );
  }

  static RemoteWallpaper parseWallpaper(Map<String, Object?> j) {
    final id = j['id'] as String? ?? (throw const FormatException('no id'));
    final full = j['path'] as String? ?? (throw FormatException('no path for $id'));
    final thumbs = _map(j['thumbs']);
    final thumb = (thumbs['large'] ?? thumbs['original'] ?? thumbs['small'] ?? full) as String;
    return RemoteWallpaper(
      sourceId: sourceId,
      id: id,
      fullUrl: Uri.parse(full),
      thumbnailUrl: Uri.parse(thumb),
      pageUrl: switch (j['url']) {
        final String url => Uri.parse(url),
        _ => null,
      },
      width: _int(j['dimension_x']),
      height: _int(j['dimension_y']),
      fileSize: _int(j['file_size']),
      mimeType: j['file_type'] as String?,
      colours: [
        for (final c in j['colors'] as List? ?? const [])
          ?_hexColour(c),
      ],
      attribution: Attribution(
        creditLine: 'From Wallhaven',
        originalUrl: _nonEmpty(j['source']),
      ),
    );
  }

  /// Adds uploader and tags from `/w/{id}`.
  static RemoteWallpaper mergeDetails(
    RemoteWallpaper w,
    Map<String, Object?> json,
  ) {
    final d = _map(json['data']);
    final username = _nonEmpty(_map(d['uploader'])['username']);
    final tags = [
      for (final t in d['tags'] as List? ?? const [])
        if (_map(t)['name'] case final String name) name,
    ];
    return w.copyWith(
      tags: tags.isEmpty ? null : tags,
      attribution: Attribution(
        authorName: username,
        authorUrl: username == null
            ? null
            : 'https://wallhaven.cc/user/${Uri.encodeComponent(username)}',
        creditLine: username == null
            ? 'From Wallhaven'
            : 'Uploaded to Wallhaven by $username',
        originalUrl: _nonEmpty(d['source']) ?? w.attribution.originalUrl,
      ),
    );
  }

  Future<Map<String, Object?>> _get(
    String path,
    Map<String, String> params,
  ) async {
    await _limiter.acquire();
    try {
      final response = await _dio.get<Object?>(
        '$apiBase$path',
        queryParameters: params,
      );
      return switch (response.data) {
        final Map<Object?, Object?> m => m.cast<String, Object?>(),
        final String s => _map(jsonDecode(s)),
        _ => throw SourceException("Wallhaven sent a response we couldn't read."),
      };
    } on DioException catch (e) {
      throw SourceException.fromDio(name, e);
    } on FormatException catch (e) {
      throw SourceException("Wallhaven sent a response we couldn't read.", cause: e);
    }
  }

  static Map<String, Object?> _map(Object? v) =>
      v is Map ? v.cast<String, Object?>() : const {};

  static int? _int(Object? v) => switch (v) {
    final int i => i,
    final String s => int.tryParse(s),
    _ => null,
  };

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  static int? _hexColour(Object? v) {
    if (v is! String) return null;
    final hex = v.replaceFirst('#', '');
    if (hex.length != 6) return null;
    final rgb = int.tryParse(hex, radix: 16);
    return rgb == null ? null : 0xFF000000 | rgb;
  }
}
