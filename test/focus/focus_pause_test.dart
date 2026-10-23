import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/field_clock.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/features/focus/data/focus_repository.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:study_reminder/features/stats/data/study_repository.dart';
import 'package:study_reminder/features/stats/domain/study_session.dart';

void main() {
  late AppDatabase db;
  late FocusRepository repo;
  final t0 = DateTime.utc(2026, 10, 22, 10);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));
  const both = {DeviceKind.phone, DeviceKind.laptop};

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FocusRepository(db, HlcClock('testdevice01', wallClock: () => t0));
  });
  tearDown(() => db.close());

  Future<List<StudySession>> studied() async {
    final rows = await db.select(db.studySessions).get();
    return [for (final r in rows) studySessionFromRow(r)]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  }

  Future<void> startRounds({bool strict = false}) => repo.startWith(
    FocusPrefs(rounds: 2, strict: strict),
    on: both,
    startedBy: 'Pixel',
    now: t0,
  );

  test('a pause keeps the time left and resumes in the same round', () async {
    await startRounds();
    await repo.pause(both, now: at(10));
    var s = await repo.current();
    expect(s.phone.isPaused, isTrue);
    expect(s.phone.runningAt(at(11)), isFalse);
    expect(s.phone.pausedLeft, const Duration(minutes: 45));
    expect(s.phone.pausedPhase!.round, 1);
    expect(s.phone.sameAs(s.laptop), isTrue);
    expect(s.sharing(DeviceKind.phone, at(11)), both);
    var log = (await studied()).single;
    expect(log.phoneUntil, at(10));
    expect(log.laptopUntil, at(10));

    await repo.resume(both, now: at(30));
    s = await repo.current();
    expect(s.phone.runningAt(at(31)), isTrue);
    expect(s.phone.isPaused, isFalse);
    expect(s.phone.startedAt, at(30));
    expect(s.phone.endsAt, at(75));
    expect(s.phone.sameAs(s.laptop), isTrue);
    // 15 minutes of round 1 were left, then the break and round 2.
    final phase = s.phone.phaseAt(at(44))!;
    expect(phase.round, 1);
    expect(phase.endsAt, at(45));
    expect(s.phone.phaseAt(at(46))!.onBreak, isTrue);

    final logs = await studied();
    expect(logs, hasLength(2));
    final first = logs.first;
    final second = logs.last;
    expect(first.focusedUntil(at(80)), const Duration(minutes: 10));
    expect(second.resumed, isTrue);
    expect(second.focusedUntil(at(80)), const Duration(minutes: 40));
  });

  test('a strict session cannot be paused or shortened', () async {
    await startRounds(strict: true);
    await repo.pause(both, now: at(5));
    expect((await repo.current()).phone.runningAt(at(6)), isTrue);
    await repo.extend(both, const Duration(minutes: -10), now: at(5));
    expect((await repo.current()).phone.endsAt, at(55));
    await repo.extend(both, const Duration(minutes: 5), now: at(5));
    expect((await repo.current()).phone.endsAt, at(60));
  });

  test('time can be taken off, down to a minute left', () async {
    await startRounds();
    await repo.extend(both, const Duration(minutes: -10), now: at(5));
    expect((await repo.current()).laptop.endsAt, at(45));
    await repo.extend(both, const Duration(minutes: -60), now: at(5));
    expect((await repo.current()).laptop.endsAt, at(6));
    expect((await studied()).single.laptopUntil, at(6));
  });

  test('time changes while paused, and stopping ends the pause', () async {
    await startRounds();
    await repo.pause({DeviceKind.laptop}, now: at(10));
    await repo.extend({DeviceKind.laptop}, const Duration(minutes: 5));
    var laptop = (await repo.current()).laptop;
    expect(laptop.pausedLeft, const Duration(minutes: 50));
    expect(
      (await studied()).single.laptopUntil,
      at(10),
      reason: 'paused time does not count',
    );
    await repo.stop({DeviceKind.laptop}, now: at(12));
    laptop = (await repo.current()).laptop;
    expect(laptop.isPaused, isFalse);
    await repo.resume({DeviceKind.laptop}, now: at(13));
    expect((await repo.current()).laptop.runningAt(at(14)), isFalse);
  });

  test('a start stopped at once stays out of the stats', () async {
    await startRounds();
    await repo.stop(both, now: t0.add(const Duration(seconds: 20)));
    final log = (await studied()).single;
    expect(log.countsAt(at(5)), isFalse);
    expect(log.countsAt(t0.add(const Duration(seconds: 10))), isTrue);
  });

  test('upgrading from schema 3 adds the pause fields', () async {
    // The two databases below open the same file one after the other.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    final dir = await Directory.systemTemp.createTemp('study_db');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    final stamp = Hlc(t0.millisecondsSinceEpoch, 0, 'laptop000000');

    // Today's tables, made to look like schema 3, with a stamp for a field
    // that version did not store.
    final old = AppDatabase(NativeDatabase(file));
    await old.customStatement('SELECT 1');
    for (final sql in [
      'ALTER TABLE focus_sessions DROP COLUMN done_ms',
      'ALTER TABLE focus_sessions DROP COLUMN paused_at',
      'ALTER TABLE study_sessions DROP COLUMN done_ms',
    ]) {
      await old.customStatement(sql);
    }
    final clock = FieldClock({'active': stamp, 'paused_at': stamp}).encode();
    await old.customStatement(
      "INSERT INTO focus_sessions (id, active, hlc, field_clock) "
      "VALUES ('laptop', 0, '${stamp.pack()}', '$clock')",
    );
    await old.customStatement('PRAGMA user_version = 3');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final row = await upgraded.select(upgraded.focusSessions).getSingle();
    expect(row.doneMs, 0);
    expect(row.pausedAt, isNull);
    expect(FieldClock.decode(row.fieldClock).stamps.keys, ['active']);
    expect(await upgraded.select(upgraded.studySessions).get(), isEmpty);
  });
}
