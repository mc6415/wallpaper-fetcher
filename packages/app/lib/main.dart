import 'dart:io';

import 'package:drift/drift.dart' show TableUpdate;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'app.dart';
import 'platform/android/background_rotation.dart';
import 'platform/desktop.dart';
import 'providers.dart';
import 'services.dart';

/// `--hidden` starts in the tray without opening the window (used on login).
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // One instance only: if it's already running, bring its window forward.
  if (Platform.isLinux || Platform.isWindows) {
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

  if (Platform.isAndroid) AndroidRotationSchedule(services.rotation).start();

  AppLifecycleListener(
    // Logged because a hidden window that doesn't draw again looks like a bug.
    onStateChange: (state) => Logger('Lifecycle').info(state.name),
    // Android's background job may have changed the wallpaper meanwhile.
    onResume: Platform.isAndroid ? () => _refreshAfterBackground(services) : null,
  );

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

/// Picks up what the background rotation job did while the app was away.
/// It normally shares the app's database connection, but not if the app
/// started while it was running.
Future<void> _refreshAfterBackground(AppServices services) async {
  await services.rotation.load();
  services.db.notifyUpdates({
    TableUpdate.onTable(services.db.wallpapers),
    TableUpdate.onTable(services.db.applyHistory),
  });
}

/// Android's background rotation job (`RotationWorker.kt`) starts here.
@pragma('vm:entry-point')
Future<void> rotationWorkerMain() => runBackgroundRotation();
