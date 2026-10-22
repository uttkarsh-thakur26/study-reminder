import 'package:timezone/timezone.dart' as tz;

import '../../../core/time/calendar_date.dart';

enum RepeatKind { once, daily, weekly, monthly }

const weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// How often a reminder repeats.
class Recurrence {
  const Recurrence({
    this.kind = RepeatKind.once,
    this.interval = 1,
    this.weekdays = const {},
    this.until,
  }) : assert(interval >= 1);

  const Recurrence.daily({int every = 1})
      : this(kind: RepeatKind.daily, interval: every);

  /// [days] uses 1 = Monday ... 7 = Sunday. Empty means the start day's weekday.
  const Recurrence.weekly(Set<int> days, {int every = 1})
      : this(kind: RepeatKind.weekly, interval: every, weekdays: days);

  const Recurrence.monthly({int every = 1})
      : this(kind: RepeatKind.monthly, interval: every);

  static const once = Recurrence();
  static const weekdaysOnly = Recurrence.weekly({1, 2, 3, 4, 5});
  static const weekends = Recurrence.weekly({6, 7});

  final RepeatKind kind;
  final int interval;
  final Set<int> weekdays;

  /// Last date (inclusive) an occurrence may fall on.
  final CalendarDate? until;

  bool get repeats => kind != RepeatKind.once;

  int get weekdayMask =>
      weekdays.fold(0, (mask, day) => mask | (1 << (day - 1)));

  static Set<int> weekdaysFromMask(int mask) => {
        for (var day = 1; day <= 7; day++)
          if (mask & (1 << (day - 1)) != 0) day,
      };

  Recurrence copyWith({
    RepeatKind? kind,
    int? interval,
    Set<int>? weekdays,
    CalendarDate? until,
    bool clearUntil = false,
  }) =>
      Recurrence(
        kind: kind ?? this.kind,
        interval: interval ?? this.interval,
        weekdays: weekdays ?? this.weekdays,
        until: clearUntil ? null : (until ?? this.until),
      );

  /// Short human label, e.g. "Every 2 days" or "Mon, Wed, Fri".
  String describe() {
    switch (kind) {
      case RepeatKind.once:
        return 'Once';
      case RepeatKind.daily:
        return interval == 1 ? 'Every day' : 'Every $interval days';
      case RepeatKind.weekly:
        final sorted = weekdays.toList()..sort();
        String days;
        if (_sameDays(sorted, const [1, 2, 3, 4, 5])) {
          days = 'Weekdays';
        } else if (_sameDays(sorted, const [6, 7])) {
          days = 'Weekends';
        } else if (sorted.length == 7) {
          days = 'Every day';
        } else if (sorted.isEmpty) {
          days = 'Weekly';
        } else {
          days = sorted.map((d) => weekdayShortNames[d - 1]).join(', ');
        }
        return interval == 1 ? days : 'Every $interval weeks · $days';
      case RepeatKind.monthly:
        return interval == 1 ? 'Every month' : 'Every $interval months';
    }
  }

  static bool _sameDays(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is Recurrence &&
      other.kind == kind &&
      other.interval == interval &&
      other.weekdayMask == weekdayMask &&
      other.until == until;

  @override
  int get hashCode => Object.hash(kind, interval, weekdayMask, until);
}

/// When a reminder fires: a start date, a time of day, a time zone and a
/// repeat rule.
class ReminderSchedule {
  const ReminderSchedule({
    required this.anchor,
    required this.minuteOfDay,
    required this.timeZone,
    this.recurrence = Recurrence.once,
  }) : assert(minuteOfDay >= 0 && minuteOfDay < 24 * 60);

  final CalendarDate anchor;
  final int minuteOfDay;

  /// IANA zone the times are meant in, e.g. `Asia/Kolkata`. Every device
  /// computes the same instants from it.
  final String timeZone;
  final Recurrence recurrence;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  ReminderSchedule copyWith({
    CalendarDate? anchor,
    int? minuteOfDay,
    String? timeZone,
    Recurrence? recurrence,
  }) =>
      ReminderSchedule(
        anchor: anchor ?? this.anchor,
        minuteOfDay: minuteOfDay ?? this.minuteOfDay,
        timeZone: timeZone ?? this.timeZone,
        recurrence: recurrence ?? this.recurrence,
      );

  tz.Location get location => resolveLocation(timeZone);

  /// The instant this schedule fires on [date].
  tz.TZDateTime at(CalendarDate date) =>
      tz.TZDateTime(location, date.year, date.month, date.day, hour, minute);

  /// Dates the reminder occurs on, on or after [from], in order.
  ///
  /// Infinite for repeating schedules without an end, so bound it.
  Iterable<CalendarDate> datesFrom(CalendarDate from) sync* {
    final r = recurrence;
    final start = from.isBefore(anchor) ? anchor : from;
    bool past(CalendarDate d) => r.until != null && d.isAfter(r.until!);

    switch (r.kind) {
      case RepeatKind.once:
        if (!anchor.isBefore(from)) yield anchor;
        return;

      case RepeatKind.daily:
        final offset = anchor.daysUntil(start);
        var k = (offset + r.interval - 1) ~/ r.interval;
        while (true) {
          final d = anchor.addDays(k * r.interval);
          if (past(d)) return;
          yield d;
          k++;
        }

      case RepeatKind.weekly:
        final days = (r.weekdays.isEmpty ? {anchor.weekday} : r.weekdays)
            .toList()
          ..sort();
        final firstWeek = anchor.startOfWeek;
        var week = firstWeek.daysUntil(start.startOfWeek) ~/ 7;
        if (week % r.interval != 0) week += r.interval - week % r.interval;
        while (true) {
          final weekStart = firstWeek.addDays(week * 7);
          for (final day in days) {
            final d = weekStart.addDays(day - 1);
            if (d.isBefore(start)) continue;
            if (past(d)) return;
            yield d;
          }
          week += r.interval;
        }

      case RepeatKind.monthly:
        final monthsApart =
            (start.year * 12 + start.month) - (anchor.year * 12 + anchor.month);
        var k = monthsApart <= 0 ? 0 : monthsApart ~/ r.interval - 1;
        if (k < 0) k = 0;
        while (true) {
          final d = anchor.addMonths(k * r.interval);
          k++;
          if (d.isBefore(start)) continue;
          if (past(d)) return;
          yield d;
        }
    }
  }

  /// Occurrence instants strictly after [after], in order.
  Iterable<tz.TZDateTime> occurrencesAfter(DateTime after) sync* {
    final local = tz.TZDateTime.from(after, location);
    // Start a day early so a time shifted by a DST change is never skipped.
    final from = CalendarDate(local.year, local.month, local.day).addDays(-1);
    for (final date in datesFrom(from)) {
      final instant = at(date);
      if (instant.isAfter(after)) yield instant;
    }
  }

  /// Occurrences in `[start, end)`.
  Iterable<tz.TZDateTime> occurrencesBetween(DateTime start, DateTime end) =>
      occurrencesAfter(start.subtract(const Duration(microseconds: 1)))
          .takeWhile((t) => t.isBefore(end));

  /// The next occurrence after [after], or null when the schedule has ended.
  tz.TZDateTime? nextAfter(DateTime after) {
    for (final t in occurrencesAfter(after)) {
      return t;
    }
    return null;
  }
}

/// Looks up an IANA zone, falling back to the device zone for unknown names.
tz.Location resolveLocation(String name) {
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return tz.local;
  }
}
