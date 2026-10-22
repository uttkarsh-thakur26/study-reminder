import '../../focus/domain/focus_plan.dart';

/// One focus session, kept for the stats after the session itself is gone.
/// Written by whichever device starts, extends or stops the session.
class StudySession {
  const StudySession({
    required this.id,
    required this.startedAt,
    required this.endsAt,
    this.stoppedAt,
    this.subjectId,
    this.workMinutes = 0,
    this.breakMinutes = 0,
    this.deleted = false,
  });

  /// The id of the study session for a focus session started at [startedAt].
  static String idFor(DateTime startedAt) =>
      '${startedAt.millisecondsSinceEpoch}';

  final String id;
  final DateTime startedAt;

  /// When it was planned to end, with any time added.
  final DateTime endsAt;

  /// When it was stopped early, if it was.
  final DateTime? stoppedAt;
  final String? subjectId;
  final int workMinutes;
  final int breakMinutes;
  final bool deleted;

  FocusPlan get plan => FocusPlan(
    start: startedAt,
    end: endsAt,
    work: Duration(minutes: workMinutes),
    rest: Duration(minutes: breakMinutes),
  );

  /// When it ended or will end.
  DateTime get endedAt {
    final stop = stoppedAt;
    return stop != null && stop.isBefore(endsAt) ? stop : endsAt;
  }

  /// The working times until [now], without breaks.
  List<({DateTime from, DateTime to})> workSpansUntil(DateTime now) {
    final until = now.isBefore(endedAt) ? now : endedAt;
    return [
      for (final s in plan.workSpans)
        if (s.from.isBefore(until))
          (from: s.from, to: s.to.isBefore(until) ? s.to : until),
    ];
  }

  Map<String, Object?> toFields() => {
    'subject_id': subjectId,
    'started_at': startedAt.toUtc().millisecondsSinceEpoch,
    'ends_at': endsAt.toUtc().millisecondsSinceEpoch,
    'stopped_at': stoppedAt?.toUtc().millisecondsSinceEpoch,
    'work_minutes': workMinutes,
    'break_minutes': breakMinutes,
    'deleted': deleted,
  };

  factory StudySession.fromFields(String id, Map<String, Object?> f) {
    DateTime? time(Object? ms) => ms is num
        ? DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true)
        : null;
    int minutes(Object? v) => v is num ? v.toInt().clamp(0, 600) : 0;
    final start =
        time(f['started_at']) ??
        DateTime.fromMillisecondsSinceEpoch(int.tryParse(id) ?? 0, isUtc: true);
    final end = time(f['ends_at']) ?? start;
    return StudySession(
      id: id,
      startedAt: start,
      endsAt: end.isBefore(start) ? start : end,
      stoppedAt: time(f['stopped_at']),
      subjectId: f['subject_id'] as String?,
      workMinutes: minutes(f['work_minutes']),
      breakMinutes: minutes(f['break_minutes']),
      deleted: f['deleted'] as bool? ?? false,
    );
  }
}
