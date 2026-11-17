import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../models/attribution.dart';
import '../models/remote_wallpaper.dart';

final _log = Logger('Sidecar');

/// The metadata stored next to each downloaded image (`name.json`), so the
/// library can be rebuilt from the folder alone.
final class Sidecar {
  const Sidecar({
    required this.source,
    required this.sourceId,
    this.pageUrl,
    this.downloadUrl,
    this.title,
    this.tags = const [],
    this.attribution = Attribution.none,
    this.dominantColour,
    this.downloadedAt,
    this.favourite = false,
    this.hidden = false,
  });

  factory Sidecar.fromRemote(RemoteWallpaper w, {DateTime? downloadedAt}) =>
      Sidecar(
        source: w.sourceId,
        sourceId: w.id,
        pageUrl: w.pageUrl?.toString(),
        downloadUrl: w.fullUrl.toString(),
        title: w.title,
        tags: w.tags,
        attribution: w.attribution,
        dominantColour: w.colours.firstOrNull,
        downloadedAt: downloadedAt ?? DateTime.now(),
      );

  /// For files that were already in the folder, with no known source.
  factory Sidecar.local(String sha256) =>
      Sidecar(source: localSource, sourceId: sha256.substring(0, 16));

  factory Sidecar.fromJson(Map<String, Object?> json) {
    final source = json['source'];
    final sourceId = json['sourceId'];
    if (source is! String || source.isEmpty || sourceId is! String || sourceId.isEmpty) {
      throw const FormatException('sidecar without source/sourceId');
    }
    return Sidecar(
      source: source,
      sourceId: sourceId,
      pageUrl: json['pageUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      title: json['title'] as String?,
      tags: (json['tags'] as List? ?? const []).whereType<String>().toList(),
      attribution: json['attribution'] is Map
          ? Attribution.fromJson((json['attribution'] as Map).cast<String, Object?>())
          : Attribution.none,
      dominantColour: json['dominantColour'] as int?,
      downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? ''),
      favourite: json['favourite'] == true,
      hidden: json['hidden'] == true,
    );
  }

  static const localSource = 'local';
  static const formatVersion = 1;

  final String source;
  final String sourceId;
  final String? pageUrl;
  final String? downloadUrl;
  final String? title;
  final List<String> tags;
  final Attribution attribution;
  final int? dominantColour;
  final DateTime? downloadedAt;

  /// Library state, kept here too so it survives a database rebuild.
  final bool favourite;
  final bool hidden;

  Sidecar copyWith({List<String>? tags, bool? favourite, bool? hidden}) => Sidecar(
    source: source,
    sourceId: sourceId,
    pageUrl: pageUrl,
    downloadUrl: downloadUrl,
    title: title,
    tags: tags ?? this.tags,
    attribution: attribution,
    dominantColour: dominantColour,
    downloadedAt: downloadedAt,
    favourite: favourite ?? this.favourite,
    hidden: hidden ?? this.hidden,
  );

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'createdBy': 'Wallpaper Fetcher',
    'source': source,
    'sourceId': sourceId,
    'pageUrl': pageUrl,
    'downloadUrl': downloadUrl,
    'title': title,
    'tags': tags,
    'attribution': attribution.toJson(),
    'dominantColour': dominantColour,
    'downloadedAt': downloadedAt?.toUtc().toIso8601String(),
    'favourite': favourite,
    'hidden': hidden,
  };

  /// Returns null if there is no sidecar or it can't be read.
  static Future<Sidecar?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return null;
      return Sidecar.fromJson(json.cast<String, Object?>());
    } on Object catch (e) {
      _log.warning('Ignoring unreadable sidecar $path: $e');
      return null;
    }
  }

  Future<void> write(String path) async {
    final tmp = File('$path.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()));
    await tmp.rename(path);
  }
}
