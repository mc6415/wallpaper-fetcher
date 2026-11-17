import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/files.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../apply/apply_sheet.dart';
import '../library/image_viewer.dart';

/// A search result up close, with download and set-as-wallpaper actions.
class RemotePreviewScreen extends ConsumerStatefulWidget {
  const RemotePreviewScreen({super.key, required this.wallpaper});

  final RemoteWallpaper wallpaper;

  @override
  ConsumerState<RemotePreviewScreen> createState() => _RemotePreviewScreenState();
}

class _RemotePreviewScreenState extends ConsumerState<RemotePreviewScreen> {
  RemoteWallpaper get w => widget.wallpaper;

  Future<LibraryItem?> _download() async {
    final item = await downloadWallpaper(ref, w);
    if (item == null && mounted) {
      final error = ref.read(downloadProgressProvider).value?[w.key]?.error;
      showSnack(context, error ?? 'Download failed.');
    }
    return item;
  }

  Future<void> _downloadAndApply() async {
    final item = await _download();
    if (item != null && mounted) await showApplySheet(context, item);
  }

  Future<void> _openInLibrary() async {
    final item = await ref.read(libraryProvider).bySource(w.sourceId, w.id);
    if (item != null && mounted) context.go('/library/${item.id}');
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourcesProvider)[w.sourceId];
    final downloaded = ref.watch(downloadedKeysProvider).value?.contains(w.key) ?? false;
    final progress = ref.watch(downloadProgressProvider).value?[w.key];
    final busy = progress != null && progress.status != DownloadStatus.failed;

    final details = _DetailsPanel(
      wallpaper: w,
      sourceName: source?.name ?? w.sourceId,
      actions: [
        if (downloaded)
          FilledButton.icon(
            onPressed: _openInLibrary,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Open in library'),
          )
        else
          FilledButton.icon(
            onPressed: busy ? null : _download,
            icon: busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(value: progress.fraction, strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(busy ? 'Downloading…' : 'Download'),
          ),
        FilledButton.tonalIcon(
          onPressed: busy ? null : _downloadAndApply,
          icon: const Icon(Icons.wallpaper),
          label: const Text('Set as wallpaper…'),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${source?.name ?? w.sourceId} · ${w.id}'),
        actions: [
          if (w.pageUrl case final page?)
            IconButton(
              tooltip: 'Open on ${source?.name ?? 'the web'}',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openWebPage(page.toString()),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final image = ImageViewer(
            image: NetworkImage((w.previewUrl ?? w.fullUrl).toString()),
            placeholder: NetworkImage(w.thumbnailUrl.toString()),
          );
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: image),
                SizedBox(width: 340, child: SingleChildScrollView(child: details)),
              ],
            );
          }
          return ListView(
            children: [
              AspectRatio(aspectRatio: 16 / 10, child: image),
              details,
            ],
          );
        },
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.wallpaper, required this.sourceName, required this.actions});

  final RemoteWallpaper wallpaper;
  final String sourceName;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = wallpaper;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...actions.expand((a) => [a, const SizedBox(height: 8)]),
          const SizedBox(height: 8),
          if (w.title case final title?) ...[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
          ],
          if (w.date case final date?) _Row(Icons.today_outlined, 'Featured ${formatDate(date)}'),
          if (w.width != null) _Row(Icons.aspect_ratio, formatSize(w.width!, w.height!)),
          if (w.fileSize != null) _Row(Icons.insert_drive_file_outlined, formatBytes(w.fileSize!)),
          _Row(
            Icons.person_outline,
            w.attribution.creditLine ?? 'From $sourceName',
            onTap: w.attribution.authorUrl == null ? null : () => openWebPage(w.attribution.authorUrl!),
          ),
          if (w.attribution.licence case final licence?) _Row(Icons.gavel_outlined, licence),
          if (w.attribution.originalUrl case final original?)
            _Row(Icons.link, 'Original source', onTap: () => openWebPage(original)),
          if (w.colours.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Colours', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final c in w.colours)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.text, {this.onTap});

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
