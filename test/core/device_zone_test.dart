import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/time/device_zone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('the guessed zone keeps the clock\'s offsets now and in six months', () {
    final now = DateTime.now();
    final later = now.add(const Duration(days: 182));
    final zone = tz.getLocation(zoneMatchingClock(now));
    expect(tz.TZDateTime.from(now, zone).timeZoneOffset, now.timeZoneOffset);
    expect(
      tz.TZDateTime.from(later, zone).timeZoneOffset,
      later.timeZoneOffset,
    );
  });
}
