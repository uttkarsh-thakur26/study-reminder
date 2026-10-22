import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/time/calendar_date.dart';
import 'package:study_reminder/features/reminders/domain/quick_add_parser.dart';
import 'package:study_reminder/features/reminders/domain/recurrence.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';

void main() {
  // Thursday 22 Oct 2026, 10:00.
  final now = DateTime(2026, 10, 22, 10, 0);
  QuickAddResult parse(String s) => parseQuickAdd(s, now: now);
  const today = CalendarDate(2026, 10, 22);

  test('weekly day and time', () {
    final r = parse('Revise chemistry every Mon 7pm');
    expect(r.title, 'Revise chemistry');
    expect(r.recurrence, const Recurrence.weekly({1}));
    expect(r.minuteOfDay, 19 * 60);
    expect(r.date, isNull);
  });

  test('tomorrow with a time', () {
    final r = parse('Physics test tomorrow 9am');
    expect(r.title, 'Physics test');
    expect(r.date, today.addDays(1));
    expect(r.minuteOfDay, 9 * 60);
    expect(r.recurrence.repeats, isFalse);
  });

  test('relative minutes', () {
    final r = parse('Read notes in 30 min');
    expect(r.title, 'Read notes');
    expect(r.date, today);
    expect(r.minuteOfDay, 10 * 60 + 30);
  });

  test('relative days keep the time open', () {
    final r = parse('Return library book in 3 days');
    expect(r.title, 'Return library book');
    expect(r.date, today.addDays(3));
    expect(r.minuteOfDay, isNull);
  });

  test('every day with a 24h time', () {
    final r = parse('Maths every day at 18:30');
    expect(r.title, 'Maths');
    expect(r.recurrence, const Recurrence.daily());
    expect(r.minuteOfDay, 18 * 60 + 30);
  });

  test('weekdays, alarm flag', () {
    final r = parse('Flashcards every weekday 6am !alarm');
    expect(r.title, 'Flashcards');
    expect(r.recurrence, Recurrence.weekdaysOnly);
    expect(r.minuteOfDay, 6 * 60);
    expect(r.style, ReminderStyle.alarm);
  });

  test('leading "alarm" word sets the style', () {
    final r = parse('alarm wake up 6am');
    expect(r.title, 'Wake up');
    expect(r.style, ReminderStyle.alarm);
    expect(r.minuteOfDay, 6 * 60);
  });

  test('on a weekday is a date, a bare hour reads as afternoon', () {
    final r = parse('Group study on friday at 5');
    expect(r.title, 'Group study');
    expect(r.date, const CalendarDate(2026, 10, 23));
    expect(r.recurrence.repeats, isFalse);
    expect(r.minuteOfDay, 17 * 60);
  });

  test('plural weekday repeats', () {
    final r = parse('Lab on tuesdays 2pm');
    expect(r.recurrence, const Recurrence.weekly({2}));
    expect(r.title, 'Lab');
  });

  test('several days', () {
    final r = parse('Revise every Mon and Wed at 7:30 pm');
    expect(r.recurrence, const Recurrence.weekly({1, 3}));
    expect(r.minuteOfDay, 19 * 60 + 30);
    expect(r.title, 'Revise');
    final r2 = parse('Gym every mon, wed, fri 6am');
    expect(r2.recurrence, const Recurrence.weekly({1, 3, 5}));
  });

  test('day and month name, subject tag', () {
    final r = parse('Mock exam 25 oct 10am #physics');
    expect(r.title, 'Mock exam');
    expect(r.date, const CalendarDate(2026, 10, 25));
    expect(r.minuteOfDay, 10 * 60);
    expect(r.subjectTag, 'physics');
    expect(parse('Results nov 3rd').date, const CalendarDate(2026, 11, 3));
  });

  test('day-first numeric dates roll to next year when past', () {
    final r = parse('Submit form 30/9');
    expect(r.title, 'Submit form');
    expect(r.date, const CalendarDate(2027, 9, 30));
    expect(parse('Fees 15/11/2026').date, const CalendarDate(2026, 11, 15));
  });

  test('decimals in titles are not times', () {
    final r = parse('Read section 3.14 tomorrow');
    expect(r.title, 'Read section 3.14');
    expect(r.minuteOfDay, isNull);
    expect(r.date, today.addDays(1));
  });

  test('dotted time counts with am/pm', () {
    expect(parse('Revise 7.30pm').minuteOfDay, 19 * 60 + 30);
  });

  test('every 2 weeks and every other day', () {
    expect(
      parse('Water plants every 2 weeks').recurrence,
      const Recurrence.weekly({}, every: 2),
    );
    expect(
      parse('Stretch every other day').recurrence,
      const Recurrence.daily(every: 2),
    );
    expect(parse('Pay rent monthly').recurrence, const Recurrence.monthly());
  });

  test('tonight sets today and an evening time', () {
    final r = parse('Call mom tonight');
    expect(r.title, 'Call mom');
    expect(r.date, today);
    expect(r.minuteOfDay, 20 * 60);
  });

  test('bare hour without a day picks the next time that hour comes round', () {
    expect(parse('Revise biology at 7').minuteOfDay, 19 * 60);
    expect(parse('Revise biology at 11').minuteOfDay, 11 * 60);
  });

  test('words that only look like keywords stay in the title', () {
    final r = parse('Revise weekday timetable');
    expect(r.title, 'Revise weekday timetable');
    expect(r.recurrence.repeats, isFalse);
    expect(parse('Alarm clock lecture notes').title, 'Clock lecture notes');
  });

  test('next weekday is a date in the future', () {
    final r = parse('Essay due next friday');
    expect(r.date!.weekday, DateTime.friday);
    expect(r.date!.isAfter(today), isTrue);
    expect(r.title, 'Essay due');
  });

  group('resolveStart', () {
    test('no time today means the next full hour', () {
      final s = resolveStart(parse('Revise'), now: now);
      expect(s.date, today);
      expect(s.minuteOfDay, 11 * 60);
    });

    test('a time already gone today moves to tomorrow', () {
      final s = resolveStart(parse('Revise 7am'), now: now);
      expect(s.date, today.addDays(1));
      expect(s.minuteOfDay, 7 * 60);
    });

    test('explicit today keeps the date', () {
      final s = resolveStart(parse('Revise today 7am'), now: now);
      expect(s.date, today);
    });

    test('a later day without a time defaults to 9:00', () {
      final s = resolveStart(parse('Revise on saturday'), now: now);
      expect(s.date, const CalendarDate(2026, 10, 24));
      expect(s.minuteOfDay, 9 * 60);
    });

    test('late at night rolls to tomorrow morning', () {
      final late = DateTime(2026, 10, 22, 23, 30);
      final s = resolveStart(parseQuickAdd('Revise', now: late), now: late);
      expect(s.date, today.addDays(1));
      expect(s.minuteOfDay, 9 * 60);
    });
  });
}
