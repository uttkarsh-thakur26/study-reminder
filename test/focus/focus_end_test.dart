import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';
import 'package:study_reminder/features/focus/ui/focus_coordinator.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 15, 10);
  DateTime at(int minutes, [int seconds = 0]) =>
      t0.add(Duration(minutes: minutes, seconds: seconds));

  FocusSession running({DateTime? from, int minutes = 25}) => FocusSession(
    active: true,
    startedAt: from ?? t0,
    endsAt: (from ?? t0).add(Duration(minutes: minutes)),
    target: FocusTarget.laptop,
  );

  test('a session that runs out rings, at its end', () {
    final s = running();
    expect(focusRanOut(before: s, session: s, now: at(24, 59)), isFalse);
    expect(focusRanOut(before: s, session: s, now: at(25)), isTrue);
    expect(focusRanOut(before: s, session: s, now: at(26, 30)), isTrue);
  });

  test('not long after the end, when the laptop slept through it', () {
    final s = running();
    expect(focusRanOut(before: s, session: s, now: at(28)), isFalse);
  });

  test('not when it was stopped or paused', () {
    final s = running();
    expect(focusRanOut(before: s, session: s.ended(), now: at(25)), isFalse);
    expect(
      focusRanOut(before: s, session: s.pausedAtTime(at(10)), now: at(25)),
      isFalse,
    );
  });

  test('not for a session that was not running here before', () {
    final s = running();
    expect(focusRanOut(before: null, session: s, now: at(25)), isFalse);
    final other = running(from: at(-60), minutes: 30);
    expect(focusRanOut(before: other, session: s, now: at(25)), isFalse);
  });

  test('time added moves the alarm to the new end', () {
    final s = running();
    final longer = s.copyWith(endsAt: at(35));
    expect(focusRanOut(before: s, session: longer, now: at(25)), isFalse);
    expect(focusRanOut(before: longer, session: longer, now: at(35)), isTrue);
  });

  test('the minutes of focus leave breaks out and count before a pause', () {
    final rounds = FocusSession(
      active: true,
      startedAt: t0,
      endsAt: at(55),
      rounds: 2,
      workMinutes: 25,
      breakMinutes: 5,
    );
    expect(rounds.focusedInAll, const Duration(minutes: 50));
    final resumed = rounds.pausedAtTime(at(10)).resumedAt(at(40));
    expect(resumed.endsAt, at(85));
    expect(resumed.focusedInAll, const Duration(minutes: 50));
  });
}
