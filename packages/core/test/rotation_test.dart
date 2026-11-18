import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

const left = DisplayTarget(id: 'DP-1', label: 'Left', width: 3840, height: 2160, isPrimary: true);
const right = DisplayTarget(id: 'DP-2', label: 'Right', width: 3840, height: 2160);
const lock = DisplayTarget(id: 'lock', label: 'Lock screen', width: 3840, height: 2160, surface: TargetSurface.lock);

class FakeSetter implements WallpaperSetter {
  List<DisplayTarget> screens = [left, right, lock];
  final calls = <List<String>>[];

  @override
  String get name => 'Fake';

  @override
  Future<List<DisplayTarget>> targets() async => screens;

  @override
  Future<SetterCapabilities> capabilities() async => SetterCapabilities.none;

  @override
  Future<void> apply(List<Assignment> assignments) async =>
      calls.add([for (final a in assignments) '${a.target.id}=${p.basenameWithoutExtension(a.imagePath)}']);
}

/// A daily source whose "today" can be changed by the test.
class FakeDaily implements WallpaperSource {
  String today = '20261117_Cedars';

  @override
  String get id => 'bing';

  @override
  String get name => 'Bing';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(isDaily: true);

  @override
  Future<SourcePage> search(SearchQuery query, {String? cursor}) async => SourcePage(
    items: [
      RemoteWallpaper(
        sourceId: 'bing',
        id: today,
        fullUrl: Uri.parse('https://www.bing.com/th?id=OHR.$today.png'),
        thumbnailUrl: Uri.parse('https://www.bing.com/th?id=OHR.${today}_t.jpg'),
      ),
    ],
  );

  @override
  Future<DownloadTicket> prepareDownload(RemoteWallpaper w) async =>
      DownloadTicket(url: w.fullUrl, wallpaper: w, fileExtension: 'png');
}

