import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';

const storageChannel = MethodChannel('dev.mcoombes.wallpaperfetcher/storage');

/// Folders picked through Android's system folder picker.
abstract final class PickedFolders {
  /// Opens the picker. With [persist], the app keeps access after restarts.
  /// Returns the folder's URI, or null if the user backed out.
  static Future<String?> pick({bool persist = true}) => storageChannel.invokeMethod<String>('pick', {'persist': persist});

  /// Gives up the app's lasting access to a folder it no longer uses.
  static Future<void> release(String uri) => storageChannel.invokeMethod<void>('release', {'tree': uri});

  /// `Pictures/Wallpapers` for `content://…/tree/primary%3APictures%2FWallpapers`.
  static String describe(String uri) {
    final segments = Uri.tryParse(uri)?.pathSegments ?? const [];
    final i = segments.indexOf('tree');
    if (i < 0 || i + 1 >= segments.length) return 'Picked folder';
    final id = segments[i + 1];
    final colon = id.indexOf(':');
    if (colon < 0) return id;
    final volume = id.substring(0, colon);
    final path = id.substring(colon + 1);
    if (volume == 'primary') return path.isEmpty ? 'Phone storage' : path;
    return path.isEmpty ? 'SD card' : 'SD card: $path';
  }
}

/// A library in a folder the user picked on Android. There are no file paths;
/// everything goes through `StorageChannel.kt`. Files that need a path
/// (downloads in progress, imports) are staged in [stagingDirectory].
class SafLibraryStorage implements LibraryStorage {
  SafLibraryStorage(this.root, {required this.stagingDirectory, this._channel = storageChannel});

  @override
  final String root;
  final String stagingDirectory;
  final MethodChannel _channel;

  @override
  String get displayName => PickedFolders.describe(root);

  @override
  String? get directory => null;

  /// `WallpaperChannel.kt` opens these through the same folder.
  @override
  String locate(String path) => '$root#$path';

  Future<T?> _call<T>(String method, [String path = '', Map<String, Object?> extra = const {}]) async {
    try {
      return await _channel.invokeMethod<T>(method, {'tree': root, 'path': path, ...extra});
    } on PlatformException catch (e) {
      throw FileSystemException(e.message ?? "Couldn't use the library folder", path.isEmpty ? displayName : '$displayName/$path');
    }
  }

  @override
  Future<void> prepare() async {
    if (!await available()) {
      throw FileSystemException("The app can't open that folder any more. Choose it again in Settings", displayName);
    }
  }

  @override
  Future<bool> available() async => await _call<bool>('available') ?? false;

  @override
  Stream<String> list() async* {
    yield* Stream.fromIterable(await _channel.invokeListMethod<String>('list', {'tree': root}) ?? const []);
  }

  @override
  Future<bool> exists(String path) async => await _call<bool>('exists', path) ?? false;

  @override
  Future<int> length(String path) async => await _call<int>('length', path) ?? 0;

  @override
  Future<String> sha256(String path) async => (await _call<String>('sha256', path))!;

  @override
  Future<Resolution?> imageSize(String path) async => switch (await _call<List<Object?>>('imageSize', path)) {
    [final int w, final int h] => (width: w, height: h),
    _ => null,
  };

  @override
  Future<Uint8List> readBytes(String path) async => (await _call<Uint8List>('read', path))!;

  @override
  Future<String?> readText(String path) async {
    if (!await exists(path)) return null;
    return utf8.decode(await readBytes(path));
  }

  @override
  Future<void> writeText(String path, String text) =>
      _call<void>('write', path, {'bytes': utf8.encode(text)});

  @override
  Future<String> stagingFile(String path) async {
    await Directory(stagingDirectory).create(recursive: true);
    return p.join(stagingDirectory, '${path.replaceAll(RegExp(r'[/\\]'), '_')}.part');
  }

  @override
  Future<void> putFile(String source, String path, {bool move = false}) =>
      _call<void>('putFile', path, {'source': source, 'move': move});

  @override
  Future<void> getFile(String path, String destination) =>
      _call<void>('getFile', path, {'destination': destination});

  @override
  Future<void> delete(String path) => _call<void>('delete', path);
}
