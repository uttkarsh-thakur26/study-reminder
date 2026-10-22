import 'package:drift/drift.dart';

/// Columns every synced record carries.
mixin SyncColumns on Table {
  /// Newest edit stamp across all fields (packed HLC).
  TextColumn get hlc => text()();

  /// JSON map of field name to packed HLC, see `FieldClock`.
  TextColumn get fieldClock => text().withDefault(const Constant(''))();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Changed locally and not yet pushed to the server.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

@DataClassName('SubjectRow')
class Subjects extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ReminderRow')
class Reminders extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get subjectId => text().nullable()();
  TextColumn get style => text()();
  TextColumn get anchorDate => text()();
  IntColumn get minuteOfDay => integer()();
  TextColumn get timeZone => text()();
  TextColumn get repeatKind => text()();
  IntColumn get repeatInterval => integer().withDefault(const Constant(1))();
  IntColumn get repeatWeekdays => integer().withDefault(const Constant(0))();
  TextColumn get repeatUntil => text().nullable()();
  TextColumn get deliverTo => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('OccurrenceRow')
class Occurrences extends Table with SyncColumns {
  /// `<reminderId>@<occurrence epoch ms>`, identical on every device.
  TextColumn get id => text()();
  TextColumn get reminderId => text()();
  IntColumn get occurrenceAt => integer()();
  TextColumn get status => text()();
  IntColumn get snoozeUntil => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The focus sessions, one row per device kind: `phone` and `laptop`.
/// Times are epoch ms.
@DataClassName('FocusSessionRow')
class FocusSessions extends Table with SyncColumns {
  TextColumn get id => text()();
  BoolColumn get active => boolean().withDefault(const Constant(false))();
  IntColumn get startedAt => integer().nullable()();
  IntColumn get endsAt => integer().nullable()();
  TextColumn get target => text().withDefault(const Constant('both'))();
  BoolColumn get blockApps => boolean().withDefault(const Constant(true))();
  BoolColumn get quiet => boolean().withDefault(const Constant(true))();
  BoolColumn get strict => boolean().withDefault(const Constant(false))();
  TextColumn get startedBy => text().withDefault(const Constant(''))();
  IntColumn get workMinutes => integer().withDefault(const Constant(0))();
  IntColumn get breakMinutes => integer().withDefault(const Constant(0))();
  TextColumn get subjectId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Every focus session ever started, for the stats. The id is the start
/// time in epoch ms, so a session started on both devices is one row.
/// Times are epoch ms.
@DataClassName('StudySessionRow')
class StudySessions extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get subjectId => text().nullable()();
  IntColumn get startedAt => integer()();
  IntColumn get endsAt => integer()();
  IntColumn get stoppedAt => integer().nullable()();
  IntColumn get workMinutes => integer().withDefault(const Constant(0))();
  IntColumn get breakMinutes => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Device-local settings and identity. Never synced.
@DataClassName('LocalSetting')
class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
