import 'package:dio/dio.dart';

import '../models/orientation.dart';
import '../models/remote_wallpaper.dart';

enum SortMode {
  toplist('Top'),
  latest('Latest'),
  random('Random'),
  views('Most viewed'),
  favourites('Most favourited'),
  relevance('Best match');

  const SortMode(this.label);
  final String label;
}

/// Time window for [SortMode.toplist].
enum TopRange {
  day('1d', 'Today'),
  threeDays('3d', 'Last 3 days'),
  week('1w', 'This week'),
  month('1M', 'This month'),
  threeMonths('3M', 'Last 3 months'),
  sixMonths('6M', 'Last 6 months'),
  year('1y', 'This year');

  const TopRange(this.code, this.label);
  final String code;
  final String label;
}

final class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.sort = SortMode.toplist,
    this.topRange = TopRange.month,
    this.orientation,
    this.minResolution,
  });

  static const _unset = Object();

  final String text;
  final SortMode sort;
  final TopRange topRange;

  /// Null means any orientation.
  final WallpaperOrientation? orientation;

  /// Null means any size.
  final Resolution? minResolution;

  SearchQuery copyWith({
    String? text,
    SortMode? sort,
    TopRange? topRange,
    Object? orientation = _unset,
    Object? minResolution = _unset,
  }) => SearchQuery(
    text: text ?? this.text,
    sort: sort ?? this.sort,
    topRange: topRange ?? this.topRange,
    orientation: identical(orientation, _unset)
        ? this.orientation
        : orientation as WallpaperOrientation?,
    minResolution: identical(minResolution, _unset)
        ? this.minResolution
        : minResolution as Resolution?,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.text == text &&
      other.sort == sort &&
      other.topRange == topRange &&
      other.orientation == orientation &&
      other.minResolution == minResolution;

  @override
  int get hashCode =>
      Object.hash(text, sort, topRange, orientation, minResolution);
}

final class SourceCapabilities {
  const SourceCapabilities({
    this.supportsSearch = false,
    this.supportsOrientation = false,
    this.supportsMinResolution = false,
    this.supportsTopRange = false,
    this.sortModes = const [],
    this.isDaily = false,
    this.requiresApiKey = false,
  });

  final bool supportsSearch;
  final bool supportsOrientation;
  final bool supportsMinResolution;
  final bool supportsTopRange;
  final List<SortMode> sortModes;

  /// Publishes one image a day (Bing, NASA APOD).
  final bool isDaily;
  final bool requiresApiKey;
}

final class SourcePage {
  const SourcePage({required this.items, this.nextCursor, this.total});

  final List<RemoteWallpaper> items;

  /// Pass to [WallpaperSource.search] for the next page. Null on the last page.
  final String? nextCursor;
  final int? total;
}

/// Everything needed to download one image.
final class DownloadTicket {
  const DownloadTicket({
    required this.url,
    required this.wallpaper,
    required this.fileExtension,
    this.headers = const {},
  });

  final Uri url;

  /// The wallpaper with any extra details fetched for the download (tags,
  /// uploader), so they end up in the library.
  final RemoteWallpaper wallpaper;

  /// Without the dot, e.g. `jpg`.
  final String fileExtension;
  final Map<String, String> headers;
}

/// A place wallpapers come from.
abstract interface class WallpaperSource {
  /// Stable identifier, also the library sub-folder name, e.g. `wallhaven`.
  String get id;
  String get name;
  SourceCapabilities get capabilities;

  Future<SourcePage> search(SearchQuery query, {String? cursor});

  /// Called right before downloading. Sources with download rules (Unsplash's
  /// download ping) follow them here.
  Future<DownloadTicket> prepareDownload(RemoteWallpaper wallpaper);
}

class SourceException implements Exception {
  SourceException(this.message, {this.statusCode, this.cause});

  factory SourceException.fromDio(String sourceName, DioException e) {
    final status = e.response?.statusCode;
    final message = switch (e.type) {
      DioExceptionType.badResponse when status == 429 =>
        '$sourceName is limiting how fast we can make requests. Try again in a minute.',
      DioExceptionType.badResponse when status == 401 || status == 403 =>
        '$sourceName rejected the request (HTTP $status). Check its API key in Settings.',
      DioExceptionType.badResponse =>
        '$sourceName returned an error (HTTP $status).',
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        "Couldn't reach $sourceName. Check your internet connection.",
      DioExceptionType.cancel => 'The request was cancelled.',
      _ => 'Something went wrong talking to $sourceName.',
    };
    return SourceException(message, statusCode: status, cause: e);
  }

  final String message;
  final int? statusCode;
  final Object? cause;

  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}
