import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app/core_services.dart';
import '../../home_widget/application/home_widget_refresh.dart';
import '../../reminders/domain/reminder.dart';
import '../data/local_notifications.dart';
import '../domain/alert_sync.dart';
import 'alert_service.dart';

/// Runs Done and Snooze from the notification shade without opening the app.
///
/// Android starts a background isolate for this, so it opens its own
/// connection to the shared database and replans alerts itself.
@pragma('vm:entry-point')
Future<void> onBackgroundAlertAction(NotificationResponse response) async {
  final (:payload, :action) = readResponse(
    payload: response.payload,
    actionId: response.actionId,
  );
  if (payload == null || payload.isTest || action == null) return;

  final core = await CoreServices.open();
  try {
    final scheduler = LocalNotificationsScheduler();
    await scheduler.initialize(onBackgroundAction: onBackgroundAlertAction);
    await AlertService(
      db: core.db,
      clock: core.clock,
      scheduler: scheduler,
      device: DeviceKind.phone,
    ).handleAction(action, payload);
    // A snoozed reminder moves on the home screen widget too.
    await refreshHomeWidget(core);
  } finally {
    await core.db.close();
  }
}
