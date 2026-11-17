import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/files.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'browse_controller.dart';
import 'remote_tile.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(sourcesProvider);
    final sources = [for (final id in ref.watch(enabledSourcesProvider)) ?all[id]];
    if (sources.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Browse')),
        body: MessageView(
          icon: Icons.travel_explore,
          title: 'No sources turned on',
          message: 'Choose where to find wallpapers in Settings.',
          actionLabel: 'Open Settings',
          onAction: () => context.go('/settings'),
        ),
      );
    }
    return DefaultTabController(
      // A new controller when the set of sources changes.
      key: ValueKey(sources.map((s) => s.id).join(',')),
      length: sources.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Browse'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final s in sources) Tab(text: s.name)],
          ),
        ),
        body: TabBarView(
          children: [for (final s in sources) SourceBrowser(key: PageStorageKey(s.id), source: s)],
        ),
      ),
    );
  }
}

/// Search bar, filter chips and an endless grid of results for one source.
class SourceBrowser extends ConsumerStatefulWidget {
  const SourceBrowser({super.key, required this.source});

  final WallpaperSource source;

  @override
  ConsumerState<SourceBrowser> createState() => _SourceBrowserState();
}

class _SourceBrowserState extends ConsumerState<SourceBrowser> with AutomaticKeepAliveClientMixin {
  late final _search = TextEditingController(
    text: ref.read(browseProvider(widget.source.id)).query.text,
  );

  static const _resolutions = <Resolution?>[
    null,
    (width: 1920, height: 1080),
    (width: 2560, height: 1440),
    (width: 3840, height: 2160),
    (width: 5120, height: 2880),
    (width: 7680, height: 4320),
  ];

  @override
  bool get wantKeepAlive => true;

  BrowseController get _controller => ref.read(browseProvider(widget.source.id).notifier);

  void _update(SearchQuery query) => _controller.search(query);

