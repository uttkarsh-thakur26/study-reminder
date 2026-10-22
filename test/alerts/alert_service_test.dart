import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/core/time/calendar_date.dart';
import 'package:study_reminder/features/alerts/application/alert_service.dart';
import 'package:study_reminder/features/alerts/data/alert_scheduler.dart';
import 'package:study_reminder/features/alerts/domain/alert_sync.dart';
import 'package:study_reminder/features/reminders/data/reminder_repository.dart';
import 'package:study_reminder/features/reminders/domain/alert_planner.dart';
import 'package:study_reminder/features/reminders/domain/occurrence.dart';
import 'package:study_reminder/features/reminders/domain/recurrence.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Stands in for the operating system's queue.
class FakeScheduler implements AlertScheduler {
  final queued = <int, PlannedAlert>{};
  var calls = 0;

  @override
  Future<List<ScheduledAlert>> pending() async => [
    for (final a in queued.values)
      ScheduledAlert(a.notificationId, AlertPayload.of(a)),
  ];

  @override
  Future<void> schedule(PlannedAlert alert) async {
    calls++;
    queued[alert.notificationId] = alert;
  }

  @override
  Future<void> cancel(int id) async {
    calls++;
    queued.remove(id);
  }
}

void main() {
  late AppDatabase db;
  late HlcClock clock;
  late FakeScheduler scheduler;
  late AlertService service;
  late ReminderRepository repo;
  // Thursday 22 Oct 2026, 10:00 in India.
  final now = DateTime.utc(2026, 10, 22, 4, 30);

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = HlcClock('test');
    scheduler = FakeScheduler();
    repo = ReminderRepository(db, clock);
    service = AlertService(
      db: db,
      clock: clock,
      scheduler: scheduler,
      device: DeviceKind.phone,
      now: () => now,
    );
  });
  tearDown(() => db.close());

  Reminder reminder({
    String id = 'r1',
    int minute = 19 * 60,
    Recurrence recurrence = Recurrence.once,
    DeliveryTarget deliverTo = DeliveryTarget.everywhere,
  }) => Reminder(
    id: id,
    title: 'Physics',
    createdAt: DateTime.utc(2026),
    deliverTo: deliverTo,
    schedule: ReminderSchedule(
      anchor: const CalendarDate(2026, 10, 22),
      minuteOfDay: minute,
      timeZone: 'Asia/Kolkata',
      recurrence: recurrence,
    ),
  );

  test(
    'queues upcoming alerts and does nothing when already in step',
    () async {
      await repo.save(reminder(recurrence: const Recurrence.daily()));
      final first = await service.replan();
      expect(first.toSchedule.length, 14); // two weeks of a daily reminder
      expect(scheduler.queued.length, 14);

      scheduler.calls = 0;
      final second = await service.replan();
      expect(second.isEmpty, isTrue);
      expect(scheduler.calls, 0);
    },
  );

  test('an edit replaces only what changed, a delete cancels', () async {
    await repo.save(reminder());
    await service.replan();
    final id = scheduler.queued.keys.single;

    await repo.save(reminder().copyWith(title: 'Physics revision'));
    final diff = await service.replan();
    expect(diff.toCancel, isEmpty);
    expect(diff.toSchedule.single.title, 'Physics revision');
    expect(scheduler.queued[id]!.title, 'Physics revision');

    await repo.delete('r1');
    await service.replan();
    expect(scheduler.queued, isEmpty);
  });

  test('reminders for the laptop only are not queued on the phone', () async {
    await repo.save(reminder(deliverTo: DeliveryTarget.laptop));
    await service.replan();
    expect(scheduler.queued, isEmpty);
  });

  test('Done cancels, Snooze queues the same occurrence again', () async {
    await repo.save(reminder());
    await service.replan();
    final alert = scheduler.queued.values.single;
    final payload = AlertPayload.of(alert);

    await service.handleAction(AlertActions.snooze, payload);
    final snoozed = scheduler.queued.values.single;
    expect(snoozed.notificationId, alert.notificationId);
    expect(snoozed.at, now.add(defaultSnooze));

    await service.handleAction(AlertActions.done, payload);
    expect(scheduler.queued, isEmpty);
    final states = await repo.watchOccurrences().first;
    expect(states[payload.occurrenceKey]!.status, OccurrenceStatus.done);
  });

  test('replans that overlap run one after the other', () async {
    await repo.save(reminder(recurrence: const Recurrence.daily()));
    await Future.wait([service.replan(), service.replan(), service.replan()]);
    expect(scheduler.queued.length, 14);
    expect(scheduler.calls, 14);
  });

  group('payload', () {
    test('round-trips and ignores foreign text', () {
      final p = AlertPayload(
        reminderId: 'r1',
        occurrenceAt: DateTime.utc(2026, 10, 22, 13, 30),
        style: ReminderStyle.alarm,
        signature: 'abc',
      );
      final back = AlertPayload.decode(p.encode())!;
      expect(back.reminderId, 'r1');
      expect(back.occurrenceAt, p.occurrenceAt);
      expect(back.style, ReminderStyle.alarm);
      expect(back.occurrenceKey, occurrenceId('r1', p.occurrenceAt));
      expect(AlertPayload.decode('not json'), isNull);
      expect(AlertPayload.decode(null), isNull);
    });
  });

  test('diff cancels alerts the plan no longer has', () {
    final keep = PlannedAlert(
      notificationId: 1,
      occurrenceId: 'a@1',
      reminderId: 'a',
      occurrenceAt: DateTime.utc(2026),
      at: DateTime.utc(2026),
      title: 'A',
      body: '',
      style: ReminderStyle.notification,
    );
    final diff = diffAlerts(
      desired: [keep],
      scheduled: [
        ScheduledAlert(1, AlertPayload.of(keep)),
        const ScheduledAlert(2, null),
      ],
    );
    expect(diff.toSchedule, isEmpty);
    expect(diff.toCancel, [2]);
  });
}
