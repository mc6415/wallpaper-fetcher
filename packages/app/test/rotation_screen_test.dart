import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';
import 'package:wallpaper_fetcher/features/rotation/rotation_screen.dart';

import 'support/test_services.dart';

void main() {
  late TestEnv env;

  tearDown(() async => env.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: env.overrides,
        retry: (_, _) => null,
        child: const MaterialApp(home: RotationScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('switching on, choosing an interval and screens saves the schedule', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    await pump(tester);
    final rotation = env.services.rotation;

    expect(find.textContaining('Off. Next and Previous still work'), findsOneWidget);
    await tester.tap(find.text('Change wallpaper automatically'));
    await settle(tester);
    expect(rotation.config.enabled, isTrue);
    expect(find.textContaining('Next change in'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '30 min'));
    await settle(tester);
    expect(rotation.config.interval, const Duration(minutes: 30));

    // Both monitors are on by default; add the lock screen.
    await tester.tap(find.widgetWithText(FilterChip, 'Lock screen'));
    await settle(tester);
    expect(rotation.config.screens, {'DP-1', 'DP-2', 'lock'});

    await tester.tap(find.text('In order'));
    await settle(tester);
    expect(rotation.config.order, RotationOrder.sequential);

    final saved = await tester.runAsync(() => env.services.settings.get(SettingsKeys.rotationConfig));
    expect(RotationConfig.parse(saved), rotation.config);
    await unmount(tester);
  });

  testWidgets('Next now puts a different image on each monitor', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    await tester.runAsync(() async {
      await env.addWallpaper('one', seed: 1);
      await env.addWallpaper('two', seed: 2);
    });
    await pump(tester);

    await tester.tap(find.text('Next now'));
    await settle(tester);

    final applied = env.setter.applied.single;
    expect(applied.map((a) => a.target.id), unorderedEquals(['DP-1', 'DP-2']));
    expect(applied.map((a) => a.imagePath).toSet(), hasLength(2));
    await unmount(tester);
  });

  testWidgets('an empty favourites pool explains itself', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    await tester.runAsync(() => env.addWallpaper('one'));
    await tester.runAsync(() => env.services.rotation.configure(const RotationConfig(pool: FavouritesPool())));
    await pump(tester);

    expect(find.text('Favourites'), findsOneWidget);
    await tester.tap(find.text('Next now'));
    await settle(tester);

    expect(find.textContaining('no favourites yet'), findsOneWidget);
    expect(env.setter.applied, isEmpty);
    await unmount(tester);
  });
}
