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
  }) : _db = db,
       _reminders = ReminderRepository(db, clock),
       _subjects = SubjectRepository(db, clock),
       _now = now ?? DateTime.now;

  final AlertScheduler scheduler;
  final DeviceKind device;

  /// How far ahead to queue alerts. The window rolls forward on every launch,
  /// resume, edit and notification action.
  final Duration horizon;

  /// Stays well under Android's 500 alarm cap and keeps each replan quick.
  final int limit;

  final AppDatabase _db;
  final ReminderRepository _reminders;
  final SubjectRepository _subjects;
  final DateTime Function() _now;

  Future<void> _last = Future.value();

  /// Brings the queue up to date. Calls never overlap; each waits for the one
  /// before, so the last call always sees the latest data.
  ///
  /// Android reports the queue from its own records, which outlive alarms
  /// the system drops (force stop, some battery savers). [verify] queues the
  /// next day again whatever the records say; it is meant for the first
  /// replan after the app starts. When the records show alerts that never
  /// rang, or the system's timing changed, everything is queued again.
  Future<AlertDiff> replan({bool verify = false}) {
    final run = _last.then((_) => _replan(verify: verify));
    _last = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  static const _timingKey = 'alert_timing';
  static const verifyWindow = Duration(days: 1);

  Future<AlertDiff> _replan({required bool verify}) async {
    final reminders = await _reminders.watchAll().first;
    final states = await _reminders.watchOccurrences().first;
    final subjects = await _subjects.watchAll().first;

    final now = _now();
    final desired = planAlerts(
      reminders: reminders,
      states: states,
      now: now,
      device: device,
      subjectNames: {for (final s in subjects) s.id: s.name},
      horizon: horizon,
      limit: limit,
    );
    final scheduled = await scheduler.pending();
    final timing = await scheduler.timing();
    final retimed = timing != await _db.readSetting(_timingKey);

    final everything = now.add(horizon * 2);
    var diff = diffAlerts(
      desired: desired,
      scheduled: scheduled,
      now: now,
      reissueBefore: retimed
          ? everything
          : verify
          ? now.add(verifyWindow)
          : null,
    );
    if (diff.missed > 0 && !retimed) {
      diff = diffAlerts(
        desired: desired,
        scheduled: scheduled,
        now: now,
        reissueBefore: everything,
      );
    }

    // One bad alert must not stop the rest from being queued.
    for (final id in diff.toCancel) {
      await _guard(() => scheduler.cancel(id));
    }
    for (final alert in diff.toSchedule) {
      await _guard(() => scheduler.schedule(alert));
    }
    if (retimed) await _db.writeSetting(_timingKey, timing);
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
