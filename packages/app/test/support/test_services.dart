import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';
import 'package:wallpaper_fetcher/platform/key_store.dart';
import 'package:wallpaper_fetcher/platform/linux_appearance.dart';
import 'package:wallpaper_fetcher/platform/thumbnails.dart';
import 'package:wallpaper_fetcher/providers.dart';
import 'package:wallpaper_fetcher/services.dart';

/// Two monitors and a lock screen; records what it was asked to apply.
class FakeSetter implements WallpaperSetter {
  final applied = <List<Assignment>>[];

  @override
  String get name => 'Fake desktop';

  @override
  Future<List<DisplayTarget>> targets() async => const [
    DisplayTarget(id: 'DP-1', label: 'Left monitor (DP-1)', width: 3840, height: 2160, isPrimary: true),
    DisplayTarget(id: 'DP-2', label: 'Right monitor (DP-2)', width: 3840, height: 2160),
    DisplayTarget(id: 'lock', label: 'Lock screen', width: 3840, height: 2160, surface: TargetSurface.lock),
  ];

  @override
  Future<SetterCapabilities> capabilities() async =>
      const SetterCapabilities(perTarget: true, lockScreen: true, fitModes: FitMode.values);

  @override
  Future<void> apply(List<Assignment> assignments) async => applied.add(assignments);
}

/// A Galaxy Fold: main and cover screens, each with a lock screen, cropped
/// around a focus point like the real Android setter.
class FakeFoldSetter extends FakeSetter {
  @override
  String get name => 'Samsung foldable';

  @override
  Future<List<DisplayTarget>> targets() async => const [
    DisplayTarget(id: 'main', label: 'Main screen', width: 2256, height: 2504, isPrimary: true),
    DisplayTarget(id: 'cover', label: 'Cover screen', width: 1080, height: 2520),
    DisplayTarget(id: 'main-lock', label: 'Main lock screen', width: 2256, height: 2504, surface: TargetSurface.lock),
    DisplayTarget(id: 'cover-lock', label: 'Cover lock screen', width: 1080, height: 2520, surface: TargetSurface.lock),
  ];

  @override
  Future<SetterCapabilities> capabilities() async =>
      const SetterCapabilities(perTarget: true, lockScreen: true, fitModes: [FitMode.fill], cropsToFocus: true);
}

/// Answers every request with an empty Wallhaven page.
class _EmptyWallhaven implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async =>
      ResponseBody.fromString(
        '{"data":[],"meta":{"current_page":1,"last_page":1,"total":0}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Keeps "keyring" contents in memory.
class FakeKeyStore extends ApiKeyStore {
  final saved = <String, String>{};

  @override
  Future<Map<String, String>> load(Iterable<String> sourceIds) async =>
      {for (final id in sourceIds) id: ?saved[id]};

  @override
  Future<void> save(String sourceId, String key) async => saved[sourceId] = key;

  @override
  Future<void> remove(String sourceId) async => saved.remove(sourceId);
}

class TestEnv {
  TestEnv._(this.services, this.setter, this.keyStore, this.temp);

  final AppServices services;
  final FakeSetter setter;
  final FakeKeyStore keyStore;
  final Directory temp;

  /// Call inside `tester.runAsync`: it touches the real file system.
  static Future<TestEnv> create({bool withLibrary = true, FakeSetter? setter}) async {
    final temp = await Directory.systemTemp.createTemp('wf_app_test_');
    final db = AppDatabase(NativeDatabase.memory());
    final settings = SettingsStore(db);
    final library = WallpaperLibrary(db, settings);
    if (withLibrary) await library.setRoot(p.join(temp.path, 'library'));
    final dio = Dio()..httpClientAdapter = _EmptyWallhaven();
    setter ??= FakeSetter();
    final history = WallpaperHistory(db, settings);
    final apiKeys = ApiKeys();
    final keyStore = FakeKeyStore();
    final downloads = DownloadManager(dio: dio, library: library);
    final applier = WallpaperApplier(setter: setter, library: library, history: history);
    final services = AppServices(
      db: db,
      settings: settings,
      library: library,
      history: history,
      dio: dio,
      sources: {
        WallhavenSource.sourceId: WallhavenSource(dio: dio),
        UnsplashSource.sourceId: UnsplashSource(dio: dio, keys: apiKeys),
        BingSource.sourceId: BingSource(dio: dio),
        WikimediaSource.sourceId: WikimediaSource(dio: dio, daysPerPage: 2),
      },
      apiKeys: apiKeys,
      keyStore: keyStore,
      downloads: downloads,
      setter: setter,
      applier: applier,
      rotation: RotationService(
        setter: setter,
        applier: applier,
        library: library,
        history: history,
        settings: settings,
        downloads: downloads,
        sources: const {},
      ),
      thumbnails: ThumbnailCache(p.join(temp.path, 'thumbs')),
      initialSettings: const {SettingsKeys.minResolution: '3840x2160'},
      logDirectory: p.join(temp.path, 'logs'),
    );
    return TestEnv._(services, setter, keyStore, temp);
  }

  /// Puts a (header-only) 3840x2160 PNG in the library. Call inside runAsync.
  Future<LibraryItem> addWallpaper(String name, {int seed = 0}) async {
    final library = services.library;
    final file = File(library.absoluteFor('wallhaven/$name.png'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, //
      0, 0, 0x0F, 0x00, 0, 0, 0x08, 0x70, ...List.filled(32, seed),
    ]);
    await library.rescan();
    return (await library.watch().first).firstWhere((i) => i.relativePath.contains(name));
  }

  List<Override> get overrides => [
    servicesProvider.overrideWithValue(services),
    appearanceProvider.overrideWith(_NoAppearance.new),
  ];

  Future<void> dispose() async {
    await services.db.close();
    await temp.delete(recursive: true);
  }
}

class _NoAppearance extends AppearanceNotifier {
  @override
  Appearance build() => const Appearance();
}
