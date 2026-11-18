import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';
import 'package:wallpaper_fetcher/features/browse/browse_screen.dart';
import 'package:wallpaper_fetcher/features/library/library_screen.dart';
import 'package:wallpaper_fetcher/features/settings/settings_screen.dart';

import 'support/test_services.dart';

void main() {
  late TestEnv env;

  tearDown(() async => env.dispose());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// Lets both kinds of async finish: simulated timers (Dio, drift) and real
  /// file I/O (sidecars), which only completes outside the fake clock.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpScoped(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: env.overrides,
        retry: (_, _) => null,
        child: MaterialApp(home: child),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Browse has a tab per source; Unsplash without a key points to Settings', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;

    await pumpScoped(tester, const BrowseScreen());

    for (final name in ['Wallhaven', 'Unsplash', 'Bing', 'Wikimedia']) {
      expect(find.widgetWithText(Tab, name), findsOneWidget);
    }
    await settle(tester);
    await tester.tap(find.widgetWithText(Tab, 'Unsplash'));
    await tester.pump(const Duration(milliseconds: 400)); // tab animation
    await settle(tester);

    expect(find.text('Unsplash needs an API key'), findsOneWidget);
    expect(find.text('Add key in Settings'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Wallhaven shows category and colour filters, defaulting to General', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;

    await pumpScoped(tester, const BrowseScreen());
    await settle(tester);

    expect(find.byTooltip('Categories'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Any colour'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('favourite a tile, then filter to favourites', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    await tester.runAsync(() async {
      await env.addWallpaper('one', seed: 1);
      await env.addWallpaper('two', seed: 2);
    });

    await pumpScoped(tester, const LibraryScreen());
    expect(find.byType(LibraryTile), findsNWidgets(2));

    await tester.tap(find.byTooltip('Add to favourites').first);
    await settle(tester);
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Favourites'));
    await settle(tester);

    expect(find.byType(LibraryTile), findsOneWidget);
    expect(find.text('Library · 1 of 2'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('now-showing strip appears after applying, with a working Previous', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    final (one, two) = (await tester.runAsync(() async {
      final one = await env.addWallpaper('one', seed: 1);
      final two = await env.addWallpaper('two', seed: 2);
      final left = (await env.setter.targets()).first;
      await env.services.applier.apply(one, [left]);
      await env.services.applier.apply(two, [left]);
      return (one, two);
    }))!;

    await pumpScoped(tester, const LibraryScreen());
    await settle(tester);

    expect(find.text('Left monitor (DP-1)'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous wallpaper'));
    await settle(tester);

    final last = env.setter.applied.last.single;
    expect(last.target.id, 'DP-1');
    expect(last.imagePath, env.services.library.absolutePath(one));
    expect(two.id, isNot(one.id));
    await unmount(tester);
  });

  testWidgets('adding an Unsplash key stores it in the keyring', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;

    await pumpScoped(tester, const SettingsScreen());
    expect(find.textContaining('Unsplash stays empty until you add one'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  my-access-key  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(env.keyStore.saved, {'unsplash': 'my-access-key'});
    expect(env.services.apiKeys['unsplash'], 'my-access-key');
    // "...system keyring" on Linux, "...your Windows account" on Windows.
    expect(find.textContaining('Saved'), findsOneWidget);
    final remembered = await tester.runAsync(() => env.services.settings.get(SettingsKeys.savedApiKeys));
    expect(remembered, 'unsplash');
    await unmount(tester);
  });
}
