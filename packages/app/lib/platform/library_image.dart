import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

/// A library image at full size, read through the library's storage: a file,
/// or on Android possibly a folder the user picked (which has no file paths).
@immutable
class LibraryImage extends ImageProvider<LibraryImage> {
  const LibraryImage(this.storage, this.item);

  final LibraryStorage storage;
  final LibraryItem item;

  @override
  Future<LibraryImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(LibraryImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1, debugLabel: item.relativePath);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await storage.readBytes(item.relativePath);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryImage &&
      other.storage.root == storage.root &&
      other.item.relativePath == item.relativePath &&
      other.item.sha256 == item.sha256;

  @override
  int get hashCode => Object.hash(storage.root, item.relativePath, item.sha256);
}
