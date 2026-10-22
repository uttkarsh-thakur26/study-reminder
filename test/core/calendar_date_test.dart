import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/time/calendar_date.dart';

void main() {
  test('parses, prints and normalises ISO dates', () {
    expect(CalendarDate.parse('2026-10-22').toIso(), '2026-10-22');
    expect(CalendarDate.parse('2026-02-30'), const CalendarDate(2026, 3, 2));
    expect(() => CalendarDate.parse('22/10/2026'), throwsFormatException);
  });

  test('weekday and start of week', () {
    const thu = CalendarDate(2026, 10, 22);
    expect(thu.weekday, DateTime.thursday);
    expect(thu.startOfWeek, const CalendarDate(2026, 10, 19));
    expect(const CalendarDate(2026, 10, 19).startOfWeek,
        const CalendarDate(2026, 10, 19));
  });

  test('day arithmetic crosses months and years', () {
    expect(const CalendarDate(2026, 12, 31).addDays(1),
        const CalendarDate(2027, 1, 1));
    expect(const CalendarDate(2026, 3, 1).addDays(-1),
        const CalendarDate(2026, 2, 28));
    expect(const CalendarDate(2026, 1, 1).daysUntil(const CalendarDate(2026, 12, 31)),
        364);
    expect(const CalendarDate(2026, 1, 10).daysUntil(const CalendarDate(2026, 1, 1)),
        -9);
  });

  test('adding months clamps to the end of shorter months', () {
    const jan31 = CalendarDate(2026, 1, 31);
    expect(jan31.addMonths(1), const CalendarDate(2026, 2, 28));
    expect(jan31.addMonths(2), const CalendarDate(2026, 3, 31));
    expect(const CalendarDate(2028, 1, 31).addMonths(1),
        const CalendarDate(2028, 2, 29));
    expect(const CalendarDate(2026, 11, 15).addMonths(3),
        const CalendarDate(2027, 2, 15));
    expect(const CalendarDate(2026, 3, 15).addMonths(-3),
        const CalendarDate(2025, 12, 15));
  });

  test('ordering and equality', () {
    final dates = [
      const CalendarDate(2026, 10, 22),
      const CalendarDate(2025, 12, 1),
      const CalendarDate(2026, 1, 5),
    ]..sort();
    expect(dates.first, const CalendarDate(2025, 12, 1));
    expect(dates.last, const CalendarDate(2026, 10, 22));
    expect(const CalendarDate(2026, 1, 1) == const CalendarDate(2026, 1, 1), isTrue);
  });
}
