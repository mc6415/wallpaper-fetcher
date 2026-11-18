import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';
import 'package:wallpaper_fetcher/platform/android/android_setter.dart';

/// What the Galaxy Fold (SM-F976B, Android 17) reported, unfolded.
const foldDevice = {
  'sdk': 37,
  'manufacturer': 'samsung',
  'model': 'SM-F976B',
  'canSet': true,
  'hasHinge': true,
  'samsungSubDisplayFlag': 16,
  'samsungMainDisplayFlag': 4,
  'current': {'width': 2256, 'height': 2504},
  'displays': [
    {'id': 0, 'name': 'Built-in Screen', 'width': 2256, 'height': 2504, 'on': true},
    {'id': 1, 'name': 'Built-in Screen', 'width': 1080, 'height': 2520, 'on': false},
  ],
};

const pixelDevice = {
  'sdk': 36,
  'manufacturer': 'Google',
  'model': 'Pixel 9',
  'canSet': true,
  'hasHinge': false,
  'samsungSubDisplayFlag': null,
  'current': {'width': 1080, 'height': 2424},
  'displays': [
    {'id': 0, 'name': 'Built-in Screen', 'width': 1080, 'height': 2424, 'on': true},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = AndroidSetter.wallpaperChannel;
  late List<MethodCall> calls;
  late Map<String, Object?> device;
  PlatformException? failure;

  setUp(() {
    calls = [];
    failure = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'device') return device;
      if (failure != null) throw failure!;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('a Samsung foldable has main and cover screens, each with a lock screen', () async {
    device = foldDevice;
    final setter = await AndroidSetter.create();
    final targets = await setter.targets();

    expect(setter.name, 'Samsung foldable');
    expect([for (final t in targets) (t.id, t.width, t.height, t.surface)], [
      ('main', 2256, 2504, TargetSurface.home),
      ('cover', 1080, 2520, TargetSurface.home),
      ('main-lock', 2256, 2504, TargetSurface.lock),
      ('cover-lock', 1080, 2520, TargetSurface.lock),
    ]);
    expect(targets.first.isPrimary, isTrue);
  });

  test("each Fold screen gets One UI's display bit and a crop to its shape", () async {
    device = foldDevice;
    final setter = await AndroidSetter.create();
    final targets = {for (final t in await setter.targets()) t.id: t};

    await setter.apply([
      for (final id in ['main', 'cover', 'main-lock', 'cover-lock'])
        Assignment(
          target: targets[id]!,
          imagePath: '/data/wallhaven_abc.jpg',
          imageSize: (width: 3840, height: 2160),
          focus: id.startsWith('cover') ? (x: 0.0, y: 0.5) : null,
        ),
    ]);

    final sent = (calls.last.arguments as Map)['assignments'] as List;
    expect([for (final a in sent) (a as Map)['which']], [1 | 4, 1 | 16, 2 | 4, 2 | 16]);
    expect((sent[0] as Map)['crop'], cropToFill(3840, 2160, 2256, 2504).toList());
    expect((sent[1] as Map)['crop'], [0, 0, 926, 2160], reason: 'cover crop pushed to the left edge by the focus');
  });

  test('an ordinary phone has a home and a lock screen with plain flags', () async {
    device = pixelDevice;
    final setter = await AndroidSetter.create();
    final targets = await setter.targets();

    expect(setter.name, 'Android');
    expect([for (final t in targets) t.id], ['screen', 'lock']);

    await setter.apply([
      for (final t in targets) Assignment(target: t, imagePath: 'content://tree/a.jpg', imageSize: (width: 1440, height: 3200)),
    ]);
    final sent = (calls.last.arguments as Map)['assignments'] as List;
    expect([for (final a in sent) (a as Map)['which']], [1, 2]);
    expect((sent[0] as Map)['path'], 'content://tree/a.jpg');
  });

  test('a Samsung phone without a hinge is treated as an ordinary phone', () async {
    device = {...foldDevice, 'hasHinge': false};
    final setter = await AndroidSetter.create();
    expect([for (final t in await setter.targets()) t.id], ['screen', 'lock']);
  });

  test('platform errors become setter errors with the message', () async {
    device = pixelDevice;
    final setter = await AndroidSetter.create();
    failure = PlatformException(code: 'not_allowed', message: 'Changing the wallpaper is blocked on this device.');

    await expectLater(
      setter.apply([
        Assignment(target: (await setter.targets()).first, imagePath: 'content://x', imageSize: (width: 1, height: 1)),
      ]),
      throwsA(isA<WallpaperSetterException>().having((e) => e.message, 'message', contains('blocked'))),
    );
  });

  test('only Fill is offered, and a blocked device says why', () async {
    device = {...pixelDevice, 'canSet': false};
    final caps = await (await AndroidSetter.create()).capabilities();
    expect(caps.fitModes, [FitMode.fill]);
    expect(caps.note, contains('blocked'));
  });
}
