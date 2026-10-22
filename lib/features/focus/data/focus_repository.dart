import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/stamped_write.dart';
import '../../reminders/domain/reminder.dart';
import '../../stats/data/study_repository.dart';
import '../../stats/domain/study_session.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';

/// The phone's and the laptop's focus sessions, and this device's Focus
/// settings. Every change to a session also updates its [StudySession], so
/// the stats see it.
class FocusRepository {
  FocusRepository(this._db, this._clock);

  final AppDatabase _db;
  final HlcClock _clock;

  Stream<FocusSessions> watch() => _query().watch().map(_sessions);

  Future<FocusSessions> current() async => _sessions(await _query().get());

  SimpleSelectStatement<$FocusSessionsTable, FocusSessionRow> _query() =>
      _db.select(_db.focusSessions)..where((f) => f.id.isIn(FocusSession.ids));

  static FocusSessions _sessions(List<FocusSessionRow> rows) {
    FocusSession of(DeviceKind kind) {
      final row = rows
          .where((r) => r.id == FocusSession.idFor(kind))
          .firstOrNull;
      return row == null ? FocusSession.idle : focusSessionFromRow(row);
    }

    return FocusSessions(
      phone: of(DeviceKind.phone),
      laptop: of(DeviceKind.laptop),
    );
  }

