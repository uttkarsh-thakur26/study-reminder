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

/// Device-local settings and identity. Never synced.
@DataClassName('LocalSetting')
class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
