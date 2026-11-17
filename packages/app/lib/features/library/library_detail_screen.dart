import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/files.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../apply/apply_sheet.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final path = library.absolutePath(item);
    final sourceName = ref.watch(sourcesProvider)[item.source]?.name ??
        (item.source == Sidecar.localSource ? 'your folder' : item.source);

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
            Icons.public,
            item.creditLine ?? 'From $sourceName',
            onTap: item.authorUrl == null ? null : () => openWebPage(item.authorUrl!),
          ),
          if (item.sourcePageUrl case final page?)
            _Info(Icons.open_in_new, 'View on $sourceName', onTap: () => openWebPage(page)),
          _Info(Icons.calendar_today_outlined, 'Added ${formatDate(item.addedAt)}'),
          _Info(
            Icons.history,
            item.applyCount == 0
                ? 'Not used yet'
                : 'Used ${item.applyCount} time${item.applyCount == 1 ? '' : 's'}, last on ${formatDate(item.lastAppliedAt!)}',
          ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in item.tags) Chip(label: Text(t), visualDensity: VisualDensity.compact)],
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showInFolder(path),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Show in folder'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(item.title ?? '${sourceName[0].toUpperCase()}${sourceName.substring(1)} · ${item.sourceId}')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final image = ImageViewer(image: FileImage(File(path)));
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: image),
                SizedBox(width: 340, child: SingleChildScrollView(child: panel)),
              ],
            );
          }
          return ListView(children: [AspectRatio(aspectRatio: 16 / 10, child: image), panel]);
        },
      ),
    );
  }
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
    title: Text(text),
    trailing: onTap == null ? null : const Icon(Icons.open_in_new, size: 16),
    onTap: onTap,
  );
}
