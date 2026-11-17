import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../../models/attribution.dart';
import '../../models/orientation.dart';
import '../../models/remote_wallpaper.dart';
import '../wallpaper_source.dart';

final _log = Logger('Bing');

/// Bing's image of the day, from the (unofficial) archive endpoint the Bing
/// homepage uses. No key. About 15 days are available: page 1 is the last 8,
/// page 2 reaches back another 7.
class BingSource implements WallpaperSource {
  BingSource({required this._dio, this.market = 'en-US'});

  static const sourceId = 'bing';
  static const host = 'https://www.bing.com';

  final Dio _dio;

  /// Bing market, e.g. `en-GB`. Markets get different images.
  final String market;

  @override
  String get id => sourceId;

  @override
  String get name => 'Bing';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsOrientation: true,
    isDaily: true,
    attributionText: 'Images of the day from Bing',
    attributionUrl: 'https://www.bing.com',
    notice: 'Bing images are copyrighted by their photographers; use them as personal wallpapers only.',
  );

  @override
  Future<SourcePage> search(SearchQuery query, {String? cursor}) async {
    final secondPage = cursor == '2';
    final portrait = query.orientation == WallpaperOrientation.portrait;
    try {
      final response = await _dio.get<Object?>(
        '$host/HPImageArchive.aspx',
        queryParameters: {'format': 'js', 'idx': secondPage ? '7' : '0', 'n': '8', 'mkt': market},
      );
      final data = response.data;
      final json = data is Map ? data.cast<String, Object?>() : const <String, Object?>{};
      final items = parseArchive(json, portrait: portrait);
      return SourcePage(items: items, nextCursor: secondPage ? null : '2');
    } on DioException catch (e) {
      throw SourceException.fromDio(name, e);
    }
  }

  @override
  Future<DownloadTicket> prepareDownload(RemoteWallpaper wallpaper) async =>
      DownloadTicket(url: wallpaper.fullUrl, wallpaper: wallpaper, fileExtension: 'jpg');

  /// Landscape results use the 4K (`_UHD`) image; portrait ones Bing's
  /// 1080x1920 phone crop.
  static List<RemoteWallpaper> parseArchive(Map<String, Object?> json, {bool portrait = false}) {
    final items = <RemoteWallpaper>[];
    for (final entry in json['images'] as List? ?? const []) {
      if (entry is! Map) continue;
      final image = entry.cast<String, Object?>();
      final base = image['urlbase'] as String?;
      final start = image['startdate'] as String?;
      if (base == null || start == null || start.length != 8) {
        _log.warning('Skipping Bing entry without urlbase/startdate');
        continue;
      }
      // "/th?id=OHR.TrailCedars_EN-GB2504891943" -> "TrailCedars"
      final name = RegExp(r'OHR\.([A-Za-z0-9]+)').firstMatch(base)?.group(1) ?? 'image';
      final copyright = (image['copyright'] as String?)?.trim();
      final photographer = RegExp(r'\(©\s*([^)]+)\)').firstMatch(copyright ?? '')?.group(1)?.trim();
      final date = DateTime.utc(
        int.parse(start.substring(0, 4)),
        int.parse(start.substring(4, 6)),
        int.parse(start.substring(6, 8)),
      );
      items.add(
        RemoteWallpaper(
          sourceId: sourceId,
          id: portrait ? '${start}_${name}_portrait' : '${start}_$name',
          fullUrl: Uri.parse('$host${base}_${portrait ? '1080x1920' : 'UHD'}.jpg'),
          thumbnailUrl: Uri.parse('$host${base}_${portrait ? '480x800' : '400x240'}.jpg'),
          previewUrl: Uri.parse('$host${base}_${portrait ? '1080x1920' : '1920x1080'}.jpg'),
          pageUrl: switch (image['copyrightlink']) {
            final String link when link.startsWith('http') => Uri.parse(link),
            _ => null,
          },
          width: portrait ? 1080 : 3840,
          height: portrait ? 1920 : 2160,
          title: (image['title'] as String?)?.trim(),
          date: date,
          attribution: Attribution(
            authorName: photographer,
            creditLine: copyright ?? 'Bing image of the day',
            licence: 'Personal use only',
          ),
        ),
      );
    }
    return items;
  }
}
