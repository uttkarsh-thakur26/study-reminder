import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/field_clock.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/core/time/calendar_date.dart';
import 'package:study_reminder/features/reminders/data/reminder_repository.dart';
import 'package:study_reminder/features/reminders/domain/occurrence.dart';
import 'package:study_reminder/features/reminders/domain/recurrence.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';

void main() {
  late AppDatabase db;
  late ReminderRepository repo;
  late int wall;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    wall = 1000;
    repo = ReminderRepository(
      db,
      HlcClock(
        'dev1',
        wallClock: () => DateTime.fromMillisecondsSinceEpoch(wall += 1000),
      ),
    );
  });
  tearDown(() => db.close());

  final reminder = Reminder(
    id: 'r1',
    title: 'Physics',
    createdAt: DateTime.utc(2026, 10, 22),
    schedule: const ReminderSchedule(
      anchor: CalendarDate(2026, 10, 22),
      minuteOfDay: 19 * 60,
      timeZone: 'Asia/Kolkata',
      recurrence: Recurrence.weekly({1, 3}),
    ),
  );

  test('saves and reads back every field', () async {
    await repo.save(
      reminder.copyWith(notes: 'Chapter 4', style: ReminderStyle.alarm),
    );
    final back = (await repo.byId('r1'))!;
    expect(
      back.toFields(),
      reminder
          .copyWith(notes: 'Chapter 4', style: ReminderStyle.alarm)
          .toFields(),
    );
    final row = await db.select(db.reminders).getSingle();
    expect(row.dirty, isTrue);
  });

  test(
    'edits stamp only the changed fields; unchanged saves write nothing',
    () async {
      await repo.save(reminder);
      final first = await db.select(db.reminders).getSingle();
      final firstClock = FieldClock.decode(first.fieldClock);

      await repo.save(reminder.copyWith(title: 'Physics revision'));
      final second = await db.select(db.reminders).getSingle();
      final secondClock = FieldClock.decode(second.fieldClock);
      expect(secondClock.of('title') > firstClock.of('title'), isTrue);
      expect(secondClock.of('minute_of_day'), firstClock.of('minute_of_day'));
      expect(Hlc.parse(second.hlc), secondClock.latest);

      await repo.save(reminder.copyWith(title: 'Physics revision'));
      final third = await db.select(db.reminders).getSingle();
      expect(third.hlc, second.hlc);
    },
  );

  test(
    'delete is a soft delete that hides the reminder, restore brings it back',
    () async {
      await repo.save(reminder);
      await repo.delete('r1');
      expect(await repo.watchAll().first, isEmpty);
      final row = await db.select(db.reminders).getSingle();
      expect(row.deleted, isTrue);
      await repo.restore('r1');
      expect((await repo.watchAll().first).single.id, 'r1');
    },
  );

  test('occurrence actions share one record per occurrence', () async {
    final at = DateTime.utc(2026, 10, 22, 13, 30);
    await repo.markDone('r1', at);
    await repo.reopen('r1', at);
    await repo.snooze('r1', at, at.add(const Duration(minutes: 10)));
    final states = await repo.watchOccurrences().first;
    expect(states.length, 1);
    final s = states[occurrenceId('r1', at)]!;
    expect(s.status, OccurrenceStatus.snoozed);
    expect(s.snoozeUntil, at.add(const Duration(minutes: 10)));
  });
}
