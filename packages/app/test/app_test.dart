import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_fetcher/app.dart';
import 'package:wallpaper_fetcher/features/apply/apply_sheet.dart';
import 'package:wallpaper_fetcher/features/library/library_screen.dart';

import 'support/test_services.dart';

void main() {
  late TestEnv env;

  tearDown(() async => env.dispose());

  /// Drift tidies up closed queries on a zero-length timer; let it run
  /// before the test framework checks for pending timers.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> pumpScoped(WidgetTester tester, Widget child) async {
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

  testWidgets('first run asks for a library folder', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create(withLibrary: false)))!;

    await tester.pumpWidget(
      ProviderScope(overrides: env.overrides, retry: (_, _) => null, child: const WallpaperFetcherApp()),
    );
    await tester.pump();

    expect(find.text('Welcome to Wallpaper Fetcher'), findsOneWidget);
    expect(find.text('Use this folder'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('empty library points to Browse', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;

    await pumpScoped(tester, const LibraryScreen());

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Browse wallpapers'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('library shows downloaded wallpapers with their size', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    await tester.runAsync(() async {
      await env.addWallpaper('one', seed: 1);
      await env.addWallpaper('two', seed: 2);
    });

    await pumpScoped(tester, const LibraryScreen());

    expect(find.text('Library · 2'), findsOneWidget);
    expect(find.text('3840 × 2160'), findsNWidgets(2));
    expect(find.byTooltip('Set as wallpaper'), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('apply sheet offers each monitor, all monitors and the lock screen', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    final item = (await tester.runAsync(() => env.addWallpaper('one')))!;

    await pumpScoped(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showApplySheet(context, item),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Left monitor (DP-1)'), findsOneWidget);
    expect(find.text('Right monitor (DP-2)'), findsOneWidget);
    expect(find.text('All monitors'), findsOneWidget);
    expect(find.text('Lock screen'), findsOneWidget);
    expect(find.text('Everywhere'), findsOneWidget);

    await tester.tap(find.text('Fit'));
    await tester.pump();
    await tester.tap(find.text('Right monitor (DP-2)'));
    await tester.pumpAndSettle();

    final applied = env.setter.applied.single;
    expect(applied.map((a) => a.target.id), ['DP-2']);
    expect(applied.single.fit.name, 'fit');
    expect(applied.single.imagePath, env.services.library.absolutePath(item));
    expect(find.text('Wallpaper set on right monitor (DP-2).'), findsOneWidget);

    final updated = await tester.runAsync(() => env.services.library.byId(item.id));
    expect(updated?.applyCount, 1);
    await unmount(tester);
  });
}
