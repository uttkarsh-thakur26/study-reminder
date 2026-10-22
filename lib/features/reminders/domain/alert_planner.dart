import 'occurrence.dart';
import 'reminder.dart';

/// A notification or alarm the device should raise at [at].
class PlannedAlert {
  const PlannedAlert({
    required this.notificationId,
    required this.occurrenceId,
    required this.reminderId,
    required this.occurrenceAt,
    required this.at,
    required this.title,
    required this.body,
    required this.style,
  });

  /// Stable 31-bit id, so rescheduling replaces rather than duplicates.
  final int notificationId;
  final String occurrenceId;
  final String reminderId;

  /// The scheduled occurrence this alert belongs to.
  final DateTime occurrenceAt;

  /// When to ring: the occurrence, or the end of a snooze.
  final DateTime at;
  final String title;
  final String body;
  final ReminderStyle style;

  @override
  bool operator ==(Object other) =>
      other is PlannedAlert &&
      other.notificationId == notificationId &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.style == style;

  @override
  int get hashCode => Object.hash(notificationId, at, title, body, style);
}

/// Works out which alerts this device should have scheduled right now.
///
/// Covers [horizon] ahead and at most [limit] alerts, soonest first. The app
/// replans on every change and on launch, so the window keeps rolling.
List<PlannedAlert> planAlerts({
  required Iterable<Reminder> reminders,
  required Map<String, OccurrenceState> states,
  required DateTime now,
  required DeviceKind device,
  Map<String, String> subjectNames = const {},
  Duration horizon = const Duration(days: 7),
  int limit = 200,
}) {
  final end = now.add(horizon);
  final alerts = <PlannedAlert>[];

  for (final r in reminders) {
    if (r.deleted || !r.enabled || !device.receives(r.deliverTo)) continue;
    final subject = r.subjectId == null ? null : subjectNames[r.subjectId];
    final body = [
      ?subject,
      if (r.notes.trim().isNotEmpty) r.notes.trim(),
    ].join(' · ');

    PlannedAlert alert(DateTime occurrence, DateTime at) {
      final id = occurrenceId(r.id, occurrence);
      return PlannedAlert(
        notificationId: notificationIdFor(id),
        occurrenceId: id,
        reminderId: r.id,
        occurrenceAt: occurrence.toUtc(),
        at: at.toUtc(),
        title: r.title,
        body: body,
        style: r.style,
      );
    }

    // Snoozed occurrences ring again at the end of the snooze, even when the
    // original time is long past.
    for (final s in states.values) {
      if (s.reminderId != r.id || s.deleted) continue;
      if (s.status != OccurrenceStatus.snoozed || s.snoozeUntil == null) {
        continue;
      }
      if (s.snoozeUntil!.isAfter(now) && s.snoozeUntil!.isBefore(end)) {
        alerts.add(alert(s.occurrenceAt, s.snoozeUntil!));
      }
    }

    for (final t in r.schedule.occurrencesAfter(now)) {
      if (!t.isBefore(end)) break;
      final state = states[occurrenceId(r.id, t)];
      if (state != null &&
          !state.deleted &&
          state.status != OccurrenceStatus.pending) {
        continue; // done, skipped, or snoozed (handled above)
      }
      alerts.add(alert(t, t));
    }
  }

  alerts.sort((a, b) => a.at.compareTo(b.at));
  return alerts.length > limit ? alerts.sublist(0, limit) : alerts;
}

/// FNV-1a hash of the occurrence id, folded to a positive 31-bit int as the
/// Android and Windows notification APIs expect.
int notificationIdFor(String occurrenceId) {
  var hash = 0x811c9dc5;
  for (final unit in occurrenceId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
