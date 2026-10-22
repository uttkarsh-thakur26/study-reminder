import 'dart:convert';

import '../../reminders/domain/alert_planner.dart';
import '../../reminders/domain/occurrence.dart';
import '../../reminders/domain/reminder.dart';

/// Ids of the buttons on a reminder notification.
abstract final class AlertActions {
  static const done = 'done';
  static const snooze = 'snooze';
  static const stop = 'stop';
}

/// What a scheduled notification carries, so a tap or an action button knows
/// which occurrence it belongs to, and a replan can tell whether it changed.
class AlertPayload {
  const AlertPayload({
    required this.reminderId,
    required this.occurrenceAt,
    required this.style,
    required this.signature,
    DateTime? ringsAt,
  }) : ringsAt = ringsAt ?? occurrenceAt;

  factory AlertPayload.of(PlannedAlert alert) => AlertPayload(
    reminderId: alert.reminderId,
    occurrenceAt: alert.occurrenceAt,
    style: alert.style,
    signature: signatureOf(alert),
    ringsAt: alert.at,
  );

  /// Marks the sample from Settings, which has no reminder behind it.
  static const testReminderId = '_test';

  final String reminderId;
  final DateTime occurrenceAt;
  final ReminderStyle style;

  /// When it rings: the occurrence time, or later after a snooze.
  final DateTime ringsAt;

  bool get isTest => reminderId == testReminderId;

  /// Fingerprint of everything the notification shows and when it rings.
  final String signature;

  String get occurrenceKey => occurrenceId(reminderId, occurrenceAt);

  String encode() => jsonEncode({
    'r': reminderId,
    'o': occurrenceAt.toUtc().millisecondsSinceEpoch,
    's': style.name,
    'k': signature,
    't': ringsAt.toUtc().millisecondsSinceEpoch,
  });

  /// Null for anything this app did not write, such as a test notification.
  static AlertPayload? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final map = jsonDecode(text) as Map<String, Object?>;
      DateTime? utc(Object? ms) => ms == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
      return AlertPayload(
        reminderId: map['r']! as String,
        occurrenceAt: utc(map['o'])!,
        style: ReminderStyle.values.byName(map['s']! as String),
        signature: map['k']! as String,
        ringsAt: utc(map['t']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// A notification the operating system currently has queued.
class ScheduledAlert {
  const ScheduledAlert(this.id, this.payload);

  final int id;
  final AlertPayload? payload;
}

class AlertDiff {
  const AlertDiff({
    required this.toSchedule,
    required this.toCancel,
    this.missed = 0,
  });

  final List<PlannedAlert> toSchedule;
  final List<int> toCancel;

  /// Queued alerts that should have rung long ago. The system dropped them,
  /// which means it may have dropped the rest of the queue too.
  final int missed;

  bool get isEmpty => toSchedule.isEmpty && toCancel.isEmpty;
}

/// How long after its time an alert may still arrive. Android can hold back
/// an inexact alarm for up to an hour.
const deliveryGrace = Duration(minutes: 70);

/// The smallest set of calls that turns [scheduled] into [desired].
///
/// Scheduling an id that is already queued replaces it, so a changed alert
/// only needs a schedule call, never a cancel first. Alerts that ring before
/// [reissueBefore] are queued again even when they look in step, for when the
/// queue the system reports may not match what it will actually ring.
///
/// An alert whose time has passed is left for the system to deliver and
/// clear, unless it is more than [deliveryGrace] overdue.
AlertDiff diffAlerts({
  required List<PlannedAlert> desired,
  required List<ScheduledAlert> scheduled,
  required DateTime now,
  DateTime? reissueBefore,
}) {
  final queued = {for (final s in scheduled) s.id: s.payload};
  final wanted = <int, PlannedAlert>{};
  for (final a in desired) {
    wanted.putIfAbsent(a.notificationId, () => a); // soonest wins a collision
  }
  final overdue = [
    for (final MapEntry(key: id, value: p) in queued.entries)
      if (p != null && p.ringsAt.isBefore(now.subtract(deliveryGrace))) id,
  ];
  return AlertDiff(
    toSchedule: [
      for (final a in wanted.values)
        if ((reissueBefore != null && a.at.isBefore(reissueBefore)) ||
            queued[a.notificationId]?.signature != signatureOf(a))
          a,
    ],
    toCancel: [
      for (final MapEntry(key: id, value: p) in queued.entries)
        if (!wanted.containsKey(id) &&
            (p == null || p.ringsAt.isAfter(now) || overdue.contains(id)))
          id,
    ],
    missed: overdue.length,
  );
}

/// Changes whenever the ring time, the text or the style changes.
String signatureOf(PlannedAlert a) {
  final text =
      '${a.at.toUtc().millisecondsSinceEpoch}|${a.style.name}|'
      '${a.title}|${a.body}';
  return notificationIdFor(text).toRadixString(36);
}
