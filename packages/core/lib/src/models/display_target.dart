import 'crop.dart';
import 'orientation.dart';

/// Which surface of a display a wallpaper goes on.
enum TargetSurface { home, lock }

/// How an image is fitted to a screen.
enum FitMode {
  /// Scale to cover the whole screen, cropping what overflows.
  fill('Fill'),

  /// Scale to fit inside the screen, leaving bars.
  fit('Fit'),
  stretch('Stretch'),
  centre('Centre'),

  /// One image stretched across every monitor (Windows).
  span('Span');

  const FitMode(this.label);
  final String label;

  /// The modes that fit an image to one screen; [span] covers them all.
  static const perScreen = [fill, fit, stretch, centre];
}

/// Anything that can show a wallpaper: a monitor, the lock screen, a phone
/// screen.
final class DisplayTarget {
  const DisplayTarget({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    this.surface = TargetSurface.home,
    this.isPrimary = false,
  });

  /// Stable identifier, e.g. `DP-1`, `lock`, `android:cover`.
  final String id;

  /// Shown in the UI, e.g. "Left monitor (DP-1)".
  final String label;

  /// Size in physical pixels.
  final int width;
  final int height;
  final TargetSurface surface;
  final bool isPrimary;

  @override
  bool operator ==(Object other) =>
      other is DisplayTarget && other.id == id && other.surface == surface;

  @override
  int get hashCode => Object.hash(id, surface);

  @override
  String toString() => 'DisplayTarget($id, ${width}x$height, ${surface.name})';
}

/// One image going onto one target.
final class Assignment {
  const Assignment({
    required this.target,
    required this.imagePath,
    this.fit = FitMode.fill,
    this.focus,
    this.imageSize,
  });

  final DisplayTarget target;

  /// Absolute path of the image file, or (Android) a `content://` URI.
  final String imagePath;
  final FitMode fit;

  /// Where to centre the crop, 0..1 on each axis. Null means the middle.
  final FocusPoint? focus;

  /// The image's size, when known, so setters that crop needn't read it.
  final Resolution? imageSize;
}

final class SetterCapabilities {
  const SetterCapabilities({
    required this.perTarget,
    required this.lockScreen,
    this.fitModes = const [],
    this.note,
    this.cropsToFocus = false,
  });

  static const none = SetterCapabilities(perTarget: false, lockScreen: false);

  /// Different images on different targets.
  final bool perTarget;
  final bool lockScreen;
  final List<FitMode> fitModes;

  /// Explains what isn't available, when something isn't.
  final String? note;

  /// Crops images to each screen's shape around [Assignment.focus], so it's
  /// worth asking the user where to crop (Android).
  final bool cropsToFocus;
}
