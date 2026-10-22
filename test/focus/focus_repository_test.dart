import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/features/focus/data/focus_repository.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';

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
