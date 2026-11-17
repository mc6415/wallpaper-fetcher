import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';

/// A library image's cached thumbnail, over its dominant colour while it loads.
class LibraryThumbnail extends ConsumerStatefulWidget {
  const LibraryThumbnail({super.key, required this.item, this.fit = BoxFit.cover});

  final LibraryItem item;
  final BoxFit fit;

  @override
  ConsumerState<LibraryThumbnail> createState() => _LibraryThumbnailState();
}

class _LibraryThumbnailState extends ConsumerState<LibraryThumbnail> {
  late Future<File> _thumbnail = _load();

  Future<File> _load() {
    final services = ref.read(servicesProvider);
    return services.thumbnails.forItem(widget.item, services.library.absolutePath(widget.item));
  }

  @override
  void didUpdateWidget(LibraryThumbnail old) {
    super.didUpdateWidget(old);
    if (old.item.sha256 != widget.item.sha256) _thumbnail = _load();
  }

  @override
  Widget build(BuildContext context) {
    final colour = widget.item.dominantColour;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: colour == null ? Theme.of(context).colorScheme.surfaceContainerHighest : Color(colour),
        ),
        FutureBuilder<File>(
          future: _thumbnail,
          builder: (context, snapshot) => switch (snapshot) {
            AsyncSnapshot(data: final file?) => Image.file(file, fit: widget.fit),
            AsyncSnapshot(hasError: true) => const Icon(Icons.broken_image_outlined),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}
