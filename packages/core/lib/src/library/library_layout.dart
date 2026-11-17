import 'package:path/path.dart' as p;

/// Where files live inside the library folder.
abstract final class LibraryLayout {
  static const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'};

  /// `<source>/<source>_<id>.<ext>`, with `/` separators.
  static String relativePathFor(String sourceId, String id, String extension) {
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return p.posix.join(sourceId, '${sourceId}_$safeId.$extension');
  }

  /// The JSON file holding an image's credits sits next to it.
  static String sidecarFor(String imagePath) => p.setExtension(imagePath, '.json');

  static bool isImage(String path) =>
      imageExtensions.contains(p.extension(path).toLowerCase());

  /// Converts a path relative to the library folder into the stored form.
  static String toStored(String relativePath) =>
      p.posix.joinAll(p.split(relativePath));
}
