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
    expect(focusEndNote(before: s, session: s, now: at(24, 59)), isNull);
    expect(focusEndNote(before: s, session: s, now: at(25)), FocusEndNote.ring);
    expect(
      focusEndNote(before: s, session: s, now: at(26, 30)),
      FocusEndNote.ring,
    );
  });

  test('long after the end it is a quiet note: the laptop slept', () {
    final s = running();
    expect(
      focusEndNote(before: s, session: s, now: at(28)),
      FocusEndNote.quiet,
    );
  });

  test('not when it was stopped or paused', () {
    final s = running();
    expect(focusEndNote(before: s, session: s.ended(), now: at(25)), isNull);
    expect(
      focusEndNote(before: s, session: s.pausedAtTime(at(10)), now: at(25)),
      isNull,
    );
  });

  test('not for a session that was not running here before', () {
    final s = running();
    expect(focusEndNote(before: null, session: s, now: at(25)), isNull);
    final other = running(from: at(-60), minutes: 30);
    expect(focusEndNote(before: other, session: s, now: at(25)), isNull);
  });

  test('time added moves the alarm to the new end', () {
    final s = running();
    final longer = s.copyWith(endsAt: at(35));
    expect(focusEndNote(before: s, session: longer, now: at(25)), isNull);
    expect(
      focusEndNote(before: longer, session: longer, now: at(35)),
      FocusEndNote.ring,
    );
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
