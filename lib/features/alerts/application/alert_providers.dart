import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/alert_scheduler.dart';
import '../data/local_notifications.dart';
import 'alert_service.dart';

/// Set at startup on platforms with notifications wired up (Android for now).
final localNotificationsProvider = Provider<LocalNotificationsScheduler?>(
  (ref) => null,
);

/// The notification tap or full-screen alarm that launched the app, if any.
final launchResponseProvider = Provider<NotificationResponse?>((ref) => null);

final alertSchedulerProvider = Provider<AlertScheduler>(
  (ref) => ref.watch(localNotificationsProvider) ?? const NoopAlertScheduler(),
);

final alertServiceProvider = Provider<AlertService>(
  (ref) => AlertService(
    db: ref.watch(databaseProvider),
    clock: ref.watch(hlcClockProvider),
    scheduler: ref.watch(alertSchedulerProvider),
    device: ref.watch(deviceKindProvider),
  ),
);

/// What the phone currently lets the app do. Null where it does not apply.
class AlertHealth {
  const AlertHealth({
    required this.notificationsEnabled,
    required this.exactAlarms,
  });

  final bool notificationsEnabled;

  /// Whether reminders can ring on the minute rather than a few minutes late.
  final bool exactAlarms;

  bool get allGood => notificationsEnabled && exactAlarms;
}

final alertHealthProvider = FutureProvider<AlertHealth?>((ref) async {
  final android = ref.watch(localNotificationsProvider)?.android;
  if (android == null) return null;
  return AlertHealth(
    notificationsEnabled: await android.areNotificationsEnabled() ?? false,
    exactAlarms: await android.canScheduleExactNotifications() ?? false,
  );
});
