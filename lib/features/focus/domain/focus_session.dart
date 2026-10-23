import '../../reminders/domain/reminder.dart';
import 'focus_plan.dart';

/// Which devices a focus session runs on.
enum FocusTarget {
  both,
  phone,
  laptop;

  bool includes(DeviceKind kind) =>
      this == both || (this == phone) == (kind == DeviceKind.phone);

  Set<DeviceKind> get kinds => {
    for (final k in DeviceKind.values)
      if (includes(k)) k,
  };

  static FocusTarget only(DeviceKind kind) =>
      kind == DeviceKind.phone ? phone : laptop;

  static FocusTarget parse(String? name) =>
      values.where((t) => t.name == name).firstOrNull ?? both;
}

/// The focus session of one device, the phone or the laptop. Each has its
/// own, so both can focus separately, and either device can start, extend or
/// stop the other's. Starting on both gives each the same session.
class FocusSession {
  const FocusSession({
    this.active = false,
    this.startedAt,
    this.endsAt,
    this.target = FocusTarget.both,
    this.blockApps = true,
    this.quiet = true,
    this.strict = false,
    this.startedBy = '',
    this.rounds = 1,
    this.workMinutes = 0,
    this.breakMinutes = 0,
    this.subjectId,
    this.doneMs = 0,
    this.pausedAt,
    this.version = '',
  });

  /// The record id of [kind]'s session.
  static String idFor(DeviceKind kind) => kind.name;

  static final ids = {for (final k in DeviceKind.values) idFor(k)};

  static const idle = FocusSession();

  /// False once stopped early. A session that ran out stays active, with
  /// [endsAt] in the past.
  final bool active;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final FocusTarget target;

  /// Block the apps and sites on each device's block list.
  final bool blockApps;

  /// Do Not Disturb on the phone.
  final bool quiet;

  /// No stopping early, and blocked laptop apps are closed, not minimised.
  final bool strict;

  /// The name of the device it was started on.
  final String startedBy;

  /// Rounds of [workMinutes] with breaks of [breakMinutes] between them,
  /// planned at the start; time added goes to the last. See [FocusPlan].
  final int rounds;
  final int workMinutes;
  final int breakMinutes;

  /// What is being studied, for the stats. Null for no subject.
  final String? subjectId;

  /// For a session resumed after a pause: how far into its plan, rounds and
  /// breaks included, it already was. 0 otherwise.
  final int doneMs;

  /// When it was paused. A paused session is stopped, [active] false, and
  /// keeps the time it had left until it is resumed. Null otherwise.
  final DateTime? pausedAt;

  /// Which edit of the session this is: its newest field stamp. Sorts as
  /// text in the order the edits were made on every device. Empty for a
  /// session never saved here. Not a synced field.
  final String version;

  /// Started together with [other], on both devices, and still alike.
  bool sameAs(FocusSession other) =>
      startedAt == other.startedAt &&
      endsAt == other.endsAt &&
      blockApps == other.blockApps &&
      quiet == other.quiet &&
      strict == other.strict &&
      rounds == other.rounds &&
      workMinutes == other.workMinutes &&
      breakMinutes == other.breakMinutes &&
      subjectId == other.subjectId &&
      doneMs == other.doneMs &&
      pausedAt == other.pausedAt;

  /// Paused with time left, so it can be resumed.
  bool get isPaused =>
      !active &&
      pausedAt != null &&
      startedAt != null &&
      endsAt != null &&
      pausedAt!.isBefore(endsAt!);

  /// The time a paused session had left.
  Duration get pausedLeft =>
      isPaused ? endsAt!.difference(pausedAt!) : Duration.zero;

  bool runningAt(DateTime now) =>
      active && endsAt != null && now.isBefore(endsAt!);

  bool runsOn(DeviceKind kind, DateTime now) =>
      runningAt(now) && target.includes(kind);

  Duration remainingAt(DateTime now) =>
      runningAt(now) ? endsAt!.difference(now) : Duration.zero;

