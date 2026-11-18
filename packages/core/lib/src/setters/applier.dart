import '../library/database.dart';
import '../library/history.dart';
import '../library/library.dart';
import '../models/display_target.dart';
import 'wallpaper_setter.dart';

/// Applies library items, records it, and steps back and forth through
/// history.
class WallpaperApplier {
  WallpaperApplier({required this.setter, required this.library, required this.history});

  final WallpaperSetter setter;
  final WallpaperLibrary library;
  final WallpaperHistory history;

  Future<void> apply(
    LibraryItem item,
    List<DisplayTarget> targets, {
    FitMode fit = FitMode.fill,
    bool fromHistory = false,
  }) async {
    if (targets.isEmpty) return;
    await setter.apply([for (final target in targets) _assignment(target, item, fit)]);
    final ids = [for (final t in targets) t.id];
    await library.recordApplied(item, ids, viaHistory: fromHistory, fit: fit);
    if (!fromHistory) await history.resetCursors(ids);
  }

  /// Different images on different targets, in one call to the desktop (on
  /// KDE both monitors change together).
  Future<void> applyMany(Map<DisplayTarget, LibraryItem> assignments, {FitMode fit = FitMode.fill}) async {
    if (assignments.isEmpty) return;
    await setter.apply([
      for (final MapEntry(key: target, value: item) in assignments.entries) _assignment(target, item, fit),
    ]);
    final byItem = <int, (LibraryItem, List<String>)>{};
    for (final MapEntry(key: target, value: item) in assignments.entries) {
      (byItem[item.id] ??= (item, <String>[])).$2.add(target.id);
    }
    for (final (item, ids) in byItem.values) {
      await library.recordApplied(item, ids, fit: fit);
      await history.resetCursors(ids);
    }
  }

  Assignment _assignment(DisplayTarget target, LibraryItem item, FitMode fit) => Assignment(
    target: target,
    imagePath: library.absolutePath(item),
    fit: fit,
    focus: item.focus,
    imageSize: item.size,
  );

  /// Puts the previous image back on [target]. Null if there's nothing older.
  Future<LibraryItem?> previous(DisplayTarget target) => _step(target, back: true);

  /// Moves forward again after [previous]. Null if already at the newest.
  Future<LibraryItem?> next(DisplayTarget target) => _step(target, back: false);

  Future<LibraryItem?> _step(DisplayTarget target, {required bool back}) async {
    final step = await history.step(target.id, back: back);
    if (step == null) return null;
    await apply(step.item, [target], fit: step.fit ?? FitMode.fill, fromHistory: true);
    await history.setCursor(target.id, step.position);
    return step.item;
  }
}
