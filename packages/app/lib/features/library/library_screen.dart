import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/android/saf_storage.dart';
import '../../platform/files.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../apply/apply_sheet.dart';
import '../browse/remote_tile.dart';
import 'library_thumbnail.dart';
import 'now_showing.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final phone = ref.read(isPhoneProvider);
    final folder = phone
        ? await PickedFolders.pick(persist: false)
        : await getDirectoryPath(confirmButtonText: 'Import this folder');
    if (folder == null || !context.mounted) return;
    final name = phone ? PickedFolders.describe(folder) : folder;
    final move = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import images'),
        content: Text(
          'Add the images in $name (and its sub-folders) to your library? '
          "They go into the library's \"local\" folder. Images already in your library are skipped.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          // A picked folder on a phone is only copied from, never changed.
          if (!phone) TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move them')),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Copy them')),
        ],
      ),
    );
    if (move == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [CircularProgressIndicator(), SizedBox(width: 24), Expanded(child: Text('Importing…'))],
        ),
      ),
    );
    String message;
    try {
      final r = phone
          ? await _importPicked(ref.read(libraryProvider), folder)
          : await ref.read(libraryProvider).importFolder(folder, move: move);
      message = [
        'Imported ${r.imported} image${r.imported == 1 ? '' : 's'}',
        if (r.duplicates > 0) '${r.duplicates} already in your library',
        if (r.failed > 0) "${r.failed} couldn't be read",
      ].join(', ');
    } on Object catch (e) {
      message = '$e';
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showSnack(context, '$message.');
    }
  }

  /// Copies a picked folder's images to a scratch folder, then imports that.
  static Future<ImportResult> _importPicked(WallpaperLibrary library, String tree) async {
    final scratch = Directory(
      p.join((await getApplicationCacheDirectory()).path, 'import', '${DateTime.now().millisecondsSinceEpoch}'),
    );
    final source = SafLibraryStorage(tree, stagingDirectory: scratch.path);
    try {
      await for (final path in source.list()) {
        if (!LibraryLayout.isImage(path) || path.split('/').any((part) => part.startsWith('.'))) continue;
        await source.getFile(path, p.joinAll([scratch.path, ...p.posix.split(path)]));
      }
      if (!await scratch.exists()) return const ImportResult();
      final name = p.posix.basename(PickedFolders.describe(tree));
      return await library.importFolder(scratch.path, move: true, folderName: name);
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider);
    final total = ref.watch(libraryTotalProvider).value;
    final filter = ref.watch(libraryFilterProvider);
    final sort = ref.watch(librarySortProvider);
    final rescan = ref.watch(rescanProvider);
    final root = ref.watch(libraryRootProvider);
    final shown = items.value?.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch ((shown, total)) {
          (final s?, final t?) when !filter.isEmpty => 'Library · $s of $t',
          (_, final t?) => 'Library · $t',
          _ => 'Library',
        }),
        actions: [
          MenuAnchor(
            menuChildren: [
              for (final s in LibrarySort.values)
                MenuItemButton(
                  leadingIcon: s == sort ? const Icon(Icons.check, size: 18) : const SizedBox(width: 18),
                  onPressed: () => ref.read(librarySortProvider.notifier).set(s),
                  child: Text(s.label),
                ),
            ],
            builder: (context, controller, _) => IconButton(
              tooltip: 'Sort: ${sort.label}',
              icon: const Icon(Icons.sort),
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => context.go('/library/history'),
          ),
          IconButton(
            tooltip: 'Rescan the library folder',
            onPressed: rescan.running ? null : () => ref.read(rescanProvider.notifier).run(),
            icon: rescan.running
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.drive_folder_upload_outlined),
                onPressed: () => _import(context, ref),
                child: const Text('Import a folder…'),
              ),
              if (root != null && canOpenFolders)
                MenuItemButton(
                  leadingIcon: const Icon(Icons.folder_open_outlined),
                  onPressed: () => openFolder(root),
                  child: const Text('Open library folder'),
                ),
            ],
            builder: (context, controller, _) => IconButton(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (rescan.error != null)
            SliverToBoxAdapter(
              child: MaterialBanner(
                content: Text(rescan.error!),
                leading: const Icon(Icons.warning_amber),
                actions: [TextButton(onPressed: () => context.go('/settings'), child: const Text('Settings'))],
              ),
            ),
          if ((total ?? 0) > 0) ...[
            const SliverToBoxAdapter(child: NowShowingStrip()),
            const SliverToBoxAdapter(child: _FilterBar()),
          ],
          ...switch (items) {
            AsyncValue(value: final list?) when list.isNotEmpty => [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    childAspectRatio: 16 / 10,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) => LibraryTile(key: ValueKey(list[i].id), item: list[i]),
                ),
              ),
            ],
            AsyncValue(value: _?) when !filter.isEmpty => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nothing matches these filters',
                  actionLabel: 'Clear filters',
                  onAction: () => ref.read(libraryFilterProvider.notifier).clear(),
                ),
              ),
            ],
            AsyncValue(value: _?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView(
                  icon: Icons.photo_library_outlined,
                  title: 'Your library is empty',
                  message: 'Wallpapers you download appear here, ready to apply in two clicks. '
                      'You can also import a folder of images you already have.',
                  actionLabel: 'Browse wallpapers',
                  onAction: () => context.go('/browse'),
                ),
              ),
            ],
            AsyncValue(error: final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView(
                  icon: Icons.error_outline,
                  title: "Couldn't load the library",
                  message: '$error',
                ),
              ),
            ],
            _ => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
          },
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar();

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  late final _search = TextEditingController(text: ref.read(libraryFilterProvider).text);

  void _set(LibraryFilter f) => ref.read(libraryFilterProvider.notifier).set(f);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(libraryFilterProvider);
    final sourceIds = ref.watch(librarySourceIdsProvider).value ?? const [];
    final tags = (ref.watch(libraryTagsProvider).value ?? const []).take(40).map((t) => t.tag).toList();
    if (filter.tag != null && !tags.contains(filter.tag)) tags.insert(0, filter.tag!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SearchBar(
              controller: _search,
              hintText: 'Search your library',
              leading: const Icon(Icons.search),
              constraints: const BoxConstraints(minHeight: 40),
              onChanged: (text) => _set(filter.copyWith(text: text)),
            ),
          ),
          if (sourceIds.length > 1)
            ChoiceMenuChip<String?>(
              icon: Icons.public,
              tooltip: 'Source',
              value: filter.source,
              options: [null, ...sourceIds],
              labelOf: (id) => id == null ? 'All sources' : sourceName(ref, id),
              onSelected: (id) => _set(filter.copyWith(source: id)),
            ),
          ChoiceMenuChip<WallpaperOrientation?>(
            icon: Icons.crop_rotate,
            tooltip: 'Shape',
            value: filter.orientation,
            options: const [null, WallpaperOrientation.landscape, WallpaperOrientation.portrait, WallpaperOrientation.square],
            labelOf: (o) => switch (o) {
              null => 'Any shape',
              WallpaperOrientation.landscape => 'Landscape',
              WallpaperOrientation.portrait => 'Portrait',
              WallpaperOrientation.square => 'Square',
            },
            onSelected: (o) => _set(filter.copyWith(orientation: o)),
          ),
          if (tags.isNotEmpty)
            ChoiceMenuChip<String?>(
              icon: Icons.sell_outlined,
              tooltip: 'Tag',
              value: filter.tag,
              options: [null, ...tags],
              labelOf: (t) => t ?? 'Any tag',
              onSelected: (t) => _set(filter.copyWith(tag: t)),
            ),
          FilterChip(
            avatar: const Icon(Icons.favorite_border, size: 18),
            label: const Text('Favourites'),
            selected: filter.favouritesOnly,
            onSelected: (v) => _set(filter.copyWith(favouritesOnly: v)),
          ),
          FilterChip(
            avatar: const Icon(Icons.visibility_off_outlined, size: 18),
            label: const Text('Hidden'),
            tooltip: 'Images left out of rotation',
            selected: filter.hiddenOnly,
            onSelected: (v) => _set(filter.copyWith(hiddenOnly: v)),
          ),
          if (!filter.isEmpty)
            TextButton(
              onPressed: () {
                _search.clear();
                ref.read(libraryFilterProvider.notifier).clear();
              },
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

/// A library image: tap for details, the wallpaper button (or right-click) to
/// set it straight away, the heart to favourite it.
class LibraryTile extends ConsumerWidget {
  const LibraryTile({super.key, required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCredit = ref.watch(sourcesProvider)[item.source]?.capabilities.creditOnDisplay ?? false;
    final label = [
      formatSize(item.width, item.height),
      if (showCredit && item.authorName != null) item.authorName!,
    ].join(' · ');
    final overlay = IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white);

    return Card.filled(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go('/library/${item.id}'),
        onSecondaryTap: () => showApplySheet(context, item),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LibraryThumbnail(item: item),
            Positioned(
              left: 8,
              bottom: 8,
              right: 56,
              child: TileBadge(text: label, icon: item.isHidden ? Icons.visibility_off_outlined : null),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: item.isFavourite ? 'Remove from favourites' : 'Add to favourites',
                style: overlay,
                icon: Icon(item.isFavourite ? Icons.favorite : Icons.favorite_border),
                onPressed: () => ref.read(libraryProvider).setFavourite(item, !item.isFavourite),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: IconButton(
                tooltip: 'Set as wallpaper',
                style: overlay,
                icon: const Icon(Icons.wallpaper),
                onPressed: () => showApplySheet(context, item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
