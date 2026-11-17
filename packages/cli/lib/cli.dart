/// `wallpaper-fetcher` command line: sends commands to the running app, or
/// does the work itself when the app isn't running.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:drift/native.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

/// Exit codes: 0 ok, 1 the command failed, 64 bad usage (sysexits EX_USAGE).
const exitOk = 0, exitFailed = 1, exitUsage = 64;

final parser = ArgParser()
  ..addMultiOption('screen', abbr: 's', valueHelp: 'id', help: 'Screen to act on (see "screens"). Repeat for more.')
  ..addFlag('all', abbr: 'a', negatable: false, help: 'Every screen, including the lock screen.')
  ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Print log messages.')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

String get usage {
  final width = CommandHandler.commands.keys.map((k) => k.length).reduce((a, b) => a > b ? a : b);
  return [
    'Usage: wallpaper-fetcher <command> [options]',
    '',
    'Commands:',
    for (final MapEntry(:key, :value) in CommandHandler.commands.entries) '  ${key.padRight(width)}  $value',
    '',
    'Options:',
    parser.usage,
    '',
    'Without --screen, next/previous/apply use the rotation screens (every',
    'monitor unless set in the app) and favourite uses the main monitor.',
    '',
    'Examples:',
    '  wallpaper-fetcher next',
    '  wallpaper-fetcher previous --screen DP-2',
    '  wallpaper-fetcher apply wallhaven/wallhaven_abc123.jpg --all',
  ].join('\n');
}

/// Builds the request from arguments, or returns a usage error message.
/// [notify] asks for a desktop notification of the outcome (no terminal).
(CommandRequest?, String?) parseArgs(List<String> args, {bool notify = false}) {
  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    return (null, e.message);
  }
  if (results.flag('help') || results.rest.isEmpty) return (null, null);
  final command = results.rest.first;
  if (!CommandHandler.commands.containsKey(command)) return (null, 'Unknown command "$command".');
  final screens = results.multiOption('screen');
  return (
    CommandRequest(
      command,
      targets: screens.isNotEmpty ? screens : (results.flag('all') ? const ['*'] : null),
      argument: results.rest.length > 1 ? results.rest[1] : null,
      notify: notify,
    ),
    null,
  );
}

/// Runs one command. [send] reaches the running app (null reply = not
/// running); [direct] opens the library to do it without the app.
Future<int> runCli(
  List<String> args, {
  required Future<CommandResponse?> Function(CommandRequest) send,
  required Future<CommandHandler> Function() direct,
  required StringSink out,
  required StringSink err,
  Future<void> Function(String summary, String body)? notify,
}) async {
  final (request, problem) = parseArgs(args, notify: notify != null);
  if (request == null) {
    if (problem != null) err.writeln('$problem\n');
    (problem == null ? out : err).writeln(usage);
    return problem == null ? exitOk : exitUsage;
  }

  var response = await send(request);
  if (response == null) {
    if (request.command == 'show' || request.command == 'quit') {
      err.writeln("Wallpaper Fetcher isn't running.");
      return exitFailed;
    }
    try {
      response = await (await direct()).handle(request);
    } on CliException catch (e) {
      err.writeln(e.message);
      await notify?.call('Wallpaper Fetcher', e.message);
      return exitFailed;
    }
    // The app notifies for itself; without it, do it here.
    if (notify != null && (!response.ok || request.command == 'favourite')) {
      await notify(response.ok ? 'Wallpaper Fetcher' : "Couldn't ${request.command}", response.message);
    }
  }
  (response.ok ? out : err).writeln(response.message);
  return response.ok ? exitOk : exitFailed;
}

class CliException implements Exception {
  CliException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Opens the app's own database and library to run commands without the app.
Future<CommandHandler> openDirect({bool verbose = false}) async {
  final dbFile = File(AppPaths.database());
  if (!dbFile.existsSync()) {
    throw CliException("Wallpaper Fetcher isn't set up yet. Open the app once and choose a library folder.");
  }
  setupLogging(directory: AppPaths.logs(), fileName: 'cli.log', echoToConsole: verbose);
  final db = AppDatabase(NativeDatabase(dbFile));
  final settings = SettingsStore(db);
  final library = WallpaperLibrary(db, settings);
  await library.load();
  if (library.root == null) {
    throw CliException("No library folder chosen yet. Open the app once and choose one.");
  }
  final history = WallpaperHistory(db, settings);
  final setter = Platform.isLinux
      ? createLinuxSetter()
      : const UnsupportedSetter("The command line can't set wallpapers on this platform yet.");
  final applier = WallpaperApplier(setter: setter, library: library, history: history);
  final dio = createHttpClient();
  final rotation = RotationService(
    setter: setter,
    applier: applier,
    library: library,
    history: history,
    settings: settings,
    downloads: DownloadManager(dio: dio, library: library),
    // Daily rotation needs these; the rest of rotation uses the library only.
    sources: {
      BingSource.sourceId: BingSource(dio: dio, market: _bingMarket(Platform.localeName)),
      WikimediaSource.sourceId: WikimediaSource(dio: dio),
    },
  );
  await rotation.load();
  return CommandHandler(rotation: rotation, library: library, history: history);
}

String _bingMarket(String localeName) {
  final match = RegExp(r'^([a-z]{2})[_-]([A-Z]{2})').firstMatch(localeName);
  return match == null ? 'en-US' : '${match[1]}-${match[2]}';
}
