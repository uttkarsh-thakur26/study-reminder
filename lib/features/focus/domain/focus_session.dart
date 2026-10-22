import '../../reminders/domain/reminder.dart';

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
      strict == other.strict;

  bool runningAt(DateTime now) =>
      active && endsAt != null && now.isBefore(endsAt!);

  bool runsOn(DeviceKind kind, DateTime now) =>
      runningAt(now) && target.includes(kind);

  Duration remainingAt(DateTime now) =>
      runningAt(now) ? endsAt!.difference(now) : Duration.zero;

  Duration get length => startedAt != null && endsAt != null
      ? endsAt!.difference(startedAt!)
      : Duration.zero;

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
  };

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
    );
  }
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
    final free = (paired ? DeviceKind.values.toSet() : {here}).difference(
      busyAt(now),
    );
    final both = paired ? wanted.kinds.intersection(free) : free;
    return both.isNotEmpty || !orFree ? both : free;
  }
}