void main() {
  late Directory temp;
  late AppDatabase db;
  late SettingsStore settings;
  late WallpaperLibrary library;
  late WallpaperHistory history;
  late FakeSetter setter;
  late WallpaperApplier applier;
  late FakeDaily daily;
  late DateTime now;
  late RotationService rotation;

  RotationService makeService({int seed = 1}) => RotationService(
    setter: setter,
    applier: applier,
    library: library,
    history: history,
    settings: settings,
    downloads: DownloadManager(
      dio: fakeDio((o) async => bytesBody(fakePng(3840, 2160, seed: o.uri.toString().hashCode))),
      library: library,
    ),
    sources: {'bing': daily},
    picker: RotationPicker(library, history, random: Random(seed)),
    now: () => now,
  );

  /// Adds images named by [names]; `p...` names are portrait.
  Future<Map<String, LibraryItem>> addImages(List<String> names) async {
    for (final (i, name) in names.indexed) {
      final portrait = name.startsWith('p');
      await File(library.absoluteFor('$name.png'))
          .writeAsBytes(fakePng(portrait ? 2160 : 3840, portrait ? 3840 : 2160, seed: 100 + i));
    }
    await library.rescan();
    return {for (final i in await library.items()) p.basenameWithoutExtension(i.relativePath): i};
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wf_rotation_');
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsStore(db);
    library = WallpaperLibrary(db, settings);
    await library.setRoot(temp.path);
    history = WallpaperHistory(db, settings);
    setter = FakeSetter();
    applier = WallpaperApplier(setter: setter, library: library, history: history);
    daily = FakeDaily();
    now = DateTime(2026, 11, 18, 9);
    rotation = makeService();
    await rotation.load();
  });

  tearDown(() async {
    await rotation.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });

  group('config', () {
    test('round-trips through JSON, and bad input gives defaults', () {
      const config = RotationConfig(
        enabled: true,
        interval: Duration(minutes: 30),
        pool: TagPool('space'),
        order: RotationOrder.sequential,
        screens: {'DP-2', 'DP-1'},
        fit: FitMode.fit,
      );
      expect(RotationConfig.parse(config.encode()), config);
      expect(RotationConfig.parse('{nope'), const RotationConfig());
      expect(RotationConfig.parse(null).pool, const AllPool());
      expect(RotationPool.fromJson({'type': 'daily', 'source': 'bing'}), const DailyPool('bing'));
    });

    test('is saved and loaded with paused state and last run', () async {
      await rotation.configure(const RotationConfig(enabled: true, pool: FavouritesPool()));
      await rotation.setPaused(true);

      final reloaded = makeService();
      await reloaded.load();
      expect(reloaded.config.pool, const FavouritesPool());
      expect(reloaded.paused, isTrue);
      expect(reloaded.state.lastRun, now);
      await reloaded.dispose();
    });
  });

  group('next', () {
    test('gives each monitor a different image and covers monitors only by default', () async {
      await addImages(['a', 'b', 'c']);

      final outcome = await rotation.next();

      expect(outcome.applied.keys, unorderedEquals(['DP-1', 'DP-2']));
      expect(outcome.applied['DP-1']!.id, isNot(outcome.applied['DP-2']!.id));
      expect(setter.calls, hasLength(1), reason: 'both monitors in one desktop call');
    });

    test('screens chosen in the config, including the lock screen', () async {
      await addImages(['a', 'b', 'c']);
      await rotation.configure(const RotationConfig(screens: {'DP-2', 'lock'}));

      final outcome = await rotation.next();

      expect(outcome.applied.keys, unorderedEquals(['DP-2', 'lock']));
    });

    test('skips hidden images and prefers ones that fit the screen shape', () async {
      final items = await addImages(['wide', 'hidden', 'ptall']);
      await library.setHidden(items['hidden']!, true);

      for (var i = 0; i < 5; i++) {
        final outcome = await rotation.next(targetIds: ['DP-1']);
        expect(outcome.applied['DP-1']!.relativePath, 'wide.png');
      }
    });

    test("shuffle doesn't repeat recent images on a screen", () async {
      await addImages(['a', 'b', 'c', 'd', 'e', 'f']);
      final shown = <String>[];
      for (var i = 0; i < 4; i++) {
        shown.add((await rotation.next(targetIds: ['DP-1'])).applied['DP-1']!.relativePath);
      }
      // Pool of 6 remembers 3, so any 4 in a row have no back-to-back or
      // within-3 repeats.
      for (var i = 1; i < shown.length; i++) {
        expect(shown.sublist(max(0, i - 3), i), isNot(contains(shown[i])));
      }
    });

    test('in order goes through the pool oldest first and wraps round', () async {
      await addImages(['a', 'b', 'c']);
      await rotation.configure(const RotationConfig(order: RotationOrder.sequential));
      final seen = [
        for (var i = 0; i < 4; i++) (await rotation.next(targetIds: ['DP-1'])).applied['DP-1']!.relativePath,
      ];
      expect(seen, ['a.png', 'b.png', 'c.png', 'a.png']);
    });

    test('after Previous, Next goes forward through history before picking anew', () async {
      await addImages(['a', 'b', 'c', 'd']);
      await rotation.configure(const RotationConfig(order: RotationOrder.sequential));
      await rotation.next(targetIds: ['DP-1']); // a
      await rotation.next(targetIds: ['DP-1']); // b

      final back = await rotation.previous(targetIds: ['DP-1']);
      final forward = await rotation.next(targetIds: ['DP-1']);
      final fresh = await rotation.next(targetIds: ['DP-1']);

      expect(back.applied['DP-1']!.relativePath, 'a.png');
      expect(forward.applied['DP-1']!.relativePath, 'b.png');
      expect(fresh.applied['DP-1']!.relativePath, 'c.png');
    });

    test('span puts one image across every monitor', () async {
      await addImages(['a', 'b', 'c']);
      await rotation.configure(const RotationConfig(fit: FitMode.span));
      final outcome = await rotation.next();
      expect(outcome.applied.keys, ['DP-1', 'DP-2']);
      expect(outcome.applied.values.map((i) => i.id).toSet(), hasLength(1));
      expect(setter.calls.last.map((c) => c.split('=').last).toSet(), hasLength(1), reason: 'one image in the desktop call');
    });

    test('an empty pool explains itself', () async {
      await addImages(['a']);
      await rotation.configure(const RotationConfig(pool: FavouritesPool()));
      final outcome = await rotation.next();
      expect(outcome.changed, isFalse);
      expect(outcome.message, contains('no favourites'));
    });

    test('tag and source pools', () async {
      final items = await addImages(['a', 'b']);
      await library.setTags(items['b']!, ['space']);
      await rotation.configure(const RotationConfig(pool: TagPool('space')));
      expect((await rotation.next(targetIds: ['DP-1'])).applied['DP-1']!.relativePath, 'b.png');
      await rotation.configure(const RotationConfig(pool: SourcePool('wallhaven')));
      expect((await rotation.next()).message, contains('nothing from'));
    });
  });

  group('schedule', () {
    test('acts only when on, not paused and due', () async {
      await addImages(['a', 'b', 'c']);
      expect(await rotation.tick(), isNull, reason: 'off');

      await rotation.configure(const RotationConfig(enabled: true, interval: Duration(minutes: 30)));
      expect(rotation.state.nextDue, now.add(const Duration(minutes: 30)));
      expect(await rotation.tick(), isNull, reason: 'switching on starts the interval');

      now = now.add(const Duration(minutes: 31));
      final outcome = await rotation.tick();
      expect(outcome?.changed, isTrue);
      expect(await rotation.tick(), isNull, reason: 'interval restarted');

      await rotation.setPaused(true);
      now = now.add(const Duration(hours: 5));
      expect(await rotation.tick(), isNull, reason: 'paused');
      expect(rotation.state.nextDue, isNull);
    });

    test('a manual Next restarts the interval', () async {
      await addImages(['a', 'b', 'c']);
      await rotation.configure(const RotationConfig(enabled: true, interval: Duration(minutes: 30)));
      now = now.add(const Duration(minutes: 29));
      await rotation.next();
      now = now.add(const Duration(minutes: 2));
      expect(await rotation.tick(), isNull);
    });

    test('a background check counts a change due within the slack as due', () async {
      await addImages(['a', 'b', 'c']);
      await rotation.configure(const RotationConfig(enabled: true, interval: Duration(hours: 1)));
      now = now.add(const Duration(minutes: 50));
      expect(await rotation.tick(slack: const Duration(minutes: 5)), isNull);
      expect((await rotation.tick(slack: const Duration(minutes: 15)))?.changed, isTrue);
    });

    test('background checks run as often as the interval, between 15 minutes and an hour', () async {
      Future<Duration> every(RotationConfig config) async {
        await rotation.configure(config);
        return rotation.backgroundCheckInterval;
      }

      expect(await every(const RotationConfig(interval: Duration(minutes: 5))), const Duration(minutes: 15));
      expect(await every(const RotationConfig(interval: Duration(minutes: 30))), const Duration(minutes: 30));
      expect(await every(const RotationConfig(interval: Duration(days: 1))), const Duration(hours: 1));
      expect(await every(const RotationConfig(pool: DailyPool('bing'))), const Duration(hours: 1));
    });
  });

  group('daily pool', () {
    test("downloads today's picture, puts it on every screen, and only once", () async {
      await rotation.configure(const RotationConfig(enabled: true, pool: DailyPool('bing')));
      now = now.add(const Duration(hours: 1, minutes: 1));

      final first = await rotation.tick();
      expect(first!.applied.keys, unorderedEquals(['DP-1', 'DP-2']));
      expect(first.applied.values.map((i) => i.sourceId).toSet(), {'20261117_Cedars'});
      expect(await library.bySource('bing', '20261117_Cedars'), isNotNull, reason: 'kept in the library');

      now = now.add(const Duration(hours: 1, minutes: 1));
      final again = await rotation.tick();
      expect(again!.changed, isFalse);
      expect(again.message, contains('Already showing'));

      daily.today = '20261118_Lake';
      now = now.add(const Duration(hours: 1, minutes: 1));
      expect((await rotation.tick())!.applied.values.first.sourceId, '20261118_Lake');
    });
  });

  test('favourite current marks what each screen shows', () async {
    await addImages(['a', 'b', 'c']);
    final outcome = await rotation.next();

    final favourited = await rotation.favouriteCurrent(targetIds: ['DP-2']);

    expect(favourited.single.id, outcome.applied['DP-2']!.id);
    expect((await library.byId(favourited.single.id))!.isFavourite, isTrue);
  });

  test('AppPaths follow XDG locations on Linux', () {
    final env = {'HOME': '/home/me', 'XDG_RUNTIME_DIR': '/run/user/1000'};
    expect(AppPaths.database(env, false), '/home/me/.local/share/dev.mcoombes.wallpaperfetcher/library.sqlite');
    expect(AppPaths.socket(env, false), '/run/user/1000/wallpaper-fetcher.sock');
    expect(AppPaths.dataDirectory({...env, 'XDG_DATA_HOME': '/data'}, false), '/data/dev.mcoombes.wallpaperfetcher');
  });

  test("AppPaths on Windows match path_provider's folder for the app", () {
    final env = {'APPDATA': r'C:\Users\me\AppData\Roaming'};
    expect(AppPaths.database(env, true), r'C:\Users\me\AppData\Roaming\dev.mcoombes\Wallpaper Fetcher\library.sqlite');
    expect(AppPaths.logs(env, true), r'C:\Users\me\AppData\Roaming\dev.mcoombes\Wallpaper Fetcher\logs');
    expect(AppPaths.socket(env, true), r'C:\Users\me\AppData\Roaming\dev.mcoombes\Wallpaper Fetcher\wallpaper-fetcher.sock');
  });
}
