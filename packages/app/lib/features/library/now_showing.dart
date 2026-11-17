import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';
import '../../widgets/common.dart';
import 'library_thumbnail.dart';

/// One card per screen showing what it has now, with Previous / Next.
class NowShowingStrip extends ConsumerWidget {
  const NowShowingStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(targetsProvider).value ?? const [];
    final now = ref.watch(nowShowingProvider).value ?? const {};
    final shown = [for (final t in targets) if (now.containsKey(t.id)) t];
    if (shown.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _ScreenCard(target: shown[i], showing: now[shown[i].id]!),
      ),
    );
  }
}

class _ScreenCard extends ConsumerStatefulWidget {
  const _ScreenCard({required this.target, required this.showing});

  final DisplayTarget target;
  final NowShowing showing;

  @override
  ConsumerState<_ScreenCard> createState() => _ScreenCardState();
}

class _ScreenCardState extends ConsumerState<_ScreenCard> {
  bool _busy = false;

  Future<void> _step({required bool back}) async {
    setState(() => _busy = true);
    try {
      final applier = ref.read(servicesProvider).applier;
      await (back ? applier.previous(widget.target) : applier.next(widget.target));
    } on Object catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.showing.item;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item == null ? null : () => context.go('/library/${item.id}'),
        child: SizedBox(
          width: 320,
          child: Row(
            children: [
              SizedBox(
                width: 144,
                child: item == null
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.hide_image_outlined),
                      )
                    : LibraryThumbnail(item: item),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.target.label, style: theme.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (widget.showing.appliedAt case final at?)
                        Text(
                          item == null ? 'Image deleted' : 'Set ${formatRelative(at)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Previous wallpaper',
                            visualDensity: VisualDensity.compact,
                            onPressed: _busy || !widget.showing.canGoBack ? null : () => _step(back: true),
                            icon: const Icon(Icons.skip_previous),
                          ),
                          IconButton(
                            tooltip: 'Next wallpaper',
                            visualDensity: VisualDensity.compact,
                            onPressed: _busy || !widget.showing.canGoForward ? null : () => _step(back: false),
                            icon: const Icon(Icons.skip_next),
                          ),
                          if (_busy)
                            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