  void _submitSearch(SearchQuery current) {
    final text = _search.text.trim();
    final modes = widget.source.capabilities.sortModes;
    // Searching for something is most useful sorted by relevance, and
    // relevance means nothing without search text.
    final sort = switch ((text.isEmpty, current.sort)) {
      (false, SortMode.toplist) when modes.contains(SortMode.relevance) => SortMode.relevance,
      (true, SortMode.relevance) => SortMode.toplist,
      (_, final s) => s,
    };
    _update(current.copyWith(text: text, sort: sort));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(browseProvider(widget.source.id));
    final query = state.query;
    final caps = widget.source.capabilities;
    final resolutions = {..._resolutions, query.minResolution}.toList();
    final theme = Theme.of(context);

    final chips = <Widget>[
      if (caps.sortModes.length > 1)
        ChoiceMenuChip<SortMode>(
          icon: Icons.sort,
          tooltip: 'Sort',
          value: query.sort,
          options: caps.sortModes,
          labelOf: (s) => s.label,
          onSelected: (s) => _update(query.copyWith(sort: s)),
        ),
      if (caps.supportsTopRange && query.sort == SortMode.toplist)
        ChoiceMenuChip<TopRange>(
          icon: Icons.calendar_today_outlined,
          tooltip: 'Top of',
          value: query.topRange,
          options: TopRange.values,
          labelOf: (r) => r.label,
          onSelected: (r) => _update(query.copyWith(topRange: r)),
        ),
      if (caps.categories.isNotEmpty)
        MultiChoiceMenuChip<String>(
          icon: Icons.category_outlined,
          tooltip: 'Categories',
          selected: query.categories ?? caps.defaultCategories,
          options: [for (final c in caps.categories) c.id],
          labelOf: (id) => caps.categories.firstWhere((c) => c.id == id).label,
          onChanged: (chosen) => _update(query.copyWith(categories: chosen)),
        ),
      if (caps.supportsOrientation)
        ChoiceMenuChip<WallpaperOrientation?>(
          icon: Icons.crop_rotate,
          tooltip: 'Shape',
          value: query.orientation,
          options: [
            if (!caps.isDaily) null,
            WallpaperOrientation.landscape,
            WallpaperOrientation.portrait,
          ],
          labelOf: (o) => switch (o) {
            null => 'Any shape',
            WallpaperOrientation.landscape => 'Landscape',
            WallpaperOrientation.portrait => 'Portrait',
            WallpaperOrientation.square => 'Square',
          },
          onSelected: (o) => _update(query.copyWith(orientation: o)),
        ),
      if (caps.supportsMinResolution)
        ChoiceMenuChip<Resolution?>(
          icon: Icons.aspect_ratio,
          tooltip: 'Minimum size',
          value: query.minResolution,
          options: resolutions,
          labelOf: (r) => r == null ? 'Any size' : 'At least ${formatSize(r.width, r.height)}',
          onSelected: (r) => _update(query.copyWith(minResolution: r)),
        ),
      if (caps.colours.isNotEmpty)
        ChoiceMenuChip<String?>(
          icon: Icons.palette_outlined,
          tooltip: 'Colour',
          value: query.colour,
          options: [null, for (final c in caps.colours) c.id],
          labelOf: (id) => id == null ? 'Any colour' : caps.colours.firstWhere((c) => c.id == id).label,
          leadingOf: (id) => id == null ? null : Swatch(Color(caps.colours.firstWhere((c) => c.id == id).argb)),
          onSelected: (id) => _update(query.copyWith(colour: id)),
        ),
    ];

    return CustomScrollView(
      key: PageStorageKey('${widget.source.id}-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caps.supportsSearch)
                  SearchBar(
                    controller: _search,
                    hintText: 'Search ${widget.source.name}',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_search.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            _submitSearch(query);
                          },
                        ),
                    ],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submitSearch(query),
                  ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: chips),
                ],
                if (caps.attributionText != null || caps.notice != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      if (caps.attributionText case final text?)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          onPressed: caps.attributionUrl == null ? null : () => openWebPage(caps.attributionUrl!),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(text),
                        ),
                      if (caps.notice case final notice?)
                        Text(
                          notice,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        ..._results(context, state),
      ],
    );
  }

  List<Widget> _results(BuildContext context, BrowseState state) {
    final caps = widget.source.capabilities;
    if (state.items.isEmpty) {
      final Widget body;
      if (state.loading) {
        body = const Center(child: CircularProgressIndicator());
      } else if (state.needsApiKey) {
        body = MessageView(
          icon: Icons.key_outlined,
          title: '${widget.source.name} needs an API key',
          message: '${state.error ?? ''}\nKeys are free; you add yours once in Settings and it\'s kept in your system keyring.',
          actionLabel: 'Add key in Settings',
          onAction: () => context.go('/settings'),
        );
      } else if (state.error != null) {
        body = MessageView(
          icon: Icons.cloud_off,
          title: "Couldn't load wallpapers",
          message: state.error,
          actionLabel: 'Try again',
          onAction: _controller.retry,
        );
      } else {
        body = MessageView(
          icon: Icons.image_search,
          title: 'Nothing found',
          message: caps.isDaily
              ? 'No recent pictures match these filters. Try a different shape or size.'
              : 'Try different words, or loosen the filters.',
          actionLabel: state.hasMore ? 'Look further back' : null,
          onAction: state.hasMore ? _controller.loadMore : null,
        );
      }
      return [SliverFillRemaining(hasScrollBody: false, child: body)];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            childAspectRatio: 16 / 10,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            // Start fetching the next page a couple of rows before the end.
            if (index >= state.items.length - 8) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadMore());
            }
            final wallpaper = state.items[index];
            return RemoteTile(
              key: ValueKey(wallpaper.key),
              wallpaper: wallpaper,
              showCredit: caps.creditOnDisplay,
              onOpen: () => context.push('/browse/preview', extra: wallpaper),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: switch (state) {
              BrowseState(loading: true) => const CircularProgressIndicator(),
              BrowseState(error: final error?) => Column(
                children: [
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _controller.retry, child: const Text('Try again')),
                ],
              ),
              BrowseState(hasMore: true) => TextButton(
                onPressed: _controller.loadMore,
                child: const Text('Load more'),
              ),
              _ => Text(
                "That's everything${state.total == null ? '' : ' (${state.total} wallpapers)'}.",
              ),
            },
          ),
        ),
      ),
    ];
  }
}
