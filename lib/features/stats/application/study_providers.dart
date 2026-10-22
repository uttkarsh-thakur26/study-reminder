import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/study_repository.dart';
import '../domain/study_session.dart';

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) =>
      StudyRepository(ref.watch(databaseProvider), ref.watch(hlcClockProvider)),
);

/// Every focus session kept for the stats, newest first.
final studySessionsProvider = StreamProvider<List<StudySession>>(
  (ref) => ref.watch(studyRepositoryProvider).watchAll(),
);

/// Minutes of study a day needs to count towards the streak.
final studyGoalProvider = StreamProvider<int>(
  (ref) => ref.watch(studyRepositoryProvider).watchGoalMinutes(),
);
