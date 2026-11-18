// Exercises the real Windows calls on a Windows machine (run in CI):
//   dart run tool/windows_smoke.dart
// Prints what happens at each step. Exits non-zero if a step throws
// something other than an expected "not available here".
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:wallpaper_core/wallpaper_core.dart';

var _failures = 0;

Future<void> step(String name, Future<Object?> Function() body) async {
  stdout.writeln('--- $name');
  try {
    final result = await body();
    if (result != null) stdout.writeln('    $result');
    stdout.writeln('    ok');
  } on Object catch (e, stack) {
    _failures++;
    stdout.writeln('    FAILED: $e\n$stack');
  }
}

/// A solid-colour 24-bit BMP, which Windows accepts as a wallpaper.
Uint8List bmp(int width, int height, int r, int g, int b) {
  final row = (width * 3 + 3) & ~3;
  final size = 54 + row * height;
  final data = ByteData(size)
    ..setUint8(0, 0x42)
    ..setUint8(1, 0x4D)
    ..setUint32(2, size, Endian.little)
    ..setUint32(10, 54, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, width, Endian.little)
    ..setInt32(22, height, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(34, row * height, Endian.little);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final o = 54 + y * row + x * 3;
      data
        ..setUint8(o, b)
        ..setUint8(o + 1, g)
        ..setUint8(o + 2, r);
    }
  }
  return data.buffer.asUint8List();
}

Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('Run this on Windows.');
    exit(2);
  }
  stdout.writeln('Windows ${Platform.operatingSystemVersion}');
  final temp = await Directory.systemTemp.createTemp('wf_smoke_');
  final red = File(p.join(temp.path, 'red.bmp'))..writeAsBytesSync(bmp(64, 36, 200, 30, 30));
  final blue = File(p.join(temp.path, 'blue.bmp'))..writeAsBytesSync(bmp(64, 36, 30, 30, 200));
  const desktop = Win32Desktop();
  final setter = WindowsSetter(desktop);

  List<WindowsMonitor>? monitors;
  await step('Monitors (IDesktopWallpaper)', () async {
    monitors = await desktop.monitors();
    return monitors == null ? 'per-monitor service unavailable' : monitors!.join('\n    ');
  });

  late List<DisplayTarget> targets;
  await step('Targets', () async {
    targets = await setter.targets();
    final caps = await setter.capabilities();
    return '${targets.map((t) => '${t.id}: ${t.label} ${t.width}x${t.height}${t.isPrimary ? ' (primary)' : ''}').join('\n    ')}\n'
        '    perTarget=${caps.perTarget} note=${caps.note}';
  });

  final screens = [for (final t in targets) if (t.surface == TargetSurface.home) t];
  await step('Different image per monitor, then read back', () async {
    await setter.apply([
      for (final (i, t) in screens.indexed) Assignment(target: t, imagePath: (i.isEven ? red : blue).path),
    ]);
    if (monitors == null) return 'set with the classic API';
    final shown = [for (final m in monitors!) await desktop.wallpaperOf(m.path)];
    return 'now showing: ${shown.join(', ')}';
  });

  await step('Span one image across all monitors', () async {
    await setter.apply([Assignment(target: screens.first, imagePath: blue.path, fit: FitMode.span)]);
    return monitors == null ? null : 'first monitor: ${await desktop.wallpaperOf(monitors!.first.path)}';
  });

  await step('Classic SystemParametersInfo fallback', () async {
    await desktop.setClassic(red.path, WindowsPosition.fill);
    return 'WallpaperStyle=${UserRegistry.readString(r'Control Panel\Desktop', 'WallpaperStyle')}';
  });

  await step('Registry round trip (HKCU)', () async {
    const key = r'Software\dev.mcoombes\WallpaperFetcherSmokeTest';
    UserRegistry.writeString(key, 'Value', 'C:\\Program Files\\x.exe" --hidden');
    final back = UserRegistry.readString(key, 'Value');
    UserRegistry.delete(key, 'Value');
    final gone = UserRegistry.readString(key, 'Value');
    if (back != 'C:\\Program Files\\x.exe" --hidden' || gone != null) throw StateError('read back "$back", after delete "$gone"');
    return 'wrote, read back and deleted';
  });

  await step('Accent colour (DWM AccentColor)', () async {
    final abgr = UserRegistry.readDword(r'Software\Microsoft\Windows\DWM', 'AccentColor');
    return abgr == null ? 'not set' : '0x${abgr.toRadixString(16)}';
  });

  await step('Pictures folder', () async => Win32Desktop.picturesFolder());

  await step('App paths', () async => 'data ${AppPaths.dataDirectory()}\n    socket ${AppPaths.socket()}');

  await step('Lock screen (LockScreen.SetImageFileAsync via PowerShell)', () async {
    try {
      await desktop.setLockScreen(blue.path);
      return 'set';
    } on WallpaperSetterException catch (e) {
      // Reported, not failed: a CI machine may not allow it.
      return 'not set: ${e.message}';
    }
  });

  await temp.delete(recursive: true);
  stdout.writeln(_failures == 0 ? 'All steps ran.' : '$_failures step(s) failed.');
  exit(_failures == 0 ? 0 : 1);
}
