import 'package:study_widget/study_widget.dart';

import '../../focus/domain/focus_session.dart';
import '../../reminders/domain/agenda.dart';
import '../../reminders/domain/reminder.dart';
import '../../subjects/domain/subject.dart';

/// How far ahead the home screen widget looks.
const widgetHorizon = Duration(days: 7);

/// How many reminders the widget is given. It shows as many as fit; the
/// rest stand in when the first ones pass before the app sends more.
const widgetLimit = 8;

/// What the home screen widget shows at [now]: the reminders still to come
/// within [horizon], soonest first, at most [limit]. Done and skipped ones
/// are left out, and a snoozed one shows at the end of its snooze. Each gets
/// its subject's colour, from [subjects] by id.
StudyWidgetData buildWidgetData({
  required Agenda agenda,
  required Map<String, Subject> subjects,
  required DateTime now,
  DateTime? focusUntil,
  Duration horizon = widgetHorizon,
  int limit = widgetLimit,
}) {
  final from = now.millisecondsSinceEpoch;
  final until = now.add(horizon).millisecondsSinceEpoch;
  bool comingUp(AgendaItem i) {
    final due = i.dueAt.millisecondsSinceEpoch;
    return !i.isDone && due > from && due <= until;
  }

  int bySoonest(AgendaItem a, AgendaItem b) {
    final byTime = a.dueAt.millisecondsSinceEpoch.compareTo(
      b.dueAt.millisecondsSinceEpoch,
    );
    if (byTime != 0) return byTime;
    final byTitle = a.reminder.title.compareTo(b.reminder.title);
    return byTitle != 0 ? byTitle : a.occurrenceId.compareTo(b.occurrenceId);
  }

  final next = [
    ...agenda.overdue,
    ...agenda.today,
    for (final day in agenda.upcoming) ...day.items,
  ].where(comingUp).toList()..sort(bySoonest);

  return StudyWidgetData(
    items: [
      for (final item in next.take(limit))
        StudyWidgetItem(
          title: switch (item.reminder.title.trim()) {
            '' => 'Reminder',
            final title => title,
          },
          at: item.dueAt,
          color: subjects[item.reminder.subjectId]?.color,
        ),
    ],
    focusUntil: focusUntil != null && focusUntil.isAfter(now)
        ? focusUntil
        : null,
  );
}

/// When the phone's focus session ends, or null when none runs on it.
DateTime? phoneFocusUntil(FocusSessions sessions, DateTime now) {
  final phone = sessions.phone;
  return phone.runsOn(DeviceKind.phone, now) ? phone.endsAt : null;
}
