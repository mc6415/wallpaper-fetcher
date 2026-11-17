import '../library/database.dart';
import '../library/library.dart';
import '../models/display_target.dart';
import 'wallpaper_setter.dart';

/// Applies library items and records that it did.
class WallpaperApplier {
  WallpaperApplier({required this.setter, required this.library});

  final WallpaperSetter setter;
  final WallpaperLibrary library;

  Future<void> apply(
    LibraryItem item,
    List<DisplayTarget> targets, {
    FitMode fit = FitMode.fill,
  }) async {
    if (targets.isEmpty) return;
    final path = library.absolutePath(item);
    await setter.apply([
      for (final target in targets)
        Assignment(target: target, imagePath: path, fit: fit),
    ]);
    await library.recordApplied(item, [for (final t in targets) t.id]);
  }
}
