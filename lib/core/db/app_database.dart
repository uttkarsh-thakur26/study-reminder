import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Subjects, Reminders, Occurrences, LocalSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'study_reminder'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX occurrences_reminder ON occurrences (reminder_id)');
          await customStatement(
              'CREATE INDEX reminders_dirty ON reminders (dirty) WHERE dirty = 1');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<String?> readSetting(String key) async {
    final row = await (select(localSettings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) =>
      (select(localSettings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> writeSetting(String key, String value) =>
      into(localSettings).insertOnConflictUpdate(
          LocalSettingsCompanion.insert(key: key, value: value));
}
