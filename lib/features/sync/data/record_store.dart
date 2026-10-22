import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/field_clock.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/stamped_write.dart';
import '../../focus/data/focus_repository.dart';
import '../../focus/domain/focus_session.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../subjects/data/subject_repository.dart';
import '../domain/sync_record.dart';

/// The synced tables, seen as [SyncRecord]s: what still has to be pushed,
/// and how a pulled record merges into what is stored.
class RecordStore {
  RecordStore(this._db, this._clock) {
    _kinds = [
      _Kind(
        name: RecordKinds.subject,
        table: 'subjects',
        dirty: (limit) async => [
          for (final r
              in await (_db.select(_db.subjects)
                    ..where((t) => t.dirty.equals(true))
                    ..limit(limit))
                  .get())
            _Row(r.id, subjectFromRow(r).toFields(), r.fieldClock, r.hlc),
        ],
        byId: (id) async {
          final r = await (_db.select(
            _db.subjects,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          return r == null
              ? null
              : _Row(r.id, subjectFromRow(r).toFields(), r.fieldClock, r.hlc);
        },
        write: (id, w, dirty) => _db
            .into(_db.subjects)
            .insertOnConflictUpdate(subjectCompanion(id, w, dirty: dirty)),
      ),
      _Kind(
        name: RecordKinds.reminder,
        table: 'reminders',
        dirty: (limit) async => [
          for (final r
              in await (_db.select(_db.reminders)
                    ..where((t) => t.dirty.equals(true))
                    ..limit(limit))
                  .get())
            _Row(r.id, reminderFromRow(r).toFields(), r.fieldClock, r.hlc),
        ],
        byId: (id) async {
          final r = await (_db.select(
            _db.reminders,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          return r == null
              ? null
              : _Row(r.id, reminderFromRow(r).toFields(), r.fieldClock, r.hlc);
        },
        write: (id, w, dirty) => _db
            .into(_db.reminders)
            .insertOnConflictUpdate(reminderCompanion(id, w, dirty: dirty)),
      ),
      _Kind(
        name: RecordKinds.occurrence,
        table: 'occurrences',
        dirty: (limit) async => [
          for (final r
              in await (_db.select(_db.occurrences)
                    ..where((t) => t.dirty.equals(true))
                    ..limit(limit))
                  .get())
            _Row(r.id, occurrenceFromRow(r).toFields(), r.fieldClock, r.hlc),
        ],
        byId: (id) async {
          final r = await (_db.select(
            _db.occurrences,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          return r == null
              ? null
              : _Row(
                  r.id,
                  occurrenceFromRow(r).toFields(),
                  r.fieldClock,
                  r.hlc,
                );
        },
        write: (id, w, dirty) => _db
            .into(_db.occurrences)
            .insertOnConflictUpdate(occurrenceCompanion(id, w, dirty: dirty)),
      ),
      _Kind(
        name: RecordKinds.focus,
        table: 'focus_sessions',
        dirty: (limit) async => [
          for (final r
              in await (_db.select(_db.focusSessions)
                    ..where((t) => t.dirty.equals(true))
                    ..limit(limit))
                  .get())
            _Row(r.id, focusSessionFromRow(r).toFields(), r.fieldClock, r.hlc),
        ],
        byId: (id) async {
          final r = await (_db.select(
            _db.focusSessions,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          return r == null
              ? null
              : _Row(
                  r.id,
                  focusSessionFromRow(r).toFields(),
                  r.fieldClock,
                  r.hlc,
                );
        },
        // Only the phone's and the laptop's sessions are stored.
        write: (id, w, dirty) async {
          if (!FocusSession.ids.contains(id)) return;
          await _db
              .into(_db.focusSessions)
              .insertOnConflictUpdate(
                focusSessionCompanion(id, w, dirty: dirty),
              );
        },
      ),
    ];
  }

  final AppDatabase _db;
  final HlcClock _clock;
  late final List<_Kind> _kinds;

  _Kind? _kind(String name) => _kinds.where((k) => k.name == name).firstOrNull;

  /// The record kinds this version of the app stores.
  List<String> get kinds => [for (final k in _kinds) k.name];

  /// Up to [limit] records with local edits not yet on the server.
  Future<List<PendingPush>> dirty({int limit = 200}) async {
    final out = <PendingPush>[];
    for (final kind in _kinds) {
      if (out.length >= limit) break;
      for (final row in await kind.dirty(limit - out.length)) {
        out.add(
          PendingPush(
            SyncRecord(
              kind: kind.name,
              id: row.id,
              fields: row.fields,
              clock: _sentClock(row),
            ),
            row.hlc,
          ),
        );
      }
    }
    return out;
  }

  /// The stamps of the fields being sent. A stamp kept for a field this
  /// version does not know stays here: sent without its value, it would
  /// blank that field for newer devices.
  static FieldClock _sentClock(_Row row) {
    final clock = FieldClock.decode(row.clock);
    return FieldClock({
      for (final e in clock.stamps.entries)
        if (row.fields.containsKey(e.key)) e.key: e.value,
    });
  }

  /// Marks pushed records clean, unless they were edited again meanwhile.
  Future<void> markPushed(List<PendingPush> pushed) =>
      _db.transaction(() async {
        for (final p in pushed) {
          final kind = _kind(p.record.kind)!;
          await _db.customUpdate(
            'UPDATE ${kind.table} SET dirty = 0 WHERE id = ? AND hlc = ?',
            variables: [Variable(p.record.id), Variable(p.hlc)],
            updates: {_tableOf(kind)},
            updateKind: UpdateKind.update,
          );
        }
      });

  /// Queues every record to be pushed again, for a new or changed space.
  Future<void> markAllDirty() => _db.transaction(() async {
    for (final kind in _kinds) {
      await _db.customUpdate(
        'UPDATE ${kind.table} SET dirty = 1',
        updates: {_tableOf(kind)},
        updateKind: UpdateKind.update,
      );
    }
  });

  /// Merges pulled records into the database, field by field. A record whose
  /// local copy still has newer fields stays queued for the next push.
  Future<void> apply(List<SyncRecord> records) async {
    if (records.isEmpty) return;
    var newest = Hlc.zero;
    await _db.transaction(() async {
      for (final remote in records) {
        final kind = _kind(remote.kind);
        if (kind == null) continue; // made by a newer version of the app
        final remoteLatest = remote.clock.latest;
        if (remoteLatest > newest) newest = remoteLatest;

        final local = await kind.byId(remote.id);
        if (local == null) {
          await kind.write(
            remote.id,
            StampedWrite(remote.fields, remote.clock),
            false,
          );
          continue;
        }
        final localClock = FieldClock.decode(local.clock);
        final merged = mergeRecords(
          local: local.fields,
          localClock: localClock,
          remote: remote.fields,
          remoteClock: remote.clock,
        );
        if (merged.clock.encode() == localClock.encode() && !merged.localWon) {
          // Nothing new, and nothing of ours left to push for it.
          await _db.customUpdate(
            'UPDATE ${kind.table} SET dirty = 0 WHERE id = ? AND hlc = ?',
            variables: [Variable(remote.id), Variable(local.hlc)],
            updates: {_tableOf(kind)},
            updateKind: UpdateKind.update,
          );
          continue;
        }
        await kind.write(
          remote.id,
          StampedWrite(merged.values, merged.clock),
          merged.localWon,
        );
      }
    });
    // Local edits from now on sort after everything just received.
    if (newest > Hlc.zero) _clock.receive(newest);
  }

  TableInfo _tableOf(_Kind kind) => switch (kind.name) {
    RecordKinds.subject => _db.subjects,
    RecordKinds.reminder => _db.reminders,
    RecordKinds.focus => _db.focusSessions,
    _ => _db.occurrences,
  };
}

/// A record on its way to the server, with the stamp it had when read so it
/// is only marked clean if nobody edited it meanwhile.
class PendingPush {
  const PendingPush(this.record, this.hlc);

  final SyncRecord record;
  final String hlc;
}

class _Row {
  const _Row(this.id, this.fields, this.clock, this.hlc);

  final String id;
  final Map<String, Object?> fields;
  final String clock;
  final String hlc;
}

class _Kind {
  const _Kind({
    required this.name,
    required this.table,
    required this.dirty,
    required this.byId,
    required this.write,
  });

  final String name;
  final String table;
  final Future<List<_Row>> Function(int limit) dirty;
  final Future<_Row?> Function(String id) byId;
  final Future<void> Function(String id, StampedWrite write, bool dirty) write;
}
