import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/reminders/application/reminder_providers.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:study_reminder/features/stats/application/study_providers.dart';
import 'package:study_reminder/features/stats/domain/study_session.dart';
import 'package:study_reminder/features/stats/ui/study_screen.dart';
import 'package:study_reminder/features/subjects/domain/subject.dart';

void main() {
  testWidgets('shows the week, the streak and time per subject', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    StudySession session(DateTime start, int minutes, {String? subject}) =>
        StudySession(
          id: StudySession.idFor(start),
          startedAt: start.toUtc(),
          endsAt: start.add(Duration(minutes: minutes)).toUtc(),
          subjectId: subject,
        );
    final sessions = [
      session(today.add(const Duration(minutes: 1)), 30, subject: 'p'),
      session(DateTime(today.year, today.month, today.day - 1, 8), 30),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studySessionsProvider.overrideWith((ref) => Stream.value(sessions)),
          studyGoalProvider.overrideWith((ref) => Stream.value(25)),
          subjectsProvider.overrideWith(
            (ref) => Stream.value(const [
              Subject(id: 'p', name: 'Physics', color: 0xFF6366F1),
            ]),
          ),
          remindersProvider.overrideWith(
            (ref) => Stream.value(const <Reminder>[]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: StudyScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Study'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);
    expect(find.textContaining('Today 30 min of 25 min'), findsOneWidget);
    expect(find.textContaining('30 min this week'), findsOneWidget);
    expect(find.text('Physics'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
