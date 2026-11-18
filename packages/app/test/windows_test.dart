import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_fetcher/platform/autostart.dart';
import 'package:wallpaper_fetcher/platform/windows_appearance.dart';

void main() {
  test("Windows' accent colour is stored as 0xAABBGGRR", () {
    expect(windowsAccentColor(0xFFD77800), const Color(0xFF0078D7)); // the classic Windows blue
  });

  test('start on login runs the app hidden, quoted for paths with spaces', () {
    expect(
      Autostart.windowsCommand(r'C:\Program Files\Wallpaper Fetcher\wallpaper_fetcher.exe'),
      r'"C:\Program Files\Wallpaper Fetcher\wallpaper_fetcher.exe" --hidden',
    );
  });
}
