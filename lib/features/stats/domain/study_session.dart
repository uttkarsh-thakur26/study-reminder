import '../../focus/domain/focus_plan.dart';
import '../../reminders/domain/reminder.dart';

/// One focus session, kept for the stats after the session itself is gone.
/// Written by whichever device starts, extends or stops the session.
///
/// A session started on both devices is one study session. Each device's
/// end is a field of its own, written only when that device's session
/// changes, so two devices stopping at once, before they hear of each
/// other, both count.
class StudySession {
  const StudySession({
    required this.id,
    required this.startedAt,
    this.phoneUntil,
    this.laptopUntil,
    this.subjectId,
    this.rounds = 1,
    this.workMinutes = 0,
    this.breakMinutes = 0,
    this.deleted = false,
  });

  /// The id of the study session for a focus session started at [startedAt].
  static String idFor(DateTime startedAt) =>
      '${startedAt.millisecondsSinceEpoch}';

  /// The field holding [kind]'s end.
  static String untilField(DeviceKind kind) => '${kind.name}_until';

  final String id;
  final DateTime startedAt;

  /// When the session ended or will end on the phone and on the laptop:
  /// the planned end, with any time added, or when it was stopped early.
  /// Null for a device it did not run on.
  final DateTime? phoneUntil;
  final DateTime? laptopUntil;
  final String? subjectId;
  final int rounds;
  final int workMinutes;
  final int breakMinutes;
  final bool deleted;

  DateTime? untilOn(DeviceKind kind) =>
      kind == DeviceKind.phone ? phoneUntil : laptopUntil;

  /// When it ended or will end on the last device it runs on.
  DateTime get endedAt {
    var end = startedAt;
    for (final t in [phoneUntil, laptopUntil]) {
      if (t != null && t.isAfter(end)) end = t;
    }
    return end;
  }

  FocusPlan get plan => FocusPlan(
    start: startedAt,
    end: endedAt,
    work: Duration(minutes: workMinutes),
    rest: Duration(minutes: breakMinutes),
    rounds: rounds,
  );

  /// The working times until [now], without breaks.
  List<({DateTime from, DateTime to})> workSpansUntil(DateTime now) => [
    for (final s in plan.workSpans)
      if (s.from.isBefore(now))
        (from: s.from, to: s.to.isBefore(now) ? s.to : now),
  ];

  Map<String, Object?> toFields() => {
    'subject_id': subjectId,
    'started_at': startedAt.toUtc().millisecondsSinceEpoch,
    untilField(DeviceKind.phone): phoneUntil?.toUtc().millisecondsSinceEpoch,
    untilField(DeviceKind.laptop): laptopUntil?.toUtc().millisecondsSinceEpoch,
    'rounds': rounds,
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
    DateTime? until(DeviceKind kind) {
      final t = time(f[untilField(kind)]);
      return t == null || t.isBefore(start) ? null : t;
    }

    return StudySession(
      id: id,
      startedAt: start,
      phoneUntil: until(DeviceKind.phone),
      laptopUntil: until(DeviceKind.laptop),
      subjectId: f['subject_id'] as String?,
      rounds: f['rounds'] is num
          ? (f['rounds']! as num).toInt().clamp(1, 100)
          : 1,
      workMinutes: minutes(f['work_minutes']),
      breakMinutes: minutes(f['break_minutes']),
      deleted: f['deleted'] as bool? ?? false,
    );
  }
}
