import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

/// Windows' accent colour (Settings → Personalisation → Colours), as the
/// desktop window manager keeps it in the registry.
Color? readWindowsAccent() {
  try {
    final abgr = UserRegistry.readDword(r'Software\Microsoft\Windows\DWM', 'AccentColor');
    return abgr == null ? null : windowsAccentColor(abgr);
  } on Object {
    return null;
  }
}

/// The registry holds 0xAABBGGRR.
Color windowsAccentColor(int abgr) =>
    Color.fromARGB(255, abgr & 0xFF, (abgr >> 8) & 0xFF, (abgr >> 16) & 0xFF);
