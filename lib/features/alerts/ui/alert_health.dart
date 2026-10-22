import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../desktop/start_with_windows.dart';
import '../../reminders/domain/reminder.dart';
import '../application/alert_providers.dart';
import '../data/local_notifications.dart';

/// Asks for the notification permission on Today when it is missing.
class AlertPermissionBanner extends ConsumerWidget {
  const AlertPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(alertHealthProvider).value;
    if (health == null || health.notificationsEnabled) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.m),
      child: Card(
        color: scheme.tertiaryContainer,
        child: ListTile(
          leading: Icon(
            Icons.notifications_off_rounded,
            color: scheme.onTertiaryContainer,
          ),
          title: Text(
            'Notifications are off',
            style: TextStyle(color: scheme.onTertiaryContainer),
          ),
          subtitle: Text(
            'Turn them on so reminders can ring.',
            style: TextStyle(color: scheme.onTertiaryContainer),
          ),
          trailing: FilledButton(
            onPressed: () => _requestNotifications(ref),
            child: const Text('Allow'),
          ),
        ),
      ),
    );
  }
}

Future<void> _requestNotifications(WidgetRef ref) async {
  final android = ref.read(localNotificationsProvider)?.android;
  final granted = await android?.requestNotificationsPermission();
  // Once denied twice Android stops asking, so send the user to settings.
  if (granted == false) await android?.openAppNotificationSettings();
  ref.invalidate(alertHealthProvider);
}

/// Settings card: what the phone allows, with a fix for each gap, and test
/// buttons to hear a reminder and an alarm.
class AlertHealthCard extends ConsumerWidget {
  const AlertHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(localNotificationsProvider);
    if (notifications == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.notifications_paused_rounded),
          title: Text('Alerts on this device'),
          subtitle: Text('Not available here. Reminders still sync.'),
        ),
      );
    }
    final android = notifications.android;
    final tests = _TestButtons(notifications);
    if (android == null) {
      return Card(
        child: Column(
          children: [
            const _StartWithWindowsRow(),
            const Divider(indent: 56),
            const ListTile(
              leading: Icon(Icons.desktop_windows_rounded),
              title: Text('Rings from the tray'),
              subtitle: Text(
                'Closing the window keeps Study Reminder running, so '
                'reminders still ring. Quit from the tray icon menu.',
              ),
            ),
            const Divider(indent: 56),
            const ListTile(
              leading: Icon(Icons.do_not_disturb_on_outlined),
              title: Text('Do not disturb'),
              subtitle: Text(
                'Windows holds back reminders while Do not disturb is on. '
                'To let them through, add Study Reminder to the priority '
                'list in Settings > System > Notifications.',
              ),
            ),
            const Divider(indent: 56),
            tests,
          ],
        ),
      );
    }
    final health = ref.watch(alertHealthProvider).value;
    if (health == null) return const SizedBox.shrink();

    return Card(
      child: Column(
        children: [
          _CheckRow(
            ok: health.notificationsEnabled,
            title: 'Notifications',
            okText: 'Allowed',
            badText: 'Off. Reminders cannot ring.',
            fixLabel: 'Allow',
            onFix: () => _requestNotifications(ref),
          ),
          const Divider(indent: 56),
          _CheckRow(
            ok: health.exactAlarms,
            title: 'Exact timing',
            okText: 'Reminders ring on the minute',
            badText: 'Off. Reminders may ring a few minutes late.',
            fixLabel: 'Fix',
            onFix: () async {
              await android.requestExactAlarmsPermission();
              ref.invalidate(alertHealthProvider);
            },
          ),
          const Divider(indent: 56),
          ListTile(
            leading: const Icon(Icons.fullscreen_rounded),
            title: const Text('Full-screen alarms'),
            subtitle: const Text(
              'Alarms take over the lock screen. If yours only show a banner, '
              'allow this in settings.',
            ),
            trailing: TextButton(
              onPressed: () => android.requestFullScreenIntentPermission(),
              child: const Text('Open'),
            ),
          ),
          const Divider(indent: 56),
          tests,
        ],
      ),
    );
  }
}

class _StartWithWindowsRow extends ConsumerWidget {
  const _StartWithWindowsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(startWithWindowsProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.power_settings_new_rounded),
      title: const Text('Start with Windows'),
      subtitle: const Text(
        'Opens quietly in the tray when you sign in, so reminders ring.',
      ),
      value: enabled.value ?? false,
      onChanged: enabled.isLoading
          ? null
          : (on) => ref.read(startWithWindowsProvider.notifier).set(on),
    );
  }
}

/// Rings a sample reminder and alarm right away.
class _TestButtons extends StatelessWidget {
  const _TestButtons(this.notifications);

  final LocalNotificationsScheduler notifications;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Gap.l),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                notifications.showTest(style: ReminderStyle.notification),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Test reminder'),
          ),
        ),
        const SizedBox(width: Gap.m),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => notifications.showTest(style: ReminderStyle.alarm),
            icon: const Icon(Icons.alarm_rounded),
            label: const Text('Test alarm'),
          ),
        ),
      ],
    ),
  );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.ok,
    required this.title,
    required this.okText,
    required this.badText,
    required this.fixLabel,
    required this.onFix,
  });

  final bool ok;
  final String title;
  final String okText;
  final String badText;
  final String fixLabel;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle_rounded : Icons.error_rounded,
        color: ok ? scheme.primary : scheme.error,
      ),
      title: Text(title),
      subtitle: Text(ok ? okText : badText),
      trailing: ok
          ? null
          : FilledButton.tonal(onPressed: onFix, child: Text(fixLabel)),
    );
  }
}
