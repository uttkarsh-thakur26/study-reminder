import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/stamped_write.dart';
import '../../reminders/domain/reminder.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';

/// The phone's and the laptop's focus sessions, and this device's Focus
/// settings.
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

  /// Starts a session of [length] from [now] on each of [on], replacing
  /// what runs there. Devices started together get the same session.
  Future<void> start({
    required Set<DeviceKind> on,
    required Duration length,
    required bool blockApps,
    required bool quiet,
    required bool strict,
    required String startedBy,
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    // Stamps every field: a new session replaces the old one whole, so two
    // starts made at once never merge into a mix of both.
    return _update(
      on,
      whole: true,
      (kind, _) => FocusSession(
        active: true,
        startedAt: at,
        endsAt: at.add(length),
        target: FocusTarget.only(kind),
        blockApps: blockApps,
        quiet: quiet,
        strict: strict,
        startedBy: startedBy,
      ),
    );
  }

  Future<void> stop(Set<DeviceKind> on) =>
      _update(on, (_, s) => s.copyWith(active: false));

  /// Moves the end of the sessions running on [on] by [by].
  Future<void> extend(Set<DeviceKind> on, Duration by, {DateTime? now}) =>
      _update(on, (_, s) {
        final at = (now ?? DateTime.now()).toUtc();
        if (!s.runningAt(at)) return s;
        return s.copyWith(endsAt: s.endsAt!.add(by));
      });

  Future<void> _update(
    Set<DeviceKind> on,
    FocusSession Function(DeviceKind kind, FocusSession current) change, {
    bool whole = false,
  }) => _db.transaction(() async {
    for (final kind in on) {
      final id = FocusSession.idFor(kind);
      final existing = await (_db.select(
        _db.focusSessions,
      )..where((f) => f.id.equals(id))).getSingleOrNull();
      final current = existing == null ? null : focusSessionFromRow(existing);
      final after = change(kind, current ?? FocusSession.idle).toFields();
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
    hlc: w.hlc.pack(),
    fieldClock: Value(w.clock.encode()),
    dirty: Value(dirty),
  );
}
