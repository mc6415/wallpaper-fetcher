import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:wallpaper_fetcher/features/rotation/rotation_screen.dart';

void main() {
  test('interval labels', () {
    expect(intervalLabel(const Duration(minutes: 15)), '15 min');
    expect(intervalLabel(const Duration(hours: 1)), '1 hour');
    expect(intervalLabel(const Duration(hours: 6)), '6 hours');
    expect(intervalLabel(const Duration(days: 1)), 'Daily');
  });

  test('shortcut command uses the launcher\'s full path when it exists', () {
    final home = Directory.systemTemp.createTempSync('wf_home_');
    addTearDown(() => home.deleteSync(recursive: true));
    expect(shortcutCommand({'HOME': home.path, 'PATH': '/nonexistent'}), 'wallpaper-fetcher');
    final launcher = File(p.join(home.path, '.local', 'bin', 'wallpaper-fetcher'))..createSync(recursive: true);
    expect(shortcutCommand({'HOME': home.path, 'PATH': '/nonexistent'}), launcher.path);
  });
}
