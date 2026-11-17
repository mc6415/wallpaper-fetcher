import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';
import 'package:wallpaper_fetcher_cli/cli.dart';

class FakeHandler implements CommandHandler {
  final seen = <CommandRequest>[];

  @override
  Future<CommandResponse> handle(CommandRequest request) async {
    seen.add(request);
    return CommandResponse(true, 'direct ${request.command}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late List<CommandRequest> sent;
  late FakeHandler direct;

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    sent = [];
    direct = FakeHandler();
  });

  Future<int> run(List<String> args, {bool appRunning = true}) => runCli(
    args,
    send: (r) async {
      sent.add(r);
      return appRunning ? CommandResponse(true, 'app ${r.command}') : null;
    },
    direct: () async => direct,
    out: out,
    err: err,
  );

  test('sends the command to the running app', () async {
    expect(await run(['next']), exitOk);
    expect(out.toString().trim(), 'app next');
    expect(sent.single.targets, isNull);
    expect(direct.seen, isEmpty);
  });

  test('--screen and --all choose the targets; the second word is the argument', () async {
    await run(['previous', '-s', 'DP-1', '--screen', 'DP-2']);
    await run(['next', '--all']);
    await run(['apply', 'wallhaven/x.jpg']);
    expect(sent[0].targets, ['DP-1', 'DP-2']);
    expect(sent[1].targets, ['*']);
    expect(sent[2].argument, 'wallhaven/x.jpg');
  });

  test('works without the app by opening the library directly', () async {
    expect(await run(['next'], appRunning: false), exitOk);
    expect(out.toString().trim(), 'direct next');
    expect(direct.seen.single.command, 'next');
  });

  test("show and quit need the app", () async {
    expect(await run(['show'], appRunning: false), exitFailed);
    expect(err.toString(), contains("isn't running"));
    expect(direct.seen, isEmpty);
  });

  test('help and usage errors', () async {
    expect(await run([]), exitOk);
    expect(out.toString(), contains('Usage: wallpaper-fetcher'));
    expect(await run(['dance']), exitUsage);
    expect(err.toString(), contains('Unknown command "dance"'));
    expect(await run(['next', '--bogus']), exitUsage);
    expect(sent, isEmpty);
  });

  test('a failed command exits 1 with the message on stderr', () async {
    final code = await runCli(
      ['favourite'],
      send: (_) async => const CommandResponse.error('Nothing to favourite'),
      direct: () async => direct,
      out: out,
      err: err,
    );
    expect(code, exitFailed);
    expect(err.toString(), contains('Nothing to favourite'));
  });
}
