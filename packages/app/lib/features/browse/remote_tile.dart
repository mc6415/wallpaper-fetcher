import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';

/// One search result: thumbnail, size, and a download button that shows
/// progress and "already in library".
class RemoteTile extends ConsumerWidget {
  const RemoteTile({super.key, required this.wallpaper, required this.onOpen});

  final RemoteWallpaper wallpaper;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final placeholder = wallpaper.colours.isEmpty
        ? theme.colorScheme.surfaceContainerHighest
        : Color(wallpaper.colours.first);
    return Card.filled(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: placeholder),
            Image.network(
              wallpaper.thumbnailUrl.toString(),
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: child,
              ),
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
            ),
            if (wallpaper.width case final w?)
              Positioned(
                left: 8,
                bottom: 8,
                child: _Badge(text: '$w × ${wallpaper.height}'),
              ),
            Positioned(top: 4, right: 4, child: DownloadButton(wallpaper: wallpaper)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
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
