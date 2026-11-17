import '../models/display_target.dart';

/// Puts images on screens. One implementation per desktop / OS.
abstract interface class WallpaperSetter {
  /// Shown in the UI, e.g. "KDE Plasma".
  String get name;

  /// Re-read every time: monitors come and go.
  Future<List<DisplayTarget>> targets();

  Future<SetterCapabilities> capabilities();

  /// Applies all assignments together (on KDE, both monitors change at once).
  Future<void> apply(List<Assignment> assignments);
}

class WallpaperSetterException implements Exception {
  WallpaperSetterException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Stands in where setting wallpapers isn't supported (yet).
class UnsupportedSetter implements WallpaperSetter {
  const UnsupportedSetter(this.reason, {this.name = 'Unsupported desktop'});

  final String reason;

  @override
  final String name;

  @override
  Future<List<DisplayTarget>> targets() async => const [];

  @override
  Future<SetterCapabilities> capabilities() async =>
      SetterCapabilities(perTarget: false, lockScreen: false, note: reason);

  @override
  Future<void> apply(List<Assignment> assignments) async =>
      throw WallpaperSetterException(reason);
}
