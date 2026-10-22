import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/domain/subject.dart';
import '../data/reminder_repository.dart';
import '../domain/agenda.dart';
import '../domain/occurrence.dart';
import '../domain/recurrence.dart';
import '../domain/reminder.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepository(
    ref.watch(databaseProvider),
    ref.watch(hlcClockProvider),
  ),
);

final subjectRepositoryProvider = Provider<SubjectRepository>(
  (ref) => SubjectRepository(
    ref.watch(databaseProvider),
    ref.watch(hlcClockProvider),
  ),
);

final remindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchAll(),
);

final occurrenceStatesProvider = StreamProvider<Map<String, OccurrenceState>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchOccurrences(),
);

final subjectsProvider = StreamProvider<List<Subject>>(
  (ref) => ref.watch(subjectRepositoryProvider).watchAll(),
);

/// Live subjects by id, for quick lookups while drawing lists.
final subjectsByIdProvider = Provider<Map<String, Subject>>((ref) {
  final subjects = ref.watch(subjectsProvider).value ?? const [];
  return {for (final s in subjects) s.id: s};
});

final agendaProvider = Provider<AsyncValue<Agenda>>((ref) {
  final reminders = ref.watch(remindersProvider);
  final states = ref.watch(occurrenceStatesProvider);
  final now = ref.watch(minuteTickProvider).value ?? DateTime.now();
  final zone = ref.watch(deviceTimeZoneProvider);
  return combineAsync([reminders, states], () {
    return buildAgenda(
      reminders: reminders.requireValue,
      states: states.requireValue,
      now: now,
      here: resolveLocation(zone),
    );
  });
});
