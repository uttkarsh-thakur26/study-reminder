import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/stamped_write.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';

/// The shared focus session, and this device's Focus settings.
class FocusRepository {
  FocusRepository(this._db, this._clock);

  final AppDatabase _db;
  final HlcClock _clock;

  Stream<FocusSession> watch() => _query().watchSingleOrNull().map(
    (row) => row == null ? FocusSession.idle : focusSessionFromRow(row),
  );

  Future<FocusSession> current() async {
    final row = await _query().getSingleOrNull();
    return row == null ? FocusSession.idle : focusSessionFromRow(row);
  }

  SimpleSelectStatement<$FocusSessionsTable, FocusSessionRow> _query() =>
      _db.select(_db.focusSessions)..where((f) => f.id.equals(FocusSession.id));

  /// Starts a session of [length] from [now], replacing any other.
  Future<void> start({
    required Duration length,
    required FocusTarget target,
    required bool blockApps,
    required bool quiet,
    required bool strict,
    required String startedBy,
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    return _update(
      (_) => FocusSession(
        active: true,
        startedAt: at,
        endsAt: at.add(length),
        target: target,
        blockApps: blockApps,
        quiet: quiet,
        strict: strict,
        startedBy: startedBy,
      ),
    );
  }

  Future<void> stop() => _update((s) => s.copyWith(active: false));

  /// Moves the end of a running session by [by].
  Future<void> extend(Duration by, {DateTime? now}) => _update((s) {
    final at = (now ?? DateTime.now()).toUtc();
    if (!s.runningAt(at)) return s;
    return s.copyWith(endsAt: s.endsAt!.add(by));
  });

  Future<void> _update(FocusSession Function(FocusSession current) change) =>
      _db.transaction(() async {
        final existing = await _query().getSingleOrNull();
        final current = existing == null ? null : focusSessionFromRow(existing);
        final after = change(current ?? FocusSession.idle).toFields();
        final write = stampLocalEdit(
          before: current?.toFields(),
          beforeClock: existing?.fieldClock ?? '',
          after: after,
          clock: _clock,
        );
        if (write == null) return;
        await _db
            .into(_db.focusSessions)
            .insertOnConflictUpdate(
              focusSessionCompanion(FocusSession.id, write),
            );
      });

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
    hlc: w.hlc.pack(),
    fieldClock: Value(w.clock.encode()),
    dirty: Value(dirty),
  );
}
