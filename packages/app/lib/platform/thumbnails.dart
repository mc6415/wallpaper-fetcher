import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';

/// Small PNG copies of library images for the grid, kept in the app's cache
/// folder (never the library folder) and keyed by file hash.
class ThumbnailCache {
  ThumbnailCache(this.directory);

  static const width = 512;

  final String directory;
  final _pending = <String, Future<File>>{};
  final _slots = Semaphore(2);

  Future<File> forItem(LibraryItem item, String imagePath) {
    final out = File(p.join(directory, '${item.sha256}.png'));
    return _pending[item.sha256] ??= _make(imagePath, out).whenComplete(() {
      _pending.remove(item.sha256);
    });
  }

  Future<File> _make(String source, File out) async {
    if (await out.exists()) return out;
    return _slots.withPermit(() async {
      final buffer = await ui.ImmutableBuffer.fromUint8List(await File(source).readAsBytes());
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.min(width, descriptor.width),
      );
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      if (png == null) throw StateError('Could not encode thumbnail for $source');
      await out.parent.create(recursive: true);
      final tmp = File('${out.path}.tmp');
      await tmp.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return tmp.rename(out.path);
    });
  }
}
