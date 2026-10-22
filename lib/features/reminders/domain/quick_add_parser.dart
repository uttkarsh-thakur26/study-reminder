import '../../../core/time/calendar_date.dart';
import 'recurrence.dart';
import 'reminder.dart';

/// What the quick-add box understood from a line of text.
class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.date,
    this.minuteOfDay,
    this.recurrence = Recurrence.once,
    this.style = ReminderStyle.notification,
    this.subjectTag,
    this.dateIsExplicit = false,
    this.dateIsWeekday = false,
  });

  final String title;
  final CalendarDate? date;
  final int? minuteOfDay;
  final Recurrence recurrence;
  final ReminderStyle style;

  /// Text after `#`, matched against subject names by the caller.
  final String? subjectTag;

  /// True when the text named a day ("today", "fri", "25 oct", "in 2 days").
  final bool dateIsExplicit;

  /// True when the day came from a weekday name ("thu", "on friday"), which
  /// means the next one to come, so a time already gone today means next week.
  final bool dateIsWeekday;

  bool get understoodWhen =>
      date != null || minuteOfDay != null || recurrence.repeats;
}

const _weekdayWords = {
  'mon': 1,
  'monday': 1,
  'tue': 2,
  'tues': 2,
  'tuesday': 2,
  'wed': 3,
  'weds': 3,
  'wednesday': 3,
  'thu': 4,
  'thur': 4,
  'thurs': 4,
  'thursday': 4,
  'fri': 5,
  'friday': 5,
  'sat': 6,
  'saturday': 6,
  'sun': 7,
  'sunday': 7,
};

