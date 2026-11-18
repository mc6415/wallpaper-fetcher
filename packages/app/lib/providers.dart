import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'platform/android/android_setter.dart';
import 'platform/autostart.dart';
import 'platform/desktop.dart';
import 'platform/linux_appearance.dart';
import 'platform/windows_appearance.dart';
import 'services.dart';

/// Overridden in `main()` with the real services.
final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden'),
);

final libraryProvider = Provider((ref) => ref.watch(servicesProvider).library);

/// Phone wording and layout (Android). Overridden in tests.
final isPhoneProvider = Provider<bool>((ref) => Platform.isAndroid);
final sourcesProvider = Provider((ref) => ref.watch(servicesProvider).sources);

// --- Sources -----------------------------------------------------------------

/// Source ids shown in Browse, in tab order.
class EnabledSourcesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final services = ref.watch(servicesProvider);
    final saved = services.initialSettings[SettingsKeys.enabledSources];
    final all = services.sources.keys.toList();
    if (saved == null) return all;
    final chosen = splitIds(saved).toSet();
    return [for (final id in all) if (chosen.contains(id)) id];
  }

  Future<void> setEnabled(String sourceId, bool enabled) async {
    final chosen = {...state};
    enabled ? chosen.add(sourceId) : chosen.remove(sourceId);
    state = [for (final id in ref.read(sourcesProvider).keys) if (chosen.contains(id)) id];
    await ref.read(servicesProvider).settings.set(SettingsKeys.enabledSources, state.join(','));
  }
}

final enabledSourcesProvider = NotifierProvider<EnabledSourcesNotifier, List<String>>(
  EnabledSourcesNotifier.new,
);

/// Source ids that have an API key.
class ApiKeysNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(servicesProvider).apiKeys.configured;

  Future<void> save(String sourceId, String key) async {
    final services = ref.read(servicesProvider);
    await services.keyStore.save(sourceId, key.trim());
    services.apiKeys[sourceId] = key;
    await _remember();
  }

  Future<void> remove(String sourceId) async {
    final services = ref.read(servicesProvider);
    await services.keyStore.remove(sourceId);
    services.apiKeys[sourceId] = null;
    await _remember();
  }

  Future<void> _remember() async {
    final services = ref.read(servicesProvider);
    state = services.apiKeys.configured;
    await services.settings.set(SettingsKeys.savedApiKeys, state.isEmpty ? null : state.join(','));
  }
}

final apiKeysProvider = NotifierProvider<ApiKeysNotifier, Set<String>>(ApiKeysNotifier.new);

// --- Library -----------------------------------------------------------------

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

class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();

  void set(LibraryFilter filter) => state = filter;

  void clear() => state = const LibraryFilter();
}

final libraryFilterProvider = NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
  LibraryFilterNotifier.new,
);

final libraryItemsProvider = StreamProvider<List<LibraryItem>>((ref) {
  ref.watch(libraryRootProvider);
  return ref
      .watch(libraryProvider)
      .watch(sort: ref.watch(librarySortProvider), filter: ref.watch(libraryFilterProvider));
});

/// Everything in the library, unfiltered (for counts).
final libraryTotalProvider = StreamProvider<int>((ref) {
  ref.watch(libraryRootProvider);
  return ref.watch(libraryProvider).watch().map((items) => items.length);
});

final libraryItemProvider = StreamProvider.family<LibraryItem?, int>(
  (ref, id) => ref.watch(libraryProvider).watchById(id),
);

final libraryTagsProvider = StreamProvider<List<({String tag, int count})>>(
  (ref) => ref.watch(libraryProvider).watchTags(),
);

final librarySourceIdsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(libraryProvider).watchSourceIds(),
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

/// A display name for a source id, including `local`.
String sourceName(WidgetRef ref, String sourceId) =>
    ref.read(sourcesProvider)[sourceId]?.name ??
    (sourceId == Sidecar.localSource ? 'Your images' : sourceId);

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

// --- Setting wallpapers and history ------------------------------------------

final targetsProvider = FutureProvider<List<DisplayTarget>>(
  (ref) => ref.watch(servicesProvider).setter.targets(),
);

final setterCapabilitiesProvider = FutureProvider<SetterCapabilities>(
  (ref) => ref.watch(servicesProvider).setter.capabilities(),
);

final nowShowingProvider = StreamProvider<Map<String, NowShowing>>(
  (ref) => ref.watch(servicesProvider).history.watchNowShowing(),
);

final recentHistoryProvider = StreamProvider<List<HistoryEntry>>(
  (ref) => ref.watch(servicesProvider).history.watchRecent(),
);

// --- Settings ----------------------------------------------------------------

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
    if (Platform.isAndroid) {
      // Material You: the accent follows the wallpaper, so look again
      // whenever the app comes back to the front.
      final listener = AppLifecycleListener(onResume: _readAndroidAccent);
      ref.onDispose(listener.dispose);
      _readAndroidAccent();
      return const Appearance();
    }
    if (Platform.isWindows) {
      // Light/dark comes from Flutter itself; the accent is re-read whenever
      // the window comes back, in case it was changed meanwhile.
      final listener = AppLifecycleListener(onResume: () {
        final accent = readWindowsAccent();
        if (ref.mounted && accent != state.accent) state = Appearance(accent: accent);
      });
      ref.onDispose(listener.dispose);
      return Appearance(accent: readWindowsAccent());
    }
    if (!Platform.isLinux) return const Appearance();
    final watcher = LinuxAppearanceWatcher();
    ref.onDispose(watcher.dispose);
    watcher.start((appearance) {
      if (ref.mounted) state = appearance;
    });
    return const Appearance();
  }

  Future<void> _readAndroidAccent() async {
    final argb = await AndroidSetter.accentColor();
    if (!ref.mounted) return;
    final accent = argb == null ? null : Color(argb);
    if (accent != state.accent) state = Appearance(accent: accent);
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(AppearanceNotifier.new);


// --- Rotation and desktop integration ----------------------------------------

/// The tray, window and command socket; null in tests and on Android.
final desktopProvider = Provider<DesktopIntegration?>((ref) => null);

final rotationStateProvider = StreamProvider<RotationState>((ref) async* {
  final rotation = ref.watch(servicesProvider).rotation;
  yield rotation.state;
  yield* rotation.changes;
});

/// Close the window to the tray (true) or quit (false).
class KeepInTrayNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(servicesProvider).initialSettings[SettingsKeys.keepInTray] != 'false';

  Future<void> set(bool keep) async {
    state = keep;
    ref.read(desktopProvider)?.keepInTray = keep;
    await ref.read(servicesProvider).settings.set(SettingsKeys.keepInTray, keep ? null : 'false');
  }
}

final keepInTrayProvider = NotifierProvider<KeepInTrayNotifier, bool>(KeepInTrayNotifier.new);

class AutostartNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => Autostart.isEnabled();

  Future<void> set(bool enabled) async {
    await Autostart.setEnabled(enabled);
    state = AsyncData(enabled);
  }
}

final autostartProvider = AsyncNotifierProvider<AutostartNotifier, bool>(AutostartNotifier.new);
