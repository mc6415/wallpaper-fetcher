/// Who to credit for a wallpaper, and how.
final class Attribution {
  const Attribution({
    this.authorName,
    this.authorUrl,
    this.licence,
    this.creditLine,
    this.originalUrl,
  });

  factory Attribution.fromJson(Map<String, Object?> json) => Attribution(
    authorName: json['authorName'] as String?,
    authorUrl: json['authorUrl'] as String?,
    licence: json['licence'] as String?,
    creditLine: json['creditLine'] as String?,
    originalUrl: json['originalUrl'] as String?,
  );

  static const none = Attribution();

  /// Photographer, artist or uploader.
  final String? authorName;
  final String? authorUrl;

  /// Licence name or copyright notice.
  final String? licence;

  /// A ready-to-show credit, e.g. "Uploaded to Wallhaven by alice".
  final String? creditLine;

  /// Where the image originally came from, when the source records it.
  final String? originalUrl;

  Map<String, Object?> toJson() => {
    'authorName': authorName,
    'authorUrl': authorUrl,
    'licence': licence,
    'creditLine': creditLine,
    'originalUrl': originalUrl,
  };
}
