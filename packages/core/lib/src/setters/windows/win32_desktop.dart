import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../platform/windows_registry.dart';
import '../wallpaper_setter.dart';
import 'lock_screen.dart';
import 'windows_setter.dart';

/// `EnumDisplayDevices` flag: report monitors by device interface path, the
/// same ids `IDesktopWallpaper` uses.
const _eddGetDeviceInterfaceName = 0x00000001;

/// The real Windows calls behind [WindowsSetter]. Each runs in its own short
/// isolate (so a slow wallpaper change never stalls the UI), which sets up
/// COM and per-monitor DPI awareness for itself.
class Win32Desktop implements WindowsDesktop {
  const Win32Desktop({this.lockScreen = const LockScreenSetter()});

  final LockScreenSetter lockScreen;

  @override
  Future<List<WindowsMonitor>?> monitors() => Isolate.run(_monitors);

  @override
  Future<void> setWallpapers(Map<String, String> imageByMonitor, WindowsPosition position) {
    final images = Map<String, String>.of(imageByMonitor);
    final value = position.value;
    return Isolate.run(
      () => _withDesktopWallpaper((wallpaper) {
        using((arena) {
          wallpaper.setPosition(DESKTOP_WALLPAPER_POSITION(value));
          for (final MapEntry(key: monitor, value: image) in images.entries) {
            wallpaper.setWallpaper(arena.pcwstr(monitor), arena.pcwstr(image));
          }
        });
      }),
    );
  }

  @override
  Future<void> setEverywhere(String image, WindowsPosition position) {
    final value = position.value;
    return Isolate.run(
      () => _withDesktopWallpaper((wallpaper) {
        using((arena) {
          wallpaper.setPosition(DESKTOP_WALLPAPER_POSITION(value));
          // A null monitor id means every monitor.
          wallpaper.setWallpaper(PCWSTR(nullptr), arena.pcwstr(image));
        });
      }),
    );
  }

  @override
  Future<void> setClassic(String image, WindowsPosition position) {
    final value = position.value;
    return Isolate.run(() => _setClassic(image, value));
  }

  @override
  Future<void> setLockScreen(String image) => lockScreen.set(image);

  /// Reads back what a monitor shows (for the smoke test).
  Future<String?> wallpaperOf(String monitorPath) => Isolate.run(
    () => _withDesktopWallpaper((wallpaper) => using((arena) {
      final path = wallpaper.getWallpaper(arena.pcwstr(monitorPath));
      try {
        return path.toDartString();
      } finally {
        CoTaskMemFree(path);
      }
    })),
  );

  static List<WindowsMonitor>? _monitors() {
    try {
      return _withDesktopWallpaper((wallpaper) {
        final names = _displayNames();
        final count = wallpaper.getMonitorDevicePathCount();
        final monitors = <WindowsMonitor>[];
        for (var i = 0; i < count; i++) {
          final idPointer = wallpaper.getMonitorDevicePathAt(i);
          final id = idPointer.toDartString();
          CoTaskMemFree(idPointer);
          final Pointer<RECT> rect;
          try {
            rect = using((arena) => wallpaper.getMonitorRECT(arena.pcwstr(id)));
          } on WindowsException {
            continue; // listed but not attached (e.g. switched off)
          }
          final r = rect.ref;
          monitors.add(
            WindowsMonitor(
              path: id,
              displayName: names[id.toLowerCase()],
              left: r.left,
              top: r.top,
              width: r.right - r.left,
              height: r.bottom - r.top,
              // The primary monitor sits at the desktop's origin.
              primary: r.left == 0 && r.top == 0,
            ),
          );
          free(rect);
        }
        return monitors;
      });
    } on WindowsException {
      return null;
    }
  }

  /// Device interface path (lower case) -> `DISPLAY1`, `DISPLAY2`...
  static Map<String, String> _displayNames() => using((arena) {
    final names = <String, String>{};
    final adapter = arena<DISPLAY_DEVICE>();
    final monitor = arena<DISPLAY_DEVICE>();
    for (var i = 0; ; i++) {
      adapter.ref.cb = sizeOf<DISPLAY_DEVICE>();
      if (!EnumDisplayDevices(null, i, adapter, 0)) break;
      final adapterName = adapter.ref.DeviceName; // \\.\DISPLAY1
      final short = adapterName.replaceFirst(r'\\.\', '');
      for (var j = 0; ; j++) {
        monitor.ref.cb = sizeOf<DISPLAY_DEVICE>();
        if (!EnumDisplayDevices(arena.pcwstr(adapterName), j, monitor, _eddGetDeviceInterfaceName)) break;
        final id = monitor.ref.DeviceID;
        if (id.isNotEmpty) names[id.toLowerCase()] = short;
      }
    }
    return names;
  });

  /// `SystemParametersInfo` plus the registry values it reads the fit from.
  static void _setClassic(String image, int position) {
    const desktop = r'Control Panel\Desktop';
    // WallpaperStyle / TileWallpaper for each DESKTOP_WALLPAPER_POSITION.
    final (style, tile) = switch (position) {
      0 => ('0', '0'), // centre
      1 => ('0', '1'), // tile
      2 => ('2', '0'), // stretch
      3 => ('6', '0'), // fit
      5 => ('22', '0'), // span
      _ => ('10', '0'), // fill
    };
    UserRegistry.writeString(desktop, 'WallpaperStyle', style);
    UserRegistry.writeString(desktop, 'TileWallpaper', tile);
    using((arena) {
      final result = SystemParametersInfo(
        SPI_SETDESKWALLPAPER,
        0,
        arena.pcwstr(image),
        SYSTEM_PARAMETERS_INFO_UPDATE_FLAGS(SPIF_UPDATEINIFILE | SPIF_SENDCHANGE),
      );
      if (!result.value) {
        throw WallpaperSetterException("Windows didn't accept the wallpaper (${result.error.toHRESULT()}).");
      }
    });
  }

  /// Runs [body] with a fresh `IDesktopWallpaper`, COM initialised on this
  /// thread and physical-pixel coordinates.
  static T _withDesktopWallpaper<T>(T Function(IDesktopWallpaper wallpaper) body) {
    final previousDpi = SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    final hr = CoInitializeEx(COINIT(COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE));
    // S_FALSE: already initialised the same way. RPC_E_CHANGED_MODE: this
    // thread uses another model; COM works either way, but only a successful
    // call of ours is balanced by CoUninitialize.
    final ours = hr.isOk;
    if (hr.isError && hr != RPC_E_CHANGED_MODE) throw WindowsException(hr);
    try {
      final wallpaper = createInstance<IDesktopWallpaper>(DesktopWallpaper);
      try {
        return body(wallpaper);
      } finally {
        wallpaper.release();
      }
    } finally {
      if (ours) CoUninitialize();
      if (previousDpi != DPI_AWARENESS_CONTEXT(nullptr)) SetThreadDpiAwarenessContext(previousDpi);
    }
  }

  /// `Pictures`, following OneDrive or a moved folder.
  static String? picturesFolder() {
    if (!Platform.isWindows) return null;
    try {
      return using((arena) {
        final path = SHGetKnownFolderPath(FOLDERID_Pictures.toNative(allocator: arena), KF_FLAG_DEFAULT, null);
        try {
          return path.toDartString();
        } finally {
          CoTaskMemFree(path);
        }
      });
    } on WindowsException {
      return null;
    }
  }
}
