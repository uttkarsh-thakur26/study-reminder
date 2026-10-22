import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/time/calendar_date.dart';
import 'package:study_reminder/features/reminders/domain/recurrence.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  ReminderSchedule schedule(
    String anchor,
    Recurrence r, {
    int minute = 19 * 60,
    String zone = 'Asia/Kolkata',
  }) => ReminderSchedule(
    anchor: CalendarDate.parse(anchor),
    minuteOfDay: minute,
    timeZone: zone,
    recurrence: r,
  );

  List<String> dates(ReminderSchedule s, String from, int count) => s
      .datesFrom(CalendarDate.parse(from))
      .take(count)
      .map((d) => d.toIso())
      .toList();

  test('once yields only the anchor, and nothing once it is behind us', () {
    final s = schedule('2026-10-25', Recurrence.once);
    expect(dates(s, '2026-10-01', 5), ['2026-10-25']);
    expect(dates(s, '2026-10-26', 5), isEmpty);
  });

  test('daily every 2 days stays on the anchor rhythm', () {
    final s = schedule('2026-10-20', const Recurrence.daily(every: 2));
    expect(dates(s, '2026-10-01', 3), [
      '2026-10-20',
      '2026-10-22',
      '2026-10-24',
    ]);
    expect(dates(s, '2026-10-23', 2), ['2026-10-24', '2026-10-26']);
  });

  test('weekly on chosen days', () {
    // 2026-10-22 is a Thursday.
    final s = schedule('2026-10-22', const Recurrence.weekly({1, 3, 5}));
    expect(dates(s, '2026-10-22', 5), [
      '2026-10-23',
      '2026-10-26',
      '2026-10-28',
      '2026-10-30',
      '2026-11-02',
    ]);
  });

  test('weekly without days uses the anchor weekday', () {
    final s = schedule('2026-10-22', const Recurrence.weekly({}));
    expect(dates(s, '2026-10-01', 3), [
      '2026-10-22',
      '2026-10-29',
      '2026-11-05',
    ]);
  });

  test('every 2 weeks skips the off weeks, also when starting mid-cycle', () {
    final s = schedule('2026-10-19', const Recurrence.weekly({1, 4}, every: 2));
    expect(dates(s, '2026-10-19', 4), [
      '2026-10-19',
      '2026-10-22',
      '2026-11-02',
      '2026-11-05',
    ]);
    // Starting in an off week jumps to the next on week.
    expect(dates(s, '2026-10-27', 2), ['2026-11-02', '2026-11-05']);
  });

  test('monthly on the 31st clamps to short months without drifting', () {
    final s = schedule('2026-01-31', const Recurrence.monthly());
    expect(dates(s, '2026-01-01', 4), [
      '2026-01-31',
      '2026-02-28',
      '2026-03-31',
      '2026-04-30',
    ]);
    expect(dates(s, '2026-06-15', 2), ['2026-06-30', '2026-07-31']);
  });

  test('every 3 months', () {
    final s = schedule('2026-01-15', const Recurrence.monthly(every: 3));
    expect(dates(s, '2026-02-01', 3), [
      '2026-04-15',
      '2026-07-15',
      '2026-10-15',
    ]);
  });

  test('until is inclusive and ends the series', () {
    final s = schedule(
      '2026-10-20',
      Recurrence(
        kind: RepeatKind.daily,
        until: CalendarDate.parse('2026-10-22'),
      ),
    );
    expect(dates(s, '2026-10-01', 10), [
      '2026-10-20',
      '2026-10-21',
      '2026-10-22',
    ]);
    final w = schedule(
      '2026-10-19',
      Recurrence(
        kind: RepeatKind.weekly,
        weekdays: const {1},
        until: CalendarDate.parse('2026-10-20'),
      ),
    );
    expect(dates(w, '2026-10-01', 10), ['2026-10-19']);
  });

  test('instants follow the reminder zone', () {
    final s = schedule(
      '2026-10-22',
      const Recurrence.daily(),
      minute: 19 * 60 + 30,
    );
    final next = s.nextAfter(DateTime.utc(2026, 10, 22, 0))!;
    // 19:30 in India is 14:00 UTC.
    expect(next.toUtc(), DateTime.utc(2026, 10, 22, 14, 0));
    // Strictly after: asking at that exact instant gives the next day.
    expect(s.nextAfter(next)!.toUtc(), DateTime.utc(2026, 10, 23, 14, 0));
  });

  test('daylight saving keeps the wall-clock time', () {
    // US clocks go forward on 2026-03-08.
    final s = schedule(
      '2026-03-06',
      const Recurrence.daily(),
      minute: 9 * 60,
      zone: 'America/New_York',
    );
    final times = s
        .occurrencesBetween(DateTime.utc(2026, 3, 6), DateTime.utc(2026, 3, 10))
        .map((t) => '${t.day} ${t.hour}:${t.minute}')
        .toList();
    expect(times, ['6 9:0', '7 9:0', '8 9:0', '9 9:0']);
  });

  test('a time that does not exist on a DST day still fires once', () {
    // 02:30 does not exist in New York on 2026-03-08.
    final s = schedule(
      '2026-03-07',
      const Recurrence.daily(),
      minute: 2 * 60 + 30,
      zone: 'America/New_York',
    );
    final list = s
        .occurrencesBetween(
          DateTime.utc(2026, 3, 7),
          DateTime.utc(2026, 3, 10, 12),
        )
        .toList();
    // 7th, 8th (shifted past the gap), 9th and 10th, each exactly once.
    expect(list.map((t) => t.day).toList(), [7, 8, 9, 10]);
    expect(list.map((t) => t.toUtc()).toSet().length, 4);
  });

  test('describe gives friendly labels', () {
    expect(Recurrence.once.describe(), 'Once');
    expect(const Recurrence.daily().describe(), 'Every day');
    expect(const Recurrence.daily(every: 3).describe(), 'Every 3 days');
    expect(Recurrence.weekdaysOnly.describe(), 'Weekdays');
    expect(Recurrence.weekends.describe(), 'Weekends');
    expect(const Recurrence.weekly({1, 3}).describe(), 'Mon, Wed');
    expect(
      const Recurrence.weekly({5}, every: 2).describe(),
      'Every 2 weeks · Fri',
    );
    expect(const Recurrence.monthly().describe(), 'Every month');
  });

  test('weekday mask round trips', () {
    const r = Recurrence.weekly({1, 5, 7});
    expect(Recurrence.weekdaysFromMask(r.weekdayMask), {1, 5, 7});
  });

  test('unknown zones fall back to the device zone', () {
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    expect(resolveLocation('Not/AZone').name, 'Asia/Kolkata');
  });
}
