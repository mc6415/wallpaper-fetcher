import 'attribution.dart';
import 'orientation.dart';

/// One result from an online source: enough to show a thumbnail, download the
/// image and credit it.
final class RemoteWallpaper {
  const RemoteWallpaper({
    required this.sourceId,
    required this.id,
    required this.fullUrl,
    required this.thumbnailUrl,
    this.previewUrl,
    this.pageUrl,
    this.width,
    this.height,
    this.fileSize,
    this.mimeType,
    this.title,
    this.tags = const [],
    this.colours = const [],
    this.attribution = Attribution.none,
  });

  final String sourceId;
  final String id;
  final Uri fullUrl;
  final Uri thumbnailUrl;

  /// A larger image than the thumbnail for previews. Null means use [fullUrl].
  final Uri? previewUrl;

  /// The image's page on the source's website.
  final Uri? pageUrl;
  final int? width;
  final int? height;
  final int? fileSize;
  final String? mimeType;
  final String? title;
  final List<String> tags;

  /// Main colours as 0xAARRGGBB, most prominent first.
  final List<int> colours;
  final Attribution attribution;

  /// Unique across all sources, e.g. `wallhaven:abc123`.
  String get key => '$sourceId:$id';

  WallpaperOrientation? get orientation => switch ((width, height)) {
    (final w?, final h?) => WallpaperOrientation.of(w, h),
    _ => null,
  };

  RemoteWallpaper copyWith({
    String? title,
    List<String>? tags,
    Attribution? attribution,
  }) => RemoteWallpaper(
    sourceId: sourceId,
    id: id,
    fullUrl: fullUrl,
    thumbnailUrl: thumbnailUrl,
    previewUrl: previewUrl,
    pageUrl: pageUrl,
    width: width,
    height: height,
    fileSize: fileSize,
    mimeType: mimeType,
    title: title ?? this.title,
    tags: tags ?? this.tags,
    colours: colours,
    attribution: attribution ?? this.attribution,
  );

  @override
  bool operator ==(Object other) => other is RemoteWallpaper && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'RemoteWallpaper($key)';
}
