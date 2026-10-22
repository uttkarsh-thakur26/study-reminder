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
    this.action,
  });

  factory AlertPayload.of(PlannedAlert alert) => AlertPayload(
    reminderId: alert.reminderId,
    occurrenceAt: alert.occurrenceAt,
    style: alert.style,
    signature: signatureOf(alert),
  );

  /// Marks the sample from Settings, which has no reminder behind it.
  static const testReminderId = '_test';

  final String reminderId;
  final DateTime occurrenceAt;
  final ReminderStyle style;

  bool get isTest => reminderId == testReminderId;

  /// Fingerprint of everything the notification shows and when it rings.
  final String signature;

  /// Set on the copy carried by a button. Windows hands back only the
  /// clicked button's text, so the button has to carry the whole payload.
  final String? action;

  AlertPayload withAction(String action) => AlertPayload(
    reminderId: reminderId,
    occurrenceAt: occurrenceAt,
    style: style,
    signature: signature,
    action: action,
  );

  String get occurrenceKey => occurrenceId(reminderId, occurrenceAt);

  String encode() => jsonEncode({
    'r': reminderId,
    'o': occurrenceAt.toUtc().millisecondsSinceEpoch,
    's': style.name,
    'k': signature,
    'a': ?action,
  });

  /// Null for anything this app did not write, such as a test notification.
  static AlertPayload? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final map = jsonDecode(text) as Map<String, Object?>;
      return AlertPayload(
        reminderId: map['r']! as String,
        occurrenceAt: DateTime.fromMillisecondsSinceEpoch(
          map['o']! as int,
          isUtc: true,
        ),
        style: ReminderStyle.values.byName(map['s']! as String),
        signature: map['k']! as String,
        action: map['a'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// What a tap on a notification asks for: which occurrence, and which button
/// if any. Android reports the button id separately; on Windows it arrives
/// inside the payload and the reported "action" is the payload itself.
({AlertPayload? payload, String? action}) readResponse({
  required String? payload,
  required String? actionId,
}) {
  final p = AlertPayload.decode(payload);
  final action =
      p?.action ?? (actionId == null || actionId == payload ? null : actionId);
  return (payload: p, action: action);
}

/// A notification the operating system currently has queued.
class ScheduledAlert {
  const ScheduledAlert(this.id, this.payload);

  final int id;
  final AlertPayload? payload;
}

class AlertDiff {
  const AlertDiff({required this.toSchedule, required this.toCancel});

  final List<PlannedAlert> toSchedule;
  final List<int> toCancel;

  bool get isEmpty => toSchedule.isEmpty && toCancel.isEmpty;
}

/// The smallest set of calls that turns [scheduled] into [desired].
///
/// Scheduling an id that is already queued replaces it, so a changed alert
/// only needs a schedule call, never a cancel first.
AlertDiff diffAlerts({
  required List<PlannedAlert> desired,
  required List<ScheduledAlert> scheduled,
}) {
  final queued = {for (final s in scheduled) s.id: s.payload?.signature};
  final wanted = <int, PlannedAlert>{};
  for (final a in desired) {
    wanted.putIfAbsent(a.notificationId, () => a); // soonest wins a collision
  }
  return AlertDiff(
    toSchedule: [
      for (final a in wanted.values)
        if (queued[a.notificationId] != signatureOf(a)) a,
    ],
    toCancel: [
      for (final id in queued.keys)
        if (!wanted.containsKey(id)) id,
    ],
  );
}

/// Changes whenever the ring time, the text or the style changes.
String signatureOf(PlannedAlert a) {
  final text =
      '${a.at.toUtc().millisecondsSinceEpoch}|${a.style.name}|'
      '${a.title}|${a.body}';
  return notificationIdFor(text).toRadixString(36);
}
