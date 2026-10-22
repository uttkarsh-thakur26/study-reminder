import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/reminder_providers.dart';
import '../domain/agenda.dart';
import '../domain/occurrence.dart';

/// Snooze lengths offered everywhere a reminder can be snoozed.
const snoozeChoices = <Duration>[
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 30),
  Duration(hours: 1),
];

String snoozeLabel(Duration d) =>
    d.inMinutes < 60 ? '${d.inMinutes} min' : '${d.inHours} h';

Future<void> toggleDone(WidgetRef ref, AgendaItem item) {
  final repo = ref.read(reminderRepositoryProvider);
  return item.isDone
      ? repo.reopen(item.reminder.id, item.at)
      : repo.markDone(item.reminder.id, item.at);
}

Future<void> snoozeItem(WidgetRef ref, AgendaItem item, Duration by) {
  // Snoozing a missed reminder counts from now, not from the old time.
  final base = DateTime.now();
  return ref
      .read(reminderRepositoryProvider)
      .snooze(item.reminder.id, item.at, base.add(by));
}

Future<void> skipItem(WidgetRef ref, AgendaItem item) =>
    ref.read(reminderRepositoryProvider).skip(item.reminder.id, item.at);

Future<void> deleteReminder(
  BuildContext context,
  WidgetRef ref,
  String reminderId,
  String title,
) async {
  final repo = ref.read(reminderRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  await repo.delete(reminderId);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Deleted "$title"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.restore(reminderId),
        ),
      ),
    );
}

String statusLabel(
  AgendaItem item,
  DateTime now,
  String Function(DateTime) time,
) {
  switch (item.status) {
    case OccurrenceStatus.done:
      return 'Done';
    case OccurrenceStatus.skipped:
      return 'Skipped';
    case OccurrenceStatus.snoozed:
      if (item.snoozeUntil != null && item.snoozeUntil!.isAfter(now)) {
        return 'Snoozed to ${time(item.snoozeUntil!.toLocal())}';
      }
      return 'Missed';
    case OccurrenceStatus.pending:
      return item.isMissed(now) ? 'Missed' : '';
  }
}
