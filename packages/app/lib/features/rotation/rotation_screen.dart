import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../providers.dart';
import '../../widgets/common.dart';

const _intervals = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 3),
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(days: 1),
];

String intervalLabel(Duration d) => switch (d.inMinutes) {
  < 60 => '${d.inMinutes} min',
  1440 => 'Daily',
  final m when m % 60 == 0 => m == 60 ? '1 hour' : '${m ~/ 60} hours',
  final m => '$m min',
};

class RotationScreen extends ConsumerStatefulWidget {
  const RotationScreen({super.key});

  @override
  ConsumerState<RotationScreen> createState() => _RotationScreenState();
}

class _RotationScreenState extends ConsumerState<RotationScreen> {
  // Keeps "next change in N min" current.
  late final Timer _clock = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  bool _busy = false;

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  RotationService get _rotation => ref.read(servicesProvider).rotation;

  Future<void> _configure(RotationConfig config) => _rotation.configure(config);

  Future<void> _act(Future<RotationOutcome> Function() action) async {
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (!outcome.changed && mounted) showSnack(context, outcome.message ?? 'Nothing changed.');
    } on Object catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(rotationStateProvider).value ?? _rotation.state;
    final config = state.config;
    final targets = ref.watch(targetsProvider).value ?? const <DisplayTarget>[];
    final monitors = [for (final t in targets) if (t.surface == TargetSurface.home) t];
    final chosen = config.screens.isEmpty ? {for (final m in monitors) m.id} : config.screens;
    final isDaily = config.pool is DailyPool;

    Widget section(String title, Widget child, {String? hint}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Rotation')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Card.outlined(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Change wallpaper automatically'),
                      subtitle: Text(_status(state)),
                      value: config.enabled,
                      onChanged: (on) => _configure(config.copyWith(enabled: on)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _act(_rotation.previous),
                            icon: const Icon(Icons.skip_previous),
                            label: const Text('Previous'),
                          ),
                          FilledButton.icon(
                            onPressed: _busy ? null : () => _act(_rotation.next),
                            icon: _busy
                                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.skip_next),
                            label: const Text('Next now'),
                          ),
                          if (config.enabled)
                            OutlinedButton.icon(
                              onPressed: () => _rotation.setPaused(!state.paused),
                              icon: Icon(state.paused ? Icons.play_arrow : Icons.pause),
                              label: Text(state.paused ? 'Resume' : 'Pause'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              section(
                'From',
                _PoolChooser(config: config, onChanged: (pool) => _configure(config.copyWith(pool: pool))),
                hint: isDaily
                    ? "Checks for a new picture every hour and puts it on every screen below. It's kept in your library."
                    : 'Images hidden from rotation are skipped. Each screen gets a different image.',
              ),
              if (!isDaily)
                section(
                  'Every',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in {..._intervals, config.interval})
                        ChoiceChip(
                          label: Text(intervalLabel(d)),
                          selected: d == config.interval,
                          onSelected: (_) => _configure(config.copyWith(interval: d)),
                        ),
                    ],
                  ),
                ),
              if (!isDaily)
                section(
                  'Order',
                  SegmentedButton<RotationOrder>(
                    segments: [for (final o in RotationOrder.values) ButtonSegment(value: o, label: Text(o.label))],
                    selected: {config.order},
                    onSelectionChanged: (s) => _configure(config.copyWith(order: s.single)),
                  ),
                  hint: 'In order goes through the pool from the oldest download, picking up where each screen left off.',
                ),
              section(
                'Screens',
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in targets)
                      FilterChip(
                        avatar: Icon(t.surface == TargetSurface.lock ? Icons.lock_outline : Icons.monitor, size: 18),
                        label: Text(t.label),
                        selected: chosen.contains(t.id),
                        onSelected: (on) {
                          final next = {...chosen};
                          on ? next.add(t.id) : next.remove(t.id);
                          if (next.isEmpty) return; // something must rotate
                          // "Every monitor" is the default; store it as such.
                          final allMonitors = next.length == monitors.length && monitors.every((m) => next.contains(m.id));
                          _configure(config.copyWith(screens: allMonitors ? <String>{} : next));
                        },
                      ),
                  ],
                ),
                hint: targets.isEmpty ? ref.watch(setterCapabilitiesProvider).value?.note : null,
              ),
              section(
                'Fit',
                SegmentedButton<FitMode>(
                  segments: [for (final f in FitMode.values) ButtonSegment(value: f, label: Text(f.label))],
                  selected: {config.fit},
                  onSelectionChanged: (s) => _configure(config.copyWith(fit: s.single)),
                ),
              ),
              const _ShortcutsCard(),
            ],
          ),
        ),
      ),
    );
  }

  String _status(RotationState state) {
    if (!state.config.enabled) return 'Off. Next and Previous still work here, in the tray and from shortcuts.';
    if (state.paused) return 'Paused.';
    final due = state.nextDue;
    if (due == null) return 'On.';
    final left = due.difference(DateTime.now());
    final when = left.inMinutes < 1
        ? 'within a minute'
        : left.inMinutes < 60
        ? 'in ${left.inMinutes} min'
        : 'in ${left.inHours} h ${left.inMinutes % 60} min';
    return state.config.pool is DailyPool ? 'On. Next check $when.' : 'On. Next change $when.';
  }
}

