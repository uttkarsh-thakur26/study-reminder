import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/core/time/calendar_date.dart';
import 'package:study_reminder/features/alerts/application/alert_service.dart';
import 'package:study_reminder/features/alerts/data/alert_scheduler.dart';
import 'package:study_reminder/features/alerts/data/payload_tracking_scheduler.dart';
import 'package:study_reminder/features/alerts/domain/alert_sync.dart';
import 'package:study_reminder/features/reminders/data/reminder_repository.dart';
import 'package:study_reminder/features/reminders/domain/alert_planner.dart';
import 'package:study_reminder/features/reminders/domain/recurrence.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Behaves like the Windows queue: ids only, and queueing an id again keeps
/// the old copy too. Cancel removes one copy.
class WindowsLikeQueue implements AlertScheduler {
  final copies = <PlannedAlert>[];

  @override
  Future<String> timing() async => 'exact';

  @override
  Future<List<ScheduledAlert>> pending() async => [
    for (final a in copies) ScheduledAlert(a.notificationId, null),
  ];

  @override
  Future<void> schedule(PlannedAlert alert) async => copies.add(alert);

  @override
  Future<void> cancel(int id) async {
    final i = copies.indexWhere((a) => a.notificationId == id);
    if (i >= 0) copies.removeAt(i);
  }

  int countOf(int id) => copies.where((a) => a.notificationId == id).length;
}

void main() {
  late AppDatabase db;
  late WindowsLikeQueue queue;
  late AlertService service;
  late ReminderRepository repo;
  final now = DateTime.utc(2026, 10, 22, 4, 30);

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  AlertService serviceFor(AlertScheduler scheduler) => AlertService(
    db: db,
    clock: HlcClock('laptop'),
    scheduler: scheduler,
    device: DeviceKind.laptop,
    now: () => now,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queue = WindowsLikeQueue();
    repo = ReminderRepository(db, HlcClock('laptop'));
    service = serviceFor(PayloadTrackingScheduler(queue, db));
  });
  tearDown(() => db.close());

  Reminder reminder({String title = 'Physics'}) => Reminder(
    id: 'r1',
    title: title,
    createdAt: DateTime.utc(2026),
    schedule: const ReminderSchedule(
      anchor: CalendarDate(2026, 10, 22),
      minuteOfDay: 19 * 60,
      timeZone: 'Asia/Kolkata',
      recurrence: Recurrence.daily(),
    ),
  );

  group('Windows queue', () {
    test('replanning again queues nothing new', () async {
      await repo.save(reminder());
      await service.replan();
      expect(queue.copies.length, 14);

      final again = await service.replan();
      expect(again.isEmpty, isTrue);
      expect(queue.copies.length, 14);
    });

    test('an edit replaces the queued copy instead of adding one', () async {
      await repo.save(reminder());
      await service.replan();
      final id = queue.copies.first.notificationId;

      await repo.save(reminder(title: 'Physics revision'));
      await service.replan();
      expect(queue.countOf(id), 1);
      expect(queue.copies.length, 14);
      expect(queue.copies.every((a) => a.title == 'Physics revision'), isTrue);
    });

    test('the ledger survives a restart', () async {
      await repo.save(reminder());
      await service.replan();

      final restarted = serviceFor(PayloadTrackingScheduler(queue, db));
      expect((await restarted.replan()).isEmpty, isTrue);
      expect(queue.copies.length, 14);
    });

    test('alerts that already rang are forgotten', () async {
      await repo.save(reminder());
      await service.replan();
      final rang = queue.copies.removeAt(0).notificationId;

      final tracker = PayloadTrackingScheduler(queue, db);
      final pending = await tracker.pending();
      expect(pending.map((a) => a.id), isNot(contains(rang)));
      final ledger = await db.readSetting(PayloadTrackingScheduler.ledgerKey);
      expect(ledger, isNot(contains('"$rang"')));
    });
  });

  group('reading a notification response', () {
    final payload = AlertPayload(
      reminderId: 'r1',
      occurrenceAt: DateTime.utc(2026, 10, 22, 13, 30),
      style: ReminderStyle.alarm,
      signature: 'abc',
      ringsAt: DateTime.utc(2026, 10, 22, 13, 40),
    );

    test('Android: the button arrives as its own id', () {
      final r = readResponse(
        payload: payload.encode(),
        actionId: AlertActions.snooze,
      );
      expect(r.payload!.reminderId, 'r1');
      expect(r.action, AlertActions.snooze);
    });

    test('Windows: a click on the text echoes the payload', () {
      final encoded = payload.encode();
      final r = readResponse(payload: encoded, actionId: encoded);
      expect(r.payload!.occurrenceKey, payload.occurrenceKey);
      expect(r.action, isNull);
    });

    test('Windows: a button carries the payload and its action', () {
      final encoded = payload.withAction(AlertActions.done).encode();
      final r = readResponse(payload: encoded, actionId: encoded);
      expect(r.payload!.signature, 'abc');
      expect(r.payload!.ringsAt, payload.ringsAt);
      expect(r.action, AlertActions.done);
    });

    test('a plain tap has no action', () {
      final r = readResponse(payload: payload.encode(), actionId: null);
      expect(r.action, isNull);
    });
  });
}
