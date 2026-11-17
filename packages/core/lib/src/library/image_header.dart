import 'dart:io';
import 'dart:typed_data';

import '../models/orientation.dart';

/// Reads an image's pixel size from its header without decoding it.
/// Supports JPEG, PNG, WebP, GIF and BMP. Returns null if unrecognised.
Resolution? readImageSize(Uint8List b) {
  int be16(int i) => (b[i] << 8) | b[i + 1];
  int le16(int i) => b[i] | (b[i + 1] << 8);
  int be32(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  int le24(int i) => b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);
  int le32s(int i) => ByteData.sublistView(b, i, i + 4).getInt32(0, Endian.little);
  bool ascii(int i, String s) {
    if (b.length < i + s.length) return false;
    for (var k = 0; k < s.length; k++) {
      if (b[i + k] != s.codeUnitAt(k)) return false;
    }
    return true;
  }

  Resolution? ok(int w, int h) => w > 0 && h > 0 ? (width: w, height: h) : null;

  // PNG: signature, then the IHDR chunk.
  if (b.length >= 24 && b[0] == 0x89 && ascii(1, 'PNG') && ascii(12, 'IHDR')) {
    return ok(be32(16), be32(20));
  }
  // GIF
  if (b.length >= 10 && ascii(0, 'GIF8')) return ok(le16(6), le16(8));
  // BMP: height is negative for top-down bitmaps.
  if (b.length >= 26 && ascii(0, 'BM')) return ok(le32s(18), le32s(22).abs());
  // WebP
  if (b.length >= 30 && ascii(0, 'RIFF') && ascii(8, 'WEBP')) {
    if (ascii(12, 'VP8 ')) return ok(le16(26) & 0x3fff, le16(28) & 0x3fff);
    if (ascii(12, 'VP8L') && b[20] == 0x2f) {
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      return ok((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
    }
    if (ascii(12, 'VP8X')) return ok(le24(24) + 1, le24(27) + 1);
    return null;
  }
  // JPEG: walk the segments until a start-of-frame marker.
  if (b.length >= 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 3 < b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      if (marker == 0xFF) {
        i++; // fill byte
        continue;
      }
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2; // markers without a length
        continue;
      }
      if (marker == 0xD9 || marker == 0xDA) return null; // end / scan data
      final length = be16(i + 2);
      final isFrame = marker >= 0xC0 && marker <= 0xCF &&
          marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
      if (isFrame) {
        if (i + 8 >= b.length) return null;
        return ok(be16(i + 7), be16(i + 5));
      }
      i += 2 + length;
    }
  }
  return null;
}

/// Reads the size from a file, looking at the first 256 KB and falling back to
/// the whole file (big EXIF blocks can push the JPEG frame header further in).
Future<Resolution?> readImageSizeFromFile(String path) async {
  final raf = await File(path).open();
  try {
    final head = await raf.read(256 * 1024);
    final size = readImageSize(head);
    if (size != null) return size;
    final length = await raf.length();
    if (length <= head.length) return null;
    await raf.setPosition(0);
    return readImageSize(await raf.read(length));
  } finally {
    await raf.close();
  }
}
