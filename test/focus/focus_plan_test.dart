import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/domain/focus_plan.dart';

void main() {
  final start = DateTime.utc(2026, 10, 22, 9);
  DateTime at(int minutes) => start.add(Duration(minutes: minutes));

  FocusPlan plan({int rounds = 4, int extra = 0}) => FocusPlan(
    start: start,
    end: FocusPlan.endFor(
      start,
      work: const Duration(minutes: 25),
      rest: const Duration(minutes: 5),
      rounds: rounds,
    ).add(Duration(minutes: extra)),
    work: const Duration(minutes: 25),
    rest: const Duration(minutes: 5),
  );

  test('four rounds of 25 with 5 minute breaks', () {
    final p = plan();
    expect(p.end, at(115));
    expect(p.rounds, 4);
    expect(p.focused, const Duration(minutes: 100));

    final first = p.phaseAt(at(10));
    expect(first.onBreak, isFalse);
    expect(first.round, 1);
    expect(first.endsAt, at(25));

    final rest = p.phaseAt(at(27));
    expect(rest.onBreak, isTrue);
    expect(rest.round, 1);
    expect(rest.startedAt, at(25));
    expect(rest.endsAt, at(30));

    final last = p.phaseAt(at(100));
    expect(last.isLastRound, isTrue);
    expect(last.endsAt, at(115));
    expect(p.nextChangeAfter(at(27)), at(30));
    expect(p.nextChangeAfter(at(115)), isNull);
  });

  test('time added goes to the last round', () {
    final p = plan(extra: 5);
    expect(p.rounds, 4);
    expect(p.workSpans.last, (from: at(90), to: at(120)));
    final one = plan(rounds: 1, extra: 5);
    expect(one.rounds, 1);
    expect(one.phaseAt(at(27)).onBreak, isFalse);
    // A whole round more makes a fifth.
    expect(plan(extra: 30).rounds, 5);
  });

  test('breaks do not count as focus', () {
    final p = plan();
    expect(p.focusedUntil(at(27)), const Duration(minutes: 25));
    expect(p.focusedUntil(at(40)), const Duration(minutes: 35));
  });

  test('without lengths it is one round', () {
    final p = FocusPlan(start: start, end: at(45));
    expect(p.hasBreaks, isFalse);
    expect(p.rounds, 1);
    expect(p.phaseAt(at(30)).endsAt, at(45));
    expect(p.focused, const Duration(minutes: 45));
  });
}
