import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../reminders/domain/alert_planner.dart';
import '../../reminders/domain/reminder.dart';
import '../../subjects/data/subject_repository.dart';
import '../data/alert_scheduler.dart';
import '../domain/alert_sync.dart';

const defaultSnooze = Duration(minutes: 10);

/// Keeps the operating system's queue in step with the reminders, and applies
/// the Done and Snooze buttons.
class AlertService {
  AlertService({
    required AppDatabase db,
    required HlcClock clock,
    required this.scheduler,
    required this.device,
    this.horizon = const Duration(days: 14),
    this.limit = 128,
    DateTime Function()? now,
  }) : _reminders = ReminderRepository(db, clock),
       _subjects = SubjectRepository(db, clock),
       _now = now ?? DateTime.now;

  final AlertScheduler scheduler;
  final DeviceKind device;

  /// How far ahead to queue alerts. The window rolls forward on every launch,
  /// resume, edit and notification action.
  final Duration horizon;

  /// Stays well under Android's 500 alarm cap and keeps each replan quick.
  final int limit;

  final ReminderRepository _reminders;
  final SubjectRepository _subjects;
  final DateTime Function() _now;

  Future<void> _last = Future.value();

  /// Brings the queue up to date. Calls never overlap; each waits for the one
  /// before, so the last call always sees the latest data.
  Future<AlertDiff> replan() {
    final run = _last.then((_) => _replan());
    _last = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<AlertDiff> _replan() async {
    final reminders = await _reminders.watchAll().first;
    final states = await _reminders.watchOccurrences().first;
    final subjects = await _subjects.watchAll().first;

    final desired = planAlerts(
      reminders: reminders,
      states: states,
      now: _now(),
      device: device,
      subjectNames: {for (final s in subjects) s.id: s.name},
      horizon: horizon,
      limit: limit,
    );
    final diff = diffAlerts(
      desired: desired,
      scheduled: await scheduler.pending(),
    );

    // One bad alert must not stop the rest from being queued.
    for (final id in diff.toCancel) {
      await _guard(() => scheduler.cancel(id));
    }
    for (final alert in diff.toSchedule) {
      await _guard(() => scheduler.schedule(alert));
    }
    return diff;
  }

  /// Applies a notification button, then replans so a snooze rings again.
  Future<void> handleAction(String actionId, AlertPayload payload) async {
    switch (actionId) {
      case AlertActions.done:
        await _reminders.markDone(payload.reminderId, payload.occurrenceAt);
      case AlertActions.snooze:
        await _reminders.snooze(
          payload.reminderId,
          payload.occurrenceAt,
          _now().add(defaultSnooze),
        );
      default:
        return;
    }
    await replan();
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      debugPrint('alert update failed: $e\n$st');
    }
  }
}
