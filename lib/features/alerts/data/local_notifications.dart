import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../reminders/domain/alert_planner.dart';
import '../../reminders/domain/reminder.dart';
import '../domain/alert_sync.dart';
import 'alert_scheduler.dart';

/// Notifications and alarms on Android and Windows, through
/// flutter_local_notifications.
class LocalNotificationsScheduler implements AlertScheduler {
  LocalNotificationsScheduler([FlutterLocalNotificationsPlugin? plugin])
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin plugin;

  final _taps = StreamController<NotificationResponse>.broadcast();

  /// Taps on a notification (and full-screen alarms) while the app runs.
  Stream<NotificationResponse> get taps => _taps.stream;

  AndroidFlutterLocalNotificationsPlugin? get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Must run before anything else on the plugin. [onBackgroundAction] has to
  /// be a top-level function marked `@pragma('vm:entry-point')`.
  Future<void> initialize({
    required DidReceiveBackgroundNotificationResponseCallback
    onBackgroundAction,
  }) async {
    await plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_reminder'),
        windows: defaultTargetPlatform == TargetPlatform.windows
            ? _windowsSettings()
            : null,
      ),
      onDidReceiveNotificationResponse: _taps.add,
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );
  }

  /// The tap or full-screen alarm that started the app, if any.
  Future<NotificationResponse?> launchResponse() async {
    final details = await plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details!.notificationResponse
        : null;
  }

  @override
  Future<List<ScheduledAlert>> pending() async => [
    for (final r in await plugin.pendingNotificationRequests())
      ScheduledAlert(r.id, AlertPayload.decode(r.payload)),
  ];

  @override
  Future<void> schedule(PlannedAlert alert) async {
    final alarm = alert.style == ReminderStyle.alarm;
    final payload = AlertPayload.of(alert);
    Future<void> queue(AndroidScheduleMode mode) => plugin.zonedSchedule(
      id: alert.notificationId,
      title: alert.title,
      body: alert.body.isEmpty ? null : alert.body,
      scheduledDate: tz.TZDateTime.from(alert.at, tz.UTC),
      notificationDetails: NotificationDetails(
        android: alarm
            ? alarmDetails(alert.occurrenceAt)
            : reminderDetails(alert.occurrenceAt),
        windows: windowsDetails(payload),
      ),
      androidScheduleMode: mode,
      payload: payload.encode(),
    );

    // Not alarmClock, even for alarms: the plugin hands Android the ringing
    // broadcast as the "next alarm" entry, so a tap on that entry in quick
    // settings would ring the alarm there and then.
    try {
      await queue(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      // The exact alarm permission was revoked: ring late rather than never.
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      await queue(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  @override
  Future<void> cancel(int id) => plugin.cancel(id: id);

  @override
  Future<String> timing() async =>
      await android?.canScheduleExactNotifications() == false
      ? 'inexact'
      : 'exact';

  /// Shows a sample right away, so the user can check sound and style.
  Future<void> showTest({required ReminderStyle style}) {
    final now = DateTime.now();
    final payload = AlertPayload(
      reminderId: AlertPayload.testReminderId,
      occurrenceAt: now,
      style: style,
      signature: '',
    );
    final windows = defaultTargetPlatform == TargetPlatform.windows;
    return plugin.show(
      id: testNotificationId,
      title: style == ReminderStyle.alarm ? 'Test alarm' : 'Test reminder',
      body:
          'This is how reminders will look on this '
          '${windows ? 'laptop' : 'phone'}.',
      notificationDetails: NotificationDetails(
        android: style == ReminderStyle.alarm
            ? alarmDetails(now, actions: const [_stopAction])
            : reminderDetails(now, actions: const []),
        windows: windowsDetails(payload),
      ),
      payload: payload.encode(),
    );
  }

  /// A plain message with no buttons, such as the hint that the app keeps
  /// running in the tray.
  Future<void> showInfo({required String title, required String body}) =>
      plugin.show(
        id: infoNotificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          windows: WindowsNotificationDetails(),
        ),
      );

  /// Stops whatever is ringing for [payload] and clears it from the shade.
  Future<void> dismiss(AlertPayload payload) => plugin.cancel(
    id: payload.isTest
        ? testNotificationId
        : notificationIdFor(payload.occurrenceKey),
  );
}

const testNotificationId = 1;
const infoNotificationId = 2;

const _doneAction = AndroidNotificationAction(
  AlertActions.done,
  'Done',
  cancelNotification: true,
);
const _snoozeAction = AndroidNotificationAction(
  AlertActions.snooze,
  'Snooze 10 min',
  cancelNotification: true,
);
const _stopAction = AndroidNotificationAction(
  AlertActions.stop,
  'Stop',
  cancelNotification: true,
);

AndroidNotificationDetails reminderDetails(
  DateTime occurrenceAt, {
  List<AndroidNotificationAction> actions = const [_doneAction, _snoozeAction],
}) => AndroidNotificationDetails(
  'reminders',
  'Reminders',
  channelDescription: 'Study reminders at the time you set',
  importance: Importance.high,
  priority: Priority.high,
  category: AndroidNotificationCategory.reminder,
  visibility: NotificationVisibility.private,
  when: occurrenceAt.millisecondsSinceEpoch,
  actions: actions,
);

/// Rings like an alarm clock: alarm volume, repeating sound, full screen over
/// the lock screen. It stops on its own after ten minutes.
AndroidNotificationDetails alarmDetails(
  DateTime occurrenceAt, {
  List<AndroidNotificationAction> actions = const [_snoozeAction, _doneAction],
}) => AndroidNotificationDetails(
  'alarms',
  'Alarms',
  channelDescription: 'Reminders set to ring as an alarm',
  importance: Importance.max,
  priority: Priority.max,
  category: AndroidNotificationCategory.alarm,
  visibility: NotificationVisibility.public,
  fullScreenIntent: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
  sound: const UriAndroidNotificationSound(
    'content://settings/system/alarm_alert',
  ),
  additionalFlags: Int32List.fromList(const [_flagInsistent]),
  autoCancel: false,
  ongoing: true,
  timeoutAfter: alarmRingDuration.inMilliseconds,
  when: occurrenceAt.millisecondsSinceEpoch,
  actions: actions,
);

/// `Notification.FLAG_INSISTENT`: repeat the sound until the user responds.
const _flagInsistent = 4;

WindowsInitializationSettings _windowsSettings() =>
    WindowsInitializationSettings(
      appName: 'Study Reminder',
      appUserModelId: 'Uttkarsh.StudyReminder',
      // Fixed for good: Windows files the app's notifications under it.
      guid: '0a05c837-23e9-4a00-8d98-eb2a4c632f35',
      iconPath: [
        File(Platform.resolvedExecutable).parent.path,
        'data',
        'flutter_assets',
        'assets',
        'icons',
        'app_icon.png',
      ].join(Platform.pathSeparator),
    );

/// Windows hands back only the clicked button's text, so each button carries
/// the whole payload plus its action. Reminders and alarms stay on screen
/// until answered. The alarm scenario loops Windows' alarm sound by itself
/// (the plugin's "Alarm1" preset names a sound Windows does not have).
WindowsNotificationDetails windowsDetails(AlertPayload payload) {
  final alarm = payload.style == ReminderStyle.alarm;
  WindowsAction button(String label, String action) => WindowsAction(
    content: label,
    arguments: payload.withAction(action).encode(),
  );
  return WindowsNotificationDetails(
    scenario: alarm
        ? WindowsNotificationScenario.alarm
        : WindowsNotificationScenario.reminder,
    timestamp: payload.occurrenceAt,
    actions: payload.isTest
        ? [button(alarm ? 'Stop' : 'Got it', AlertActions.stop)]
        : [
            button('Snooze 10 min', AlertActions.snooze),
            button('Done', AlertActions.done),
          ],
  );
}
