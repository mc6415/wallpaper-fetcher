import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../platform/files.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// First run: choose where the library lives.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  late final Future<String> _defaultFolder = defaultLibraryDirectory();
  bool _busy = false;

  Future<void> _use(String path) async {
    setState(() => _busy = true);
    try {
      await ref.read(libraryRootProvider.notifier).choose(path);
      if (mounted) context.go('/browse');
    } on Object catch (e) {
      if (mounted) showSnack(context, "Couldn't use that folder: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(String initial) async {
    final path = await getDirectoryPath(
      initialDirectory: initial,
      confirmButtonText: 'Use this folder',
    );
    if (path != null) await _use(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<String>(
              future: _defaultFolder,
              builder: (context, snapshot) {
                final folder = snapshot.data;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wallpaper, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Welcome to Wallpaper Fetcher', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(
                      'Choose a folder for your wallpaper library. Downloads go into one '
                      'sub-folder per source, and any images already in the folder are '
                      'added to your library too.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Card.outlined(
                      child: ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: const Text('Suggested folder'),
                        subtitle: Text(folder ?? '…'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy || folder == null ? null : () => _use(folder),
                          icon: _busy
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check),
                          label: const Text('Use this folder'),
                        ),
                        OutlinedButton(
                          onPressed: _busy || folder == null ? null : () => _pick(folder),
                          child: const Text('Choose another…'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
