import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';

final class BrowseState {
  const BrowseState({
    required this.query,
    this.items = const [],
    this.nextCursor,
    this.total,
    this.loading = false,
    this.error,
    this.needsApiKey = false,
  });

  static const _keep = Object();

  final SearchQuery query;
  final List<RemoteWallpaper> items;
  final String? nextCursor;
  final int? total;
  final bool loading;

  /// A message for the user when the last request failed.
  final String? error;

  /// The source has no key (or rejected it): point the user at Settings.
  final bool needsApiKey;

  bool get hasMore => nextCursor != null;

  BrowseState copyWith({
    List<RemoteWallpaper>? items,
    Object? nextCursor = _keep,
    Object? total = _keep,
    bool? loading,
    Object? error = _keep,
    bool? needsApiKey,
  }) => BrowseState(
    query: query,
    items: items ?? this.items,
    nextCursor: identical(nextCursor, _keep) ? this.nextCursor : nextCursor as String?,
    total: identical(total, _keep) ? this.total : total as int?,
    loading: loading ?? this.loading,
    error: identical(error, _keep) ? this.error : error as String?,
    needsApiKey: needsApiKey ?? this.needsApiKey,
  );
}

/// Search results for one source, with paging.
class BrowseController extends Notifier<BrowseState> {
  BrowseController(this.sourceId);

  final String sourceId;
  int _generation = 0;

  /// Pages fetched in a row when filters leave a page empty, before giving up
  /// until the user scrolls.
  static const _maxEmptyPages = 4;

  WallpaperSource get _source => ref.read(sourcesProvider)[sourceId]!;

  @override
  BrowseState build() {
    final caps = _source.capabilities;
    final query = SearchQuery(
      // Phones default to wallpapers of their own shape.
      orientation: caps.supportsOrientation
          ? (ref.read(isPhoneProvider) ? WallpaperOrientation.portrait : WallpaperOrientation.landscape)
          : null,
      minResolution: caps.supportsMinResolution ? ref.read(minResolutionProvider) : null,
      sort: caps.sortModes.firstOrNull ?? SortMode.toplist,
    );
    Future.microtask(() => _load(query, reset: true));
    return BrowseState(query: query, loading: true);
  }

  Future<void> search(SearchQuery query) => _load(query, reset: true);

  Future<void> retry() => _load(state.query, reset: state.items.isEmpty);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.error != null) return;
    await _load(state.query, reset: false);
  }

  Future<void> _load(SearchQuery query, {required bool reset}) async {
    final generation = ++_generation;
    var cursor = reset ? null : state.nextCursor;
    state = reset
        ? BrowseState(query: query, loading: true)
        : state.copyWith(loading: true, error: null);
    try {
      // Filters applied by the source (sizes, shapes) can leave a page empty
      // while more remain; keep going a little so the grid isn't blank.
      final found = <RemoteWallpaper>[];
      SourcePage page;
      var pages = 0;
      do {
        page = await _source.search(query, cursor: cursor);
        if (!ref.mounted || generation != _generation) return;
        found.addAll(page.items);
        cursor = page.nextCursor;
        pages++;
      } while (found.isEmpty && cursor != null && pages < _maxEmptyPages);

      final seen = {for (final w in state.items) w.key};
      state = state.copyWith(
        items: [...state.items, ...found.where((w) => seen.add(w.key))],
        nextCursor: page.nextCursor,
        total: page.total,
        loading: false,
        error: null,
        needsApiKey: false,
      );
    } on SourceException catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(loading: false, error: e.message, needsApiKey: e.needsApiKey);
    }
  }
}

final browseProvider = NotifierProvider.family<BrowseController, BrowseState, String>(
  BrowseController.new,
);
