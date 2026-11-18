import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show IsolateNameServer;

import 'package:dio/dio.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'platform/android/android_setter.dart';
import 'platform/android/saf_storage.dart';
import 'platform/key_store.dart';
import 'platform/thumbnails.dart';

final _log = Logger('App');

/// Browse tab order.
const sourceOrder = [
  WallhavenSource.sourceId,
  UnsplashSource.sourceId,
  BingSource.sourceId,
  WikimediaSource.sourceId,
];

/// Everything the app needs, created once at startup and handed to Riverpod.
class AppServices {
  AppServices({
    required this.db,
    required this.settings,
    required this.library,
    required this.history,
    required this.dio,
    required this.sources,
    required this.apiKeys,
    required this.keyStore,
    required this.downloads,
    required this.setter,
    required this.applier,
    required this.rotation,
    required this.thumbnails,
    required this.initialSettings,
    required this.logDirectory,
    this.startupRescan,
    this.keyringError,
  });

  final AppDatabase db;
  final SettingsStore settings;
  final WallpaperLibrary library;
  final WallpaperHistory history;
  final Dio dio;

  /// In [sourceOrder].
  final Map<String, WallpaperSource> sources;
  final ApiKeys apiKeys;
  final ApiKeyStore keyStore;
  final DownloadManager downloads;
  final WallpaperSetter setter;
  final WallpaperApplier applier;
  final RotationService rotation;
  final ThumbnailCache thumbnails;

  /// Settings as they were at startup, so providers can start synchronously.
  final Map<String, String> initialSettings;
  final String logDirectory;

  /// The rescan kicked off at startup, if a library folder was already set.
  final Future<RescanResult>? startupRescan;

  /// Set when saved API keys couldn't be read from the keyring.
  final String? keyringError;

  /// With [background] (Android's rotation job), only what rotation needs:
  /// no keyring, no rescan, no global error handlers.
  static Future<AppServices> create({bool background = false}) async {
    final support = await getApplicationSupportDirectory();
    final cache = await getApplicationCacheDirectory();
    final logDirectory = p.join(support.path, 'logs');
    setupLogging(directory: logDirectory, echoToConsole: kDebugMode);
    if (!background) {
      FlutterError.onError = (details) {
        _log.severe('Flutter error: ${details.exceptionAsString()}', details.exception, details.stack);
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        _log.severe('Uncaught error', error, stack);
        return true;
      };
    }

    final db = AppDatabase(
      driftDatabase(
        name: 'library',
        native: DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
          // Android's background rotation runs in a second engine in the same
          // process. While the app is open they share its connection, so its
          // lists update live. The job never starts the shared connection
          // itself: it would vanish with the job's engine, under an app that
          // opened meanwhile.
          shareAcrossIsolates: Platform.isAndroid && (!background || _appDatabaseIsOpen),
          // Two connections can meet (job and app); wait rather than fail.
          setup: (db) => db.execute('PRAGMA busy_timeout = 5000'),
        ),
      ),
    );
    final settings = SettingsStore(db);
    final staging = p.join(cache.path, 'staging');
    final library = WallpaperLibrary(
      db,
      settings,
      openStorage: (root) => root.startsWith('content://')
          ? SafLibraryStorage(root, stagingDirectory: staging)
          : LocalLibraryStorage(root),
    );
    await library.load();

    final dio = createHttpClient();
    final WallpaperSetter setter;
    if (Platform.isLinux) {
      setter = createLinuxSetter(settings: settings);
    } else if (Platform.isAndroid) {
      setter = await AndroidSetter.create();
    } else if (Platform.isWindows) {
      setter = WindowsSetter(const Win32Desktop());
    } else {
      setter = const UnsupportedSetter("Setting wallpapers on this platform isn't supported yet.");
    }

    var initialSettings = await settings.all();
    if (!background && !initialSettings.containsKey(SettingsKeys.minResolution)) {
      final screen = await defaultMinResolution(setter, phone: Platform.isAndroid);
      await settings.set(SettingsKeys.minResolution, screen);
      initialSettings = {...initialSettings, SettingsKeys.minResolution: screen};
    }

