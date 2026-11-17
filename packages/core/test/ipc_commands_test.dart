import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'rotation_test.dart' show FakeSetter;
import 'support/fake_http.dart';

void main() {
  group('IPC over a Unix socket', () {
    late Directory temp;
    late String socket;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('wf_ipc_');
      socket = p.join(temp.path, 'test.sock');
    });

    tearDown(() => temp.delete(recursive: true));

    test('a request reaches the handler and the reply comes back', () async {
      CommandRequest? received;
      final server = await IpcServer.bind(socket, (r) async {
        received = r;
        return CommandResponse(true, 'did ${r.command}');
      });
      addTearDown(server.close);

      final reply = await IpcClient(socket).send(const CommandRequest('next', targets: ['DP-2'], argument: 'x'));

      expect(reply?.ok, isTrue);
      expect(reply?.message, 'did next');
      expect(received?.targets, ['DP-2']);
      expect(received?.argument, 'x');
    });

    test('no app listening gives null, so the CLI can work directly', () async {
      expect(await IpcClient(socket).send(const CommandRequest('next')), isNull);
    });

    test('a second instance is refused; a stale socket file is cleaned up', () async {
      final first = await IpcServer.bind(socket, (r) async => const CommandResponse(true, 'pong'));
      await expectLater(IpcServer.bind(socket, (r) async => const CommandResponse(true, '')), throwsA(isA<IpcAlreadyRunning>()));
      await first.close();
      expect(File(socket).existsSync(), isFalse);

      File(socket).writeAsStringSync(''); // left over from a crash
      final again = await IpcServer.bind(socket, (r) async => const CommandResponse(true, 'pong'));
      expect(await IpcClient(socket).ping(), isTrue);
      await again.close();
    });

    test('a server that closes without answering gives an error reply, not a crash', () async {
      final server = await ServerSocket.bind(InternetAddress(socket, type: InternetAddressType.unix), 0);
      server.listen((s) => s.destroy());
      addTearDown(server.close);
      final reply = await IpcClient(socket).send(const CommandRequest('quit'));
      expect(reply?.ok, isFalse);
      expect(reply?.message, contains('without answering'));
    });

    test('handler errors become error replies, not dropped connections', () async {
      final server = await IpcServer.bind(socket, (r) async => throw StateError('boom'));
      addTearDown(server.close);
      final reply = await IpcClient(socket).send(const CommandRequest('next'));
      expect(reply?.ok, isFalse);
      expect(reply?.message, contains('boom'));
    });
  });

  group('commands', () {
    late Directory temp;
    late AppDatabase db;
    late WallpaperLibrary library;
    late WallpaperHistory history;
    late FakeSetter setter;
    late RotationService rotation;
    late CommandHandler handler;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('wf_commands_');
      db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsStore(db);
      library = WallpaperLibrary(db, settings);
      await library.setRoot(temp.path);
      history = WallpaperHistory(db, settings);
      setter = FakeSetter();
      final applier = WallpaperApplier(setter: setter, library: library, history: history);
      rotation = RotationService(
        setter: setter,
        applier: applier,
        library: library,
        history: history,
        settings: settings,
        downloads: DownloadManager(dio: fakeDio((_) async => jsonBody({})), library: library),
        sources: const {},
      );
      await rotation.load();
      handler = CommandHandler(rotation: rotation, library: library, history: history);
      for (final (i, name) in ['a', 'b', 'c'].indexed) {
        await File(library.absoluteFor('$name.png')).writeAsBytes(fakePng(3840, 2160, seed: i));
      }
      await library.rescan();
    });

    tearDown(() async {
      await rotation.dispose();
      await db.close();
      await temp.delete(recursive: true);
    });

    Future<CommandResponse> run(String command, {List<String>? targets, String? argument}) =>
        handler.handle(CommandRequest(command, targets: targets, argument: argument));

    test('next reports what went where', () async {
      final reply = await run('next');
      expect(reply.ok, isTrue);
      expect(reply.message, allOf(contains('Left: '), contains('Right: ')));
    });

    test('--all means every screen, lock screen included', () async {
      final reply = await run('next', targets: ['*']);
      expect(reply.message.split('\n'), hasLength(3));
    });

    test('favourite defaults to the main monitor', () async {
      await run('next');
      final reply = await run('favourite');
      expect(reply.ok, isTrue);
      final favourites = await library.items(filter: const LibraryFilter(favouritesOnly: true));
      final onLeft = (await history.nowShowing())['DP-1']!.item!;
      expect(favourites.map((i) => i.id), [onLeft.id]);
    });

    test('apply by library path or id; unknown images explain themselves', () async {
      final byPath = await run('apply', argument: p.join(temp.path, 'b.png'), targets: ['DP-2']);
      expect(byPath.ok, isTrue, reason: byPath.message);
      expect(setter.calls.last, ['DP-2=b']);

      final c = (await library.items()).firstWhere((i) => i.relativePath == 'c.png');
      expect((await run('apply', argument: '${c.id}', targets: ['DP-1'])).ok, isTrue);
      expect(setter.calls.last, ['DP-1=c']);

      expect((await run('apply', argument: 'nope.png')).ok, isFalse);
      expect((await run('apply')).message, contains('Say which image'));
    });

    test('status lists each screen and the schedule; pause and resume', () async {
      await run('next', targets: ['DP-1']);
      await rotation.configure(const RotationConfig(enabled: true, interval: Duration(minutes: 30)));
      expect((await run('status')).message, allOf(contains('Left [DP-1]: '), contains('Rotation: every 30 minutes')));

      await run('pause');
      expect((await run('status')).message, contains('Rotation: paused'));
      await run('resume');
      expect(rotation.paused, isFalse);
    });

    test('app-only commands without the app, and unknown commands', () async {
      expect((await run('show')).ok, isFalse);
      expect((await run('dance')).message, contains('Unknown command'));
    });

    test('screens lists ids for --screen', () async {
      expect((await run('screens')).message, contains('DP-2\tRight\t3840x2160'));
    });
  });
}
