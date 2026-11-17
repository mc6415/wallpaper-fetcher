import 'dart:math';

import '../library/database.dart';
import '../library/history.dart';
import '../library/library.dart';
import '../models/display_target.dart';
import '../models/orientation.dart';
import 'rotation_config.dart';

/// Chooses the next image for each screen.
///
/// - Hidden images are never chosen.
/// - Screens in the same round get different images while the pool allows.
/// - Images that match the screen's shape are preferred.
/// - Shuffle avoids what the screen showed recently; in-order continues after
///   the screen's current image (oldest download first).
class RotationPicker {
  RotationPicker(this._library, this._history, {Random? random}) : _random = random ?? Random();

  final WallpaperLibrary _library;
  final WallpaperHistory _history;
  final Random _random;

  Future<List<LibraryItem>> poolItems(RotationPool pool) async {
    final filter = switch (pool) {
      FavouritesPool() => const LibraryFilter(favouritesOnly: true),
      TagPool(:final tag) => LibraryFilter(tag: tag),
      SourcePool(:final sourceId) => LibraryFilter(source: sourceId),
      AllPool() || DailyPool() => const LibraryFilter(),
    };
    final items = await _library.items(filter: filter, sort: LibrarySort.oldest);
    return [for (final item in items) if (!item.isHidden) item];
  }

  /// An image per target, keyed by target id. Empty if the pool is empty.
  /// [exclude] are image ids already used this round.
  Future<Map<String, LibraryItem>> pick(
    RotationConfig config,
    List<DisplayTarget> targets, {
    Set<int> exclude = const {},
  }) async {
    final pool = await poolItems(config.pool);
    if (pool.isEmpty) return const {};
    final used = {...exclude};
    final picks = <String, LibraryItem>{};
    for (final target in targets) {
      final shape = WallpaperOrientation.of(target.width, target.height);
      bool fits(LibraryItem i) => i.orientation == shape || i.orientation == WallpaperOrientation.square;
      final timeline = await _history.timeline(target.id);

      final LibraryItem choice;
      if (config.order == RotationOrder.sequential) {
        final current = timeline.firstOrNull?.item?.id;
        final start = current == null ? -1 : pool.indexWhere((i) => i.id == current);
        LibraryItem? nextWhere(bool Function(LibraryItem) ok) {
          for (var step = 1; step <= pool.length; step++) {
            final candidate = pool[(start + step) % pool.length];
            if (ok(candidate)) return candidate;
          }
          return null;
        }

        choice = nextWhere((i) => !used.contains(i.id) && fits(i)) ??
            nextWhere((i) => !used.contains(i.id)) ??
            pool[(start + 1) % pool.length];
      } else {
        // Remember up to half the pool (max 20) so small pools still vary.
        final recentCount = min(20, pool.length ~/ 2);
        final recent = {for (final e in timeline.take(recentCount)) e.item!.id};
        // Shape matters more than variety: a portrait image on a landscape
        // monitor looks worse than seeing a landscape one again.
        final tiers = [
          (LibraryItem i) => !used.contains(i.id) && !recent.contains(i.id) && fits(i),
          (LibraryItem i) => !used.contains(i.id) && fits(i),
          (LibraryItem i) => !used.contains(i.id) && !recent.contains(i.id),
          (LibraryItem i) => !used.contains(i.id),
          (LibraryItem i) => true,
        ];
        final candidates = tiers.map((ok) => pool.where(ok).toList()).firstWhere((c) => c.isNotEmpty);
        choice = candidates[_random.nextInt(candidates.length)];
      }
      picks[target.id] = choice;
      used.add(choice.id);
    }
    return picks;
  }
}
