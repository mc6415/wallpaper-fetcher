import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';
import '../../widgets/common.dart';

/// Asks where to put [item] (each monitor, all monitors, lock screen) and
/// applies it in one tap. Shows a snack bar with the outcome.
Future<void> showApplySheet(BuildContext context, LibraryItem item) async {
  final message = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => ApplySheet(item: item),
  );
  if (message != null && context.mounted) showSnack(context, message);
}

class ApplySheet extends ConsumerStatefulWidget {
  const ApplySheet({super.key, required this.item});

  final LibraryItem item;

  @override
  ConsumerState<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<ApplySheet> {
  FitMode _fit = FitMode.fill;
  String? _busyLabel;
  String? _error;

  Future<void> _apply(String label, List<DisplayTarget> targets) async {
    setState(() {
      _busyLabel = label;
      _error = null;
    });
    try {
      await ref.read(servicesProvider).applier.apply(widget.item, targets, fit: _fit);
      if (mounted) Navigator.of(context).pop('Wallpaper set on ${label[0].toLowerCase()}${label.substring(1)}.');
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busyLabel = null;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targets = ref.watch(targetsProvider);
    final caps = ref.watch(setterCapabilitiesProvider).value;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: switch (targets) {
          AsyncValue(value: final list?) when list.isNotEmpty => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Set as wallpaper', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if ((caps?.fitModes ?? const []).length > 1) ...[
                SegmentedButton<FitMode>(
                  segments: [
                    for (final f in caps!.fitModes) ButtonSegment(value: f, label: Text(f.label)),
                  ],
                  selected: {_fit},
                  onSelectionChanged: (s) => setState(() => _fit = s.single),
                ),
                const SizedBox(height: 8),
              ],
              ..._options(list),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
            ],
          ),
          AsyncValue(error: final error?) => MessageView(
            icon: Icons.error_outline,
            title: "Couldn't find your screens",
            message: '$error',
          ),
          AsyncValue(value: _?) => MessageView(
            icon: Icons.desktop_access_disabled_outlined,
            title: "Can't set wallpapers here yet",
            message: caps?.note,
          ),
          _ => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ),
    );
  }

  List<Widget> _options(List<DisplayTarget> targets) {
    final screens = [for (final t in targets) if (t.surface == TargetSurface.home) t];
    final lock = [for (final t in targets) if (t.surface == TargetSurface.lock) t];
    final item = widget.item;
    final itemShape = WallpaperOrientation.of(item.width, item.height);

    Widget option(IconData icon, String label, List<DisplayTarget> to, {String? subtitle}) {
      final busy = _busyLabel == label;
      return ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right),
        enabled: _busyLabel == null,
        onTap: () => _apply(label, to),
      );
    }

    String? fitNote(DisplayTarget t) {
      final note = <String>[formatSize(t.width, t.height)];
      if (WallpaperOrientation.of(t.width, t.height) != itemShape) note.add('different shape, will be cropped');
      if (item.width < t.width || item.height < t.height) note.add('image is smaller than the screen');
      return note.join(' · ');
    }

    return [
      for (final s in screens) option(Icons.monitor, s.label, [s], subtitle: fitNote(s)),
      if (screens.length > 1) option(Icons.desktop_windows_outlined, 'All monitors', screens),
      for (final l in lock) option(Icons.lock_outline, l.label, [l]),
      if (lock.isNotEmpty && screens.isNotEmpty)
        option(Icons.done_all, 'Everywhere', [...screens, ...lock], subtitle: 'All monitors and the lock screen'),
    ];
  }
}
