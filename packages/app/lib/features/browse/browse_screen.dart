import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';
import '../../widgets/common.dart';
import 'browse_controller.dart';
import 'remote_tile.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider).values.toList();
    if (sources.length == 1) {
      return Scaffold(
        appBar: AppBar(title: Text('Browse ${sources.single.name}')),
        body: SourceBrowser(source: sources.single),
      );
    }
    return DefaultTabController(
      length: sources.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Browse'),
          bottom: TabBar(tabs: [for (final s in sources) Tab(text: s.name)]),
        ),
        body: TabBarView(children: [for (final s in sources) SourceBrowser(source: s)]),
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

class _SourceBrowserState extends ConsumerState<SourceBrowser> {
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

  BrowseController get _controller => ref.read(browseProvider(widget.source.id).notifier);

  void _update(SearchQuery query) => _controller.search(query);

  void _submitSearch(SearchQuery current) {
    final text = _search.text.trim();
    // Searching for something is most useful sorted by relevance, and
    // relevance means nothing without search text.
    final sort = switch ((text.isEmpty, current.sort)) {
      (false, SortMode.toplist) => SortMode.relevance,
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
    final state = ref.watch(browseProvider(widget.source.id));
    final query = state.query;
    final caps = widget.source.capabilities;
    final resolutions = {..._resolutions, query.minResolution}.toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
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
                    if (caps.supportsOrientation)
                      ChoiceMenuChip<WallpaperOrientation?>(
                        icon: Icons.crop_rotate,
                        tooltip: 'Orientation',
                        value: query.orientation,
                        options: const [null, WallpaperOrientation.landscape, WallpaperOrientation.portrait],
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
                  ],
                ),
              ],
            ),
          ),
        ),
        ..._results(context, state),
      ],
    );
  }

  List<Widget> _results(BuildContext context, BrowseState state) {
    if (state.items.isEmpty) {
      final Widget body;
      if (state.loading) {
        body = const Center(child: CircularProgressIndicator());
      } else if (state.error != null) {
        body = MessageView(
          icon: Icons.cloud_off,
          title: "Couldn't load wallpapers",
          message: state.error,
          actionLabel: 'Try again',
          onAction: _controller.retry,
        );
      } else {
        body = const MessageView(
          icon: Icons.image_search,
          title: 'Nothing found',
          message: 'Try different words, or loosen the filters.',
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
              BrowseState(hasMore: false) => Text(
                "That's everything${state.total == null ? '' : ' (${state.total} wallpapers)'}.",
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    ];
  }
}
