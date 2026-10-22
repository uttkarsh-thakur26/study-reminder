import 'study_session.dart';

typedef _Span = ({DateTime from, DateTime to});

/// Study time worked out from the focus sessions: this week by day and by
/// subject, and the streak of days on which the daily goal was met.
///
/// Time counts once even when sessions overlap, such as one on the phone
/// and one on the laptop at the same time. Breaks do not count.
class StudyStats {
  const StudyStats({
    required this.weekStart,
    required this.days,
    required this.lastWeek,
    required this.bySubject,
    required this.streak,
    required this.bestStreak,
    required this.goal,
  });

  /// The first day of this week, local midnight.
  final DateTime weekStart;

  /// Study time on each day of this week, from [weekStart].
  final List<Duration> days;

  /// Study time last week, to compare with.
  final Duration lastWeek;

  /// Study time this week per subject id; null for no subject.
  final Map<String?, Duration> bySubject;

  /// Days in a row the goal was met, up to today. Today counts once met;
  /// until then the streak runs to yesterday.
  final int streak;
  final int bestStreak;
  final Duration goal;

  Duration get week => days.fold(Duration.zero, (a, b) => a + b);

  static StudyStats compute(
    Iterable<StudySession> sessions, {
    required DateTime now,
    required Duration goal,
    int firstWeekday = DateTime.monday,
  }) {
    final local = now.toLocal();
    final today = _day(local);
    final weekStart = _addDays(today, -((today.weekday - firstWeekday) % 7));
    final weekEnd = _addDays(weekStart, 7);
    final lastWeekStart = _addDays(weekStart, -7);

    final live = [
      for (final s in sessions)
        if (s.countsAt(now)) s,
    ];
    final all = _merge([for (final s in live) ...s.workSpansUntil(now)]);
    final perDay = _perDay(all);

    final days = [
      for (var i = 0; i < 7; i++)
        perDay[_addDays(weekStart, i)] ?? Duration.zero,
    ];
    final lastWeek = _within(all, lastWeekStart, weekStart);

    final bySubjectSpans = <String?, List<_Span>>{};
    for (final s in live) {
      (bySubjectSpans[s.subjectId] ??= []).addAll(s.workSpansUntil(now));
    }
    final bySubject = <String?, Duration>{
      for (final e in bySubjectSpans.entries)
        e.key: _within(_merge(e.value), weekStart, weekEnd),
    }..removeWhere((_, d) => d == Duration.zero);

    bool met(DateTime day) =>
        (perDay[day] ?? Duration.zero) >= goal && goal > Duration.zero;
    var streak = 0;
    var day = met(today) ? today : _addDays(today, -1);
    while (met(day)) {
      streak++;
      day = _addDays(day, -1);
    }

    final metDays = perDay.keys.where(met).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final d in metDays) {
      run = previous != null && _addDays(previous, 1) == d ? run + 1 : 1;
      if (run > best) best = run;
      previous = d;
    }

    return StudyStats(
      weekStart: weekStart,
      days: days,
      lastWeek: lastWeek,
      bySubject: bySubject,
      streak: streak,
      bestStreak: best < streak ? streak : best,
      goal: goal,
    );
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Calendar days, so a change of clocks does not shift midnight.
  static DateTime _addDays(DateTime day, int n) =>
      DateTime(day.year, day.month, day.day + n);

  /// The spans joined where they overlap, in order, in local time.
  static List<_Span> _merge(List<_Span> spans) {
    final sorted = [
      for (final s in spans)
        if (s.to.isAfter(s.from)) (from: s.from.toLocal(), to: s.to.toLocal()),
    ]..sort((a, b) => a.from.compareTo(b.from));
    final out = <_Span>[];
    for (final s in sorted) {
      if (out.isNotEmpty && !s.from.isAfter(out.last.to)) {
        final last = out.removeLast();
        out.add((from: last.from, to: s.to.isAfter(last.to) ? s.to : last.to));
      } else {
        out.add(s);
      }
    }
    return out;
  }

  /// Time per local day, split at midnight.
  static Map<DateTime, Duration> _perDay(List<_Span> merged) {
    final out = <DateTime, Duration>{};
    for (final s in merged) {
      var day = _day(s.from);
      while (day.isBefore(s.to)) {
        final next = _addDays(day, 1);
        final from = s.from.isAfter(day) ? s.from : day;
        final to = s.to.isBefore(next) ? s.to : next;
        if (to.isAfter(from)) {
          out[day] = (out[day] ?? Duration.zero) + to.difference(from);
        }
        day = next;
      }
    }
    return out;
  }

  static Duration _within(List<_Span> merged, DateTime from, DateTime to) {
    var total = Duration.zero;
    for (final s in merged) {
      final a = s.from.isAfter(from) ? s.from : from;
      final b = s.to.isBefore(to) ? s.to : to;
      if (b.isAfter(a)) total += b.difference(a);
    }
    return total;
  }
}
