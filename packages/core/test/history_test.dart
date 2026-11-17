import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

class RecordingSetter implements WallpaperSetter {
  final applied = <String>[];

  @override
  String get name => 'Test';

  @override
  Future<List<DisplayTarget>> targets() async => const [];

  @override
  Future<SetterCapabilities> capabilities() async => SetterCapabilities.none;

  @override
  Future<void> apply(List<Assignment> assignments) async {
    for (final a in assignments) {
      applied.add('${a.target.id}=${p.basenameWithoutExtension(a.imagePath)}/${a.fit.name}');
    }
  }
}

const left = DisplayTarget(id: 'DP-1', label: 'Left', width: 3840, height: 2160);
const right = DisplayTarget(id: 'DP-2', label: 'Right', width: 3840, height: 2160);

void main() {
  late Directory temp;
  late AppDatabase db;
  late WallpaperLibrary library;
  late WallpaperHistory history;
  late RecordingSetter setter;
  late WallpaperApplier applier;
  late Map<String, LibraryItem> items;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wf_history_');
    db = AppDatabase(NativeDatabase.memory());
    final settings = SettingsStore(db);
    library = WallpaperLibrary(db, settings);
    await library.setRoot(temp.path);
    history = WallpaperHistory(db, settings);
    setter = RecordingSetter();
    applier = WallpaperApplier(setter: setter, library: library, history: history);
    for (final (i, name) in ['a', 'b', 'c'].indexed) {
      await File(library.absoluteFor('$name.png')).writeAsBytes(fakePng(100, 50, seed: i));
    }
    await library.rescan();
    items = {for (final i in await library.watch().first) p.basenameWithoutExtension(i.relativePath): i};
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<String?> current(String target) async =>
      (await history.nowShowing())[target]?.item?.relativePath.replaceAll('.png', '');

  test('previous and next walk the timeline without adding to it', () async {
    await applier.apply(items['a']!, [left]);
    await applier.apply(items['b']!, [left], fit: FitMode.fit);
    await applier.apply(items['c']!, [left]);
    setter.applied.clear();

    expect((await applier.previous(left))?.relativePath, 'b.png');
    expect((await applier.previous(left))?.relativePath, 'a.png');
    expect(await applier.previous(left), isNull, reason: 'nothing older than a');
    expect((await applier.next(left))?.relativePath, 'b.png');
    expect((await applier.next(left))?.relativePath, 'c.png');
    expect(await applier.next(left), isNull, reason: 'already at the newest');

    expect(setter.applied, ['DP-1=b/fit', 'DP-1=a/fill', 'DP-1=b/fit', 'DP-1=c/fill'],
        reason: 'history replays each image with the fit it had');
    expect(await history.timeline('DP-1'), hasLength(3));
  });

  test('a normal apply after stepping back starts again from the newest', () async {
    await applier.apply(items['a']!, [left]);
    await applier.apply(items['b']!, [left]);
    await applier.previous(left);
    expect(await history.cursor('DP-1'), 1);

    await applier.apply(items['c']!, [left]);

    expect(await history.cursor('DP-1'), 0);
    expect((await history.timeline('DP-1')).map((e) => e.item!.relativePath), ['c.png', 'b.png', 'a.png']);
  });

  test('each monitor has its own history', () async {
    await applier.apply(items['a']!, [left, right]);
    await applier.apply(items['b']!, [right]);

    final now = await history.nowShowing();
    expect(await current('DP-1'), 'a');
    expect(await current('DP-2'), 'b');
    expect(now['DP-1']!.canGoBack, isFalse);
    expect(now['DP-2']!.canGoBack, isTrue);
    expect(now['DP-2']!.canGoForward, isFalse);

    await applier.previous(right);
    final after = await history.nowShowing();
    expect(await current('DP-2'), 'a');
    expect(after['DP-2']!.canGoForward, isTrue);
    expect(await current('DP-1'), 'a', reason: 'left untouched');
  });

  test('repeats collapse and deleted images drop out', () async {
    await applier.apply(items['a']!, [left]);
    await applier.apply(items['b']!, [left]);
    await applier.apply(items['b']!, [left]);
    await applier.apply(items['c']!, [left]);
    expect((await history.timeline('DP-1')).map((e) => e.item!.relativePath), ['c.png', 'b.png', 'a.png']);

    await library.delete(items['b']!);
    expect((await history.timeline('DP-1')).map((e) => e.item!.relativePath), ['c.png', 'a.png']);
    expect((await applier.previous(left))?.relativePath, 'a.png');
  });

  test('recent list includes history steps and survives deletions', () async {
    await applier.apply(items['a']!, [left]);
    await applier.apply(items['b']!, [left]);
    await applier.previous(left);
    await library.delete(items['b']!);

    final recent = await history.watchRecent().first;
    expect(recent, hasLength(3));
    expect(recent.first.viaHistory, isTrue);
    expect(recent.where((e) => e.item == null), hasLength(1), reason: 'b was deleted');
  });

  test('watchNowShowing updates when something is applied', () async {
    final updates = history.watchNowShowing();
    final seen = <String?>[];
    final sub = updates.listen((m) => seen.add(m['DP-1']?.item?.relativePath));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await applier.apply(items['a']!, [left]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen.first, isNull);
    expect(seen.last, 'a.png');
  });
}
