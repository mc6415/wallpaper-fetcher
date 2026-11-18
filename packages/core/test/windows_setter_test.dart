import 'dart:io';

import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

/// Records what [WindowsSetter] asks Windows to do.
class FakeDesktop implements WindowsDesktop {
  FakeDesktop(this.screens);

  /// Null: the per-monitor service isn't available.
  List<WindowsMonitor>? screens;
  final calls = <String>[];

  @override
  Future<List<WindowsMonitor>?> monitors() async => screens;

  @override
  Future<void> setWallpapers(Map<String, String> imageByMonitor, WindowsPosition position) async =>
      calls.add('wallpapers ${position.name} ${[for (final e in imageByMonitor.entries) '${e.key}=${e.value}'].join(' ')}');

  @override
  Future<void> setEverywhere(String image, WindowsPosition position) async =>
      calls.add('everywhere ${position.name} $image');

  @override
  Future<void> setClassic(String image, WindowsPosition position) async => calls.add('classic ${position.name} $image');

  @override
  Future<void> setLockScreen(String image) async => calls.add('lock $image');
}

const left = WindowsMonitor(
  path: r'\\?\DISPLAY#DELA0A5#5&1&UID4353#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}',
  displayName: 'DISPLAY1',
  left: 0,
  top: 0,
  width: 3840,
  height: 2160,
  primary: true,
);

const right = WindowsMonitor(
  path: r'\\?\DISPLAY#DELA0A5#5&1&UID4354#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}',
  displayName: 'DISPLAY2',
  left: 3840,
  top: 0,
  width: 3840,
  height: 2160,
);

void main() {
  test('monitors are named by position and display, plus the lock screen', () async {
    final setter = WindowsSetter(FakeDesktop([right, left]));
    final targets = await setter.targets();

    expect([for (final t in targets) (t.id, t.label, t.width, t.isPrimary, t.surface)], [
      ('DISPLAY2', 'Right monitor (DISPLAY2)', 3840, false, TargetSurface.home),
      ('DISPLAY1', 'Left monitor (DISPLAY1)', 3840, true, TargetSurface.home),
      ('lock', 'Lock screen', 3840, false, TargetSurface.lock),
    ]);
    final caps = await setter.capabilities();
    expect(caps.perTarget, isTrue);
    expect(caps.fitModes, contains(FitMode.span));
    expect(caps.note, isNull);
  });

  test('different images per monitor go in one call, with one position for all', () async {
    final desktop = FakeDesktop([left, right]);
    final setter = WindowsSetter(desktop);
    final targets = {for (final t in await setter.targets()) t.id: t};

    await setter.apply([
      Assignment(target: targets['DISPLAY1']!, imagePath: r'C:\Pics\a.jpg', fit: FitMode.fit),
      Assignment(target: targets['DISPLAY2']!, imagePath: r'C:\Pics\b.jpg', fit: FitMode.fit),
      Assignment(target: targets['lock']!, imagePath: r'C:\Pics\c.jpg'),
    ]);

    expect(desktop.calls, [
      'wallpapers fit ${left.path}=C:\\Pics\\a.jpg ${right.path}=C:\\Pics\\b.jpg',
      r'lock C:\Pics\c.jpg',
    ]);
  });

  test('span puts the first image across every monitor', () async {
    final desktop = FakeDesktop([left, right]);
    final setter = WindowsSetter(desktop);
    final display1 = (await setter.targets()).first;

    await setter.apply([Assignment(target: display1, imagePath: r'C:\Pics\wide.jpg', fit: FitMode.span)]);

    expect(desktop.calls, [r'everywhere span C:\Pics\wide.jpg']);
  });

  test('a monitor that has gone is a clear error', () async {
    final desktop = FakeDesktop([left, right]);
    final setter = WindowsSetter(desktop);
    final display2 = (await setter.targets())[1];
    desktop.screens = [left];

    await expectLater(
      setter.apply([Assignment(target: display2, imagePath: r'C:\x.jpg')]),
      throwsA(isA<WallpaperSetterException>().having((e) => e.message, 'message', contains('no longer connected'))),
    );
  });

  test('without the per-monitor service, one image goes on the whole desktop the old way', () async {
    final desktop = FakeDesktop(null);
    final setter = WindowsSetter(desktop);
    final targets = await setter.targets();

    expect([for (final t in targets) t.id], ['desktop', 'lock']);
    final caps = await setter.capabilities();
    expect(caps.perTarget, isFalse);
    expect(caps.note, contains('same image'));

    await setter.apply([Assignment(target: targets.first, imagePath: r'C:\x.jpg', fit: FitMode.centre)]);
    expect(desktop.calls, [r'classic center C:\x.jpg']);
  });

  test('every fit has a Windows position', () {
    expect({for (final f in FitMode.values) f: WindowsPosition.of(f).value}, {
      FitMode.fill: 4,
      FitMode.fit: 3,
      FitMode.stretch: 2,
      FitMode.centre: 0,
      FitMode.span: 5,
    });
  });

  group('lock screen', () {
    test('runs Windows PowerShell with the image in an environment variable', () async {
      late List<String> args;
      late Map<String, String>? env;
      final lock = LockScreenSetter(
        run: (exe, arguments, {environment}) async {
          args = arguments;
          env = environment;
          return ProcessResult(1, 0, '', '');
        },
      );

      await lock.set(r"C:\Users\me\Pictures\it's here.jpg");

      expect(env, {LockScreenSetter.imageVariable: r"C:\Users\me\Pictures\it's here.jpg"});
      expect(args, containsAllInOrder(['-NoProfile', '-Command']));
      expect(args.last, contains('SetImageFileAsync'));
      expect(args.last, isNot(contains('here.jpg')), reason: 'the path never goes into the script');
    });

    test('a failure says why', () async {
      final lock = LockScreenSetter(
        run: (exe, arguments, {environment}) async =>
            ProcessResult(1, 1, '', 'Exception calling "Wait": Access is denied.\r\n  at line 1\r\n'),
      );
      await expectLater(
        lock.set(r'C:\x.jpg'),
        throwsA(isA<WallpaperSetterException>().having((e) => e.message, 'message', contains('Access is denied'))),
      );
    });
  });
}
