import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/formatters.dart';
import '../../reminders/application/reminder_providers.dart';
import '../application/alert_providers.dart';
import '../domain/alert_sync.dart';

/// Full-screen page for a ringing alarm, shown over the lock screen.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key, required this.payload});

  final AlertPayload payload;

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  bool _busy = false;

  Future<void> _finish(String? action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    await ref.read(localNotificationsProvider)?.dismiss(widget.payload);
    if (action != null) {
      await ref.read(alertServiceProvider).handleAction(action, widget.payload);
    }
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.payload;
    final reminders = ref.watch(remindersProvider).value ?? const [];
    final reminder = reminders.where((r) => r.id == p.reminderId).firstOrNull;
    final subject = reminder?.subjectId == null
        ? null
        : ref.watch(subjectsByIdProvider)[reminder!.subjectId];
    final now = ref.watch(minuteTickProvider).value ?? DateTime.now();

    final title = p.isTest ? 'Test alarm' : reminder?.title ?? 'Reminder';
    final detail = [
      ?subject?.name,
      if (reminder != null && reminder.notes.trim().isNotEmpty)
        reminder.notes.trim(),
    ].join(' · ');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(null);
      },
      child: Scaffold(
        backgroundColor: scheme.primaryContainer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              children: [
                const Spacer(),
                Icon(
                  Icons.alarm_rounded,
                  size: 48,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(height: Gap.l),
                Text(
                  formatTime(context, now),
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: Gap.l),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: Gap.s),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const Spacer(flex: 2),
                if (!p.isTest) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _finish(AlertActions.done),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Done'),
                    ),
                  ),
                  const SizedBox(height: Gap.m),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _finish(AlertActions.snooze),
                      icon: const Icon(Icons.snooze_rounded),
                      label: const Text('Snooze 10 min'),
                    ),
                  ),
                  const SizedBox(height: Gap.s),
                ],
                TextButton(
                  onPressed: _busy ? null : () => _finish(null),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimaryContainer,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Stop ringing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