const _monthWords = {
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

final _weekdayAlt =
    (_weekdayWords.keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
        .join('|');
final _monthAlt =
    (_monthWords.keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
        .join('|');

RegExp _re(String pattern) => RegExp(pattern, caseSensitive: false);

/// Parses text like "Revise chemistry every Mon 7pm #chem !alarm".
///
/// [now] is the local wall-clock time. Dates are read day-first (25/10).
QuickAddResult parseQuickAdd(String input, {required DateTime now}) {
  var text = ' ${input.trim()} ';
  final today = CalendarDate(now.year, now.month, now.day);

  /// Removes the first match of [re] that [accept] returns true for. The
  /// gap is marked so the title cleanup knows where text was taken out.
  void takeIf(RegExp re, bool Function(Match m) accept) {
    for (final m in re.allMatches(text)) {
      if (!accept(m)) continue;
      text = text.replaceRange(m.start, m.end, ' $_gap ');
      return;
    }
  }

  /// Removes the first match of [re] from the text after passing it to [use].
  void take(RegExp re, void Function(Match m) use) => takeIf(re, (m) {
    use(m);
    return true;
  });

  var style = ReminderStyle.notification;
  String? subjectTag;
  CalendarDate? date;
  var dateIsExplicit = false;
  int? minute;
  var recurrence = Recurrence.once;
  var bareHour = -1;
  var tonight = false;
  var weekdayName = false;

  // Style: "!alarm", or "alarm" as the first or last word.
  take(_re(r'\s!a(larm)?(?=[\s,.!?;])'), (_) => style = ReminderStyle.alarm);
  take(
    _re(r'^\s+alarm(\s+(for|to))?(?=[\s,.!?;])'),
    (_) => style = ReminderStyle.alarm,
  );
  take(_re(r'\s(as\s+an?\s+)?alarm\s+$'), (_) => style = ReminderStyle.alarm);

  // Subject tag.
  take(_re(r'\s#([\w-]+)(?=[\s,.!?;])'), (m) => subjectTag = m.group(1));

  // Relative times: "in 30 min", "in 2 hours", "in an hour", "in 3 days".
  take(
    _re(
      r'\sin\s+(\d+|an?|half\s+an?)\s*(minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|w)(?=[\s,.!?;])',
    ),
    (m) {
      final amountText = m.group(1)!.toLowerCase();
      final unit = m.group(2)!.toLowerCase();
      final half = amountText.startsWith('half');
      final amount = half ? 1 : int.tryParse(amountText) ?? 1;
      Duration d;
      if (unit.startsWith('m')) {
        d = Duration(minutes: amount);
      } else if (unit.startsWith('h')) {
        d = half ? const Duration(minutes: 30) : Duration(hours: amount);
      } else if (unit.startsWith('d')) {
        d = Duration(days: amount);
      } else {
        d = Duration(days: 7 * amount);
      }
      final at = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      ).add(d);
      date = CalendarDate(at.year, at.month, at.day);
      dateIsExplicit = true;
      if (!unit.startsWith('d') && !unit.startsWith('w')) {
        minute = at.hour * 60 + at.minute;
      }
    },
  );

  // Repeats.
  take(
    _re(r'\s(every\s+weekday|(on\s+)?weekdays)(?=[\s,.!?;])'),
    (_) => recurrence = Recurrence.weekdaysOnly,
  );
  if (!recurrence.repeats) {
    take(
      _re(r'\s(every\s+weekends?|weekends)(?=[\s,.!?;])'),
      (_) => recurrence = Recurrence.weekends,
    );
  }
  if (!recurrence.repeats) {
    take(
      _re(
        '\\s(?:every|on)\\s+((?:$_weekdayAlt)s?(?:\\s*(?:,|and|&|/)\\s*(?:$_weekdayAlt)s?)*)(?=[\\s,.!?;])',
      ),
      (m) {
        final t = m.group(0)!.toLowerCase();
        final days = _re(_weekdayAlt)
            .allMatches(m.group(1)!)
            .map((d) => _weekdayWords[d.group(0)!.toLowerCase()]!)
            .toSet();
        // "on friday" is a date, "on fridays" or "every friday" repeats.
        // "tues" and "thurs" are abbreviations, not plurals.
        final plural = _re(r'[a-z]+').allMatches(m.group(1)!).any((w) {
          final t = w.group(0)!.toLowerCase();
          return t.endsWith('s') &&
              !_weekdayWords.containsKey(t) &&
              _weekdayWords.containsKey(t.substring(0, t.length - 1));
        });
        if (t.trimLeft().startsWith('every') || plural || days.length > 1) {
          recurrence = Recurrence.weekly(days);
        } else {
          date = _nextWeekday(today, days.first, includeToday: true);
          dateIsExplicit = true;
          weekdayName = true;
        }
      },
    );
  }
  if (!recurrence.repeats) {
    take(
      _re(r'\severy\s+(other\s+|(\d+)\s+)?(days?|weeks?|months?)(?=[\s,.!?;])'),
      (m) {
        final every = m.group(1)?.trim().toLowerCase() == 'other'
            ? 2
            : int.tryParse(m.group(2) ?? '') ?? 1;
        final unit = m.group(3)!.toLowerCase();
        final n = every.clamp(1, 365);
        recurrence = unit.startsWith('day')
            ? Recurrence.daily(every: n)
            : unit.startsWith('week')
            ? Recurrence.weekly(const {}, every: n)
            : Recurrence.monthly(every: n);
      },
    );
  }
  if (!recurrence.repeats) {
    take(
      _re(r'\s(daily|everyday|each\s+day)(?=[\s,.!?;])'),
      (_) => recurrence = const Recurrence.daily(),
    );
  }
  if (!recurrence.repeats) {
    take(
      _re(r'\sweekly(?=[\s,.!?;])'),
      (_) => recurrence = const Recurrence.weekly({}),
    );
  }
  if (!recurrence.repeats) {
    take(
      _re(r'\smonthly(?=[\s,.!?;])'),
      (_) => recurrence = const Recurrence.monthly(),
    );
  }

  // Dates.
  if (date == null) {
    take(_re(r'\s(the\s+)?day\s+after\s+tomorrow(?=[\s,.!?;])'), (_) {
      date = today.addDays(2);
      dateIsExplicit = true;
    });
  }
  if (date == null) {
    take(_re(r'\s(tomorrow|tmrw|tmr)(?=[\s,.!?;])'), (_) {
      date = today.addDays(1);
      dateIsExplicit = true;
    });
  }
  if (date == null) {
    take(_re(r'\stoday(?=[\s,.!?;])'), (_) {
      date = today;
      dateIsExplicit = true;
    });
  }
  if (date == null) {
    take(_re(r'\stonight(?=[\s,.!?;])'), (_) {
      date = today;
      dateIsExplicit = true;
      tonight = true;
    });
  }
  if (date == null && !recurrence.repeats) {
    takeIf(
      _re(
        '\\s(next\\s+|this\\s+|on\\s+|by\\s+)?(?:on\\s+)?($_weekdayAlt)(?=[\\s,.!?;])',
      ),
      (m) {
        final word = m.group(2)!.toLowerCase();
        // "SAT prep" or "the sun" are not days unless the text says so.
        if (m.group(1) == null && _wordLikeDays.contains(word)) return false;
        final next = m.group(1)?.trim().toLowerCase() == 'next';
        date = _nextWeekday(today, _weekdayWords[word]!, includeToday: !next);
        dateIsExplicit = true;
        weekdayName = true;
        return true;
      },
    );
  }

  /// Takes a calendar date only when it is a real date.
  void takeDate(RegExp re, CalendarDate? Function(Match m) read) {
    if (date != null) return;
    takeIf(re, (m) {
      final d = read(m);
      if (d == null) return false;
      date = d;
      dateIsExplicit = true;
      return true;
    });
  }

  takeDate(
    _re(
      '\\s(?:on\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+($_monthAlt)\\.?(?:\\s+(\\d{4}))?(?=[\\s,.!?;])',
    ),
    (m) => _dateOrNextYear(
      today,
      int.parse(m.group(1)!),
      _monthWords[m.group(2)!.toLowerCase()]!,
      int.tryParse(m.group(3) ?? ''),
    ),
  );
  takeDate(
    _re(
      '\\s(?:on\\s+)?($_monthAlt)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?(?=[\\s,.!?;])',
    ),
    (m) => _dateOrNextYear(
      today,
      int.parse(m.group(2)!),
      _monthWords[m.group(1)!.toLowerCase()]!,
      int.tryParse(m.group(3) ?? ''),
    ),
  );
  takeDate(
    _re(r'\s(?:on\s+)?(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?(?=[\s,.!?;])'),
    (m) {
      var year = int.tryParse(m.group(3) ?? '');
      if (year != null && year < 100) year += 2000;
      return _dateOrNextYear(
        today,
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        year,
      );
    },
  );

  // Times. "7.30" only counts with "at" or am/pm, so "chapter 3.14" stays text.
  if (minute == null) {
    takeIf(
      _re(
        r'\s(at\s+|@\s*)?(\d{1,2})([:.])(\d{2})\s*(am|pm|a\.m\.|p\.m\.)?(?=[\s,.!?;])',
      ),
      (m) {
        if (m.group(3) == '.' && m.group(1) == null && m.group(5) == null) {
          return false;
        }
        final hour = _hour24(int.parse(m.group(2)!), m.group(5));
        final mm = int.parse(m.group(4)!);
        if (hour == null || mm > 59) return false;
        minute = hour * 60 + mm;
        return true;
      },
    );
  }
  if (minute == null) {
    takeIf(
      _re(r'\s(?:at\s+|@\s*)?(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)(?=[\s,.!?;])'),
      (m) {
        final hour = _hour24(int.parse(m.group(1)!), m.group(2));
        if (hour == null) return false;
        minute = hour * 60;
        return true;
      },
    );
  }
  if (minute == null) {
    takeIf(_re(r'\s(?:at\s+|@\s*)(\d{1,2})(?=[\s,.!?;])'), (m) {
      final h = int.parse(m.group(1)!);
      if (h > 23) return false;
      bareHour = h;
      return true;
    });
  }
  if (minute == null && bareHour < 0) {
    const named = {
      'noon': 12 * 60,
      'midday': 12 * 60,
      'morning': 8 * 60,
      'afternoon': 14 * 60,
      'evening': 18 * 60,
      'night': 21 * 60,
    };
    take(
      _re(
        r'\s(?:at\s+|in\s+the\s+|this\s+)?(noon|midday|morning|afternoon|evening|night)(?=[\s,.!?;])',
      ),
      (m) => minute = named[m.group(1)!.toLowerCase()],
    );
  }
  if (bareHour >= 0) {
    if (bareHour == 0 || bareHour > 12) {
      minute = bareHour * 60;
    } else if (tonight) {
      minute = (bareHour == 12 ? 12 : bareHour + 12) * 60;
    } else if (date != null || recurrence.repeats) {
      // A study reminder "at 5" means 5 pm; "at 9" means 9 am.
      final h = bareHour == 12
          ? 12
          : (bareHour <= 6 ? bareHour + 12 : bareHour);
      minute = h * 60;
    } else {
      // No day given: the next time the clock shows that hour.
      final nowMinute = now.hour * 60 + now.minute;
      final am = (bareHour % 12) * 60;
      final pm = am + 12 * 60;
      minute = am > nowMinute ? am : (pm > nowMinute ? pm : am);
    }
  }

  if (tonight && minute == null) {
    // 8 pm, or the next full hour once 8 pm has gone.
    final nextHour = (now.hour + 1) * 60;
    minute = nextHour > 20 * 60 && nextHour < 24 * 60 ? nextHour : 20 * 60;
  }

  return QuickAddResult(
    title: _cleanTitle(text),
    date: date,
    minuteOfDay: minute,
    recurrence: recurrence,
    style: style,
    subjectTag: subjectTag,
    dateIsExplicit: dateIsExplicit,
    dateIsWeekday: weekdayName,
  );
}

/// Turns a parse result into a concrete start date and time.
///
/// Without a time it picks the next full hour today, or 9:00 on a later day.
/// A time already past today moves to tomorrow, or a week on when a weekday
/// was named ("thu 9am" said on Thursday afternoon), unless the text said
/// "today" or gave the date.
({CalendarDate date, int minuteOfDay}) resolveStart(
  QuickAddResult r, {
  required DateTime now,
}) {
  final today = CalendarDate(now.year, now.month, now.day);
  final nowMinute = now.hour * 60 + now.minute;
  var date = r.date ?? today;
  var minute = r.minuteOfDay;
  if (minute == null) {
    if (date == today) {
      final nextHour = (now.hour + 1) * 60;
      if (nextHour >= 24 * 60) {
        date = today.addDays(r.dateIsWeekday ? 7 : 1);
        minute = 9 * 60;
      } else {
        minute = nextHour;
      }
    } else {
      minute = 9 * 60;
    }
  }
  if (date == today && minute <= nowMinute) {
    if (r.dateIsWeekday) {
      date = today.addDays(7);
    } else if (!r.dateIsExplicit) {
      date = today.addDays(1);
    }
  }
  return (date: date, minuteOfDay: minute);
}

int? _hour24(int h, String? meridiem) {
  if (meridiem == null) return h <= 23 ? h : null;
  if (h < 1 || h > 12) return null;
  final pm = meridiem.toLowerCase().startsWith('p');
  if (h == 12) return pm ? 12 : 0;
  return pm ? h + 12 : h;
}

CalendarDate _nextWeekday(
  CalendarDate from,
  int weekday, {
  required bool includeToday,
}) {
  var delta = (weekday - from.weekday) % 7;
  if (delta == 0 && !includeToday) delta = 7;
  return from.addDays(delta);
}

CalendarDate? _dateOrNextYear(
  CalendarDate today,
  int day,
  int month,
  int? year,
) {
  if (month < 1 || month > 12 || day < 1) return null;
  CalendarDate? on(int y) => day > CalendarDate.daysInMonth(y, month)
      ? null
      : CalendarDate(y, month, day);
  if (year != null) return on(year);
  // Without a year: the next time that date comes round, so 29 Feb said in
  // 2027 means 2028.
  for (var y = today.year; y <= today.year + 4; y++) {
    final d = on(y);
    if (d != null && !d.isBefore(today)) return d;
  }
  return null;
}

/// Stands in for text taken out of the title.
const _gap = '\u0000';

/// Weekday abbreviations that are also everyday words.
const _wordLikeDays = {'sat', 'sun'};

/// Connecting words left behind just before a removed date or time
/// ("essay due by [fri]"). Words elsewhere are part of the title.
final _danglingBeforeGap = _re(
  '(?:\\s(?:at|on|by|for|to|in|every|from|and|,|-))+\\s*$_gap',
);

String _cleanTitle(String text) {
  var t = text.replaceAll(_danglingBeforeGap, ' ').replaceAll(_gap, ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll(RegExp(r'\s+,'), ',');
  t = t.replaceAll(RegExp(r'^[,\s-]+|[,\s-]+$'), '');
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}
