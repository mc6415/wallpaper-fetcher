import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';
import 'support/memory_storage.dart';

/// The library on a folder without file paths (Android's picked folders), and
/// moving between that and a plain folder.
void main() {
  late Directory temp;
  late AppDatabase db;
  late WallpaperLibrary library;
  final picked = <String, MemoryStorage>{};

  LibraryStorage open(String root) => root.startsWith('content://')
      ? picked.putIfAbsent(root, () => MemoryStorage(root, p.join(temp.path, 'cache')))
      : LocalLibraryStorage(root);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wf_storage_');
    picked.clear();
    db = AppDatabase(NativeDatabase.memory());
    library = WallpaperLibrary(db, SettingsStore(db), openStorage: open);
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  const tree = 'content://com.android.externalstorage.documents/tree/primary%3APictures%2FWallpapers';

  test('rescans a picked folder, reading sidecars, and skips hidden files', () async {
    await library.setRoot(tree);
    final storage = picked[tree]!;
    storage.files['wallhaven/wallhaven_abc.png'] = fakePng(1440, 3200, seed: 1);
    storage.files['wallhaven/wallhaven_abc.json'] = utf8.encode(
      const Sidecar(source: 'wallhaven', sourceId: 'abc', favourite: true, focus: (x: 0.2, y: 0.8)).encode(),
    );
    storage.files['.trash/old.png'] = fakePng(10, 10, seed: 2);
    storage.files['notes.txt'] = utf8.encode('not an image');

    final result = await library.rescan();

    expect(result.added, 1);
    final item = (await library.items()).single;
    expect(item.isFavourite, isTrue);
    expect(item.focus, (x: 0.2, y: 0.8));
    expect(item.size, (width: 1440, height: 3200));
    expect(library.absolutePath(item), '$tree/wallhaven/wallhaven_abc.png');
  });

  test('a chosen focus is kept in the sidecar, so a rebuilt database still has it', () async {
    await library.setRoot(p.join(temp.path, 'library'));
    final file = File(library.absoluteFor('local/a.png'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fakePng(3840, 2160));
    await library.rescan();

    await library.setFocus((await library.items()).single, (x: 0.25, y: 0.5));
    final sidecar = jsonDecode(await File(library.absoluteFor('local/a.json')).readAsString()) as Map;
    expect(sidecar['focus'], {'x': 0.25, 'y': 0.5});

    final freshDb = AppDatabase(NativeDatabase.memory());
    addTearDown(freshDb.close);
    final rebuilt = WallpaperLibrary(freshDb, SettingsStore(freshDb));
    await rebuilt.setRoot(library.root!);
    await rebuilt.rescan();
    expect((await rebuilt.items()).single.focus, (x: 0.25, y: 0.5));

    await library.setFocus((await library.items()).single, null);
    expect((await library.items()).single.focus, isNull);
  });

  test('moves a library from a plain folder to a picked one and back', () async {
    final local = p.join(temp.path, 'library');
    await library.setRoot(local);
    final image = File(library.absoluteFor('wallhaven/wallhaven_abc.png'));
    await image.parent.create(recursive: true);
    await image.writeAsBytes(fakePng(3840, 2160, seed: 3));
    await const Sidecar(source: 'wallhaven', sourceId: 'abc').write(library.absoluteFor('wallhaven/wallhaven_abc.json'));
    await library.rescan();

    await library.moveTo(tree);

    expect(library.root, tree);
    expect(picked[tree]!.files.keys, unorderedEquals(['wallhaven/wallhaven_abc.png', 'wallhaven/wallhaven_abc.json']));
    expect(image.existsSync(), isFalse);
    expect((await library.rescan()).changed, isFalse, reason: 'the database already points at the moved files');

    final back = p.join(temp.path, 'again');
    await library.moveTo(back);

    expect(picked[tree]!.files, isEmpty);
    expect(File(p.join(back, 'wallhaven', 'wallhaven_abc.png')).readAsBytesSync(), fakePng(3840, 2160, seed: 3));
    expect(File(p.join(back, 'wallhaven', 'wallhaven_abc.json')).existsSync(), isTrue);
    final leftovers = Directory(temp.path).listSync(recursive: true).where((f) => f.path.endsWith('.part'));
    expect(leftovers, isEmpty, reason: 'no staging files left behind');
  });

  test('a move that fails part-way puts everything back where it was', () async {
    final local = p.join(temp.path, 'library');
    await library.setRoot(local);
    for (final name in ['a', 'b', 'c']) {
      final image = File(library.absoluteFor('local/$name.png'));
      await image.parent.create(recursive: true);
      await image.writeAsBytes(fakePng(100, 100, seed: name.codeUnitAt(0)));
    }
    await library.rescan();
    picked[tree] = _FailingStorage(tree, p.join(temp.path, 'cache'), failAfter: 2);

    await expectLater(library.moveTo(tree), throwsA(isA<LibraryException>()));

    expect(library.root, local);
    for (final name in ['a', 'b', 'c']) {
      expect(File(library.absoluteFor('local/$name.png')).existsSync(), isTrue, reason: '$name is back');
    }
    expect(picked[tree]!.files, isEmpty);
  });

  test('imports a folder into a picked library', () async {
    await library.setRoot(tree);
    final source = Directory(p.join(temp.path, 'import'));
    await File(p.join(source.path, 'a.png')).create(recursive: true);
    await File(p.join(source.path, 'a.png')).writeAsBytes(fakePng(100, 200, seed: 4));

    final result = await library.importFolder(source.path, folderName: 'Camera');

    expect(result.imported, 1);
    expect(picked[tree]!.files.keys, ['local/Camera/a.png']);
    expect(File(p.join(source.path, 'a.png')).existsSync(), isTrue, reason: 'copied, not moved');
  });

  test('applying passes the image size and focus to the setter', () async {
    await library.setRoot(tree);
    picked[tree]!.files['local/a.png'] = fakePng(3840, 2160);
    await library.rescan();
    await library.setFocus((await library.items()).single, (x: 0.1, y: 0.5));
    final setter = _RecordingSetter();
    final applier = WallpaperApplier(setter: setter, library: library, history: WallpaperHistory(db, SettingsStore(db)));

    await applier.apply((await library.items()).single, const [
      DisplayTarget(id: 'cover', label: 'Cover screen', width: 1080, height: 2520),
    ]);

    final assignment = setter.applied.single.single;
    expect(assignment.imagePath, '$tree/local/a.png');
    expect(assignment.imageSize, (width: 3840, height: 2160));
    expect(assignment.focus, (x: 0.1, y: 0.5));
  });
}

/// Runs out of room after [failAfter] files.
class _FailingStorage extends MemoryStorage {
  _FailingStorage(super.root, super.scratch, {required this.failAfter});

  final int failAfter;
  var _written = 0;

  @override
  Future<void> putFile(String source, String path, {bool move = false}) async {
    if (++_written > failAfter) throw FileSystemException('No space left on device', locate(path));
    await super.putFile(source, path, move: move);
  }
}

class _RecordingSetter implements WallpaperSetter {
  final applied = <List<Assignment>>[];

  @override
  String get name => 'Recording';

  @override
  Future<List<DisplayTarget>> targets() async => const [];

  @override
  Future<SetterCapabilities> capabilities() async => SetterCapabilities.none;

  @override
  Future<void> apply(List<Assignment> assignments) async => applied.add(assignments);
}
