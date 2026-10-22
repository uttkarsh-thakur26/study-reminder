import 'package:drift/drift.dart' show Variable;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../core/db/app_database.dart';
import '../core/sync/hlc.dart';
import '../core/time/device_zone.dart';
import '../features/settings/settings_controller.dart';

/// The database, this device's identity and its clock.
///
/// Opened the same way by the app and by notification actions that run in a
/// background isolate, so both write with a clock that never goes backwards.
class CoreServices {
  CoreServices._(this.db, this.deviceId, this.clock, this.timeZone);

  final AppDatabase db;
  final String deviceId;
  final HlcClock clock;

  /// IANA name of the device time zone, e.g. `Asia/Kolkata`.
  final String timeZone;

  static Future<CoreServices> open() async {
    tzdata.initializeTimeZones();
    final zone = await readDeviceTimeZone();
    tz.setLocalLocation(tz.getLocation(zone));

    final db = AppDatabase();
    var deviceId = await db.readSetting(SettingKeys.deviceId);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await db.writeSetting(SettingKeys.deviceId, deviceId);
    }

    final clock = HlcClock(
      deviceId.replaceAll('-', '').substring(0, 12),
      last: await _latestStamp(db),
    );
    return CoreServices._(db, deviceId, clock, zone);
  }
}

/// The newest stamp already written on this device, so the clock never
/// issues an older one even if the system clock was moved back.
Future<Hlc?> _latestStamp(AppDatabase db) async {
  final row = await db
      .customSelect(
        'SELECT MAX(h) AS h FROM ('
        'SELECT MAX(hlc) AS h FROM reminders UNION ALL '
        'SELECT MAX(hlc) FROM subjects UNION ALL '
        'SELECT MAX(hlc) FROM occurrences UNION ALL '
        'SELECT MAX(hlc) FROM focus_sessions)',
        variables: const <Variable<Object>>[],
      )
      .getSingleOrNull();
  final packed = row?.read<String?>('h');
  if (packed == null || packed.isEmpty) return null;
  try {
    return Hlc.parse(packed);
  } on FormatException {
    return null;
  }
}
