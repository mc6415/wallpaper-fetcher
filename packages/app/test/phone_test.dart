import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';
import 'package:wallpaper_fetcher/features/apply/apply_sheet.dart';
import 'package:wallpaper_fetcher/features/rotation/rotation_screen.dart';
import 'package:wallpaper_fetcher/providers.dart';

import 'support/test_services.dart';

/// The app as it behaves on a Galaxy Fold.
void main() {
  late TestEnv env;

  tearDown(() async => env.dispose());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...env.overrides, isPhoneProvider.overrideWithValue(true)],
        retry: (_, _) => null,
        child: MaterialApp(home: child),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Lets real file I/O (sidecars) finish between frames.
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('setting a landscape image asks where to crop, remembers it, and sends it to the setter', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create(setter: FakeFoldSetter())))!;
    final item = (await tester.runAsync(() => env.addWallpaper('wide')))!;

    await pumpPhone(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => showApplySheet(context, item), child: const Text('open')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Both screens'), findsOneWidget);
    expect(find.text('Both screens and their lock screens'), findsOneWidget);
    expect(find.textContaining("you'll choose the crop"), findsNWidgets(2));
    expect(find.text('Fill'), findsNothing, reason: 'Android only fills; no fit choice');

    await tester.tap(find.text('Cover screen'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the crop'), findsOneWidget);

    // Tap the left edge: the cover screen shows the left of the image.
    final area = tester.getRect(find.byKey(const ValueKey('crop-area')));
    await tester.tapAt(Offset(area.left + 1, area.center.dy));
    await tester.pump();
    await tester.tap(find.text('Set wallpaper'));
    await settleIo(tester);

    final applied = env.setter.applied.single.single;
    expect(applied.target.id, 'cover');
    expect(applied.focus!.x, lessThan(0.01));
    expect(applied.imageSize, (width: 3840, height: 2160));
    expect(find.text('Wallpaper set on cover screen.'), findsOneWidget);

    final saved = await tester.runAsync(() => env.services.library.byId(item.id));
    expect(saved!.focus!.x, lessThan(0.01), reason: 'remembered for next time and for rotation');
    await unmount(tester);
  });

  testWidgets('cancelling the crop sets nothing', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create(setter: FakeFoldSetter())))!;
    final item = (await tester.runAsync(() => env.addWallpaper('wide')))!;

    await pumpPhone(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => showApplySheet(context, item), child: const Text('open')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Everywhere'));
    await tester.pumpAndSettle();
    await settleIo(tester); // let the crop screen finish reading the image
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(env.setter.applied, isEmpty);
    expect(find.text('Set as wallpaper'), findsOneWidget, reason: 'back at the sheet');
    await unmount(tester);
  });

  testWidgets('rotation on a phone has no fit choice or keyboard shortcuts', (tester) async {
    env = (await tester.runAsync(() => TestEnv.create(setter: FakeFoldSetter())))!;

    await pumpPhone(tester, const RotationScreen());
    await tester.pumpAndSettle();

    expect(find.text('Main screen'), findsOneWidget);
    expect(find.text('Cover lock screen'), findsOneWidget);
    expect(find.text('Fit'), findsNothing);
    expect(find.text('Keyboard shortcuts'), findsNothing);
    expect(find.textContaining('Changes happen in the background'), findsOneWidget);
    expect(find.text('Off. Next and Previous still work here.'), findsOneWidget);
    await unmount(tester);
  });
}
