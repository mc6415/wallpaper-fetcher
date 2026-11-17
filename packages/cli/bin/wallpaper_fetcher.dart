import 'dart:io';

import 'package:wallpaper_core/wallpaper_core.dart';
import 'package:wallpaper_fetcher_cli/cli.dart';

Future<void> main(List<String> args) async {
  final code = await runCli(
    args,
    send: IpcClient(AppPaths.socket()).send,
    direct: () => openDirect(verbose: args.contains('-v') || args.contains('--verbose')),
    out: stdout,
    err: stderr,
    // Run from a keyboard shortcut there's no terminal; say what happened.
    notify: stdout.hasTerminal ? null : DesktopNotifier().notify,
  );
  await stdout.flush();
  // The desktop's D-Bus connection would otherwise keep the process alive.
  exit(code);
}
