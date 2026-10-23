import 'package:flutter/foundation.dart';
import 'package:study_widget/study_widget.dart';

import '../../../app/core_services.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../../focus/data/focus_repository.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../reminders/domain/agenda.dart';
import '../../reminders/domain/recurrence.dart';
import '../../subjects/data/subject_repository.dart';
import '../domain/widget_payload.dart';

/// Brings the home screen widget up to date from the database, for runs
/// without the app's providers: the background sync and the notification
/// buttons. Never throws.
Future<void> refreshHomeWidget(
  CoreServices core, {
  StudyWidget widget = const StudyWidget(),
}) async {
  if (!StudyWidget.isSupported) return;
  try {
    await widget.update(
      await readHomeWidgetData(
        db: core.db,
        clock: core.clock,
        timeZone: core.timeZone,
      ),
    );
  } on Object catch (e) {
    debugPrint('home widget refresh failed: $e');
  }
}

/// What the widget should show at [now], read from [db].
Future<StudyWidgetData> readHomeWidgetData({
  required AppDatabase db,
  required HlcClock clock,
  required String timeZone,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final reminders = ReminderRepository(db, clock);
  final agenda = buildAgenda(
    reminders: await reminders.watchAll().first,
    states: await reminders.watchOccurrences().first,
    now: at,
    here: resolveLocation(timeZone),
  );
  final subjects = await SubjectRepository(db, clock).watchAll().first;
  DateTime? focusUntil;
  try {
    focusUntil = phoneFocusUntil(
      await FocusRepository(db, clock).current(),
      at,
    );
  } on Object catch (e) {
    // The reminders are worth showing without the focus line.
    debugPrint('home widget: focus unavailable: $e');
  }
  return buildWidgetData(
    agenda: agenda,
    subjects: {for (final s in subjects) s.id: s},
    now: at,
    focusUntil: focusUntil,
  );
}
