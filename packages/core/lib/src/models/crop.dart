import 'dart:math' as math;

/// Where to centre a crop, 0..1 on each axis of the image.
typedef FocusPoint = ({double x, double y});

/// A rectangle in image pixels.
final class CropRect {
  const CropRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;

  List<int> toList() => [left, top, right, bottom];

  @override
  bool operator ==(Object other) =>
      other is CropRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'CropRect($left, $top, $right, $bottom)';
}

/// The largest part of an image with the screen's shape, centred on [focus]
/// as far as the image's edges allow. Scaling it up or down to the screen
/// fills the screen with nothing stretched ("fill").
CropRect cropToFill(
  int imageWidth,
  int imageHeight,
  int screenWidth,
  int screenHeight, {
  FocusPoint? focus,
}) {
  if (imageWidth <= 0 || imageHeight <= 0 || screenWidth <= 0 || screenHeight <= 0) {
    return CropRect(0, 0, math.max(imageWidth, 0), math.max(imageHeight, 0));
  }
  final screenAspect = screenWidth / screenHeight;
  var width = imageWidth;
  var height = imageHeight;
  if (imageWidth / imageHeight > screenAspect) {
    width = math.min(imageWidth, (imageHeight * screenAspect).round());
  } else {
    height = math.min(imageHeight, (imageWidth / screenAspect).round());
  }
  final fx = (focus?.x ?? 0.5).clamp(0.0, 1.0);
  final fy = (focus?.y ?? 0.5).clamp(0.0, 1.0);
  final left = (fx * imageWidth - width / 2).round().clamp(0, imageWidth - width);
  final top = (fy * imageHeight - height / 2).round().clamp(0, imageHeight - height);
  return CropRect(left, top, left + width, top + height);
}

/// How much of the image a fill crop for the screen leaves out, 0..1.
/// Small amounts (a few percent) aren't worth asking about.
double cropLoss(int imageWidth, int imageHeight, int screenWidth, int screenHeight) {
  if (imageWidth <= 0 || imageHeight <= 0) return 0;
  final crop = cropToFill(imageWidth, imageHeight, screenWidth, screenHeight);
  return 1 - (crop.width * crop.height) / (imageWidth * imageHeight);
}
