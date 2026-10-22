import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/stats/domain/study_session.dart';
import 'package:study_reminder/features/stats/domain/study_stats.dart';

void main() {
  // Thursday.
  final now = DateTime(2026, 10, 22, 20);
  const goal = Duration(minutes: 25);

  StudySession session(
    DateTime start,
    int minutes, {
    String? subject,
    int work = 0,
    int rest = 0,
    int rounds = 1,
    DateTime? stoppedAt,
  }) => StudySession(
    id: StudySession.idFor(start),
    startedAt: start.toUtc(),
    phoneUntil: (stoppedAt ?? start.add(Duration(minutes: minutes))).toUtc(),
    subjectId: subject,
    rounds: rounds,
    workMinutes: work,
    breakMinutes: rest,
  );

  test('this week by day and by subject, breaks left out', () {
    final stats = StudyStats.compute(
      [
        // Monday: 2 rounds of 25 with a 5 minute break.
        session(
          DateTime(2026, 10, 19, 9),
          55,
          subject: 'p',
          work: 25,
          rest: 5,
          rounds: 2,
        ),
        // Thursday.
        session(DateTime(2026, 10, 22, 18), 30, subject: 'm'),
        // Last week.
        session(DateTime(2026, 10, 15, 18), 40),
      ],
      now: now,
      goal: goal,
    );
    expect(stats.weekStart, DateTime(2026, 10, 19));
    expect(stats.days[0], const Duration(minutes: 50));
    expect(stats.days[3], const Duration(minutes: 30));
    expect(stats.week, const Duration(minutes: 80));
    expect(stats.lastWeek, const Duration(minutes: 40));
    expect(stats.bySubject, {
      'p': const Duration(minutes: 50),
      'm': const Duration(minutes: 30),
    });
  });

  test('overlapping sessions count once, stopped ones up to the stop', () {
    final stats = StudyStats.compute(
      [
        session(DateTime(2026, 10, 22, 9), 60),
        session(DateTime(2026, 10, 22, 9, 30), 60),
        session(
          DateTime(2026, 10, 22, 14),
          60,
          stoppedAt: DateTime(2026, 10, 22, 14, 10),
        ),
      ],
      now: now,
      goal: goal,
    );
    expect(stats.days[3], const Duration(minutes: 100));
  });

  test('a session on both devices counts until the later end', () {
    final start = DateTime(2026, 10, 22, 9);
    final stats = StudyStats.compute(
      [
        StudySession(
          id: StudySession.idFor(start),
          startedAt: start.toUtc(),
          phoneUntil: start.add(const Duration(minutes: 10)).toUtc(),
          laptopUntil: start.add(const Duration(minutes: 40)).toUtc(),
        ),
      ],
      now: now,
      goal: goal,
    );
    expect(stats.days[3], const Duration(minutes: 40));
  });

  test('a session still running counts until now', () {
    final stats = StudyStats.compute(
      [session(DateTime(2026, 10, 22, 19, 45), 60)],
      now: now,
      goal: goal,
    );
    expect(stats.days[3], const Duration(minutes: 15));
  });

  test('the streak runs to yesterday until today meets the goal', () {
    final days = [
      for (var d = 17; d <= 21; d++) session(DateTime(2026, 10, d, 8), 30),
      // Too short to count.
      session(DateTime(2026, 10, 15, 8), 10),
      session(DateTime(2026, 10, 12, 8), 30),
      session(DateTime(2026, 10, 13, 8), 30),
    ];
    var stats = StudyStats.compute(days, now: now, goal: goal);
    expect(stats.streak, 5);
    expect(stats.bestStreak, 5);

    stats = StudyStats.compute(
      [...days, session(DateTime(2026, 10, 22, 8), 30)],
      now: now,
      goal: goal,
    );
    expect(stats.streak, 6);

    stats = StudyStats.compute(
      [
        session(DateTime(2026, 10, 20, 8), 30),
        session(DateTime(2026, 10, 12, 8), 30),
        session(DateTime(2026, 10, 13, 8), 30),
      ],
      now: now,
      goal: goal,
    );
    expect(stats.streak, 0);
    expect(stats.bestStreak, 2);
  });

  test('time across midnight goes to both days, deleted ones to none', () {
    final stats = StudyStats.compute(
      [
        session(DateTime(2026, 10, 20, 23, 30), 60),
        StudySession(
          id: 'x',
          startedAt: DateTime(2026, 10, 19, 8).toUtc(),
          phoneUntil: DateTime(2026, 10, 19, 9).toUtc(),
          deleted: true,
        ),
      ],
      now: now,
      goal: goal,
    );
    expect(stats.days[0], Duration.zero);
    expect(stats.days[1], const Duration(minutes: 30));
    expect(stats.days[2], const Duration(minutes: 30));
  });
}
