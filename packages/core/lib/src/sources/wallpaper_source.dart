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

/// A source-specific choice, e.g. a Wallhaven category.
final class SourceOption {
  const SourceOption(this.id, this.label);

  final String id;
  final String label;
}

/// A colour a source can filter by.
final class SourceColour {
  const SourceColour(this.id, this.label, this.argb);

  /// What the source's API expects.
  final String id;
  final String label;

  /// 0xAARRGGBB, for the swatch.
  final int argb;
}

final class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.sort = SortMode.toplist,
    this.topRange = TopRange.month,
    this.orientation,
    this.minResolution,
    this.categories,
    this.colour,
  });

  static const _unset = Object();

  final String text;
  final SortMode sort;
  final TopRange topRange;

  /// Null means any orientation.
  final WallpaperOrientation? orientation;

  /// Null means any size.
  final Resolution? minResolution;

  /// [SourceOption.id]s from [SourceCapabilities.categories]. Null means the
  /// source's defaults.
  final Set<String>? categories;

  /// A [SourceColour.id], or null for any colour.
  final String? colour;

  SearchQuery copyWith({
    String? text,
    SortMode? sort,
    TopRange? topRange,
    Object? orientation = _unset,
    Object? minResolution = _unset,
    Object? categories = _unset,
    Object? colour = _unset,
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
    categories: identical(categories, _unset)
        ? this.categories
        : categories as Set<String>?,
    colour: identical(colour, _unset) ? this.colour : colour as String?,
  );

  /// Whether [w] passes the size and shape filters. Unknown sizes pass.
  bool accepts(RemoteWallpaper w) {
    final (width, height) = (w.width, w.height);
    if (width == null || height == null) return true;
    if (minResolution case final min?) {
      if (width < min.width || height < min.height) return false;
    }
    if (orientation case final o?) {
      if (WallpaperOrientation.of(width, height) != o) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.text == text &&
      other.sort == sort &&
      other.topRange == topRange &&
      other.orientation == orientation &&
      other.minResolution == minResolution &&
      _sameSet(other.categories, categories) &&
      other.colour == colour;

  @override
  int get hashCode => Object.hash(
    text,
    sort,
    topRange,
    orientation,
    minResolution,
    categories == null ? null : Object.hashAllUnordered(categories!),
    colour,
  );

  static bool _sameSet(Set<String>? a, Set<String>? b) =>
      a == null ? b == null : b != null && a.length == b.length && a.containsAll(b);
}

final class SourceCapabilities {
  const SourceCapabilities({
    this.supportsSearch = false,
    this.supportsOrientation = false,
    this.supportsMinResolution = false,
    this.supportsTopRange = false,
    this.sortModes = const [],
    this.categories = const [],
    this.defaultCategories = const {},
    this.colours = const [],
    this.isDaily = false,
    this.requiresApiKey = false,
    this.apiKeyUrl,
    this.attributionText,
    this.attributionUrl,
    this.notice,
    this.creditOnDisplay = false,
  });

  final bool supportsSearch;
  final bool supportsOrientation;
  final bool supportsMinResolution;
  final bool supportsTopRange;
  final List<SortMode> sortModes;
  final List<SourceOption> categories;
  final Set<String> defaultCategories;
  final List<SourceColour> colours;

  /// Publishes one image a day (Bing, Wikimedia).
  final bool isDaily;
  final bool requiresApiKey;

  /// Where to get a key.
  final String? apiKeyUrl;

  /// A credit to show wherever the source's results are listed, e.g.
  /// "Photos from Unsplash", linking to [attributionUrl].
  final String? attributionText;
  final String? attributionUrl;

  /// Terms worth knowing, e.g. "personal use only".
  final String? notice;

  /// The source's terms require crediting the author wherever an image is
  /// shown (Unsplash).
  final bool creditOnDisplay;
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

  /// One page of results. Sources filter out results that fail
  /// [SearchQuery.accepts], so a page can be empty while more pages remain.
  Future<SourcePage> search(SearchQuery query, {String? cursor});

  /// Called right before downloading. Sources with download rules (Unsplash's
  /// download ping) follow them here.
  Future<DownloadTicket> prepareDownload(RemoteWallpaper wallpaper);
}

class SourceException implements Exception {
  SourceException(this.message, {this.statusCode, this.cause, this.needsApiKey = false});

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
    return SourceException(
      message,
      statusCode: status,
      cause: e,
      needsApiKey: status == 401,
    );
  }

  factory SourceException.missingKey(String sourceName) => SourceException(
    '$sourceName needs a free API key. Add it in Settings.',
    needsApiKey: true,
  );

  final String message;
  final int? statusCode;
  final Object? cause;

  /// The source has no key, or rejected it: point the user at Settings.
  final bool needsApiKey;

  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}
