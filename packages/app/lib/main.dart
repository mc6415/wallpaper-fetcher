import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'providers.dart';
import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      // Errors are shown to the user rather than silently retried.
      retry: (_, _) => null,
      child: const WallpaperFetcherApp(),
    ),
  );
}
