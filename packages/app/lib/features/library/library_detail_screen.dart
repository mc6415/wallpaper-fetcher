import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/files.dart';
import '../../platform/library_image.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../apply/apply_sheet.dart';
import '../apply/crop_screen.dart';
import 'history_screen.dart';
import 'image_viewer.dart';

class LibraryDetailScreen extends ConsumerWidget {
  const LibraryDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(libraryItemProvider(id));
    return switch (item) {
      AsyncValue(value: final item?) => _Detail(item: item),
      AsyncValue(hasValue: true) => Scaffold(
        appBar: AppBar(),
        body: const MessageView(icon: Icons.hide_image_outlined, title: 'This wallpaper is no longer in your library'),
      ),
      AsyncValue(error: final e?) => Scaffold(
        appBar: AppBar(),
        body: MessageView(icon: Icons.error_outline, title: 'Something went wrong', message: '$e'),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.item});

  final LibraryItem item;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this wallpaper?'),
        content: const Text('The image file is deleted from your library folder.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(libraryProvider).delete(item);
      if (context.mounted) {
        context.go('/library');
        showSnack(context, 'Deleted.');
      }
    } on Object catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  /// Choose where this image is cropped on screens of another shape.
  Future<void> _adjustCrop(BuildContext context, WidgetRef ref) async {
    final screens = [
      for (final t in await ref.read(targetsProvider.future))
        if (t.surface == TargetSurface.home) t,
    ];
    if (!context.mounted) return;
    final focus = await showCropScreen(context, item: item, screens: screens, actionLabel: 'Save');
    if (focus != null) await ref.read(libraryProvider).setFocus(item, focus);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final name = sourceName(ref, item.source);
    final cropsToFocus = ref.watch(setterCapabilitiesProvider).value?.cropsToFocus ?? false;

    final panel = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => showApplySheet(context, item),
            icon: const Icon(Icons.wallpaper),
            label: const Text('Set as wallpaper…'),
          ),
          const SizedBox(height: 16),
          _Info(Icons.aspect_ratio, formatSize(item.width, item.height)),
          _Info(Icons.insert_drive_file_outlined, formatBytes(item.fileSize)),
          _Info(
            Icons.person_outline,
            item.creditLine ?? 'From $name',
            onTap: item.authorUrl == null ? null : () => openWebPage(item.authorUrl!),
          ),
          if (item.licence case final licence?) _Info(Icons.gavel_outlined, licence),
          if (item.sourcePageUrl case final page?)
            _Info(Icons.open_in_new, 'View on $name', onTap: () => openWebPage(page)),
          _Info(Icons.calendar_today_outlined, 'Added ${formatDate(item.addedAt)}'),
          _Info(
            Icons.history,
            item.applyCount == 0
                ? 'Not used yet'
                : 'Used ${item.applyCount} time${item.applyCount == 1 ? '' : 's'}, last on ${formatDate(item.lastAppliedAt!)}',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            secondary: const Icon(Icons.visibility_off_outlined, size: 20),
            title: const Text('Leave out of rotation'),
            value: item.isHidden,
            onChanged: (v) => library.setHidden(item, v),
          ),
          const SizedBox(height: 8),
          _TagsEditor(item: item),
          const SizedBox(height: 16),
          if (cropsToFocus) ...[
            OutlinedButton.icon(
              onPressed: () => _adjustCrop(context, ref),
              icon: const Icon(Icons.crop),
              label: Text(item.focus == null ? 'Choose the crop…' : 'Adjust the crop…'),
            ),
            const SizedBox(height: 8),
          ],
          if (canOpenFolders && library.storage.directory != null) ...[
            OutlinedButton.icon(
              onPressed: () => showInFolder(library.absolutePath(item)),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Show in folder'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(itemName(item)),
        actions: [
          IconButton(
            tooltip: item.isFavourite ? 'Remove from favourites' : 'Add to favourites',
            icon: Icon(item.isFavourite ? Icons.favorite : Icons.favorite_border),
            onPressed: () => library.setFavourite(item, !item.isFavourite),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final image = ImageViewer(image: LibraryImage(library.storage, item));
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: image),
                SizedBox(width: 360, child: SingleChildScrollView(child: panel)),
              ],
            );
          }
          return ListView(children: [AspectRatio(aspectRatio: 16 / 10, child: image), panel]);
        },
      ),
    );
  }
}

/// Tags as removable chips; tapping one shows the library filtered by it.
class _TagsEditor extends ConsumerWidget {
  const _TagsEditor({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.read(libraryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in item.tags)
              InputChip(
                label: Text(tag),
                visualDensity: VisualDensity.compact,
                tooltip: 'Show wallpapers tagged "$tag"',
                onPressed: () {
                  ref.read(libraryFilterProvider.notifier).set(LibraryFilter(tag: tag));
                  context.go('/library');
                },
                onDeleted: () => library.setTags(item, [...item.tags]..remove(tag)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add tag'),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final tag = await showDialog<String>(context: context, builder: (_) => const _AddTagDialog());
                if (tag != null && tag.trim().isNotEmpty) await library.setTags(item, [...item.tags, tag]);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog();

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add tag'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'e.g. mountains'),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Add')),
    ],
  );
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text, {this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, size: 20),
    title: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
    trailing: onTap == null ? null : const Icon(Icons.open_in_new, size: 16),
    onTap: onTap,
  );
}
