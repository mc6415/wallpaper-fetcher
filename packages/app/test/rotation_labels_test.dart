import 'package:flutter_test/flutter_test.dart';
import 'package:wallpaper_fetcher/features/rotation/rotation_screen.dart';

void main() {
  test('interval labels', () {
    expect(intervalLabel(const Duration(minutes: 15)), '15 min');
    expect(intervalLabel(const Duration(hours: 1)), '1 hour');
    expect(intervalLabel(const Duration(hours: 6)), '6 hours');
    expect(intervalLabel(const Duration(days: 1)), 'Daily');
  });
}
