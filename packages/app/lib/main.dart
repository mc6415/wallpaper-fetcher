import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'app.dart';
import 'platform/desktop.dart';
import 'providers.dart';
import 'services.dart';

/// `--hidden` starts in the tray without opening the window (used on login).
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // One instance only: if it's already running, bring its window forward.
  if (Platform.isLinux) {
    final running = await IpcClient(AppPaths.socket(), timeout: const Duration(seconds: 5))
        .send(const CommandRequest('show'));
    if (running != null) exit(0);
  }

  final services = await AppServices.create();
  final DesktopIntegration? desktop;
  try {
    desktop = await DesktopIntegration.start(services);
  } on IpcAlreadyRunning {
    exit(0);
  }

  runApp(
    ProviderScope(
      overrides: [
        servicesProvider.overrideWithValue(services),
        desktopProvider.overrideWithValue(desktop),
      ],
      // Errors are shown to the user rather than silently retried.
      retry: (_, _) => null,
      child: const WallpaperFetcherApp(),
    ),
  );
}