  Duration get length => startedAt != null && endsAt != null
      ? endsAt!.difference(startedAt!)
      : Duration.zero;

  /// Its rounds and breaks. Only for a session with a start and an end. A
  /// resumed session carries on the plan of the one it continues.
  FocusPlan get plan => FocusPlan(
    start: startedAt!.subtract(Duration(milliseconds: doneMs)),
    since: startedAt,
    end: endsAt!,
    work: Duration(minutes: workMinutes),
    rest: Duration(minutes: breakMinutes),
    rounds: rounds,
  );

  /// The round or break at [now], while it runs.
  FocusPhase? phaseAt(DateTime now) =>
      runningAt(now) ? plan.phaseAt(now) : null;

  /// The round or break it was paused in.
  FocusPhase? get pausedPhase => isPaused ? plan.phaseAt(pausedAt!) : null;

  bool onBreakAt(DateTime now) => phaseAt(now)?.onBreak ?? false;

  /// Whether [kind] should be blocking and quiet at [now]: the session runs
  /// there and is not on a break.
  bool enforcesOn(DeviceKind kind, DateTime now) =>
      runsOn(kind, now) && !onBreakAt(now);

  /// When the next round or break begins, or the session ends. Null when
  /// it is not running.
  DateTime? nextChangeAfter(DateTime now) =>
      runningAt(now) ? plan.nextChangeAfter(now) : null;

  FocusSession copyWith({
    bool? active,
    DateTime? startedAt,
    DateTime? endsAt,
    FocusTarget? target,
    bool? blockApps,
    bool? quiet,
    bool? strict,
    String? startedBy,
  }) => FocusSession(
    active: active ?? this.active,
    startedAt: startedAt ?? this.startedAt,
    endsAt: endsAt ?? this.endsAt,
    target: target ?? this.target,
    blockApps: blockApps ?? this.blockApps,
    quiet: quiet ?? this.quiet,
    strict: strict ?? this.strict,
    startedBy: startedBy ?? this.startedBy,
    rounds: rounds,
    workMinutes: workMinutes,
    breakMinutes: breakMinutes,
    subjectId: subjectId,
    doneMs: doneMs,
    pausedAt: pausedAt,
  );

  /// Stopped for good: no longer paused either.
  FocusSession ended() => FocusSession(
    startedAt: startedAt,
    endsAt: endsAt,
    target: target,
    blockApps: blockApps,
    quiet: quiet,
    strict: strict,
    startedBy: startedBy,
    rounds: rounds,
    workMinutes: workMinutes,
    breakMinutes: breakMinutes,
    subjectId: subjectId,
    doneMs: doneMs,
  );

  /// Paused at [at], with the time left kept for [resumedAt].
  FocusSession pausedAtTime(DateTime at) => FocusSession(
    startedAt: startedAt,
    endsAt: endsAt,
    target: target,
    blockApps: blockApps,
    quiet: quiet,
    strict: strict,
    startedBy: startedBy,
    rounds: rounds,
    workMinutes: workMinutes,
    breakMinutes: breakMinutes,
    subjectId: subjectId,
    doneMs: doneMs,
    pausedAt: at,
  );

  /// A paused session started again at [at], where it left off: a new
  /// session with the time that was left, in the same round or break.
  FocusSession resumedAt(DateTime at) => FocusSession(
    active: true,
    startedAt: at,
    endsAt: at.add(pausedLeft),
    target: target,
    blockApps: blockApps,
    quiet: quiet,
    strict: strict,
    startedBy: startedBy,
    rounds: rounds,
    workMinutes: workMinutes,
    breakMinutes: breakMinutes,
    subjectId: subjectId,
    doneMs: doneMs + pausedAt!.difference(startedAt!).inMilliseconds,
  );

  FocusSession withSubject(String? id) => FocusSession(
    active: active,
    startedAt: startedAt,
    endsAt: endsAt,
    target: target,
    blockApps: blockApps,
    quiet: quiet,
    strict: strict,
    startedBy: startedBy,
    rounds: rounds,
    workMinutes: workMinutes,
    breakMinutes: breakMinutes,
    subjectId: id,
    doneMs: doneMs,
    pausedAt: pausedAt,
  );

