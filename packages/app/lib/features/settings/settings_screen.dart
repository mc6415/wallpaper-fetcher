import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/files.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _resolutions = <Resolution?>[
    null,
    (width: 1920, height: 1080),
    (width: 2560, height: 1440),
    (width: 3840, height: 2160),
    (width: 5120, height: 2880),
  ];

  Future<void> _changeFolder(BuildContext context, WidgetRef ref, String current) async {
    final picked = await getDirectoryPath(initialDirectory: current, confirmButtonText: 'Use this folder');
    if (picked == null || !context.mounted) return;
    final count = ref.read(libraryItemsProvider).value?.length ?? 0;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change library folder'),
        content: Text(
          count == 0
              ? 'Use $picked for your library?'
              : 'Move your $count wallpapers to $picked, or just start using that folder? '
                    "If you don't move them, the library is rebuilt from what's in the new folder.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (count > 0) TextButton(onPressed: () => Navigator.pop(context, 'switch'), child: const Text("Don't move")),
          FilledButton(
            onPressed: () => Navigator.pop(context, count > 0 ? 'move' : 'switch'),
            child: Text(count > 0 ? 'Move them' : 'Use it'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final notifier = ref.read(libraryRootProvider.notifier);
    try {
      if (choice == 'move') {
        await notifier.moveTo(picked);
      } else {
        await notifier.switchTo(picked);
      }
      if (context.mounted) showSnack(context, 'Library folder changed.');
    } on Object catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final root = ref.watch(libraryRootProvider);
    final rescan = ref.watch(rescanProvider);
    final minResolution = ref.watch(minResolutionProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appearance = ref.watch(appearanceProvider);
    final services = ref.watch(servicesProvider);
    final caps = ref.watch(setterCapabilitiesProvider).value;
    final resolutions = {..._resolutions, minResolution}.toList();

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            children: [
              header('Library'),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Library folder'),
                subtitle: Text(root ?? 'Not chosen'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (root != null)
                      IconButton(tooltip: 'Open', icon: const Icon(Icons.open_in_new), onPressed: () => openFolder(root)),
                    OutlinedButton(
                      onPressed: root == null ? null : () => _changeFolder(context, ref, root),
                      child: const Text('Change…'),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Rescan folder'),
                subtitle: Text(switch (rescan) {
                  RescanState(running: true) => 'Scanning…',
                  RescanState(error: final e?) => e,
                  RescanState(last: final r?) =>
                    'Last scan: ${r.added} added, ${r.moved} moved, ${r.removed} removed',
                  _ => 'Picks up images you add to or remove from the folder yourself',
                }),
                enabled: !rescan.running && root != null,
                onTap: () => ref.read(rescanProvider.notifier).run(),
              ),
              header('Browsing'),
              ListTile(
                leading: const Icon(Icons.aspect_ratio),
                title: const Text('Default minimum size'),
                subtitle: const Text('For new searches. Each search can still change it.'),
                trailing: ChoiceMenuChip<Resolution?>(
                  icon: Icons.aspect_ratio,
                  value: minResolution,
                  options: resolutions,
                  labelOf: (r) => r == null ? 'Any size' : formatSize(r.width, r.height),
                  onSelected: (r) => ref.read(minResolutionProvider.notifier).set(r),
                ),
              ),
              header('Appearance'),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Theme'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.single),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Accent colour'),
                subtitle: Text(
                  appearance.accent == null
                      ? 'Your desktop has no accent colour set, so the default is used'
                      : 'Follows your desktop accent colour',
                ),
                trailing: CircleAvatar(radius: 12, backgroundColor: theme.colorScheme.primary),
              ),
              header('Setting wallpapers'),
              ListTile(
                leading: const Icon(Icons.desktop_windows_outlined),
                title: Text(services.setter.name),
                subtitle: Text(
                  caps?.note ??
                      [
                        if (caps?.perTarget ?? false) 'a different image per monitor',
                        if (caps?.lockScreen ?? false) 'lock screen',
                      ].join(', ').replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase()),
                ),
              ),
              header('About'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Wallpaper Fetcher'),
                subtitle: Text('Version 0.1.0'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Log files'),
                subtitle: Text(services.logDirectory),
                onTap: () => openFolder(services.logDirectory),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
