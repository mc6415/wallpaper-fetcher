import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'platform/linux_appearance.dart';
import 'services.dart';

/// Overridden in `main()` with the real services.
final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden'),
);

final libraryProvider = Provider((ref) => ref.watch(servicesProvider).library);
final sourcesProvider = Provider((ref) => ref.watch(servicesProvider).sources);

// --- Library ---------------------------------------------------------------

class LibraryRootNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(libraryProvider).root;

  /// First-run choice: set the folder and pick up anything already in it.
  Future<void> choose(String path) async {
    await ref.read(libraryProvider).setRoot(path);
    state = ref.read(libraryProvider).root;
    await ref.read(rescanProvider.notifier).run();
  }

  /// Moves every wallpaper to [path] and uses it from now on.
  Future<void> moveTo(String path) async {
    await ref.read(libraryProvider).moveTo(path);
    state = ref.read(libraryProvider).root;
  }

  /// Uses [path] without moving anything; the library is rebuilt from it.
  Future<void> switchTo(String path) => choose(path);
}

final libraryRootProvider = NotifierProvider<LibraryRootNotifier, String?>(
  LibraryRootNotifier.new,
);

class LibrarySortNotifier extends Notifier<LibrarySort> {
  @override
  LibrarySort build() => LibrarySort.newest;

  void set(LibrarySort sort) => state = sort;
}

final librarySortProvider = NotifierProvider<LibrarySortNotifier, LibrarySort>(
  LibrarySortNotifier.new,
);

final libraryItemsProvider = StreamProvider<List<LibraryItem>>((ref) {
  ref.watch(libraryRootProvider);
  return ref.watch(libraryProvider).watch(sort: ref.watch(librarySortProvider));
});

final libraryItemProvider = StreamProvider.family<LibraryItem?, int>(
  (ref, id) => ref.watch(libraryProvider).watchById(id),
);

final downloadedKeysProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(libraryProvider).watchDownloadedKeys(),
);

final downloadProgressProvider = StreamProvider<Map<String, DownloadProgress>>((ref) async* {
  final downloads = ref.watch(servicesProvider).downloads;
  yield downloads.current;
  yield* downloads.changes;
});

/// Downloads into the library. Returns null on failure; the failure itself is
/// shown on the tile through [downloadProgressProvider].
Future<LibraryItem?> downloadWallpaper(WidgetRef ref, RemoteWallpaper wallpaper) async {
  final services = ref.read(servicesProvider);
  final source = services.sources[wallpaper.sourceId];
  if (source == null) return null;
  try {
    return await services.downloads.download(source, wallpaper);
  } on Object {
    return null;
  }
}

final class RescanState {
  const RescanState({this.running = false, this.last, this.error});

  final bool running;
  final RescanResult? last;
  final String? error;
}

class RescanNotifier extends Notifier<RescanState> {
  @override
  RescanState build() {
    final startup = ref.read(servicesProvider).startupRescan;
    if (startup == null) return const RescanState();
    startup.then(_finished, onError: _failed);
    return const RescanState(running: true);
  }

  Future<void> run() async {
    final library = ref.read(libraryProvider);
    if (state.running || library.root == null) return;
    state = RescanState(running: true, last: state.last);
    try {
      _finished(await library.rescan());
    } on Object catch (e) {
      _failed(e);
    }
  }

  void _finished(RescanResult result) {
    if (ref.mounted) state = RescanState(last: result);
  }

  void _failed(Object error) {
    if (ref.mounted) state = RescanState(last: state.last, error: '$error');
  }
}

final rescanProvider = NotifierProvider<RescanNotifier, RescanState>(RescanNotifier.new);

// --- Setting wallpapers ----------------------------------------------------

final targetsProvider = FutureProvider<List<DisplayTarget>>(
  (ref) => ref.watch(servicesProvider).setter.targets(),
);

final setterCapabilitiesProvider = FutureProvider<SetterCapabilities>(
  (ref) => ref.watch(servicesProvider).setter.capabilities(),
);

// --- Settings --------------------------------------------------------------

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.watch(servicesProvider).initialSettings[SettingsKeys.themeMode];
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(servicesProvider).settings.set(SettingsKeys.themeMode, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Default minimum resolution for new searches. Null means any size.
class MinResolutionNotifier extends Notifier<Resolution?> {
  @override
  Resolution? build() => parseResolution(
    ref.watch(servicesProvider).initialSettings[SettingsKeys.minResolution],
  );

  Future<void> set(Resolution? resolution) async {
    state = resolution;
    await ref
        .read(servicesProvider)
        .settings
        .set(SettingsKeys.minResolution, resolution == null ? 'any' : formatResolution(resolution));
  }
}

final minResolutionProvider = NotifierProvider<MinResolutionNotifier, Resolution?>(
  MinResolutionNotifier.new,
);

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() {
    if (!Platform.isLinux) return const Appearance();
    final watcher = LinuxAppearanceWatcher();
    ref.onDispose(watcher.dispose);
    watcher.start((appearance) {
      if (ref.mounted) state = appearance;
    });
    return const Appearance();
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(AppearanceNotifier.new);