  Map<String, Object?> toFields() => {
    'active': active,
    'started_at': startedAt?.toUtc().millisecondsSinceEpoch,
    'ends_at': endsAt?.toUtc().millisecondsSinceEpoch,
    'target': target.name,
    'block_apps': blockApps,
    'quiet': quiet,
    'strict': strict,
    'started_by': startedBy,
    'rounds': rounds,
    'work_minutes': workMinutes,
    'break_minutes': breakMinutes,
    'subject_id': subjectId,
    'done_ms': doneMs,
    'paused_at': pausedAt?.toUtc().millisecondsSinceEpoch,
  };

  /// The fields a start sets that older versions of the app do not know.
  /// A start made there leaves the previous session's values in place.
  static const startFields = [
    'rounds',
    'work_minutes',
    'break_minutes',
    'subject_id',
    'done_ms',
    'paused_at',
  ];

  factory FocusSession.fromFields(Map<String, Object?> f) {
    DateTime? time(Object? ms) => ms is num
        ? DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true)
        : null;
    return FocusSession(
      active: f['active'] as bool? ?? false,
      startedAt: time(f['started_at']),
      endsAt: time(f['ends_at']),
      target: FocusTarget.parse(f['target'] as String?),
      blockApps: f['block_apps'] as bool? ?? true,
      quiet: f['quiet'] as bool? ?? true,
      strict: f['strict'] as bool? ?? false,
      startedBy: f['started_by'] as String? ?? '',
      rounds: f['rounds'] is num
          ? (f['rounds']! as num).toInt().clamp(1, 100)
          : 1,
      workMinutes: _minutes(f['work_minutes']),
      breakMinutes: _minutes(f['break_minutes']),
      subjectId: f['subject_id'] as String?,
      doneMs: f['done_ms'] is num
          ? (f['done_ms']! as num).toInt().clamp(0, 7 * 24 * 3600 * 1000)
          : 0,
      pausedAt: time(f['paused_at']),
    );
  }

  static int _minutes(Object? v) => v is num ? v.toInt().clamp(0, 600) : 0;
}

/// The phone's and the laptop's sessions.
class FocusSessions {
  const FocusSessions({
    this.phone = FocusSession.idle,
    this.laptop = FocusSession.idle,
  });

  static const idle = FocusSessions();

  final FocusSession phone;
  final FocusSession laptop;

  FocusSession of(DeviceKind kind) => kind == DeviceKind.phone ? phone : laptop;

  /// [kind], and the other device when it runs the same session: what a
  /// change to [kind]'s session applies to, so the two stay alike.
  Set<DeviceKind> sharing(DeviceKind kind, DateTime now) {
    final other = kind == DeviceKind.phone
        ? DeviceKind.laptop
        : DeviceKind.phone;
    final o = of(other);
    return {
      kind,
      if ((o.runningAt(now) || o.isPaused) && o.sameAs(of(kind))) other,
    };
  }

  /// The devices with a session paused.
  Set<DeviceKind> get paused => {
    for (final k in DeviceKind.values)
      if (of(k).isPaused) k,
  };

  /// The devices with a session running.
  Set<DeviceKind> busyAt(DateTime now) => {
    for (final k in DeviceKind.values)
      if (of(k).runningAt(now)) k,
  };

  /// Where a session the user wants on [wanted] can start: the devices among
  /// those with none running, or with [orFree] any free one when none of
  /// those is. With no paired device, only [here].
  Set<DeviceKind> startable(
    FocusTarget wanted, {
    required DeviceKind here,
    required bool paired,
    required DateTime now,
    bool orFree = true,
  }) {
    // A paused session holds its device until it is resumed or stopped.
    final free = (paired ? DeviceKind.values.toSet() : {here})
        .difference(busyAt(now))
        .difference(paused);
    final both = paired ? wanted.kinds.intersection(free) : free;
    return both.isNotEmpty || !orFree ? both : free;
  }
}
