import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

/// IANA name of the system time zone. Needs the time zone database loaded.
///
/// When the system name is unknown (Windows reports `Etc/Unknown` for zones
/// it cannot map), picks a zone with the same offsets instead of UTC, so new
/// reminders are not saved hours off.
Future<String> readDeviceTimeZone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.getLocation(info.identifier); // throws for names the database lacks
    return info.identifier;
  } catch (_) {
    return zoneMatchingClock(DateTime.now());
  }
}

/// A zone whose offset now and in six months matches the local clock, which
/// also gets daylight saving right. Prefers one with the same abbreviation.
String zoneMatchingClock(DateTime now) {
  final later = now.add(const Duration(days: 182));
  String? sameOffsets;
  for (final location in tz.timeZoneDatabase.locations.values) {
    if (tz.TZDateTime.from(now, location).timeZoneOffset !=
            now.timeZoneOffset ||
        tz.TZDateTime.from(later, location).timeZoneOffset !=
            later.timeZoneOffset) {
      continue;
    }
    if (location.timeZone(now.millisecondsSinceEpoch).abbreviation ==
        now.timeZoneName) {
      return location.name;
    }
    sameOffsets ??= location.name;
  }
  return sameOffsets ?? 'UTC';
}
