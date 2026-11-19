import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_fetcher/app.dart';
import 'package:wallpaper_fetcher/features/browse/remote_tile.dart';
import 'package:wallpaper_fetcher/features/library/history_screen.dart';
import 'package:wallpaper_fetcher/features/library/library_screen.dart';

import 'support/test_services.dart';

/// Three Wallhaven results, w1 to w3, and no more pages.
class _ThreeWallpapers implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async =>
      ResponseBody.fromString(
        jsonEncode({
          'data': [
            for (final id in ['w1', 'w2', 'w3'])
              {
                'id': id,
                'path': 'https://w.wallhaven.cc/full/$id.jpg',
                'thumbs': {'large': 'https://th.wallhaven.cc/lg/$id.jpg'},
                'dimension_x': 3840,
                'dimension_y': 2160,
              },
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'total': 3},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late TestEnv env;

  tearDown(() async => env.dispose());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// Lets simulated timers, real file I/O and page transitions finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: env.overrides, retry: (_, _) => null, child: const WallpaperFetcherApp()),
    );
    await settle(tester);
  }

  Finder titled(String title) => find.widgetWithText(AppBar, title);

  testWidgets('library detail steps through the grid by arrows and arrow keys; Back returns to the grid', (
    tester,
  ) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    await tester.runAsync(() async {
      for (final (i, name) in ['one', 'two', 'three'].indexed) {
        await env.addWallpaper(name, seed: i);
      }
    });
    await pumpApp(tester);
    await tester.tap(find.text('Library'));
    await settle(tester);

    final tiles = find.byType(LibraryTile);
    expect(tiles, findsNWidgets(3));
    final names = [for (final e in tiles.evaluate()) itemName((e.widget as LibraryTile).item)];

    await tester.tap(tiles.first);
    await settle(tester);
    expect(titled(names[0]), findsOneWidget);
    expect(find.byTooltip('Previous wallpaper'), findsNothing);

    await tester.tap(find.byTooltip('Next wallpaper'));
    await settle(tester);
    expect(titled(names[1]), findsOneWidget);
    expect(find.byTooltip('Previous wallpaper'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(titled(names[2]), findsOneWidget);
    expect(find.byTooltip('Next wallpaper'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(titled(names[1]), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(LibraryTile), findsNWidgets(3));
    expect(find.byTooltip('Previous wallpaper'), findsNothing);
    await unmount(tester);
  });

  testWidgets('browse preview steps through the search results; Back returns to them', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create()))!;
    env.services.dio.httpClientAdapter = _ThreeWallpapers();
    await pumpApp(tester);
    expect(find.byType(RemoteTile), findsNWidgets(3));

    await tester.tap(find.byType(RemoteTile).first);
    await settle(tester);
    expect(titled('Wallhaven · w1'), findsOneWidget);
    expect(find.byTooltip('Previous wallpaper'), findsNothing);

    await tester.tap(find.byTooltip('Next wallpaper'));
    await settle(tester);
    expect(titled('Wallhaven · w2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(titled('Wallhaven · w3'), findsOneWidget);
    expect(find.byTooltip('Next wallpaper'), findsNothing);

    await tester.tap(find.byTooltip('Previous wallpaper'));
    await settle(tester);
    expect(titled('Wallhaven · w2'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(RemoteTile), findsNWidgets(3));
    expect(find.byTooltip('Next wallpaper'), findsNothing);
    await unmount(tester);
  });
}
