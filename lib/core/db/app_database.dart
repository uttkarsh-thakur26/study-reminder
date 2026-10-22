import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Subjects,
    Reminders,
    Occurrences,
    FocusSessions,
    StudySessions,
    LocalSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Shared across isolates so notification actions handled in the
  /// background write through the same connection and the UI sees them.
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'study_reminder',
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            ),
      );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX occurrences_reminder ON occurrences (reminder_id)',
      );
      await customStatement(
        'CREATE INDEX reminders_dirty ON reminders (dirty) WHERE dirty = 1',
      );
      await _indexStudySessions();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(focusSessions);
      } else if (from < 3) {
        await m.addColumn(focusSessions, focusSessions.workMinutes);
        await m.addColumn(focusSessions, focusSessions.breakMinutes);
        await m.addColumn(focusSessions, focusSessions.subjectId);
      }
      if (from < 3) {
        await m.createTable(studySessions);
        await _indexStudySessions();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _indexStudySessions() => customStatement(
    'CREATE INDEX study_sessions_started ON study_sessions (started_at)',
  );

  Future<String?> readSetting(String key) async {
    final row = await (select(
      localSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) =>
      (select(localSettings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  /// Writes [value] only if [key] has none yet; the first writer wins.
  Future<void> writeSettingIfAbsent(String key, String value) =>
      into(localSettings).insert(
        LocalSettingsCompanion.insert(key: key, value: value),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> writeSetting(String key, String value) => into(localSettings)
      .insertOnConflictUpdate(
        LocalSettingsCompanion.insert(key: key, value: value),
      );
}
