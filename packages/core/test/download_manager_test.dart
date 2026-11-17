import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

void main() {
  late Directory temp;
  late AppDatabase db;
  late WallpaperLibrary library;
  late Dio dio;
  late DownloadManager downloads;
  late WallhavenSource source;
  final images = <String, List<int>>{};

  RemoteWallpaper wallpaper(String id) => RemoteWallpaper(
    sourceId: 'wallhaven',
    id: id,
    fullUrl: Uri.parse('https://w.wallhaven.cc/full/xx/wallhaven-$id.png'),
    thumbnailUrl: Uri.parse('https://th.wallhaven.cc/lg/xx/$id.jpg'),
    width: 3840,
    height: 2160,
    colours: const [0xFF112233],
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wf_downloads_');
    db = AppDatabase(NativeDatabase.memory());
    library = WallpaperLibrary(db, SettingsStore(db));
    await library.setRoot(temp.path);
    images.clear();
    dio = fakeDio((options) async {
      if (options.uri.host == 'wallhaven.cc') return jsonBody(fixture('wallhaven/detail.json'));
      final id = RegExp(r'wallhaven-(\w+)\.png').firstMatch(options.uri.path)!.group(1)!;
      final bytes = images[id];
      return bytes == null ? bytesBody(const [], status: 404) : bytesBody(bytes);
    });
    source = WallhavenSource(dio: dio);
    downloads = DownloadManager(dio: dio, library: library);
  });

  tearDown(() async {
    await downloads.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });

  test('downloads into <source>/<source>_<id>.<ext> with a sidecar and a row', () async {
    images['abc'] = fakePng(3840, 2160, seed: 1);

    final item = await downloads.download(source, wallpaper('abc'));

    expect(item.relativePath, 'wallhaven/wallhaven_abc.png');
    final file = File(p.join(temp.path, 'wallhaven', 'wallhaven_abc.png'));
    expect(file.readAsBytesSync(), images['abc']);
    expect(File('${file.path}.part').existsSync(), isFalse);

    final sidecar = jsonDecode(File(p.join(temp.path, 'wallhaven', 'wallhaven_abc.json')).readAsStringSync()) as Map;
    expect(sidecar['source'], 'wallhaven');
    expect(sidecar['sourceId'], 'abc');
    expect((sidecar['tags'] as List), isNotEmpty, reason: 'details were merged in');

    expect(item.width, 3840);
    expect(item.dominantColour, 0xFF112233);
    expect(item.creditLine, startsWith('Uploaded to Wallhaven by'));
    expect(downloads.current, isEmpty, reason: 'finished downloads leave the progress map');
  });

  test('second download of the same wallpaper reuses the library entry', () async {
    images['abc'] = fakePng(10, 10, seed: 1);
    final first = await downloads.download(source, wallpaper('abc'));
    final requestsAfterFirst = adapterOf(dio).requests.length;

    final again = await downloads.download(source, wallpaper('abc'));

    expect(again.id, first.id);
    expect(adapterOf(dio).requests.length, requestsAfterFirst);
  });

  test('concurrent calls share one download', () async {
    images['abc'] = fakePng(10, 10, seed: 1);
    final results = await Future.wait([
      downloads.download(source, wallpaper('abc')),
      downloads.download(source, wallpaper('abc')),
    ]);
    expect(results[0].id, results[1].id);
    expect(adapterOf(dio).requests.where((r) => r.uri.host == 'w.wallhaven.cc'), hasLength(1));
  });

  test('identical image under another id is not stored twice', () async {
    images['one'] = fakePng(10, 10, seed: 5);
    images['two'] = fakePng(10, 10, seed: 5);
    final first = await downloads.download(source, wallpaper('one'));

    final second = await downloads.download(source, wallpaper('two'));

    expect(second.id, first.id);
    expect(File(p.join(temp.path, 'wallhaven', 'wallhaven_two.png')).existsSync(), isFalse);
  });

  test('failures are reported with a readable message and leave no files', () async {
    final progress = <Map<String, DownloadProgress>>[];
    final sub = downloads.changes.listen(progress.add);

    await expectLater(downloads.download(source, wallpaper('missing')), throwsA(isA<DioException>()));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    final failed = downloads.current['wallhaven:missing']!;
    expect(failed.status, DownloadStatus.failed);
    expect(failed.error, contains('HTTP 404'));
    expect(Directory(p.join(temp.path, 'wallhaven')).listSync(), isEmpty);
    expect(progress.map((m) => m['wallhaven:missing']?.status), contains(DownloadStatus.queued));

    downloads.dismiss('wallhaven:missing');
    expect(downloads.current, isEmpty);
  });
}
