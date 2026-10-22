/// A date without a time or time zone, such as the day a reminder starts.
///
/// Arithmetic runs on UTC midnights so daylight saving changes can never
/// shift a date by a day.
class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate(this.year, this.month, this.day);

  factory CalendarDate.fromDateTime(DateTime dt) =>
      CalendarDate(dt.year, dt.month, dt.day);

  /// Parses `YYYY-MM-DD`.
  factory CalendarDate.parse(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) {
      throw FormatException('Expected YYYY-MM-DD', iso);
    }
    return CalendarDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    ).normalized();
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// 1 = Monday ... 7 = Sunday, matching [DateTime.weekday].
  int get weekday => _utc.weekday;

  /// Rolls overflowing values over, e.g. 2026-02-30 becomes 2026-03-02.
  CalendarDate normalized() => CalendarDate.fromDateTime(_utc);

  CalendarDate addDays(int days) =>
      CalendarDate.fromDateTime(_utc.add(Duration(days: days)));

  /// Adds whole months, clamping the day to the target month's length.
  CalendarDate addMonths(int months) {
    final index = year * 12 + (month - 1) + months;
    final y = index ~/ 12;
    final m = index % 12 + 1;
    final last = daysInMonth(y, m);
    return CalendarDate(y, m, day > last ? last : day);
  }

  /// Whole days from this date to [other]; negative when [other] is earlier.
  int daysUntil(CalendarDate other) =>
      other._utc.difference(_utc).inDays;

  /// The Monday of this date's week.
  CalendarDate get startOfWeek => addDays(1 - weekday);

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
