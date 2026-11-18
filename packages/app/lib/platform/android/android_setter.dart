import 'package:flutter/services.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

/// One of the phone's built-in screens, portrait, in physical pixels.
typedef PhoneScreen = ({int id, int width, int height});

/// What Android says about the phone (from `WallpaperChannel.kt`).
final class AndroidDevice {
  const AndroidDevice({
    required this.sdk,
    required this.manufacturer,
    required this.model,
    required this.canSet,
    required this.current,
    this.screens = const [],
    this.hasHinge = false,
    this.samsungSubDisplayFlag,
    this.samsungMainDisplayFlag = 4,
  });

  factory AndroidDevice.fromMap(Map<Object?, Object?> map) {
    Resolution size(Object? m) => switch (m) {
      {'width': final int w, 'height': final int h} => (width: w, height: h),
      _ => (width: 1080, height: 1920),
    };
    return AndroidDevice(
      sdk: map['sdk'] as int? ?? 0,
      manufacturer: map['manufacturer'] as String? ?? '',
      model: map['model'] as String? ?? '',
      canSet: map['canSet'] as bool? ?? true,
      hasHinge: map['hasHinge'] as bool? ?? false,
      samsungSubDisplayFlag: map['samsungSubDisplayFlag'] as int?,
      samsungMainDisplayFlag: map['samsungMainDisplayFlag'] as int? ?? 4,
      current: size(map['current']),
      screens: [
        for (final d in (map['displays'] as List? ?? const []).whereType<Map<Object?, Object?>>())
          if (d case {'id': final int id, 'width': final int w, 'height': final int h} when w > 0 && h > 0)
            (id: id, width: w, height: h),
      ],
    );
  }

  final int sdk;
  final String manufacturer;
  final String model;

  /// False when a device policy blocks wallpaper changes.
  final bool canSet;

  /// The screen in use when the app started.
  final Resolution current;
  final List<PhoneScreen> screens;
  final bool hasHinge;

  /// One UI's `which` bits for the cover and main screens; null on phones
  /// that aren't Samsung's.
  final int? samsungSubDisplayFlag;
  final int samsungMainDisplayFlag;

  /// A Samsung foldable (Fold or Flip): a separate wallpaper per screen.
  bool get samsungDualScreen =>
      samsungSubDisplayFlag != null &&
      hasHinge &&
      {for (final s in screens) (s.width, s.height)}.length >= 2;

  /// The big inner screen and the small cover screen of a foldable.
  (PhoneScreen main, PhoneScreen cover)? get foldScreens {
    if (!samsungDualScreen) return null;
    final bySize = [...screens]..sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return (bySize.first, bySize.last);
  }
}

/// Sets wallpapers through `WallpaperManager`, cropping each image to its
/// screen's shape around the image's focus point. On Samsung foldables the
/// main and cover screens (and their lock screens) each get their own image.
class AndroidSetter implements WallpaperSetter {
  AndroidSetter(this.device, {this._channel = wallpaperChannel});

  static const wallpaperChannel = MethodChannel('dev.mcoombes.wallpaperfetcher/wallpaper');

  static const mainId = 'main';
  static const coverId = 'cover';
  static const mainLockId = 'main-lock';
  static const coverLockId = 'cover-lock';
  static const screenId = 'screen';
  static const lockId = 'lock';

  static Future<AndroidSetter> create({MethodChannel channel = wallpaperChannel}) async {
    final map = await channel.invokeMapMethod<Object?, Object?>('device');
    return AndroidSetter(AndroidDevice.fromMap(map ?? const {}), channel: channel);
  }

  final AndroidDevice device;
  final MethodChannel _channel;

  @override
  String get name => device.samsungDualScreen ? 'Samsung foldable' : 'Android';

  @override
  Future<List<DisplayTarget>> targets() async {
    if (device.foldScreens case (final main, final cover)) {
      return [
        DisplayTarget(id: mainId, label: 'Main screen', width: main.width, height: main.height, isPrimary: true),
        DisplayTarget(id: coverId, label: 'Cover screen', width: cover.width, height: cover.height),
        DisplayTarget(
          id: mainLockId,
          label: 'Main lock screen',
          width: main.width,
          height: main.height,
          surface: TargetSurface.lock,
        ),
        DisplayTarget(
          id: coverLockId,
          label: 'Cover lock screen',
          width: cover.width,
          height: cover.height,
          surface: TargetSurface.lock,
        ),
      ];
    }
    final size = device.current;
    return [
      DisplayTarget(id: screenId, label: 'Home screen', width: size.width, height: size.height, isPrimary: true),
      DisplayTarget(id: lockId, label: 'Lock screen', width: size.width, height: size.height, surface: TargetSurface.lock),
    ];
  }

  @override
  Future<SetterCapabilities> capabilities() async => SetterCapabilities(
    perTarget: true,
    lockScreen: true,
    // Android only crops to fill; the focus point says where.
    fitModes: const [FitMode.fill],
    cropsToFocus: true,
    note: device.canSet ? null : 'Changing the wallpaper is blocked on this phone (by a work profile or device policy).',
  );

  /// The `which` argument for `WallpaperManager.setStream`.
  int whichFor(DisplayTarget target) {
    var which = target.surface == TargetSurface.home ? 1 : 2; // FLAG_SYSTEM, FLAG_LOCK
    if (device.samsungDualScreen) {
      final cover = target.id == coverId || target.id == coverLockId;
      which |= cover ? device.samsungSubDisplayFlag! : device.samsungMainDisplayFlag;
    }
    return which;
  }

  @override
  Future<void> apply(List<Assignment> assignments) async {
    final calls = <Map<String, Object?>>[];
    for (final a in assignments) {
      final size = a.imageSize ??
          (a.imagePath.startsWith('content://') ? null : await readImageSizeFromFile(a.imagePath));
      calls.add({
        'path': a.imagePath,
        'which': whichFor(a.target),
        if (size != null)
          'crop': cropToFill(size.width, size.height, a.target.width, a.target.height, focus: a.focus).toList(),
      });
    }
    try {
      await _channel.invokeMethod<Object?>('apply', {'assignments': calls});
    } on PlatformException catch (e) {
      throw WallpaperSetterException(e.message ?? "Couldn't set the wallpaper.", cause: e);
    }
  }

  /// Material You's accent colour (Android 12+), or null.
  static Future<int?> accentColor({MethodChannel channel = wallpaperChannel}) async {
    try {
      return await channel.invokeMethod<int>('accentColor');
    } on PlatformException {
      return null;
    }
  }
}
