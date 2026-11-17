import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

Uint8List bytes(List<int> b) => Uint8List.fromList(b);

void main() {
  test('PNG', () {
    expect(readImageSize(fakePng(3840, 2160)), (width: 3840, height: 2160));
  });

  test('JPEG, skipping APP segments before the frame header', () {
    final jpeg = bytes([
      0xFF, 0xD8, // SOI
      0xFF, 0xE1, 0x00, 0x06, 1, 2, 3, 4, // APP1, 4 bytes of payload
      0xFF, 0xFF, // fill byte
      0xFF, 0xC2, 0x00, 0x11, 0x08, 0x08, 0x70, 0x0F, 0x00, // SOF2: 2160 tall, 3840 wide
      ...List.filled(12, 0),
    ]);
    expect(readImageSize(jpeg), (width: 3840, height: 2160));
  });

  test('JPEG without a frame header before the scan is unreadable', () {
    expect(readImageSize(bytes([0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02, 0, 0])), isNull);
  });

  test('GIF and BMP (including top-down BMPs)', () {
    expect(readImageSize(bytes([...'GIF89a'.codeUnits, 0x80, 0x07, 0x38, 0x04])), (width: 1920, height: 1080));
    final bmp = Uint8List(26)
      ..setAll(0, 'BM'.codeUnits)
      ..buffer.asByteData().setInt32(18, 1920, Endian.little)
      ..buffer.asByteData().setInt32(22, -1080, Endian.little);
    expect(readImageSize(bmp), (width: 1920, height: 1080));
  });

  test('WebP: lossy, lossless and extended', () {
    Uint8List riff(String chunk, List<int> payload) =>
        bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, ...chunk.codeUnits, 0, 0, 0, 0, ...payload]);

    final lossy = riff('VP8 ', [0, 0, 0, 0x9D, 0x01, 0x2A, 0x00, 0x0F, 0x70, 0x08, 0, 0]);
    expect(readImageSize(lossy), (width: 3840, height: 2160));

    // 14 bits of width-1 then 14 bits of height-1, little-endian.
    const w = 3840 - 1, h = 2160 - 1;
    const packed = w | (h << 14);
    final lossless = riff('VP8L', [0x2f, packed & 0xff, (packed >> 8) & 0xff, (packed >> 16) & 0xff, (packed >> 24) & 0xff, 0, 0, 0, 0, 0]);
    expect(readImageSize(lossless), (width: 3840, height: 2160));

    final extended = riff('VP8X', [0, 0, 0, 0, 0xFF, 0x0E, 0x00, 0x6F, 0x08, 0x00]);
    expect(readImageSize(extended), (width: 3840, height: 2160));
  });

  test('anything else is null', () {
    expect(readImageSize(bytes('hello world'.codeUnits)), isNull);
    expect(readImageSize(Uint8List(0)), isNull);
  });

  test('orientation and resolution helpers', () {
    expect(WallpaperOrientation.of(3840, 2160), WallpaperOrientation.landscape);
    expect(WallpaperOrientation.of(1080, 2520), WallpaperOrientation.portrait);
    expect(WallpaperOrientation.of(2256, 2504), WallpaperOrientation.portrait);
    expect(WallpaperOrientation.of(2000, 2050), WallpaperOrientation.square);
    expect(parseResolution('3840x2160'), (width: 3840, height: 2160));
    expect(parseResolution('any'), isNull);
    expect(formatResolution((width: 1920, height: 1080)), '1920x1080');
  });
}
