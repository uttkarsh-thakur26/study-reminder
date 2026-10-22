import 'dart:math';

/// Where a session is at a given moment.
class FocusPhase {
  const FocusPhase({
    required this.onBreak,
    required this.round,
    required this.rounds,
    required this.startedAt,
    required this.endsAt,
  });

  /// A break between two rounds: nothing is blocked.
  final bool onBreak;

  /// The round running, or the one just finished during a break. From 1.
  final int round;
  final int rounds;
  final DateTime startedAt;
  final DateTime endsAt;

  bool get isLastRound => round == rounds;

  Duration get length => endsAt.difference(startedAt);

  @override
  bool operator ==(Object other) =>
      other is FocusPhase &&
      other.onBreak == onBreak &&
      other.round == round &&
      other.rounds == rounds &&
      other.startedAt == startedAt &&
      other.endsAt == endsAt;

  @override
  int get hashCode => Object.hash(onBreak, round, rounds, startedAt, endsAt);
}

/// The rounds of a session from [start] to [end]: [rounds] rounds of
/// [work] with a break of [rest] after each but the last, which runs to the
/// end. Time added to a session so goes to its last round, and an end
/// before the plan's (a session stopped early) cuts it short. With no work
/// or rest length, or one round, it is a single round.
///
/// Every device works out the same rounds from these values. The phone does
/// it in Kotlin as well (FocusState.phaseAt), for sessions it gets with the
/// app closed; keep the two alike.
class FocusPlan {
  const FocusPlan({
    required this.start,
    required this.end,
    this.work = Duration.zero,
    this.rest = Duration.zero,
    this._rounds = 1,
  });

  final DateTime start;
  final DateTime end;
  final Duration work;
  final Duration rest;
  final int _rounds;

  /// The end of a session of [rounds] rounds of [work], with breaks of
  /// [rest] between them.
  static DateTime endFor(
    DateTime start, {
    required Duration work,
    required Duration rest,
    required int rounds,
  }) => start.add(work * rounds + rest * max(0, rounds - 1));

  bool get hasBreaks =>
      work > Duration.zero && rest > Duration.zero && _rounds > 1;

  int get rounds => hasBreaks ? _rounds : 1;

  /// The rounds' working times up to [end], in order.
  List<({DateTime from, DateTime to})> get workSpans {
    final n = rounds;
    if (n == 1) return end.isAfter(start) ? [(from: start, to: end)] : [];
    final cycle = work + rest;
    final out = <({DateTime from, DateTime to})>[];
    for (var k = 0; k < n; k++) {
      final from = start.add(cycle * k);
      if (!from.isBefore(end)) break;
      final planned = from.add(work);
      final to = k == n - 1 || planned.isAfter(end) ? end : planned;
      out.add((from: from, to: to));
    }
    return out;
  }

  /// The round or break at [now], which must be within the session; times
  /// before it count as its first round and after it as its last.
  FocusPhase phaseAt(DateTime now) {
    final n = rounds;
    if (n == 1) {
      return FocusPhase(
        onBreak: false,
        round: 1,
        rounds: 1,
        startedAt: start,
        endsAt: end,
      );
    }
    final cycle = work + rest;
    for (var k = 0; k < n - 1; k++) {
      final from = start.add(cycle * k);
      final workEnd = from.add(work);
      if (now.isBefore(workEnd)) {
        return FocusPhase(
          onBreak: false,
          round: k + 1,
          rounds: n,
          startedAt: from,
          endsAt: workEnd,
        );
      }
      final next = from.add(cycle);
      if (now.isBefore(next)) {
        return FocusPhase(
          onBreak: true,
          round: k + 1,
          rounds: n,
          startedAt: workEnd,
          endsAt: next,
        );
      }
    }
    return FocusPhase(
      onBreak: false,
      round: n,
      rounds: n,
      startedAt: start.add(cycle * (n - 1)),
      endsAt: end,
    );
  }

  /// When the phase at [now] gives way to the next one, or the session
  /// ends. Null once it has.
  DateTime? nextChangeAfter(DateTime now) {
    if (!now.isBefore(end)) return null;
    final at = phaseAt(now).endsAt;
    return at.isAfter(end) ? end : at;
  }

  /// The working time from the start until [until], not counting breaks.
  Duration focusedUntil(DateTime until) {
    var total = Duration.zero;
    for (final s in workSpans) {
      if (!until.isAfter(s.from)) break;
      final to = until.isBefore(s.to) ? until : s.to;
      total += to.difference(s.from);
    }
    return total;
  }

  /// The total working time, not counting breaks.
  Duration get focused => focusedUntil(end);
}
