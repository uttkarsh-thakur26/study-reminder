import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/core/time/calendar_date.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';
import 'package:study_reminder/features/home_widget/application/home_widget_refresh.dart';
import 'package:study_reminder/features/home_widget/domain/widget_payload.dart';
import 'package:study_reminder/features/reminders/data/reminder_repository.dart';
import 'package:study_reminder/features/reminders/domain/agenda.dart';
import 'package:study_reminder/features/reminders/domain/occurrence.dart';
import 'package:study_reminder/features/reminders/domain/recurrence.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:study_reminder/features/subjects/data/subject_repository.dart';
import 'package:study_reminder/features/subjects/domain/subject.dart';
import 'package:study_widget/study_widget.dart';
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
  DateTime ist(int day, int hour, [int minute = 0]) =>
      tz.TZDateTime(india, 2026, 10, day, hour, minute);

  Reminder reminder(
    String id, {
    String? title,
    String anchor = '2026-10-22',
    int minute = 19 * 60,
    Recurrence recurrence = Recurrence.once,
    String? subjectId,
  }) => Reminder(
    id: id,
    title: title ?? 'R $id',
    subjectId: subjectId,
    createdAt: DateTime.utc(2026),
    schedule: ReminderSchedule(
      anchor: CalendarDate.parse(anchor),
      minuteOfDay: minute,
      timeZone: 'Asia/Kolkata',
      recurrence: recurrence,
    ),
  );

  OccurrenceState state(
    String id,
    DateTime at,
    OccurrenceStatus status, {
    DateTime? snoozeUntil,
  }) => OccurrenceState(
    reminderId: id,
    occurrenceAt: at,
    status: status,
    snoozeUntil: snoozeUntil,
  );

  StudyWidgetData build(
    List<Reminder> reminders, {
    List<OccurrenceState> states = const [],
    Map<String, Subject> subjects = const {},
    DateTime? now,
    DateTime? focusUntil,
  }) {
    final at = now ?? nowIst();
    return buildWidgetData(
      agenda: buildAgenda(
        reminders: reminders,
        states: {for (final s in states) s.id: s},
        now: at,
        here: india,
      ),
      subjects: subjects,
      now: at,
      focusUntil: focusUntil,
    );
  }

  int ms(DateTime t) => t.millisecondsSinceEpoch;

  List<String> titles(StudyWidgetData data) => [
    for (final i in data.items) i.title,
  ];

  test('lists what is still to come, soonest first, across days', () {
    final data = build([
      reminder('friday', anchor: '2026-10-23', minute: 9 * 60),
      reminder('tonight', minute: 19 * 60),
      reminder('noon', minute: 12 * 60),
      reminder('missed', minute: 8 * 60),
      reminder('overdue', anchor: '2026-10-20'),
      reminder('b same', title: 'B', minute: 15 * 60),
      reminder('a same', title: 'A', minute: 15 * 60),
    ]);
    expect(titles(data), ['R noon', 'A', 'B', 'R tonight', 'R friday']);
    expect(ms(data.items.first.at), ms(ist(22, 12)));
    expect(ms(data.items.last.at), ms(ist(23, 9)));
  });

  test('stops at a week ahead and at the limit', () {
    final week = build([
      reminder('in a week', anchor: '2026-10-29', minute: 9 * 60),
      reminder('past a week', anchor: '2026-10-29', minute: 11 * 60),
    ]);
    expect(titles(week), ['R in a week']);

    final daily = build([
      reminder('six', minute: 18 * 60, recurrence: const Recurrence.daily()),
      reminder('seven', minute: 19 * 60, recurrence: const Recurrence.daily()),
    ]);
    expect(daily.items, hasLength(widgetLimit));
    expect(ms(daily.items.first.at), ms(ist(22, 18)));
    expect(ms(daily.items.last.at), ms(ist(25, 19)));
  });

  test('leaves out done and skipped ones, keeps pending ones', () {
    final daily = reminder(
      'daily',
      minute: 18 * 60,
      recurrence: const Recurrence.daily(),
    );
    final data = build(
      [daily],
      states: [
        state('daily', ist(22, 18), OccurrenceStatus.done),
        state('daily', ist(23, 18), OccurrenceStatus.skipped),
        state('daily', ist(24, 18), OccurrenceStatus.pending),
      ],
    );
    final times = [for (final i in data.items) ms(i.at)];
    expect(times.first, ms(ist(24, 18)));
    expect(times, isNot(contains(ms(ist(22, 18)))));
    expect(times, isNot(contains(ms(ist(23, 18)))));
  });

  test('a snoozed reminder shows at the end of its snooze', () {
    final data = build(
      [
        reminder('missed', minute: 9 * 60),
        reminder('later', minute: 11 * 60),
        reminder('from tuesday', anchor: '2026-10-20', minute: 9 * 60),
      ],
      states: [
        state(
          'missed',
          ist(22, 9),
          OccurrenceStatus.snoozed,
          snoozeUntil: ist(22, 10, 10).toUtc(),
        ),
        state(
          'from tuesday',
          ist(20, 9),
          OccurrenceStatus.snoozed,
          snoozeUntil: ist(22, 12).toUtc(),
        ),
      ],
    );
    expect(titles(data), ['R missed', 'R later', 'R from tuesday']);
    expect(ms(data.items.first.at), ms(ist(22, 10, 10)));
    expect(ms(data.items.last.at), ms(ist(22, 12)));
  });

  test('gives each reminder its subject colour', () {
    const physics = Subject(id: 'phy', name: 'Physics', color: 0xFF0EA5E9);
    final data = build(
      [
        reminder('a', minute: 11 * 60, subjectId: 'phy'),
        reminder('b', minute: 12 * 60),
        reminder('c', minute: 13 * 60, subjectId: 'gone'),
      ],
      subjects: {'phy': physics},
    );
    expect([for (final i in data.items) i.color], [0xFF0EA5E9, null, null]);
  });

  test('a blank title still reads as a reminder', () {
    final data = build([reminder('blank', title: '  ')]);
    expect(titles(data), ['Reminder']);
  });

  test('sends the JSON the widget reads', () {
    const maths = Subject(id: 'm', name: 'Maths', color: 0xFF6366F1);
    final focusUntil = ist(22, 10, 30);
    final data = build(
      [reminder('a', title: 'Algebra', minute: 19 * 60, subjectId: 'm')],
      subjects: {'m': maths},
      focusUntil: focusUntil,
    );
    expect(jsonDecode(data.encode()), {
      'items': [
        {
          'title': 'Algebra',
          'at': ist(22, 19).millisecondsSinceEpoch,
          'color': 0xFF6366F1,
        },
      ],
      'focusUntil': focusUntil.millisecondsSinceEpoch,
    });
    expect(jsonDecode(build(const []).encode()), {
      'items': <Object?>[],
      'focusUntil': null,
    });
  });

  test('the focus line shows only while the phone focuses', () {
    final now = nowIst().toUtc();
    final ends = now.add(const Duration(minutes: 25));
    FocusSessions sessions(FocusTarget target, {bool active = true}) =>
        FocusSessions(
          phone: target.includes(DeviceKind.phone)
              ? FocusSession(
                  active: active,
                  startedAt: now,
                  endsAt: ends,
                  target: target,
                )
              : FocusSession.idle,
          laptop: target.includes(DeviceKind.laptop)
              ? FocusSession(
                  active: active,
                  startedAt: now,
                  endsAt: ends,
                  target: target,
                )
              : FocusSession.idle,
        );

    expect(phoneFocusUntil(sessions(FocusTarget.phone), now), ends);
    expect(phoneFocusUntil(sessions(FocusTarget.both), now), ends);
    expect(phoneFocusUntil(sessions(FocusTarget.laptop), now), isNull);
    expect(
      phoneFocusUntil(sessions(FocusTarget.phone, active: false), now),
      isNull,
    );
    expect(
      phoneFocusUntil(
        sessions(FocusTarget.phone),
        ends.add(const Duration(seconds: 1)),
      ),
      isNull,
    );
    // One that has ended is not sent.
    expect(build(const [], focusUntil: ist(22, 9)).focusUntil, isNull);
  });

  test(
    'the background refresh reads the same list from the database',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = HlcClock('testdevice01');
      await SubjectRepository(
        db,
        clock,
      ).save(const Subject(id: 'phy', name: 'Physics', color: 0xFF14B8A6));
      final reminders = ReminderRepository(db, clock);
      await reminders.save(reminder('tonight', subjectId: 'phy'));
      await reminders.save(reminder('noon', minute: 12 * 60));
      await reminders.save(reminder('done', minute: 13 * 60));
      await reminders.markDone('done', ist(22, 13));

      final data = await readHomeWidgetData(
        db: db,
        clock: clock,
        timeZone: 'Asia/Kolkata',
        now: nowIst(),
      );
      expect(data.items, [
        StudyWidgetItem(title: 'R noon', at: ist(22, 12)),
        StudyWidgetItem(title: 'R tonight', at: ist(22, 19), color: 0xFF14B8A6),
      ]);
      expect(data.focusUntil, isNull);
    },
  );
}
