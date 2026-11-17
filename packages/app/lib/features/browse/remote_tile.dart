import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';
import '../../widgets/common.dart';

/// One search result: thumbnail, a label (size, date or credit), and a
/// download button that shows progress and "already in library".
class RemoteTile extends ConsumerWidget {
  const RemoteTile({
    super.key,
    required this.wallpaper,
    required this.onOpen,
    this.showCredit = false,
  });

  final RemoteWallpaper wallpaper;
  final VoidCallback onOpen;

  /// Show the author on the tile (Unsplash requires it wherever a photo is
  /// shown).
  final bool showCredit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final w = wallpaper;
    final placeholder = w.colours.isEmpty ? theme.colorScheme.surfaceContainerHighest : Color(w.colours.first);
    final label = [
      if (w.date case final d?) formatDate(d),
      if (showCredit && w.attribution.authorName != null) w.attribution.authorName!,
      if (w.date == null && !showCredit && w.width != null) formatSize(w.width!, w.height!),
    ].join(' · ');

    return Tooltip(
      message: w.title ?? w.attribution.creditLine ?? '',
      waitDuration: const Duration(milliseconds: 600),
      child: Card.filled(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onOpen,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: placeholder),
              Image.network(
                w.thumbnailUrl.toString(),
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                ),
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
              ),
              if (label.isNotEmpty) Positioned(left: 8, bottom: 8, right: 56, child: TileBadge(text: label)),
              Positioned(top: 4, right: 4, child: DownloadButton(wallpaper: w)),
            ],
          ),
        ),
      ),
    );
  }
}

/// White text on a translucent dark pill, for labels over images.
class TileBadge extends StatelessWidget {
  const TileBadge({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: DecoratedBox(
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DownloadButton extends ConsumerWidget {
  const DownloadButton({super.key, required this.wallpaper});

  final RemoteWallpaper wallpaper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded = ref.watch(downloadedKeysProvider).value?.contains(wallpaper.key) ?? false;
    final progress = ref.watch(downloadProgressProvider).value?[wallpaper.key];
    final style = IconButton.styleFrom(
      backgroundColor: Colors.black54,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.black54,
      disabledForegroundColor: Colors.white,
    );

    if (downloaded) {
      return IconButton(
        style: style,
        tooltip: 'In your library',
        onPressed: null,
        icon: const Icon(Icons.download_done),
      );
    }
    if (progress?.status == DownloadStatus.failed) {
      return IconButton(
        style: style.copyWith(backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.error)),
        tooltip: '${progress!.error}\nClick to try again.',
        onPressed: () => downloadWallpaper(ref, wallpaper),
        icon: const Icon(Icons.error_outline),
      );
    }
    if (progress != null) {
      return Tooltip(
        message: progress.status == DownloadStatus.queued ? 'Waiting…' : 'Downloading…',
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: CircularProgressIndicator(
            value: progress.fraction,
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    }
    return IconButton(
      style: style,
      tooltip: 'Download',
      onPressed: () => downloadWallpaper(ref, wallpaper),
      icon: const Icon(Icons.download),
    );
  }
}
