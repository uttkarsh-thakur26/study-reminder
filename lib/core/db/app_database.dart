import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../sync/field_clock.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Synced fields added after the first version of their table.
abstract final class FocusSessionKeys {
  /// Focus session fields added in schema 3.
  static const added = [
    'rounds',
    'work_minutes',
    'break_minutes',
    'subject_id',
  ];

  /// Focus session fields added in schema 4, for pausing.
  static const pause = ['done_ms', 'paused_at'];

  /// Study session fields added in schema 4.
  static const studyPause = ['done_ms'];
}

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
  int get schemaVersion => 4;

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
        await m.addColumn(focusSessions, focusSessions.rounds);
        await m.addColumn(focusSessions, focusSessions.workMinutes);
        await m.addColumn(focusSessions, focusSessions.breakMinutes);
        await m.addColumn(focusSessions, focusSessions.subjectId);
        await _forgetUnknownStamps('focus_sessions', FocusSessionKeys.added);
      }
      if (from < 3) {
        await m.createTable(studySessions);
        await _indexStudySessions();
      }
      if (from >= 2 && from < 4) {
        await m.addColumn(focusSessions, focusSessions.doneMs);
        await m.addColumn(focusSessions, focusSessions.pausedAt);
        await _forgetUnknownStamps('focus_sessions', FocusSessionKeys.pause);
      }
      if (from == 3) {
        await m.addColumn(studySessions, studySessions.doneMs);
        await _forgetUnknownStamps(
          'study_sessions',
          FocusSessionKeys.studyPause,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// An older version kept the stamps of fields it did not know, but not
  /// their values. Now that it stores them, those stamps would make the
  /// empty columns look current, so they go, and the pull that follows an
  /// update brings the values.
  Future<void> _forgetUnknownStamps(String table, List<String> fields) async {
    final rows = await customSelect(
      'SELECT id, field_clock FROM $table',
      readsFrom: const {},
    ).get();
    for (final row in rows) {
      final raw = row.read<String>('field_clock');
      final clock = FieldClock.decode(raw);
      if (!fields.any(clock.stamps.containsKey)) continue;
      final kept = FieldClock({
        for (final e in clock.stamps.entries)
          if (!fields.contains(e.key)) e.key: e.value,
      });
      await customUpdate(
        'UPDATE $table SET field_clock = ? WHERE id = ?',
        variables: [Variable(kept.encode()), Variable(row.read<String>('id'))],
      );
    }
  }

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
