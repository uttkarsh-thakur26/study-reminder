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

/// The rounds of a session from [start] to [end]: [work], a break of
/// [rest], [work] again, and so on, the last round running to the end. With
/// no work or rest length it is one round.
///
/// Only the start, the end and the two lengths are stored, so every device
/// works out the same rounds, and time added to a session goes to its last
/// round. The phone works this out in Kotlin as well (FocusState.phaseAt),
/// for sessions it gets with the app closed; keep the two alike.
class FocusPlan {
  const FocusPlan({
    required this.start,
    required this.end,
    this.work = Duration.zero,
    this.rest = Duration.zero,
  });

  final DateTime start;
  final DateTime end;
  final Duration work;
  final Duration rest;

  /// The end of a session of [rounds] rounds of [work], with breaks of
  /// [rest] between them.
  static DateTime endFor(
    DateTime start, {
    required Duration work,
    required Duration rest,
    required int rounds,
  }) => start.add(work * rounds + rest * max(0, rounds - 1));

  bool get hasBreaks => work > Duration.zero && rest > Duration.zero;

  int get rounds {
    if (!hasBreaks) return 1;
    final total = end.difference(start).inMicroseconds;
    final cycle = (work + rest).inMicroseconds;
    return max(1, (total + rest.inMicroseconds) ~/ cycle);
  }

  /// The rounds' working times, in order.
  List<({DateTime from, DateTime to})> get workSpans {
    final n = rounds;
    if (n == 1) return [(from: start, to: end)];
    final cycle = work + rest;
    return [
      for (var k = 0; k < n - 1; k++)
        (from: start.add(cycle * k), to: start.add(cycle * k + work)),
      (from: start.add(cycle * (n - 1)), to: end),
    ];
  }

  /// The round or break at [now], which must be within the session; times
  /// before it count as its first round and after it as its last.
  FocusPhase phaseAt(DateTime now) {
    final spans = workSpans;
    final n = spans.length;
    for (var k = 0; k < n; k++) {
      final span = spans[k];
      if (k == n - 1 || now.isBefore(span.to)) {
        return FocusPhase(
          onBreak: false,
          round: k + 1,
          rounds: n,
          startedAt: span.from,
          endsAt: span.to,
        );
      }
      final next = spans[k + 1].from;
      if (now.isBefore(next)) {
        return FocusPhase(
          onBreak: true,
          round: k + 1,
          rounds: n,
          startedAt: span.to,
          endsAt: next,
        );
      }
    }
    throw StateError('unreachable');
  }

  /// When the phase at [now] gives way to the next one, or the session
  /// ends. Null once it has.
  DateTime? nextChangeAfter(DateTime now) {
    if (!now.isBefore(end)) return null;
    return phaseAt(now).endsAt;
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
