import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:study_widget/study_widget.dart';

import '../../../app/providers.dart';
import '../../focus/application/focus_providers.dart';
import '../../reminders/application/reminder_providers.dart';
import '../domain/widget_payload.dart';

/// The home screen widget. Set at startup on Android.
final studyWidgetProvider = Provider<StudyWidget?>((ref) => null);

/// The home screen widget, for the root ProviderScope.
List<Override> homeWidgetOverrides() => [
  if (StudyWidget.isSupported)
    studyWidgetProvider.overrideWithValue(const StudyWidget()),
];

/// What the home screen widget should show now. Null until the reminders
/// and subjects have loaded.
final homeWidgetDataProvider = Provider<StudyWidgetData?>((ref) {
  final agenda = ref.watch(agendaProvider).value;
  final subjects = ref.watch(subjectsProvider);
  if (agenda == null || !subjects.hasValue) return null;
  final now = ref.watch(minuteTickProvider).value ?? DateTime.now();
  final focus = ref.watch(focusSessionsProvider).value;
  return buildWidgetData(
    agenda: agenda,
    subjects: ref.watch(subjectsByIdProvider),
    now: now,
    focusUntil: focus == null ? null : phoneFocusUntil(focus, now),
  );
});
