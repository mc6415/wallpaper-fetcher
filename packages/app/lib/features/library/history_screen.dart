import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';
import '../../widgets/common.dart';
import '../apply/apply_sheet.dart';
import 'library_thumbnail.dart';

/// A name for a library image: its title, or its file name.
String itemName(LibraryItem item) => item.title ?? p.basenameWithoutExtension(item.relativePath);

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(recentHistoryProvider);
    final labels = {for (final t in ref.watch(targetsProvider).value ?? const <DisplayTarget>[]) t.id: t.label};
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: switch (entries) {
        AsyncValue(value: final list?) when list.isNotEmpty => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 128),
          itemBuilder: (context, i) {
            final entry = list[i];
            final item = entry.item;
            return ListTile(
              leading: SizedBox(
                width: 96,
                height: 54,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item == null
                      ? ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.hide_image_outlined),
                        )
                      : LibraryThumbnail(item: item),
                ),
              ),
              title: Text(item == null ? 'Deleted image' : itemName(item), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  labels[entry.target] ?? entry.target,
                  formatRelative(entry.appliedAt),
                  if (entry.viaHistory) 'via Previous/Next',
                ].join(' · '),
              ),
              trailing: item == null
                  ? null
                  : IconButton(
                      tooltip: 'Set as wallpaper again',
                      icon: const Icon(Icons.wallpaper),
                      onPressed: () => showApplySheet(context, item),
                    ),
              onTap: item == null ? null : () => context.go('/library/${item.id}'),
            );
          },
        ),
        AsyncValue(value: _?) => const MessageView(
          icon: Icons.history,
          title: 'Nothing set yet',
          message: 'Wallpapers you set appear here, newest first.',
        ),
        AsyncValue(error: final e?) => MessageView(icon: Icons.error_outline, title: 'Something went wrong', message: '$e'),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
