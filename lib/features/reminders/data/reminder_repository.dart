import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/stamped_write.dart';
import '../../../core/time/calendar_date.dart';
import '../domain/occurrence.dart';
import '../domain/recurrence.dart';
import '../domain/reminder.dart';

class ReminderRepository {
  ReminderRepository(this._db, this._clock);

  final AppDatabase _db;
  final HlcClock _clock;

  Stream<List<Reminder>> watchAll() {
    final query = _db.select(_db.reminders)
      ..where((r) => r.deleted.equals(false));
    return query.watch().map((rows) => rows.map(reminderFromRow).toList());
  }

  Future<Reminder?> byId(String id) async {
    final row = await (_db.select(
      _db.reminders,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : reminderFromRow(row);
  }

  /// Saves an edit. Pass the version the editor started from as [base] so
  /// only the fields the user changed are written; see [applyEdit].
  Future<void> save(Reminder edited, {Reminder? base}) => _update(
    edited.id,
    (current) => applyEdit(
      current: current,
      base: base?.toFields(),
      edited: edited.toFields(),
    ),
  );

  Future<void> delete(String id) => _setDeleted(id, true);

  /// Brings back a reminder deleted by mistake (the undo in the snackbar).
  Future<void> restore(String id) => _setDeleted(id, false);

  Future<void> _setDeleted(String id, bool deleted) => _update(
    id,
    (current) => current == null ? null : {...current, 'deleted': deleted},
  );

  /// Reads the stored record, applies [change] and stamps whatever differs,
  /// all in one transaction. [change] returns null to write nothing.
  Future<void> _update(
    String id,
    Map<String, Object?>? Function(Map<String, Object?>? current) change,
  ) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.reminders,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    final current = existing == null
        ? null
        : reminderFromRow(existing).toFields();
    final after = change(current);
    if (after == null) return;
    final write = stampLocalEdit(
      before: current,
      beforeClock: existing?.fieldClock ?? '',
      after: after,
      clock: _clock,
    );
    if (write == null) return;
    await _db
        .into(_db.reminders)
        .insertOnConflictUpdate(reminderCompanion(id, write));
  });

  /// Live occurrence states keyed by occurrence id.
  Stream<Map<String, OccurrenceState>> watchOccurrences() => _db
      .select(_db.occurrences)
      .watch()
      .map((rows) => {for (final row in rows) row.id: occurrenceFromRow(row)});

  Future<void> setOccurrence(OccurrenceState state) =>
      _db.transaction(() async {
        final existing = await (_db.select(
          _db.occurrences,
        )..where((o) => o.id.equals(state.id))).getSingleOrNull();
        final write = stampLocalEdit(
          before: existing == null
              ? null
              : occurrenceFromRow(existing).toFields(),
          beforeClock: existing?.fieldClock ?? '',
          after: state.toFields(),
          clock: _clock,
        );
        if (write == null) return;
        await _db
            .into(_db.occurrences)
            .insertOnConflictUpdate(occurrenceCompanion(state.id, write));
      });

  Future<void> markDone(String reminderId, DateTime occurrenceAt) =>
      setOccurrence(
        OccurrenceState(
          reminderId: reminderId,
          occurrenceAt: occurrenceAt,
          status: OccurrenceStatus.done,
        ),
      );

  Future<void> snooze(
    String reminderId,
    DateTime occurrenceAt,
    DateTime until,
  ) => setOccurrence(
    OccurrenceState(
      reminderId: reminderId,
      occurrenceAt: occurrenceAt,
      status: OccurrenceStatus.snoozed,
      snoozeUntil: until,
    ),
  );

  Future<void> skip(String reminderId, DateTime occurrenceAt) => setOccurrence(
    OccurrenceState(
      reminderId: reminderId,
      occurrenceAt: occurrenceAt,
      status: OccurrenceStatus.skipped,
    ),
  );

  /// Puts an occurrence back to pending (undo of done, skip or snooze).
  Future<void> reopen(String reminderId, DateTime occurrenceAt) =>
      setOccurrence(
        OccurrenceState(
          reminderId: reminderId,
          occurrenceAt: occurrenceAt,
          status: OccurrenceStatus.pending,
        ),
      );
}

Reminder reminderFromRow(ReminderRow row) => Reminder(
  id: row.id,
  title: row.title,
  notes: row.notes,
  subjectId: row.subjectId,
  style:
      ReminderStyle.values.asNameMap()[row.style] ?? ReminderStyle.notification,
  schedule: ReminderSchedule(
    anchor: CalendarDate.parse(row.anchorDate),
    minuteOfDay: row.minuteOfDay,
    timeZone: row.timeZone,
    recurrence: Recurrence(
      kind: RepeatKind.values.asNameMap()[row.repeatKind] ?? RepeatKind.once,
      interval: row.repeatInterval < 1 ? 1 : row.repeatInterval,
      weekdays: Recurrence.weekdaysFromMask(row.repeatWeekdays),
      until: row.repeatUntil == null
          ? null
          : CalendarDate.parse(row.repeatUntil!),
    ),
  ),
  deliverTo:
      DeliveryTarget.values.asNameMap()[row.deliverTo] ??
      DeliveryTarget.everywhere,
  enabled: row.enabled,
  createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
  deleted: row.deleted,
);

RemindersCompanion reminderCompanion(
  String id,
  StampedWrite w, {
  bool dirty = true,
}) {
  final r = Reminder.fromFields(id, w.fields);
  return RemindersCompanion.insert(
    id: id,
    title: r.title,
    notes: Value(r.notes),
    subjectId: Value(r.subjectId),
    style: r.style.name,
    anchorDate: r.schedule.anchor.toIso(),
    minuteOfDay: r.schedule.minuteOfDay,
    timeZone: r.schedule.timeZone,
    repeatKind: r.recurrence.kind.name,
    repeatInterval: Value(r.recurrence.interval),
    repeatWeekdays: Value(r.recurrence.weekdayMask),
    repeatUntil: Value(r.recurrence.until?.toIso()),
    deliverTo: r.deliverTo.name,
    enabled: Value(r.enabled),
    createdAt: r.createdAt.millisecondsSinceEpoch,
    hlc: w.hlc.pack(),
    fieldClock: Value(w.clock.encode()),
    deleted: Value(r.deleted),
    dirty: Value(dirty),
  );
}

OccurrenceState occurrenceFromRow(OccurrenceRow row) => OccurrenceState(
  reminderId: row.reminderId,
  occurrenceAt: DateTime.fromMillisecondsSinceEpoch(
    row.occurrenceAt,
    isUtc: true,
  ),
  status:
      OccurrenceStatus.values.asNameMap()[row.status] ??
      OccurrenceStatus.pending,
  snoozeUntil: row.snoozeUntil == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(row.snoozeUntil!, isUtc: true),
  deleted: row.deleted,
);

OccurrencesCompanion occurrenceCompanion(
  String id,
  StampedWrite w, {
  bool dirty = true,
}) {
  final s = OccurrenceState.fromFields(w.fields);
  return OccurrencesCompanion.insert(
    id: id,
    reminderId: s.reminderId,
    occurrenceAt: s.occurrenceAt.millisecondsSinceEpoch,
    status: s.status.name,
    snoozeUntil: Value(s.snoozeUntil?.millisecondsSinceEpoch),
    hlc: w.hlc.pack(),
    fieldClock: Value(w.clock.encode()),
    deleted: Value(s.deleted),
    dirty: Value(dirty),
  );
}
