import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';

/// A library folder with no file paths, like a folder picked through
/// Android's file picker. Files live in memory; staging uses [scratch].
class MemoryStorage implements LibraryStorage {
  MemoryStorage(this.root, this.scratch);

  @override
  final String root;
  final String scratch;
  final files = <String, Uint8List>{};

  @override
  String get displayName => 'Picked folder';

  @override
  String? get directory => null;

  @override
  String locate(String path) => '$root/$path';

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> available() async => true;

  @override
  Stream<String> list() => Stream.fromIterable(files.keys.toList());

  Uint8List _get(String path) =>
      files[path] ?? (throw FileSystemException('No such file', locate(path)));

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<int> length(String path) async => _get(path).length;

  @override
  Future<String> sha256(String path) async => sha256Of(_get(path));

  static String sha256Of(List<int> bytes) => crypto.sha256.convert(bytes).toString();

  @override
  Future<Resolution?> imageSize(String path) async => readImageSize(_get(path));

  @override
  Future<Uint8List> readBytes(String path) async => _get(path);

  @override
  Future<String?> readText(String path) async => files.containsKey(path) ? utf8.decode(files[path]!) : null;

  @override
  Future<void> writeText(String path, String text) async => files[path] = utf8.encode(text);

  @override
  Future<String> stagingFile(String path) async {
    await Directory(scratch).create(recursive: true);
    return p.join(scratch, '${path.replaceAll('/', '_')}.part');
  }

  @override
  Future<void> putFile(String source, String path, {bool move = false}) async {
    files[path] = await File(source).readAsBytes();
    if (move) await File(source).delete();
  }

  @override
  Future<void> getFile(String path, String destination) => File(destination).writeAsBytes(_get(path));

  @override
  Future<void> delete(String path) async => files.remove(path);
}
