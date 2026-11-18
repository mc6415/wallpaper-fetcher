import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/android/saf_storage.dart';
import '../../platform/files.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../browse/browse_controller.dart';

const _sourceDescriptions = {
  'wallhaven': 'A huge wallpaper collection. Filter by size, shape, colour and category. No key needed.',
  'unsplash': 'High-quality photos. Needs a free API key; new keys allow 50 requests an hour.',
  'bing': "Bing's image of the day for the last 15 days. For personal use.",
  'wikimedia': "Wikimedia Commons' Picture of the Day. Freely licensed.",
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _resolutions = <Resolution?>[
    null,
    (width: 1920, height: 1080),
    (width: 2560, height: 1440),
    (width: 3840, height: 2160),
    (width: 5120, height: 2880),
  ];

  static const _phoneResolutions = <Resolution?>[
    null,
    (width: 1080, height: 1920),
    (width: 1080, height: 2400),
    (width: 1440, height: 2560),
    (width: 1440, height: 3200),
    (width: 2160, height: 3840),
  ];

  /// On a phone: a folder from the system picker, or back to app storage.
  Future<String?> _choosePhoneFolder(BuildContext context, WidgetRef ref) async {
    final onPicked = ref.read(libraryRootProvider)?.startsWith('content://') ?? false;
    final where = !onPicked
        ? 'pick'
        : await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Library folder'),
              children: [
                SimpleDialogOption(onPressed: () => Navigator.pop(context, 'pick'), child: const Text('Pick another folder…')),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, 'app'),
                  child: const Text("Use the app's own storage"),
                ),
              ],
            ),
          );
    return switch (where) {
      'pick' => PickedFolders.pick(),
      'app' => defaultLibraryDirectory(),
      _ => null,
    };
  }

  Future<void> _changeFolder(BuildContext context, WidgetRef ref, String current) async {
    final phone = ref.read(isPhoneProvider);
    final picked = phone
        ? await _choosePhoneFolder(context, ref)
        : await getDirectoryPath(initialDirectory: current, confirmButtonText: 'Use this folder');
    if (picked == null || picked == current || !context.mounted) return;
    final name = switch (picked) {
      final p when p.startsWith('content://') => PickedFolders.describe(p),
      final p when phone && p.contains('/Android/data/') => "the app's own storage",
      final p => p,
    };
    // Counted here: the Library's own count may not have loaded yet.
    final count = (await ref.read(libraryProvider).items()).length;
    if (!context.mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change library folder'),
        content: Text(
          count == 0
              ? 'Use $name for your library?'
              : 'Move your $count wallpapers to $name, or just start using that folder? '
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
      // Hand back access to a picked folder the library has left.
      if (current.startsWith('content://')) await PickedFolders.release(current);
      if (context.mounted) showSnack(context, 'Library folder changed.');
    } on Object catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  Future<void> _editKey(BuildContext context, WidgetRef ref, WallpaperSource source) async {
    final key = await showDialog<String>(
      context: context,
      builder: (_) => _ApiKeyDialog(source: source),
    );
    if (key == null || key.trim().isEmpty || !context.mounted) return;
    try {
      await ref.read(apiKeysProvider.notifier).save(source.id, key);
      ref.invalidate(browseProvider(source.id));
      if (context.mounted) {
        showSnack(context, Platform.isLinux ? '${source.name} key saved to your system keyring.' : '${source.name} key saved.');
      }
    } on Object catch (e) {
      if (context.mounted) showSnack(context, "Couldn't save the key: $e");
    }
  }

  Future<void> _removeKey(BuildContext context, WidgetRef ref, WallpaperSource source) async {
    try {
      await ref.read(apiKeysProvider.notifier).remove(source.id);
      ref.invalidate(browseProvider(source.id));
      if (context.mounted) showSnack(context, '${source.name} key removed.');
    } on Object catch (e) {
      if (context.mounted) showSnack(context, "Couldn't remove the key: $e");
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
    final enabled = ref.watch(enabledSourcesProvider);
    final keys = ref.watch(apiKeysProvider);
    final caps = ref.watch(setterCapabilitiesProvider).value;
    final phone = ref.watch(isPhoneProvider);
    final screens = [
      for (final t in ref.watch(targetsProvider).value ?? const <DisplayTarget>[])
        if (t.surface == TargetSurface.home) (width: t.width, height: t.height),
    ];
    final resolutions = {...(phone ? _phoneResolutions : _resolutions), ...screens, minResolution}.toList();
    final library = ref.watch(libraryProvider);

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
                subtitle: Text(switch (root) {
                  null => 'Not chosen',
                  final r when phone && r.contains('/Android/data/') => "The app's own storage",
                  final r => library.displayName ?? r,
                }),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (root != null && canOpenFolders)
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
              header('Sources'),
              if (services.keyringError case final error?)
                ListTile(
                  leading: Icon(Icons.warning_amber, color: theme.colorScheme.error),
                  title: Text(error),
                  subtitle: Text(
                    phone ? 'Add the keys again below.' : 'Check that your keyring is unlocked, then restart the app.',
                  ),
                ),
              for (final source in services.sources.values) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.public),
                  title: Text(source.name),
                  subtitle: Text(_sourceDescriptions[source.id] ?? source.capabilities.notice ?? ''),
                  value: enabled.contains(source.id),
                  onChanged: (on) => ref.read(enabledSourcesProvider.notifier).setEnabled(source.id, on),
                ),
                if (source.capabilities.requiresApiKey)
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: ListTile(
                      leading: Icon(keys.contains(source.id) ? Icons.key : Icons.key_off_outlined, size: 20),
                      title: Text('${source.name} API key'),
                      subtitle: Text(
                        keys.contains(source.id)
                            ? switch (Platform.operatingSystem) {
                                'android' => 'Saved on this phone, encrypted',
                                'windows' => 'Saved, encrypted with your Windows account',
                                _ => 'Saved in your system keyring',
                              }
                            : 'Not set. ${source.name} stays empty until you add one.',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (source.capabilities.apiKeyUrl case final url?)
                            TextButton(onPressed: () => openWebPage(url), child: const Text('Get a key')),
                          FilledButton.tonal(
                            onPressed: () => _editKey(context, ref, source),
                            child: Text(keys.contains(source.id) ? 'Change…' : 'Add…'),
                          ),
                          if (keys.contains(source.id))
                            IconButton(
                              tooltip: 'Remove key',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeKey(context, ref, source),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
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
                subtitle: Text(switch ((phone, appearance.accent)) {
                  (true, null) => 'Material You needs Android 12 or later, so the default is used',
                  (true, _) => "Follows your phone's Material You colours",
                  (false, null) => 'Your desktop has no accent colour set, so the default is used',
                  (false, _) when Platform.isWindows => "Follows Windows' accent colour",
                  (false, _) => 'Follows your desktop accent colour',
                }),
                trailing: CircleAvatar(radius: 12, backgroundColor: theme.colorScheme.primary),
              ),
              if (ref.watch(desktopProvider) != null) ...[
                header('Desktop'),
                SwitchListTile(
                  secondary: const Icon(Icons.login),
                  title: const Text('Start when I log in'),
                  subtitle: const Text('Starts hidden in the tray so rotation keeps going.'),
                  value: ref.watch(autostartProvider).value ?? false,
                  onChanged: (on) => ref.read(autostartProvider.notifier).set(on),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.inbox_outlined),
                  title: const Text('Keep running in the tray when closed'),
                  subtitle: const Text('Otherwise closing the window quits, and rotation stops.'),
                  value: ref.watch(keepInTrayProvider),
                  onChanged: (on) => ref.read(keepInTrayProvider.notifier).set(on),
                ),
              ],
              header('Setting wallpapers'),
              ListTile(
                leading: Icon(phone ? Icons.smartphone : Icons.desktop_windows_outlined),
                title: Text(services.setter.name),
                subtitle: Text(
                  caps?.note ??
                      [
                        if ((caps?.perTarget ?? false) && screens.length > 1)
                          phone ? 'a different image per screen' : 'a different image per monitor',
                        if (caps?.lockScreen ?? false) 'lock screen',
                        if (caps?.cropsToFocus ?? false) 'you choose the crop',
                      ].join(', ').replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase()),
                ),
              ),
              if (services.setter case final KdeSetter kde)
                SwitchListTile(
                  secondary: const Icon(Icons.blur_on),
                  title: const Text('Blur the wallpaper behind windows'),
                  subtitle: Text(
                    kde.blurAvailable
                        ? 'Uses the Blurred Wallpaper plugin, which blurs the desktop while a window is '
                              'active. Starts with the next wallpaper change.'
                        : "Needs the Blurred Wallpaper plugin (a2n.blur), which isn't installed.",
                  ),
                  value: kde.blurAvailable && ref.watch(kdeBlurProvider),
                  onChanged: kde.blurAvailable ? (on) => ref.read(kdeBlurProvider.notifier).set(on) : null,
                ),
              header('About'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Wallpaper Fetcher'),
                subtitle: Text('Version 0.6.1'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Log files'),
                subtitle: Text(services.logDirectory),
                onTap: canOpenFolders ? () => openFolder(services.logDirectory) : null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.source});

  final WallpaperSource source;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.source.name;
    return AlertDialog(
      title: Text('$name API key'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name == 'Unsplash'
                  ? 'Create an app at unsplash.com/oauth/applications, then paste its "Access Key" '
                        '(not the Secret key). $_whereKeysGo'
                  : 'Paste your $name key. $_whereKeysGo',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: !_visible,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Access key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _visible ? 'Hide' : 'Show',
                  icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.source.capabilities.apiKeyUrl case final url?)
          TextButton(onPressed: () => openWebPage(url), child: const Text('Get a key')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Save')),
      ],
    );
  }
}

String get _whereKeysGo => switch (Platform.operatingSystem) {
  'android' => "It's stored encrypted on this phone, not in a file.",
  'windows' => "It's stored encrypted with your Windows account, not as plain text.",
  _ => 'It is stored in your system keyring, not in a file.',
};
