import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'platform/thumbnails.dart';

final _log = Logger('App');

/// Everything the app needs, created once at startup and handed to Riverpod.
class AppServices {
  AppServices({
    required this.db,
    required this.settings,
    required this.library,
    required this.dio,
    required this.sources,
    required this.downloads,
    required this.setter,
    required this.applier,
    required this.thumbnails,
    required this.initialSettings,
    required this.logDirectory,
    this.startupRescan,
  });

  final AppDatabase db;
  final SettingsStore settings;
  final WallpaperLibrary library;
  final Dio dio;
  final Map<String, WallpaperSource> sources;
  final DownloadManager downloads;
  final WallpaperSetter setter;
  final WallpaperApplier applier;
  final ThumbnailCache thumbnails;

  /// Settings as they were at startup, so providers can start synchronously.
  final Map<String, String> initialSettings;
  final String logDirectory;

  /// The rescan kicked off at startup, if a library folder was already set.
  final Future<RescanResult>? startupRescan;

  static Future<AppServices> create() async {
    final support = await getApplicationSupportDirectory();
    final cache = await getApplicationCacheDirectory();
    final logDirectory = p.join(support.path, 'logs');
    setupLogging(directory: logDirectory, echoToConsole: kDebugMode);
    FlutterError.onError = (details) {
      _log.severe('Flutter error: ${details.exceptionAsString()}', details.exception, details.stack);
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _log.severe('Uncaught error', error, stack);
      return true;
    };

    final db = AppDatabase(
      driftDatabase(
        name: 'library',
        native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
      ),
    );
    final settings = SettingsStore(db);
    final library = WallpaperLibrary(db, settings);
    await library.load();

    final dio = createHttpClient();
    final setter = Platform.isLinux
        ? createLinuxSetter()
        : const UnsupportedSetter("Setting wallpapers on this platform isn't supported yet.");

    var initialSettings = await settings.all();
    if (!initialSettings.containsKey(SettingsKeys.minResolution)) {
      // Default the minimum resolution to the biggest screen.
      final screen = await _largestScreen(setter);
      await settings.set(SettingsKeys.minResolution, screen);
      initialSettings = {...initialSettings, SettingsKeys.minResolution: screen};
    }

    Future<RescanResult>? startupRescan;
    if (library.root != null) {
      startupRescan = library.rescan();
      // Errors are shown by the rescan provider; don't let them go unhandled.
      unawaited(startupRescan.then<void>((_) {}, onError: (Object _) {}));
    }

    _log.info('Started. Setter: ${setter.name}. Library: ${library.root ?? '(not chosen)'}');
    return AppServices(
      db: db,
      settings: settings,
      library: library,
      dio: dio,
      sources: {WallhavenSource.sourceId: WallhavenSource(dio: dio)},
      downloads: DownloadManager(dio: dio, library: library),
      setter: setter,
      applier: WallpaperApplier(setter: setter, library: library),
      thumbnails: ThumbnailCache(p.join(cache.path, 'thumbnails')),
      initialSettings: initialSettings,
      logDirectory: logDirectory,
      startupRescan: startupRescan,
    );
  }

  static Future<String> _largestScreen(WallpaperSetter setter) async {
    try {
      final screens = [
        for (final t in await setter.targets())
          if (t.surface == TargetSurface.home) t,
      ];
      if (screens.isNotEmpty) {
        final biggest = screens.reduce((a, b) => a.width * a.height >= b.width * b.height ? a : b);
        return formatResolution((width: biggest.width, height: biggest.height));
      }
    } on Object catch (e) {
      _log.warning("Couldn't read screen sizes: $e");
    }
    return '1920x1080';
  }
}
