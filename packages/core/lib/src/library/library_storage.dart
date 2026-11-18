import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/orientation.dart';
import 'hashing.dart';
import 'image_header.dart';

/// Where the library's files live. Paths are relative to the library folder
/// with `/` separators, as stored in the database.
///
/// Usually a folder on disk ([LocalLibraryStorage]). On Android it can also
/// be a folder the user picked through the system file picker, which the app
/// can only reach through the picker's own API (no file paths).
abstract interface class LibraryStorage {
  /// Identifies the folder; stored in settings. A path, or a `content://` URI.
  String get root;

  /// Shown to the user.
  String get displayName;

  /// The folder on disk, or null when there's no file path for it.
  String? get directory;

  /// Creates the folder if needed. Throws if it can't be used.
  Future<void> prepare();

  Future<bool> available();

  /// Every file below the folder, recursively, including sidecars.
  Stream<String> list();

  Future<bool> exists(String path);
  Future<int> length(String path);
  Future<String> sha256(String path);
  Future<Resolution?> imageSize(String path);
  Future<Uint8List> readBytes(String path);

  /// Null if there's no such file.
  Future<String?> readText(String path);
  Future<void> writeText(String path, String text);

  /// A local file to download [path] into before [putFile] moves it in.
  Future<String> stagingFile(String path);

  /// Puts the local file [source] at [path], replacing what's there. With
  /// [move], [source] is gone afterwards.
  Future<void> putFile(String source, String path, {bool move = false});

  /// Copies [path] out to the local file [destination].
  Future<void> getFile(String path, String destination);

  /// Does nothing if the file isn't there.
  Future<void> delete(String path);

  /// What a wallpaper setter is given: a file path or a `content://` URI.
  String locate(String path);
}

/// A plain folder on disk.
class LocalLibraryStorage implements LibraryStorage {
  LocalLibraryStorage(String root) : root = p.normalize(p.absolute(root));

  @override
  final String root;

  @override
  String get displayName => root;

  @override
  String get directory => root;

  File _file(String path) => File(locate(path));

  @override
  String locate(String path) => p.joinAll([root, ...p.posix.split(path)]);

  @override
  Future<void> prepare() => Directory(root).create(recursive: true);

  @override
  Future<bool> available() => Directory(root).exists();

  @override
  Stream<String> list() async* {
    await for (final entity in Directory(root).list(recursive: true, followLinks: false)) {
      if (entity is File) yield p.posix.joinAll(p.split(p.relative(entity.path, from: root)));
    }
  }

  @override
  Future<bool> exists(String path) => _file(path).exists();

  @override
  Future<int> length(String path) => _file(path).length();

  @override
  Future<String> sha256(String path) => hashFile(locate(path));

  @override
  Future<Resolution?> imageSize(String path) => readImageSizeFromFile(locate(path));

  @override
  Future<Uint8List> readBytes(String path) => _file(path).readAsBytes();

  @override
  Future<String?> readText(String path) async {
    final file = _file(path);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> writeText(String path, String text) async {
    final file = _file(path);
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text);
    await tmp.rename(file.path);
  }

  /// Next to the final file, so moving it in is a rename.
  @override
  Future<String> stagingFile(String path) async {
    final file = _file(path);
    await file.parent.create(recursive: true);
    return '${file.path}.part';
  }

  @override
  Future<void> putFile(String source, String path, {bool move = false}) async {
    final to = locate(path);
    if (p.equals(source, to)) return;
    await File(to).parent.create(recursive: true);
    if (move) {
      await moveFile(source, to);
    } else {
      await File(source).copy(to);
    }
  }

  @override
  Future<void> getFile(String path, String destination) async {
    await File(destination).parent.create(recursive: true);
    await _file(path).copy(destination);
  }

  @override
  Future<void> delete(String path) async {
    final file = _file(path);
    if (await file.exists()) await file.delete();
  }

  /// Renames, or copies and deletes across drives.
  static Future<void> moveFile(String from, String to) async {
    final file = File(from);
    try {
      await file.rename(to);
    } on FileSystemException {
      await file.copy(to);
      await file.delete();
    }
  }
}
