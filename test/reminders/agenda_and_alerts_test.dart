import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/time/calendar_date.dart';
import 'package:study_reminder/features/reminders/domain/agenda.dart';
import 'package:study_reminder/features/reminders/domain/alert_planner.dart';
import 'package:study_reminder/features/reminders/domain/occurrence.dart';
import 'package:study_reminder/features/reminders/domain/recurrence.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location india;
  setUpAll(() {
    tzdata.initializeTimeZones();
    india = tz.getLocation('Asia/Kolkata');
    tz.setLocalLocation(india);
  });

  // Thursday 22 Oct 2026, 10:00 in India.
  DateTime nowIst() => tz.TZDateTime(india, 2026, 10, 22, 10);

  Reminder reminder(
    String id, {
    String anchor = '2026-10-22',
    int minute = 19 * 60,
    Recurrence recurrence = Recurrence.once,
    DeliveryTarget deliverTo = DeliveryTarget.everywhere,
    bool enabled = true,
    bool deleted = false,
  }) =>
      Reminder(
        id: id,
        title: 'R $id',
        createdAt: DateTime.utc(2026),
        deliverTo: deliverTo,
        enabled: enabled,
        deleted: deleted,
        schedule: ReminderSchedule(
          anchor: CalendarDate.parse(anchor),
          minuteOfDay: minute,
          timeZone: 'Asia/Kolkata',
          recurrence: recurrence,
        ),
      );

  group('buildAgenda', () {
    test('sorts today, keeps missed earlier items, groups upcoming days', () {
      final agenda = buildAgenda(
        reminders: [
          reminder('evening', minute: 19 * 60),
          reminder('morning', minute: 8 * 60),
          reminder('daily', minute: 7 * 60, recurrence: const Recurrence.daily()),
          reminder('nextweek', anchor: '2026-10-27'),
          reminder('far', anchor: '2026-12-25'),
        ],
        states: const {},
        now: nowIst(),
        here: india,
      );
      expect(agenda.todayDate, const CalendarDate(2026, 10, 22));
      expect(agenda.today.map((i) => i.reminder.id), ['daily', 'morning', 'evening']);
      expect(agenda.today.first.isMissed(nowIst()), isTrue);
      expect(agenda.today.last.isMissed(nowIst()), isFalse);
      // Daily shows on each of the next 14 days; the one-off on the 27th too.
      expect(agenda.upcoming.length, 14);
      final day27 = agenda.upcoming.firstWhere(
          (d) => d.date == const CalendarDate(2026, 10, 27));
      expect(day27.items.map((i) => i.reminder.id), ['daily', 'nextweek']);
      expect(agenda.upcoming.any((d) => d.items.any((i) => i.reminder.id == 'far')),
          isFalse);
    });

    test('unhandled one-offs from earlier days are overdue until done', () {
      final old = reminder('old', anchor: '2026-10-20');
      final done = reminder('done', anchor: '2026-10-19');
      final doneAt = done.schedule.at(done.schedule.anchor);
      final agenda = buildAgenda(
        reminders: [old, done, reminder('gone', anchor: '2026-10-18', deleted: true)],
        states: {
          occurrenceId('done', doneAt): OccurrenceState(
              reminderId: 'done', occurrenceAt: doneAt, status: OccurrenceStatus.done),
        },
        now: nowIst(),
        here: india,
      );
      expect(agenda.overdue.map((i) => i.reminder.id), ['old']);
    });

    test('done and snoozed states show on the item', () {
      final r = reminder('r', minute: 8 * 60);
      final at = r.schedule.at(r.schedule.anchor);
      final agenda = buildAgenda(
        reminders: [r],
        states: {
          occurrenceId('r', at): OccurrenceState(
            reminderId: 'r',
            occurrenceAt: at,
            status: OccurrenceStatus.snoozed,
            snoozeUntil: at.add(const Duration(hours: 3)),
          ),
        },
        now: nowIst(),
        here: india,
      );
      final item = agenda.today.single;
      expect(item.status, OccurrenceStatus.snoozed);
      expect(item.dueAt, at.add(const Duration(hours: 3)));
      expect(item.isMissed(nowIst()), isFalse);
      expect(agenda.openToday, 1);
    });

    test('items are shown in the viewing device zone', () {
      final london = tz.getLocation('Europe/London');
      final agenda = buildAgenda(
        reminders: [reminder('r', minute: 19 * 60)],
        states: const {},
        now: nowIst(),
        here: london,
      );
      // 19:00 IST = 14:30 in London (BST).
      expect(agenda.today.single.at.hour, 14);
      expect(agenda.today.single.at.minute, 30);
    });
  });

  group('planAlerts', () {
    test('only reminders meant for this device, soonest first', () {
      final alerts = planAlerts(
        reminders: [
          reminder('both', minute: 19 * 60),
          reminder('phone', minute: 12 * 60, deliverTo: DeliveryTarget.phone),
          reminder('laptop', minute: 11 * 60, deliverTo: DeliveryTarget.laptop),
          reminder('off', minute: 13 * 60, enabled: false),
          reminder('past', minute: 9 * 60),
        ],
        states: const {},
        now: nowIst(),
        device: DeviceKind.phone,
      );
      expect(alerts.map((a) => a.reminderId), ['phone', 'both']);
      expect(alerts.first.at, tz.TZDateTime(india, 2026, 10, 22, 12).toUtc());
    });

    test('done occurrences are skipped, snoozes ring at the snooze end', () {
      final r = reminder('d', minute: 8 * 60, recurrence: const Recurrence.daily());
      final today8 = r.schedule.at(const CalendarDate(2026, 10, 22));
      final tomorrow8 = r.schedule.at(const CalendarDate(2026, 10, 23));
      final snoozeEnd = nowIst().add(const Duration(minutes: 10));
      final alerts = planAlerts(
        reminders: [r],
        states: {
          occurrenceId('d', today8): OccurrenceState(
            reminderId: 'd',
            occurrenceAt: today8,
            status: OccurrenceStatus.snoozed,
            snoozeUntil: snoozeEnd,
          ),
          occurrenceId('d', tomorrow8): OccurrenceState(
            reminderId: 'd',
            occurrenceAt: tomorrow8,
            status: OccurrenceStatus.done,
          ),
        },
        now: nowIst(),
        device: DeviceKind.laptop,
        horizon: const Duration(days: 3),
      );
      expect(alerts.first.at, snoozeEnd.toUtc());
      expect(alerts.first.occurrenceAt, today8.toUtc());
      expect(alerts.map((a) => a.occurrenceAt),
          isNot(contains(tomorrow8.toUtc())));
      // Snooze, then the 24th and 25th (the 23rd is already done).
      expect(alerts.length, 3);
    });

    test('respects the limit and gives stable positive ids', () {
      final r = reminder('many', minute: 0, recurrence: const Recurrence.daily());
      final alerts = planAlerts(
        reminders: [r],
        states: const {},
        now: nowIst(),
        device: DeviceKind.phone,
        horizon: const Duration(days: 30),
        limit: 5,
      );
      expect(alerts.length, 5);
      final again = planAlerts(
        reminders: [r],
        states: const {},
        now: nowIst(),
        device: DeviceKind.phone,
        horizon: const Duration(days: 30),
        limit: 5,
      );
      expect(again.map((a) => a.notificationId), alerts.map((a) => a.notificationId));
      expect(alerts.every((a) => a.notificationId >= 0), isTrue);
      expect(alerts.map((a) => a.notificationId).toSet().length, 5);
    });
  });
}
