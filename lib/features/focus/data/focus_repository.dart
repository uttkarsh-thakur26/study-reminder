import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/field_clock.dart';
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
    int rounds = 1,
    Duration work = Duration.zero,
    Duration rest = Duration.zero,
    String? subjectId,
    DateTime? now,
  }) {
    final at = _wholeMs(now);
    final breaks = rounds > 1 && work > Duration.zero && rest > Duration.zero;
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
              rounds: breaks ? rounds : 1,
              workMinutes: breaks ? work.inMinutes : 0,
              breakMinutes: breaks ? rest.inMinutes : 0,
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
    rounds: prefs.rounds,
    work: prefs.work,
    rest: prefs.rest,
    subjectId: prefs.subjectId,
    blockApps: prefs.blockApps,
    quiet: prefs.quiet,
    strict: prefs.strict,
    startedBy: startedBy,
    now: now,
  );

  /// Stops the sessions on [on], running or paused.
  Future<void> stop(Set<DeviceKind> on, {DateTime? now}) =>
      _update(on, at: (now ?? DateTime.now()).toUtc(), (_, s) => s.ended());

  /// Pauses the sessions running on [on], strict ones aside: they stop, and
  /// keep the time they had left for [resume].
  Future<void> pause(Set<DeviceKind> on, {DateTime? now}) {
    final at = _wholeMs(now);
    return _update(
      on,
      at: at,
      (_, s) => s.runningAt(at) && !s.strict ? s.pausedAtTime(at) : null,
    );
  }

  /// Starts the paused sessions on [on] again where they left off. Devices
  /// paused together are resumed as one session again.
  Future<void> resume(Set<DeviceKind> on, {DateTime? now}) {
    final at = _wholeMs(now);
    return _update(
      on,
      at: at,
      whole: true,
      (_, s) => s.isPaused ? s.resumedAt(at) : null,
    );
  }

  /// Whole milliseconds, as stored, so a session read back matches.
  static DateTime _wholeMs(DateTime? now) =>
      DateTime.fromMillisecondsSinceEpoch(
        (now ?? DateTime.now()).millisecondsSinceEpoch,
        isUtc: true,
      );

  /// Moves the end of the sessions running or paused on [on] by [by]. Time
  /// taken off a strict session is ignored, and a session keeps at least
  /// [minimumLeft].
  Future<void> extend(Set<DeviceKind> on, Duration by, {DateTime? now}) {
    final at = (now ?? DateTime.now()).toUtc();
    return _update(on, at: at, (_, s) {
      final running = s.runningAt(at);
      if (!running && !s.isPaused) return null;
      if (by.isNegative && s.strict) return null;
      var end = s.endsAt!.add(by);
      final from = running ? at : s.pausedAt!;
      final least = from.add(minimumLeft);
      if (end.isBefore(least)) end = least;
      if (end == s.endsAt) return null;
      return s.copyWith(endsAt: end);
    });
  }

  /// The least time a session keeps when time is taken off it.
  static const minimumLeft = Duration(minutes: 1);

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
    final studied = <int, List<_Change>>{};
    for (final kind in on) {
      final id = FocusSession.idFor(kind);
      final existing = await (_db.select(
        _db.focusSessions,
      )..where((f) => f.id.equals(id))).getSingleOrNull();
      final current = existing == null ? null : focusSessionFromRow(existing);
      final changed = change(kind, current ?? FocusSession.idle);
      if (changed == null) continue;
      final write = stampLocalEdit(
        before: whole ? null : current?.toFields(),
        beforeClock: existing?.fieldClock ?? '',
        after: changed.toFields(),
        clock: _clock,
      );
      if (write == null) continue;
      await _db
          .into(_db.focusSessions)
          .insertOnConflictUpdate(focusSessionCompanion(id, write));
      final started = changed.startedAt;
      if (started == null || changed.endsAt == null) continue;
      studied.putIfAbsent(started.millisecondsSinceEpoch, () => []).add((
        kind: kind,
        before: current,
        after: changed,
      ));
    }
    for (final changes in studied.values) {
      await _recordStudy(changes, at);
    }
  });

  /// Carries [changes] to focus sessions started together over to their
  /// study session: each device's end, and the subject and rounds when they
  /// changed. Only what changed is written, so a change made meanwhile on
  /// the other device is kept.
  Future<void> _recordStudy(List<_Change> changes, DateTime at) async {
    final started = changes.first.after.startedAt!;
    final id = StudySession.idFor(started);
    final existing = await (_db.select(
      _db.studySessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    final current = existing == null
        ? null
        : studySessionFromRow(existing).toFields();
    final after = {
      ...current ?? StudySession(id: id, startedAt: started).toFields(),
    };
    for (final c in changes) {
      final s = c.after;
      final endsAt = s.endsAt!;
      final same = c.before?.startedAt == s.startedAt ? c.before : null;
      // Its planned end while it runs; stopped, when it stopped.
      final until = s.active
          ? endsAt
          : same != null && same.active
          ? (at.isBefore(endsAt) ? at : endsAt)
          : null;
      if (until != null) {
        after[StudySession.untilField(c.kind)] = until.millisecondsSinceEpoch;
      }
      if (current == null || same == null) {
        after['subject_id'] = s.subjectId;
        after['rounds'] = s.rounds;
        after['work_minutes'] = s.workMinutes;
        after['break_minutes'] = s.breakMinutes;
        after['done_ms'] = s.doneMs;
      } else if (same.subjectId != s.subjectId) {
        after['subject_id'] = s.subjectId;
      }
    }
    final write = stampLocalEdit(
      before: current,
      beforeClock: existing?.fieldClock ?? '',
      after: after,
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

  static const _studyProgressKey = 'study_video_progress';
  static const _studySiteKey = 'study_player_site';

  /// Where the user got to in the study playlist [playlistId]: the video,
  /// and its place in the playlist from 0, as far as they are known. Null
  /// before they watched it here.
  Future<StudyPlace?> studyPlaylistPlace(String playlistId) async =>
      (await _studyProgress())[playlistId];

  Future<void> saveStudyPlaylistPlace(
    String playlistId, {
    String? video,
    int? index,
  }) async {
    final progress = await _studyProgress();
    final place = (video: video, index: index);
    if (progress[playlistId] == place) return;
    progress[playlistId] = place;
    await _db.writeSetting(
      _studyProgressKey,
      jsonEncode({
        for (final MapEntry(:key, :value) in progress.entries)
          key: {'v': ?value.video, 'i': ?value.index},
      }),
    );
  }

  Future<Map<String, StudyPlace>> _studyProgress() async {
    final raw = await _db.readSetting(_studyProgressKey);
    if (raw == null) return {};
    try {
      return {
        for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map).entries)
          if (key is String)
            if (value is Map)
              key: (
                video: value['v'] is String ? value['v'] as String : null,
                index: value['i'] is int ? value['i'] as int : null,
              )
            // Saved by the first study player: the place only.
            else if (value is int)
              key: (video: null, index: value),
      };
    } on Object {
      return {};
    }
  }

  /// Whether the phone plays study videos on YouTube's mobile site, for
  /// when YouTube won't play them in the app's own player.
  Future<bool> studyPlayerUsesSite() async =>
      await _db.readSetting(_studySiteKey) == 'true';

  Future<void> saveStudyPlayerUsesSite(bool site) =>
      _db.writeSetting(_studySiteKey, site ? 'true' : 'false');
}

/// Where the user got to in a study playlist.
typedef StudyPlace = ({String? video, int? index});

/// A change [_update] made to one device's session.
typedef _Change = ({DeviceKind kind, FocusSession? before, FocusSession after});

FocusSession focusSessionFromRow(FocusSessionRow row) {
  DateTime? time(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  // A start from an older version leaves the fields it does not know as the
  // last session had them; stamped before the start, they are not this one's.
  FieldClock clock;
  try {
    clock = FieldClock.decode(row.fieldClock);
  } on FormatException {
    clock = FieldClock.empty;
  }
  final startedStamp = clock.of('started_at');
  bool fresh(String field) => !(clock.of(field) < startedStamp);
  final ofThisStart = ['rounds', 'work_minutes', 'break_minutes'].every(fresh);
  return FocusSession(
    active: row.active,
    startedAt: time(row.startedAt),
    endsAt: time(row.endsAt),
    target: FocusTarget.parse(row.target),
    blockApps: row.blockApps,
    quiet: row.quiet,
    strict: row.strict,
    startedBy: row.startedBy,
    rounds: ofThisStart ? row.rounds : 1,
    workMinutes: ofThisStart ? row.workMinutes : 0,
    breakMinutes: ofThisStart ? row.breakMinutes : 0,
    subjectId: fresh('subject_id') ? row.subjectId : null,
    doneMs: fresh('done_ms') ? row.doneMs : 0,
    pausedAt: fresh('paused_at') ? time(row.pausedAt) : null,
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
    rounds: Value(s.rounds),
    workMinutes: Value(s.workMinutes),
    breakMinutes: Value(s.breakMinutes),
    subjectId: Value(s.subjectId),
    doneMs: Value(s.doneMs),
    pausedAt: Value(s.pausedAt?.millisecondsSinceEpoch),
    hlc: w.hlc.pack(),
    fieldClock: Value(w.clock.encode()),
    dirty: Value(dirty),
  );
}