class _PoolChooser extends ConsumerWidget {
  const _PoolChooser({required this.config, required this.onChanged});

  final RotationConfig config;
  final ValueChanged<RotationPool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = (ref.watch(libraryTagsProvider).value ?? const []).take(30);
    final sourceIds = ref.watch(librarySourceIdsProvider).value ?? const [];
    final total = ref.watch(libraryTotalProvider).value;
    final pools = <RotationPool>{
      const AllPool(),
      const FavouritesPool(),
      for (final t in tags) TagPool(t.tag),
      for (final id in sourceIds) SourcePool(id),
      const DailyPool(BingSource.sourceId),
      const DailyPool(WikimediaSource.sourceId),
      config.pool,
    }.toList();

    String label(RotationPool pool) => switch (pool) {
      AllPool() => total == null ? 'Whole library' : 'Whole library ($total)',
      FavouritesPool() => 'Favourites',
      TagPool(:final tag) => 'Tagged "$tag"',
      SourcePool(:final sourceId) => 'From ${sourceName(ref, sourceId)}',
      DailyPool(:final sourceId) => "Today's ${sourceName(ref, sourceId)} picture",
    };
    IconData icon(RotationPool pool) => switch (pool) {
      AllPool() => Icons.photo_library_outlined,
      FavouritesPool() => Icons.favorite_border,
      TagPool() => Icons.sell_outlined,
      SourcePool() => Icons.public,
      DailyPool() => Icons.today_outlined,
    };

    return ChoiceMenuChip<RotationPool>(
      icon: icon(config.pool),
      value: config.pool,
      options: pools,
      labelOf: label,
      leadingOf: (p) => Icon(icon(p), size: 18),
      onSelected: onChanged,
    );
  }
}

/// The command to bind to shortcuts: the launcher's full path when it can be
/// found, because desktop sessions often don't have ~/.local/bin on PATH.
String shortcutCommand([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final dirs = [...(env['PATH'] ?? '').split(':'), p.join(env['HOME'] ?? '', '.local', 'bin')];
  for (final dir in dirs.where((d) => d.isNotEmpty)) {
    final launcher = File(p.join(dir, 'wallpaper-fetcher'));
    if (launcher.existsSync()) return launcher.path;
  }
  return 'wallpaper-fetcher';
}

class _ShortcutsCard extends StatelessWidget {
  const _ShortcutsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cli = shortcutCommand();
    final commands = [
      ('$cli next', 'Next wallpaper on every rotation screen'),
      ('$cli previous', 'Back to the previous one'),
      ('$cli favourite', "Favourite what's on the main monitor"),
      ('$cli next --screen DP-2', 'Just one screen (ids from "wallpaper-fetcher screens")'),
    ];
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.keyboard_outlined),
                const SizedBox(width: 8),
                Text('Keyboard shortcuts', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Bind these commands to keys. In KDE: System Settings → Keyboard → Shortcuts → '
              'Add New → Command or Script, paste a command, then set its shortcut. They work '
              'whether or not this app is open, and show a notification if something goes wrong.',
            ),
            const SizedBox(height: 8),
            if (cli == 'wallpaper-fetcher')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "The wallpaper-fetcher command isn't installed yet; see the README.",
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            for (final (command, what) in commands)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(command, style: const TextStyle(fontFamily: 'monospace')),
                subtitle: Text(what),
                trailing: IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: command));
                    if (context.mounted) showSnack(context, 'Copied "$command".');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