    // Only open the keyring if a key was saved; it may ask to be unlocked.
    final keyStore = ApiKeyStore();
    final apiKeys = ApiKeys();
    String? keyringError;
    final saved = splitIds(initialSettings[SettingsKeys.savedApiKeys]);
    if (saved.isNotEmpty && !background) {
      try {
        (await keyStore.load(saved)).forEach((id, key) => apiKeys[id] = key);
      } on Object catch (e) {
        keyringError = Platform.isAndroid
            ? "Couldn't read your saved API keys."
            : "Couldn't read your saved API keys from the system keyring.";
        _log.warning('$keyringError $e');
      }
    }

    final history = WallpaperHistory(db, settings);
    Future<RescanResult>? startupRescan;
    if (library.root != null && !background) {
      startupRescan = library.rescan();
      // Errors are shown by the rescan provider; don't let them go unhandled.
      unawaited(startupRescan.then<void>((_) {}, onError: (Object _) {}));
    }

    final sources = <String, WallpaperSource>{
      WallhavenSource.sourceId: WallhavenSource(dio: dio),
      UnsplashSource.sourceId: UnsplashSource(dio: dio, keys: apiKeys),
      BingSource.sourceId: BingSource(dio: dio, market: bingMarket(Platform.localeName)),
      WikimediaSource.sourceId: WikimediaSource(dio: dio),
    };
    final downloads = DownloadManager(dio: dio, library: library);
    final applier = WallpaperApplier(setter: setter, library: library, history: history);
    final rotation = RotationService(
      setter: setter,
      applier: applier,
      library: library,
      history: history,
      settings: settings,
      downloads: downloads,
      sources: sources,
    );
    await rotation.load();

    _log.info(
      '${background ? 'Background job started' : 'Started'}. Setter: ${setter.name}. '
      'Library: ${library.displayName ?? '(not chosen)'}',
    );
    return AppServices(
      db: db,
      settings: settings,
      library: library,
      history: history,
      dio: dio,
      sources: sources,
      apiKeys: apiKeys,
      keyStore: keyStore,
      downloads: downloads,
      setter: setter,
      applier: applier,
      rotation: rotation,
      thumbnails: ThumbnailCache(p.join(cache.path, 'thumbnails')),
      initialSettings: initialSettings,
      logDirectory: logDirectory,
      startupRescan: startupRescan,
      keyringError: keyringError,
    );
  }

  /// The biggest screen on a desktop. On a phone, the tallest screen held
  /// upright (the cover screen of a Fold), since searches default to portrait.
  static Future<String> defaultMinResolution(WallpaperSetter setter, {required bool phone}) async {
    try {
      final screens = [
        for (final t in await setter.targets())
          if (t.surface == TargetSurface.home) t,
      ];
      if (screens.isNotEmpty) {
        if (phone) {
          final tallest = screens.reduce((a, b) => math.max(a.width, a.height) >= math.max(b.width, b.height) ? a : b);
          return formatResolution((
            width: math.min(tallest.width, tallest.height),
            height: math.max(tallest.width, tallest.height),
          ));
        }
        final biggest = screens.reduce((a, b) => a.width * a.height >= b.width * b.height ? a : b);
        return formatResolution((width: biggest.width, height: biggest.height));
      }
    } on Object catch (e) {
      _log.warning("Couldn't read screen sizes: $e");
    }
    return phone ? '1080x1920' : '1920x1080';
  }

  Future<void> dispose() async {
    await rotation.dispose();
    await downloads.dispose();
    dio.close();
    await db.close();
  }
}

/// Whether the app's engine has the shared database open (drift_flutter's
/// port name for the `library` database).
bool get _appDatabaseIsOpen => IsolateNameServer.lookupPortByName('drift-db/library') != null;

List<String> splitIds(String? value) => [
  for (final id in (value ?? '').split(','))
    if (id.trim().isNotEmpty) id.trim(),
];

/// `en_GB.UTF-8` -> `en-GB`. Bing serves its own picks per market.
String bingMarket(String localeName) {
  final match = RegExp(r'^([a-z]{2})[_-]([A-Z]{2})').firstMatch(localeName);
  return match == null ? 'en-US' : '${match[1]}-${match[2]}';
}
