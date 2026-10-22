import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../core/db/app_database.dart';
import '../core/sync/hlc.dart';
import '../features/settings/settings_controller.dart';
import 'providers.dart';

/// Everything the app needs before the first frame: time zones, the
/// database, this device's identity and the saved appearance settings.
Future<List<Override>> bootstrap() async {
  tzdata.initializeTimeZones();
  final zone = await _deviceTimeZone();
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
  final settings = await AppSettings.load(db);

  return [
    databaseProvider.overrideWithValue(db),
    deviceIdProvider.overrideWithValue(deviceId),
    hlcClockProvider.overrideWithValue(clock),
    deviceTimeZoneProvider.overrideWithValue(zone),
    initialSettingsProvider.overrideWithValue(settings),
  ];
}

Future<String> _deviceTimeZone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.getLocation(info.identifier); // throws for names the database lacks
    return info.identifier;
  } catch (_) {
    return 'UTC';
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
        'SELECT MAX(hlc) FROM occurrences)',
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
