import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../models/attribution.dart';
import '../../models/remote_wallpaper.dart';
import '../../net/rate_limiter.dart';
import '../../util/semaphore.dart';
import '../wallpaper_source.dart';

final _log = Logger('Wikimedia');

/// Wikimedia Commons' Picture of the Day, through the Wikimedia feed API.
/// No key; every image is freely licensed. One request per day, so a page of
/// [daysPerPage] days costs that many requests (fetched a few at a time).
class WikimediaSource implements WallpaperSource {
  WikimediaSource({
    required this._dio,
    DateTime Function()? today,
    this.daysPerPage = 10,
    RateLimiter? limiter,
    RateLimiter? burstLimiter,
  }) : _today = today ?? DateTime.now,
       _limiter = limiter ?? RateLimiter(maxRequests: 400, window: const Duration(hours: 1)),
       // Wikimedia answers bursts with 429s (seen at ~20 requests in a few
       // seconds), so pace them as well as capping the hourly total.
       _burst = burstLimiter ?? RateLimiter(maxRequests: 10, window: const Duration(seconds: 10));

  static const sourceId = 'wikimedia';
  static const feedBase = 'https://api.wikimedia.org/feed/v1/wikipedia/en/featured';

  /// Formats that make sense as wallpapers (POTDs are sometimes SVG or TIFF).
  static const _usable = {'.jpg', '.jpeg', '.png', '.webp'};

  /// Picture of the Day started in 2004; stop paging well before running out.
  static final _earliest = DateTime.utc(2007);

  final Dio _dio;
  final DateTime Function() _today;
  final int daysPerPage;
  final RateLimiter _limiter;
  final RateLimiter _burst;
  final _slots = Semaphore(2);

  /// Past Pictures of the Day never change, so each day is fetched once per
  /// run; changing filters re-filters these instead of asking again.
  final _days = <String, RemoteWallpaper?>{};

  @override
  String get id => sourceId;

  @override
  String get name => 'Wikimedia';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsOrientation: true,
    supportsMinResolution: true,
    isDaily: true,
    attributionText: 'Pictures of the Day from Wikimedia Commons',
    attributionUrl: 'https://commons.wikimedia.org/wiki/Commons:Picture_of_the_day',
    notice: 'Freely licensed. Each picture shows its licence and author, which you need to credit if you share it.',
  );

  @override
  Future<SourcePage> search(SearchQuery query, {String? cursor}) async {
    final now = _today().toUtc();
    final start = DateTime.tryParse(cursor ?? '') ?? DateTime.utc(now.year, now.month, now.day);
    final days = [for (var i = 0; i < daysPerPage; i++) start.subtract(Duration(days: i))];
    SourceException? failure;
    var failures = 0;
    final results = await Future.wait(
      days.map(
        (d) => _slots.withPermit(() async {
          try {
            return await _fetchDay(d);
          } on SourceException catch (e) {
            // One bad day shouldn't hide the rest; only fail if all of them do.
            failure ??= e;
            failures++;
            return null;
          }
        }),
      ),
    );
    if (failures == days.length) throw failure!;
    final items = [
      for (final w in results)
        if (w != null && query.accepts(w)) w,
    ];
    final next = start.subtract(Duration(days: daysPerPage));
    return SourcePage(
      items: items,
      nextCursor: next.isBefore(_earliest) ? null : _isoDate(next),
    );
  }

  @override
  Future<DownloadTicket> prepareDownload(RemoteWallpaper wallpaper) async {
    final ext = p.extension(wallpaper.fullUrl.path).replaceFirst('.', '').toLowerCase();
    return DownloadTicket(
      url: wallpaper.fullUrl,
      wallpaper: wallpaper,
      fileExtension: ext == 'jpeg' ? 'jpg' : (ext.isEmpty ? 'jpg' : ext),
    );
  }

  Future<RemoteWallpaper?> _fetchDay(DateTime day) async {
    final key = _isoDate(day);
    if (_days.containsKey(key)) return _days[key];
    await _burst.acquire();
    await _limiter.acquire();
    final path = '${day.year}/${_two(day.month)}/${_two(day.day)}';
    try {
      final response = await _dio.get<Object?>('$feedBase/$path');
      final data = response.data;
      return _days[key] = data is Map ? parseFeed(data.cast<String, Object?>(), day) : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Today's feed may not exist yet, so only remember older gaps.
        final now = _today().toUtc();
        if (day.isBefore(DateTime.utc(now.year, now.month, now.day))) _days[key] = null;
        return null;
      }
      throw SourceException.fromDio(name, e);
    }
  }

  /// Reads the `image` (Picture of the Day) part of one day's feed.
  static RemoteWallpaper? parseFeed(Map<String, Object?> json, DateTime day) {
    final image = _map(json['image']);
    final original = _map(image['image']);
    final source = original['source'] as String?;
    if (source == null) return null;
    final fullUrl = Uri.parse(source);
    if (!_usable.contains(p.extension(fullUrl.path).toLowerCase())) {
      _log.fine('Skipping ${_isoDate(day)}: not a photo format');
      return null;
    }
    final thumb = _map(image['thumbnail'])['source'] as String?;
    final artist = _text(image['artist']);
    final licence = _map(image['license']);
    final licenceName = licence['type'] as String?;
    final filePage = image['file_page'] as String?;
    final description = _text(image['description']);
    final fileTitle = (image['title'] as String?)?.replaceFirst('File:', '');
    return RemoteWallpaper(
      sourceId: sourceId,
      id: _isoDate(day),
      fullUrl: fullUrl,
      thumbnailUrl: Uri.parse(thumb ?? source),
      pageUrl: filePage == null ? null : Uri.parse(filePage),
      width: original['width'] as int?,
      height: original['height'] as int?,
      title: description ?? (fileTitle == null ? null : p.withoutExtension(fileTitle)),
      date: day,
      attribution: Attribution(
        authorName: artist,
        authorUrl: filePage,
        licence: licenceName,
        creditLine: [
          artist ?? 'Unknown author',
          'Wikimedia Commons',
          ?licenceName,
        ].join(' · '),
      ),
    );
  }

  /// Wikimedia sends HTML fields as `{html, text}`; take the plain text.
  static String? _text(Object? v) {
    final text = (_map(v)['text'] as String?)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
}
