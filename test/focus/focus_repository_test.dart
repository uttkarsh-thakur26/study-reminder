import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/field_clock.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/features/focus/data/focus_repository.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:study_reminder/features/stats/data/study_repository.dart';
import 'package:study_reminder/features/stats/domain/study_session.dart';

void main() {
  late AppDatabase db;
  late FocusRepository repo;
  final now = DateTime.utc(2026, 10, 22, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FocusRepository(db, HlcClock('testdevice01', wallClock: () => now));
  });
  tearDown(() => db.close());

  Future<void> start(Set<DeviceKind> on, {bool strict = false}) => repo.start(
    on: on,
    length: const Duration(minutes: 25),
    blockApps: true,
    quiet: true,
    strict: strict,
    startedBy: 'Pixel',
    now: now,
  );

  Future<List<StudySession>> studied() async => [
    for (final r in await db.select(db.studySessions).get())
      studySessionFromRow(r),
  ];

  test('a session on both devices is one study session', () async {
    await repo.startWith(
      const FocusPrefs(rounds: 2, subjectId: 's1'),
      on: {DeviceKind.phone, DeviceKind.laptop},
      startedBy: 'Pixel',
      now: now,
    );
    final sessions = await repo.current();
    expect(sessions.phone.workMinutes, 25);
    expect(sessions.phone.breakMinutes, 5);
    expect(sessions.phone.endsAt, now.add(const Duration(minutes: 55)));
    var log = (await studied()).single;
    expect(log.id, StudySession.idFor(now));
    expect(log.subjectId, 's1');
    expect(log.rounds, 2);
    expect(log.phoneUntil, now.add(const Duration(minutes: 55)));
    expect(log.laptopUntil, now.add(const Duration(minutes: 55)));

    await repo.extend(
      {DeviceKind.laptop},
      const Duration(minutes: 5),
      now: now,
    );
    log = (await studied()).single;
    expect(log.laptopUntil, now.add(const Duration(minutes: 60)));
    expect(log.phoneUntil, now.add(const Duration(minutes: 55)));
    expect(log.endedAt, now.add(const Duration(minutes: 60)));
    expect(
      (await repo.current()).laptop.rounds,
      2,
      reason: 'time added stays in the last round',
    );

    final later = now.add(const Duration(minutes: 10));
    await repo.stop({DeviceKind.phone}, now: later);
    log = (await studied()).single;
    expect(log.phoneUntil, later);
    expect(log.endedAt, now.add(const Duration(minutes: 60)));
    await repo.stop({
      DeviceKind.laptop,
    }, now: later.add(const Duration(minutes: 2)));
    log = (await studied()).single;
    expect(log.laptopUntil, later.add(const Duration(minutes: 2)));
    expect(log.phoneUntil, later, reason: 'each device keeps its own end');

    await repo.stop({
      DeviceKind.laptop,
    }, now: later.add(const Duration(minutes: 9)));
    expect(
      (await studied()).single.laptopUntil,
      later.add(const Duration(minutes: 2)),
      reason: 'stopping a stopped session changes nothing',
    );

    await repo.setSubject({DeviceKind.phone}, 's2', now: later);
    expect(
      (await studied()).single.subjectId,
      's1',
      reason: 'only a running session changes subject',
    );
  });

  test('changing the subject of a running session updates its stats', () async {
    await start({DeviceKind.phone});
    await repo.setSubject({DeviceKind.phone}, 's2', now: now);
    expect((await repo.current()).phone.subjectId, 's2');
    expect((await studied()).single.subjectId, 's2');
  });

  test('a start at a time with microseconds is still recorded', () async {
    final odd = now.add(const Duration(microseconds: 1234));
    await repo.start(
      on: {DeviceKind.phone},
      length: const Duration(minutes: 25),
      blockApps: true,
      quiet: true,
      strict: false,
      startedBy: 'Pixel',
      now: odd,
    );
    // Kept to the millisecond, like everything stored.
    final started = now.add(const Duration(milliseconds: 1));
    final log = (await studied()).single;
    expect(log.startedAt, started);
    expect(log.phoneUntil, started.add(const Duration(minutes: 25)));
    await repo.stop({
      DeviceKind.phone,
    }, now: odd.add(const Duration(minutes: 5)));
    expect(
      (await studied()).single.phoneUntil,
      started.add(const Duration(minutes: 5)),
    );
  });

  test('a start from an older version does not keep the last rounds', () {
    Hlc stamp(int minutes) => Hlc(
      now.add(Duration(minutes: minutes)).millisecondsSinceEpoch,
      0,
      'laptop000000',
    );
    final row = FocusSessionRow(
      id: FocusSession.idFor(DeviceKind.laptop),
      active: true,
      startedAt: now.millisecondsSinceEpoch,
      endsAt: now.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
      target: 'laptop',
      blockApps: true,
      quiet: true,
      strict: false,
      startedBy: 'DESKTOP-1',
      rounds: 4,
      workMinutes: 25,
      breakMinutes: 5,
      subjectId: 'old',
      doneMs: 0,
      hlc: stamp(1).pack(),
      fieldClock: FieldClock({
        'started_at': stamp(1),
        'ends_at': stamp(1),
        for (final f in FocusSession.startFields) f: stamp(0),
      }).encode(),
      deleted: false,
      dirty: false,
    );
    final s = focusSessionFromRow(row);
    expect(s.rounds, 1);
    expect(s.workMinutes, 0);
    expect(s.subjectId, isNull);

    final current = FocusSessionRow(
      id: row.id,
      active: row.active,
      startedAt: row.startedAt,
      endsAt: row.endsAt,
      target: row.target,
      blockApps: row.blockApps,
      quiet: row.quiet,
      strict: row.strict,
      startedBy: row.startedBy,
      rounds: 4,
      workMinutes: 25,
      breakMinutes: 5,
      subjectId: 'new',
      doneMs: 0,
      hlc: row.hlc,
      fieldClock: FieldClock({
        'started_at': stamp(1),
        for (final f in FocusSession.startFields) f: stamp(1),
        'subject_id': stamp(2),
      }).encode(),
      deleted: false,
      dirty: false,
    );
    final kept = focusSessionFromRow(current);
    expect(kept.rounds, 4);
    expect(kept.subjectId, 'new');
  });

  test('a start leaves a session that already runs alone', () async {
    await start({DeviceKind.laptop}, strict: true);
    final before = (await repo.current()).laptop;
    await start({DeviceKind.phone, DeviceKind.laptop});
    final after = await repo.current();
    expect(after.laptop.version, before.version);
    expect(after.laptop.strict, isTrue);
    expect(after.phone.runningAt(now), isTrue);
  });

  test('the old shared session becomes the devices it covered', () async {
    // Stamped ahead of this device's clock, like one from a fast laptop.
    final stamp = Hlc(
      now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      0,
      'laptop000000',
    ).pack();
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'current',
            active: const Value(true),
            startedAt: Value(now.millisecondsSinceEpoch),
            endsAt: Value(
              now.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
            ),
            target: const Value('both'),
            strict: const Value(true),
            startedBy: const Value('DESKTOP-1'),
            hlc: stamp,
          ),
        );
    await repo.adoptLegacy(now: now);
    final s = await repo.current();
    for (final one in [s.phone, s.laptop]) {
      expect(one.runningAt(now), isTrue);
      expect(one.strict, isTrue);
      expect(one.startedBy, 'DESKTOP-1');
      expect(one.version.compareTo(stamp), greaterThan(0));
    }
    expect(s.phone.sameAs(s.laptop), isTrue);
    final rows = await db.select(db.focusSessions).get();
    expect(rows.map((r) => r.id), isNot(contains('current')));

    // Once only.
    await repo.adoptLegacy(now: now);
    expect((await repo.current()).phone.version, s.phone.version);
  });

  test('an old session that ended is just dropped', () async {
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'current',
            active: const Value(false),
            target: const Value('phone'),
            hlc: Hlc(now.millisecondsSinceEpoch, 0, 'laptop000000').pack(),
          ),
        );
    await repo.adoptLegacy(now: now);
    expect(await db.select(db.focusSessions).get(), isEmpty);
  });

  test('a change to a shared session goes to both devices', () {
    final both = FocusSession(
      active: true,
      startedAt: now,
      endsAt: now.add(const Duration(minutes: 25)),
      target: FocusTarget.phone,
    );
    final shared = FocusSessions(
      phone: both,
      laptop: both.copyWith(target: FocusTarget.laptop),
    );
    expect(shared.sharing(DeviceKind.laptop, now), {
      DeviceKind.laptop,
      DeviceKind.phone,
    });
    final apart = FocusSessions(
      phone: both,
      laptop: both.copyWith(endsAt: now.add(const Duration(minutes: 30))),
    );
    expect(apart.sharing(DeviceKind.laptop, now), {DeviceKind.laptop});
  });

  test('flip starts only where the user wants', () {
    final laptopBusy = FocusSessions(
      laptop: FocusSession(
        active: true,
        startedAt: now,
        endsAt: now.add(const Duration(minutes: 25)),
        target: FocusTarget.laptop,
      ),
    );
    expect(
      laptopBusy.startable(
        FocusTarget.laptop,
        here: DeviceKind.phone,
        paired: true,
        now: now,
        orFree: false,
      ),
      isEmpty,
    );
    expect(
      laptopBusy.startable(
        FocusTarget.laptop,
        here: DeviceKind.phone,
        paired: true,
        now: now,
      ),
      {DeviceKind.phone},
    );
  });
}
