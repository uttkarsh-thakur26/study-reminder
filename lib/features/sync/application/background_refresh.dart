import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../../app/core_services.dart';
import '../../alerts/application/alert_service.dart';
import '../../alerts/application/background_actions.dart';
import '../../alerts/data/local_notifications.dart';
import '../../focus/data/android_focus_enforcer.dart';
import '../../focus/data/focus_repository.dart';
import '../../home_widget/application/home_widget_refresh.dart';

import 'package:focus_guard/focus_guard.dart';

import '../../reminders/domain/reminder.dart';
import '../data/supabase_sync_api.dart';
import '../data/sync_api.dart';
import '../data/sync_config.dart';
import 'sync_service.dart';

const _task = 'refresh';

/// Android only: every 15 minutes or so, even when the app is closed, sync
/// with the other devices and roll the two-week alarm window forward.
Future<void> scheduleBackgroundRefresh() async {
  await Workmanager().initialize(backgroundRefresh);
  await Workmanager().registerPeriodicTask(
    'study-reminder-refresh',
    _task,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

@pragma('vm:entry-point')
void backgroundRefresh() {
  Workmanager().executeTask((task, input) async {
    final core = await CoreServices.open();
    try {
      if (SyncConfig.isSet) {
        final api = SupabaseSyncApi(
          url: SyncConfig.url,
          publicKey: SyncConfig.publicKey,
        );
        try {
          await SyncService(
            db: core.db,
            clock: core.clock,
            api: api,
            isPhone: true,
            // The app registers the real name; a background run keeps it.
            deviceName: switch (await core.db.readSetting(
              SyncKeys.registeredName,
            )) {
              final String name when name.isNotEmpty => name,
              _ => 'Phone',
            },
            pushToken: const FocusGuard().pushToken,
          ).sync();
        } on SyncUnavailable {
          // Offline: alarms still get topped up below.
        } on Object catch (e) {
          debugPrint('background sync failed: $e');
        } finally {
          await api.close();
        }
      }
      // Picks up a session started on another device when push is not set
      // up or a message was missed.
      try {
        final focus = FocusRepository(core.db, core.clock);
        await focus.adoptLegacy();
        await AndroidFocusEnforcer().apply(
          (await focus.current()).phone,
          await focus.prefs(),
        );
      } on Object catch (e) {
        debugPrint('background focus check failed: $e');
      }
      final scheduler = LocalNotificationsScheduler();
      await scheduler.initialize(onBackgroundAction: onBackgroundAlertAction);
      await AlertService(
        db: core.db,
        clock: core.clock,
        scheduler: scheduler,
        device: DeviceKind.phone,
      ).replan();
    } finally {
      // Also after a failed run, so the widget shows what is synced.
      await refreshHomeWidget(core);
      await core.db.close();
    }
    return true;
  });
}