  /// Starts a session of [length] from [now] on each of [on] that has none
  /// running, so one that began meanwhile (on the other device, say) is
  /// kept. Devices started together get the same session. With [work] and
  /// [rest] it runs in rounds with breaks between them, see `FocusPlan`.
  Future<void> start({
    required Set<DeviceKind> on,
    required Duration length,
    required bool blockApps,
    required bool quiet,
    required bool strict,
    required String startedBy,
    Duration work = Duration.zero,
    Duration rest = Duration.zero,
    String? subjectId,
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    final rounds = work > Duration.zero && rest > Duration.zero;
    // Stamps every field: a new session replaces the old one whole, so two
    // starts made at once never merge into a mix of both.
    return _update(
      on,
      at: at,
      whole: true,
      (kind, current) => current.runningAt(at)
          ? null
          : FocusSession(
              active: true,
              startedAt: at,
              endsAt: at.add(length),
              target: FocusTarget.only(kind),
              blockApps: blockApps,
              quiet: quiet,
              strict: strict,
              startedBy: startedBy,
              workMinutes: rounds ? work.inMinutes : 0,
              breakMinutes: rounds ? rest.inMinutes : 0,
              subjectId: subjectId,
            ),
    );
  }

  /// Starts a session on [on] with this device's Focus settings.
  Future<void> startWith(
    FocusPrefs prefs, {
    required Set<DeviceKind> on,
    required String startedBy,
    DateTime? now,
  }) => start(
    on: on,
    length: prefs.length,
    work: prefs.work,
    rest: prefs.rest,
    subjectId: prefs.subjectId,
    blockApps: prefs.blockApps,
    quiet: prefs.quiet,
    strict: prefs.strict,
    startedBy: startedBy,
    now: now,
  );

  Future<void> stop(Set<DeviceKind> on, {DateTime? now}) => _update(
    on,
    at: (now ?? DateTime.now()).toUtc(),
    (_, s) => s.copyWith(active: false),
  );

  /// Moves the end of the sessions running on [on] by [by].
  Future<void> extend(Set<DeviceKind> on, Duration by, {DateTime? now}) {
    final at = (now ?? DateTime.now()).toUtc();
    return _update(on, at: at, (_, s) {
      if (!s.runningAt(at)) return s;
      return s.copyWith(endsAt: s.endsAt!.add(by));
    });
  }

  /// Changes what the sessions running on [on] are for.
  Future<void> setSubject(
    Set<DeviceKind> on,
    String? subjectId, {
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    return _update(
      on,
      at: at,
      (_, s) => s.runningAt(at) ? s.withSubject(subjectId) : s,
    );
  }

  /// Before each device had its own session there was one shared record.
  /// One still running here becomes the sessions of the devices it covered,
  /// stamped after it, and the old record goes.
  Future<void> adoptLegacy({DateTime? now}) => _db.transaction(() async {
    final legacy = await (_db.select(
      _db.focusSessions,
    )..where((f) => f.id.equals(_legacyId))).getSingleOrNull();
    if (legacy == null) return;
    final old = focusSessionFromRow(legacy);
    // Newer than every version the phone already acted on.
    try {
      _clock.receive(Hlc.parse(legacy.hlc));
    } on FormatException {
      // Unreadable; the clock is past it in practice.
    }
    await (_db.delete(
      _db.focusSessions,
    )..where((f) => f.id.equals(_legacyId))).go();
    final at = (now ?? DateTime.now()).toUtc();
    if (!old.runningAt(at)) return;
    for (final kind in old.target.kinds) {
      final id = FocusSession.idFor(kind);
      final existing = await (_db.select(
        _db.focusSessions,
      )..where((f) => f.id.equals(id))).getSingleOrNull();
      if (existing != null) continue;
      final write = stampLocalEdit(
        before: null,
        beforeClock: '',
        after: old.copyWith(target: FocusTarget.only(kind)).toFields(),
        clock: _clock,
      );
      if (write == null) continue;
      await _db
          .into(_db.focusSessions)
          .insertOnConflictUpdate(focusSessionCompanion(id, write));
    }
  });

  static const _legacyId = 'current';

  Future<void> _update(
    Set<DeviceKind> on,
    FocusSession? Function(DeviceKind kind, FocusSession current) change, {
    required DateTime at,
    bool whole = false,
  }) => _db.transaction(() async {
    final touched = <DateTime>{};
    for (final kind in on) {
      final id = FocusSession.idFor(kind);
      final existing = await (_db.select(
        _db.focusSessions,
      )..where((f) => f.id.equals(id))).getSingleOrNull();
      final current = existing == null ? null : focusSessionFromRow(existing);
      final changed = change(kind, current ?? FocusSession.idle);
      if (changed == null) continue;
      final started = changed.startedAt;
      if (started != null) touched.add(started);
      final after = changed.toFields();
      final write = stampLocalEdit(
        before: whole ? null : current?.toFields(),
        beforeClock: existing?.fieldClock ?? '',
        after: after,
        clock: _clock,
      );
      if (write == null) continue;
      await _db
          .into(_db.focusSessions)
          .insertOnConflictUpdate(focusSessionCompanion(id, write));
    }
    for (final started in touched) {
      await _recordStudy(started, at);
    }
  });

  /// Brings the study session of the focus sessions started at [started]
  /// up to date: planned end, subject, and when it stopped, once every
  /// device it ran on has stopped early.
  Future<void> _recordStudy(DateTime started, DateTime at) async {
    final all = await current();
    final group = [
      for (final s in [all.phone, all.laptop])
        if (s.startedAt == started && s.endsAt != null) s,
    ];
    if (group.isEmpty) return;
    final id = StudySession.idFor(started);
    final existing = await (_db.select(
      _db.studySessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    final before = existing == null ? null : studySessionFromRow(existing);
    final running = group.any((s) => s.runningAt(at));
    final stoppedEarly = !running && group.every((s) => !s.active);
    final endsAt = group
        .map((s) => s.endsAt!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final first = group.first;
    final after = StudySession(
      id: id,
      startedAt: started,
      endsAt: endsAt,
      stoppedAt: running
          ? null
          : stoppedEarly
          ? (before?.stoppedAt ?? (at.isBefore(endsAt) ? at : endsAt))
          : before?.stoppedAt,
      subjectId: first.subjectId,
      workMinutes: first.workMinutes,
      breakMinutes: first.breakMinutes,
      deleted: before?.deleted ?? false,
    );
    final write = stampLocalEdit(
      before: before?.toFields(),
      beforeClock: existing?.fieldClock ?? '',
      after: after.toFields(),
      clock: _clock,
    );
    if (write == null) return;
    await _db
        .into(_db.studySessions)
        .insertOnConflictUpdate(studySessionCompanion(id, write));
  }

  Stream<FocusPrefs> watchPrefs() =>
      _db.watchSetting(FocusPrefs.key).map(FocusPrefs.decode);

  Future<FocusPrefs> prefs() async =>
      FocusPrefs.decode(await _db.readSetting(FocusPrefs.key));

  Future<void> savePrefs(FocusPrefs prefs) =>
      _db.writeSetting(FocusPrefs.key, prefs.encode());
}

FocusSession focusSessionFromRow(FocusSessionRow row) {
  DateTime? time(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  return FocusSession(
    active: row.active,
    startedAt: time(row.startedAt),
    endsAt: time(row.endsAt),
    target: FocusTarget.parse(row.target),
    blockApps: row.blockApps,
    quiet: row.quiet,
    strict: row.strict,
    startedBy: row.startedBy,
    workMinutes: row.workMinutes,
    breakMinutes: row.breakMinutes,
    subjectId: row.subjectId,
    version: row.hlc,
  );
}

FocusSessionsCompanion focusSessionCompanion(
  String id,
  StampedWrite w, {
  bool dirty = true,
}) {
  final s = FocusSession.fromFields(w.fields);
  return FocusSessionsCompanion.insert(
    id: id,
    active: Value(s.active),
    startedAt: Value(s.startedAt?.millisecondsSinceEpoch),
    endsAt: Value(s.endsAt?.millisecondsSinceEpoch),
    target: Value(s.target.name),
    blockApps: Value(s.blockApps),
    quiet: Value(s.quiet),
    strict: Value(s.strict),
    startedBy: Value(s.startedBy),
    workMinutes: Value(s.workMinutes),
    breakMinutes: Value(s.breakMinutes),
    subjectId: Value(s.subjectId),
    hlc: w.hlc.pack(),
    fieldClock: Value(w.clock.encode()),
    dirty: Value(dirty),
  );
}
