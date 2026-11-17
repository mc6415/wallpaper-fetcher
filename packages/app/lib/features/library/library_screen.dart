import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/files.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../apply/apply_sheet.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider);
    final sort = ref.watch(librarySortProvider);
    final rescan = ref.watch(rescanProvider);
    final root = ref.watch(libraryRootProvider);
    final count = items.value?.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(count == null ? 'Library' : 'Library · $count'),
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
            tooltip: 'Rescan the library folder',
            onPressed: rescan.running ? null : () => ref.read(rescanProvider.notifier).run(),
            icon: rescan.running
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          if (root != null)
            IconButton(
              tooltip: 'Open the library folder',
              icon: const Icon(Icons.folder_open_outlined),
              onPressed: () => openFolder(root),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (rescan.error != null)
            MaterialBanner(
              content: Text(rescan.error!),
              leading: const Icon(Icons.warning_amber),
              actions: [TextButton(onPressed: () => context.go('/settings'), child: const Text('Settings'))],
            ),
          Expanded(
            child: switch (items) {
              AsyncValue(value: final list?) when list.isNotEmpty => _Grid(items: list),
              AsyncValue(value: _?) => MessageView(
                icon: Icons.photo_library_outlined,
                title: 'Your library is empty',
                message: 'Wallpapers you download appear here, ready to apply in two clicks.',
                actionLabel: 'Browse wallpapers',
                onAction: () => context.go('/browse'),
              ),
              AsyncValue(error: final error?) => MessageView(
                icon: Icons.error_outline,
                title: "Couldn't load the library",
                message: '$error',
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items});

  final List<LibraryItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        childAspectRatio: 16 / 10,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => LibraryTile(key: ValueKey(items[i].id), item: items[i]),
    );
  }
}

/// A library image: tap for details, or use the button to set it straight away.
class LibraryTile extends ConsumerStatefulWidget {
  const LibraryTile({super.key, required this.item});

  final LibraryItem item;

  @override
  ConsumerState<LibraryTile> createState() => _LibraryTileState();
}

class _LibraryTileState extends ConsumerState<LibraryTile> {
  late Future<File> _thumbnail = _load();

  Future<File> _load() {
    final services = ref.read(servicesProvider);
    return services.thumbnails.forItem(widget.item, services.library.absolutePath(widget.item));
  }

  @override
  void didUpdateWidget(LibraryTile old) {
    super.didUpdateWidget(old);
    if (old.item.sha256 != widget.item.sha256) _thumbnail = _load();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    return Card.filled(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go('/library/${item.id}'),
        onSecondaryTap: () => showApplySheet(context, item),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: item.dominantColour == null
                  ? theme.colorScheme.surfaceContainerHighest
                  : Color(item.dominantColour!),
            ),
            FutureBuilder<File>(
              future: _thumbnail,
              builder: (context, snapshot) => switch (snapshot) {
                AsyncSnapshot(data: final file?) => Image.file(file, fit: BoxFit.cover),
                AsyncSnapshot(hasError: true) => const Icon(Icons.broken_image_outlined),
                _ => const SizedBox.shrink(),
              },
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    formatSize(item.width, item.height),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: IconButton(
                tooltip: 'Set as wallpaper',
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
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
