import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/stamped_write.dart';
import '../domain/study_session.dart';

/// The focus sessions kept for the stats, and the daily goal. The sessions
/// are written by FocusRepository as focus sessions start and change.
class StudyRepository {
  StudyRepository(this._db, this._clock);

  final AppDatabase _db;
  final HlcClock _clock;

  static const goalKey = 'study_goal_minutes';
  static const defaultGoalMinutes = 25;

  /// Every session not deleted, newest first.
  Stream<List<StudySession>> watchAll() {
    final query = _db.select(_db.studySessions)
      ..where((s) => s.deleted.equals(false))
      ..orderBy([
        (s) => OrderingTerm(expression: s.startedAt, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows.map(studySessionFromRow).toList());
  }

  /// Removes a session from the stats on every device.
  Future<void> delete(String id) => _setDeleted(id, true);

  /// Puts back a session removed with [delete].
  Future<void> restore(String id) => _setDeleted(id, false);

  Future<void> _setDeleted(String id, bool deleted) =>
      _db.transaction(() async {
        final existing = await (_db.select(
          _db.studySessions,
        )..where((s) => s.id.equals(id))).getSingleOrNull();
        if (existing == null) return;
        final current = studySessionFromRow(existing).toFields();
        final write = stampLocalEdit(
          before: current,
          beforeClock: existing.fieldClock,
          after: {...current, 'deleted': deleted},
          clock: _clock,
        );
        if (write == null) return;
        await _db
            .into(_db.studySessions)
            .insertOnConflictUpdate(studySessionCompanion(id, write));
      });

  /// Minutes of study a day needs to count towards the streak.
  Stream<int> watchGoalMinutes() => _db.watchSetting(goalKey).map(_goal);

  Future<void> saveGoalMinutes(int minutes) =>
      _db.writeSetting(goalKey, '${minutes.clamp(5, 600)}');

  static int _goal(String? raw) =>
      (int.tryParse(raw ?? '') ?? defaultGoalMinutes).clamp(5, 600);
}

StudySession studySessionFromRow(StudySessionRow row) {
  DateTime time(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  return StudySession(
    id: row.id,
    startedAt: time(row.startedAt),
    phoneUntil: row.phoneUntil == null ? null : time(row.phoneUntil!),
    laptopUntil: row.laptopUntil == null ? null : time(row.laptopUntil!),
    subjectId: row.subjectId,
    rounds: row.rounds,
    workMinutes: row.workMinutes,
    breakMinutes: row.breakMinutes,
    doneMs: row.doneMs,
    deleted: row.deleted,
  );
}

StudySessionsCompanion studySessionCompanion(
  String id,
  StampedWrite w, {
  bool dirty = true,
}) {
  final s = StudySession.fromFields(id, w.fields);
  return StudySessionsCompanion.insert(
    id: id,
    subjectId: Value(s.subjectId),
    startedAt: s.startedAt.millisecondsSinceEpoch,
    phoneUntil: Value(s.phoneUntil?.millisecondsSinceEpoch),
    laptopUntil: Value(s.laptopUntil?.millisecondsSinceEpoch),
    rounds: Value(s.rounds),
    workMinutes: Value(s.workMinutes),
    breakMinutes: Value(s.breakMinutes),
    doneMs: Value(s.doneMs),
    hlc: w.hlc.pack(),
    fieldClock: Value(w.clock.encode()),
    deleted: Value(s.deleted),
    dirty: Value(dirty),
  );
}
