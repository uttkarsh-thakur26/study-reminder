import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/alerts/application/alert_providers.dart';
import '../features/alerts/application/background_actions.dart';
import '../features/alerts/data/local_notifications.dart';
import '../features/focus/application/focus_providers.dart';
import '../features/settings/settings_controller.dart';
import '../desktop/desktop_window.dart';
import '../desktop/start_with_windows.dart';
import '../features/sync/application/background_refresh.dart';
import '../features/sync/application/sync_providers.dart';
import '../features/sync/data/device_name.dart';
import '../features/sync/data/supabase_sync_api.dart';
import '../features/sync/data/sync_config.dart';
import 'core_services.dart';
import 'providers.dart';

/// Everything the app needs before the first frame: time zones, the
/// database, this device's identity, notifications and saved settings.
Future<List<Override>> bootstrap() async {
  final core = await CoreServices.open();
  final settings = await AppSettings.load(core.db);
  if (isWindowsApp) await setUpStartWithWindows(core.db);

  return [
    databaseProvider.overrideWithValue(core.db),
    deviceIdProvider.overrideWithValue(core.deviceId),
    hlcClockProvider.overrideWithValue(core.clock),
    initialTimeZoneProvider.overrideWithValue(core.timeZone),
    initialSettingsProvider.overrideWithValue(settings),
    ...await _notifications(),
    deviceNameProvider.overrideWithValue(await readDeviceName()),
    if (SyncConfig.isSet)
      syncApiProvider.overrideWithValue(
        SupabaseSyncApi(url: SyncConfig.url, publicKey: SyncConfig.publicKey),
      ),
    ...focusPlatformOverrides(),
    ...await _backgroundRefresh(),
  ];
}

/// Android: sync and top up alarms every 15 minutes, even when closed.
Future<List<Override>> _backgroundRefresh() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return [];
  try {
    await scheduleBackgroundRefresh();
  } catch (e) {
    debugPrint('background refresh unavailable: $e');
  }
  return [];
}

Future<List<Override>> _notifications() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.windows)) {
    return [];
  }
  try {
    final notifications = LocalNotificationsScheduler();
    await notifications.initialize(onBackgroundAction: onBackgroundAlertAction);
    return [
      localNotificationsProvider.overrideWithValue(notifications),
      launchResponseProvider.overrideWithValue(
        await notifications.launchResponse(),
      ),
    ];
  } catch (e) {
    // The app still works without alerts; Settings shows what is missing.
    debugPrint('notifications unavailable: $e');
    return [];
  }
}
