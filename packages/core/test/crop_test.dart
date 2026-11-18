import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

void main() {
  group('cropToFill', () {
    test('a landscape image on a tall phone screen keeps the full height, centred', () {
      final crop = cropToFill(3840, 2160, 1080, 2520);
      expect(crop.height, 2160);
      expect(crop.width, 926); // 2160 * 1080 / 2520
      expect(crop.left, (3840 - 926) ~/ 2);
      expect(crop.top, 0);
    });

    test('the focus moves the crop, stopping at the edges', () {
      expect(cropToFill(3840, 2160, 1080, 2520, focus: (x: 0.0, y: 0.5)).left, 0);
      expect(cropToFill(3840, 2160, 1080, 2520, focus: (x: 1.0, y: 0.5)).right, 3840);
      final third = cropToFill(3840, 2160, 1080, 2520, focus: (x: 1 / 3, y: 0.5));
      expect(third.left + third.width / 2, closeTo(1280, 1));
    });

    test('a portrait image on a near-square screen crops top and bottom', () {
      final crop = cropToFill(2160, 3840, 2256, 2504);
      expect(crop.width, 2160);
      expect(crop.height, 2397); // 2160 * 2504 / 2256
      expect(crop.top, ((3840 - 2397) / 2).round());
      final top = cropToFill(2160, 3840, 2256, 2504, focus: (x: 0.5, y: 0));
      expect(top.top, 0);
    });

    test('an image with the screen shape is used whole', () {
      expect(cropToFill(1080, 2520, 1080, 2520), const CropRect(0, 0, 1080, 2520));
      expect(cropToFill(2160, 5040, 1080, 2520, focus: (x: 0.9, y: 0.1)), const CropRect(0, 0, 2160, 5040));
    });

    test('nonsense sizes give the whole image rather than throwing', () {
      expect(cropToFill(100, 100, 0, 0), const CropRect(0, 0, 100, 100));
    });
  });

  test('cropLoss says how much a screen leaves out', () {
    expect(cropLoss(1080, 2520, 1080, 2520), 0);
    expect(cropLoss(3840, 2160, 1080, 2520), closeTo(1 - 926 / 3840, 0.001));
    expect(cropLoss(2160, 3840, 2256, 2504), closeTo(1 - 2397 / 3840, 0.001));
  });
}
