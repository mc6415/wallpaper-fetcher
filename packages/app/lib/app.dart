import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers.dart';
import 'router.dart';

/// Used when the desktop doesn't provide an accent colour.
const fallbackAccent = Color(0xFF6750A4);

class WallpaperFetcherApp extends ConsumerWidget {
  const WallpaperFetcherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final chosen = ref.watch(themeModeProvider);
    final seed = appearance.accent ?? fallbackAccent;
    // "System" follows the desktop's own light/dark preference when it has one.
    final mode = chosen != ThemeMode.system
        ? chosen
        : switch (appearance.prefersDark) {
            true => ThemeMode.dark,
            false => ThemeMode.light,
            null => ThemeMode.system,
          };

    return MaterialApp.router(
      title: 'Wallpaper Fetcher',
      debugShowCheckedModeBanner: false,
      theme: themeFor(seed, Brightness.light),
      darkTheme: themeFor(seed, Brightness.dark),
      themeMode: mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

ThemeData themeFor(Color seed, Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
);
