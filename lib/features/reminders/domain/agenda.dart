import 'package:timezone/timezone.dart' as tz;

import '../../../core/time/calendar_date.dart';
import 'occurrence.dart';
import 'reminder.dart';

/// One occurrence of a reminder, as shown in a list.
class AgendaItem {
  const AgendaItem({
    required this.reminder,
    required this.at,
    required this.status,
    this.snoozeUntil,
  });

  final Reminder reminder;

  /// When the occurrence was scheduled, in the viewing device's zone.
  final tz.TZDateTime at;
  final OccurrenceStatus status;
  final DateTime? snoozeUntil;

  String get occurrenceId => occurrenceIdFor(reminder.id, at);

  bool get isDone =>
      status == OccurrenceStatus.done || status == OccurrenceStatus.skipped;

  /// When it next needs attention: the snooze end if snoozed.
  DateTime get dueAt =>
      status == OccurrenceStatus.snoozed && snoozeUntil != null
      ? snoozeUntil!
      : at;

  bool isMissed(DateTime now) => !isDone && dueAt.isBefore(now);
}

String occurrenceIdFor(String reminderId, DateTime at) =>
    occurrenceId(reminderId, at);

class AgendaDay {
  const AgendaDay(this.date, this.items);
  final CalendarDate date;
  final List<AgendaItem> items;
}

class Agenda {
  const Agenda({
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.todayDate,
  });

  static const horizonDays = 14;

  /// One-off reminders from earlier days that were never handled.
  final List<AgendaItem> overdue;
  final List<AgendaItem> today;

  /// Days after today, each with at least one item.
  final List<AgendaDay> upcoming;
  final CalendarDate todayDate;

  int get openToday => today.where((i) => !i.isDone).length;
}

/// Builds the lists shown on the Today and Upcoming screens.
///
/// [here] is the viewing device's zone; reminders still fire in their own
/// zone, they are just displayed in local time.
Agenda buildAgenda({
  required Iterable<Reminder> reminders,
  required Map<String, OccurrenceState> states,
  required DateTime now,
  required tz.Location here,
  int horizonDays = Agenda.horizonDays,
}) {
  final localNow = tz.TZDateTime.from(now, here);
  final todayDate = CalendarDate(localNow.year, localNow.month, localNow.day);
  final startOfToday = tz.TZDateTime(
    here,
    localNow.year,
    localNow.month,
    localNow.day,
  );
  final tomorrow = todayDate.addDays(1);
  final end = tz.TZDateTime(
    here,
    tomorrow.year,
    tomorrow.month,
    tomorrow.day,
  ).add(Duration(days: horizonDays));

  final overdue = <AgendaItem>[];
  final today = <AgendaItem>[];
  final byDay = <CalendarDate, List<AgendaItem>>{};

  AgendaItem itemFor(Reminder r, DateTime instant) {
    final state = states[occurrenceId(r.id, instant)];
    final live = state != null && !state.deleted;
    return AgendaItem(
      reminder: r,
      at: tz.TZDateTime.from(instant, here),
      status: live ? state.status : OccurrenceStatus.pending,
      snoozeUntil: live ? state.snoozeUntil : null,
    );
  }

  void addByDay(AgendaItem item, DateTime when) {
    final local = tz.TZDateTime.from(when, here);
    final day = CalendarDate(local.year, local.month, local.day);
    if (day == todayDate) {
      today.add(item);
    } else {
      byDay.putIfAbsent(day, () => []).add(item);
    }
  }

  // A snooze can carry an earlier day's occurrence of a repeating reminder
  // past midnight; it still needs to be on a list to be ticked off.
  final carriedOver = <String, List<OccurrenceState>>{};
  for (final s in states.values) {
    final until = s.snoozeUntil;
    if (s.deleted || s.status != OccurrenceStatus.snoozed || until == null) {
      continue;
    }
    if (s.occurrenceAt.isBefore(startOfToday) &&
        !until.isBefore(startOfToday) &&
        until.isBefore(end)) {
      carriedOver.putIfAbsent(s.reminderId, () => []).add(s);
    }
  }

  for (final r in reminders) {
    if (r.deleted || !r.enabled) continue;

    if (!r.recurrence.repeats) {
      final instant = r.schedule.at(r.schedule.anchor);
      if (instant.isBefore(startOfToday)) {
        final item = itemFor(r, instant);
        if (!item.isDone) overdue.add(item);
        continue;
      }
    }

    if (r.recurrence.repeats) {
      for (final s in carriedOver[r.id] ?? const <OccurrenceState>[]) {
        final item = itemFor(r, s.occurrenceAt);
        addByDay(item, item.dueAt);
      }
    }

    for (final instant in r.schedule.occurrencesBetween(startOfToday, end)) {
      final item = itemFor(r, instant);
      addByDay(item, item.at);
    }
  }

  int byTime(AgendaItem a, AgendaItem b) {
    final c = a.at.compareTo(b.at);
    return c != 0 ? c : a.reminder.title.compareTo(b.reminder.title);
  }

  overdue.sort(byTime);
  today.sort(byTime);
  final days = byDay.keys.toList()..sort();
  return Agenda(
    overdue: overdue,
    today: today,
    upcoming: [for (final d in days) AgendaDay(d, byDay[d]!..sort(byTime))],
    todayDate: todayDate,
  );
}
