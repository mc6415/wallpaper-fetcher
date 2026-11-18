import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../models/attribution.dart';
import '../models/crop.dart';
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
    this.focus,
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
      focus: switch (json['focus']) {
        {'x': final num x, 'y': final num y} => (x: x.toDouble(), y: y.toDouble()),
        _ => null,
      },
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

  /// Where crops are centred, when the user has chosen.
  final FocusPoint? focus;

  static const _unset = Object();

  Sidecar copyWith({List<String>? tags, bool? favourite, bool? hidden, Object? focus = _unset}) => Sidecar(
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
    focus: identical(focus, _unset) ? this.focus : focus as FocusPoint?,
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
    if (focus case final f?) 'focus': {'x': f.x, 'y': f.y},
  };

  /// Null if [text] isn't a sidecar. [name] is for the log.
  static Sidecar? parse(String text, {String? name}) {
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      return Sidecar.fromJson(json.cast<String, Object?>());
    } on Object catch (e) {
      _log.warning('Ignoring unreadable sidecar ${name ?? ''}: $e');
      return null;
    }
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Returns null if there is no sidecar or it can't be read.
  static Future<Sidecar?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return parse(await file.readAsString(), name: path);
  }

  Future<void> write(String path) async {
    final tmp = File('$path.tmp');
    await tmp.writeAsString(encode());
    await tmp.rename(path);
  }
}
