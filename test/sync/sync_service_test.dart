import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/field_clock.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/core/time/calendar_date.dart';
import 'package:study_reminder/features/focus/data/focus_repository.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';
import 'package:study_reminder/features/reminders/data/reminder_repository.dart';
import 'package:study_reminder/features/reminders/domain/recurrence.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:study_reminder/features/subjects/data/subject_repository.dart';
import 'package:study_reminder/features/subjects/domain/subject.dart';
import 'package:study_reminder/features/sync/application/sync_service.dart';
import 'package:study_reminder/features/sync/data/sync_api.dart';
import 'package:study_reminder/features/sync/domain/sync_record.dart';

import 'fake_sync_api.dart';

/// One app install: its own database, clock and sync service, all talking
/// to the same fake server.
class _Device {
  _Device(
    String name,
    FakeSyncApi api, {
    required bool phone,
    required int Function() wall,
    int skewMs = 0,
  }) {
    db = AppDatabase(NativeDatabase.memory());
    clock = HlcClock(
      name,
      wallClock: () => DateTime.fromMillisecondsSinceEpoch(wall() + skewMs),
    );
    reminders = ReminderRepository(db, clock);
    subjects = SubjectRepository(db, clock);
    focus = FocusRepository(db, clock);
    sync = SyncService(
      db: db,
      clock: clock,
      api: api,
      isPhone: phone,
      deviceName: name,
      pushToken: () async => token,
    );
  }

  /// The push token this device has, if any.
  String? token;

  late final AppDatabase db;
  late final HlcClock clock;
  late final ReminderRepository reminders;
  late final SubjectRepository subjects;
  late final FocusRepository focus;
  late final SyncService sync;

  Future<String> title(String id) async => (await reminders.byId(id))!.title;

  Future<int> waiting() async => (await sync.store.dirty()).length;
}

void main() {
  late FakeSyncApi api;
  late _Device laptop;
  late _Device phone;
  late int wall;

  int tick() => wall += 1000;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    wall = DateTime.utc(2026, 10, 22, 9).millisecondsSinceEpoch;
    api = FakeSyncApi(now: () => DateTime.fromMillisecondsSinceEpoch(wall));
    laptop = _Device('Laptop', api, phone: false, wall: tick);
    phone = _Device('Pixel', api, phone: true, wall: tick);
  });
  tearDown(() async {
    await laptop.db.close();
    await phone.db.close();
  });

  final physics = Reminder(
    id: 'r1',
    title: 'Physics',
    createdAt: DateTime.utc(2026, 10, 22),
    schedule: const ReminderSchedule(
      anchor: CalendarDate(2026, 10, 22),
      minuteOfDay: 19 * 60,
      timeZone: 'Asia/Kolkata',
      recurrence: Recurrence.weekly({1, 3}),
    ),
  );

  /// Pairs the phone with the laptop the way the app does: the laptop has
  /// synced (it does on start), and both sync once more afterwards.
  Future<void> pair() async {
    await laptop.sync.sync();
    final code = await laptop.sync.createPairingCode();
    await phone.sync.joinWithCode(code.display);
    await laptop.sync.sync();
    await phone.sync.sync();
  }

  test('pairing brings both devices together and keeps both sides', () async {
    await laptop.reminders.save(physics);
    await phone.subjects.save(
      const Subject(id: 's1', name: 'Maths', color: 0xFF2255AA),
    );
    await laptop.sync.sync();
    await phone.sync.sync();

    await pair();

    expect(await phone.title('r1'), 'Physics');
    expect(
      (await laptop.db.select(laptop.db.subjects).getSingle()).name,
      'Maths',
    );
    expect(api.spaceCount, 1, reason: "the phone's old space is gone");
    expect(await laptop.waiting(), 0);
    expect(await phone.waiting(), 0);
    expect(await laptop.sync.spaceId(), await phone.sync.spaceId());
    final devices = await laptop.sync.devices();
    expect(devices.map((d) => d.name), unorderedEquals(['Laptop', 'Pixel']));
  });

  test('a fresh code already carries this device\'s data', () async {
    await laptop.reminders.save(physics);
    final code = await laptop.sync.createPairingCode();
    await phone.sync.joinWithCode(code.code);
    expect(await phone.title('r1'), 'Physics');
  });

  test('a sync with nothing new sends nothing', () async {
    await laptop.reminders.save(physics);
    await pair();
    await phone.sync.sync();
    final before = api.pushedRecords;
    await laptop.sync.sync();
    await phone.sync.sync();
    expect(api.pushedRecords, before);
  });

  test('offline edits to different fields both survive', () async {
    await laptop.reminders.save(physics);
    await pair();

    final base = (await laptop.reminders.byId('r1'))!;
    await laptop.reminders.save(base.copyWith(title: 'Physics ch. 4'));
    await phone.reminders.save(base.copyWith(notes: 'Bring formula sheet'));

    await laptop.sync.sync();
    await phone.sync.sync();
    await laptop.sync.sync();

    for (final d in [laptop, phone]) {
      final r = (await d.reminders.byId('r1'))!;
      expect(r.title, 'Physics ch. 4');
      expect(r.notes, 'Bring formula sheet');
      expect(await d.waiting(), 0);
    }
  });

  test('the later edit to the same field wins everywhere', () async {
    await laptop.reminders.save(physics);
    await pair();

    final base = (await laptop.reminders.byId('r1'))!;
    await laptop.reminders.save(base.copyWith(title: 'Earlier'));
    await phone.reminders.save(base.copyWith(title: 'Later'));

    // The device with the older edit syncs last; it still loses.
    await phone.sync.sync();
    await laptop.sync.sync();
    await phone.sync.sync();

    expect(await laptop.title('r1'), 'Later');
    expect(await phone.title('r1'), 'Later');
  });

  test('deletes and done marks reach the other device', () async {
    await laptop.reminders.save(physics);
    await laptop.reminders.save(
      Reminder(
        id: 'r2',
        title: 'Chem',
        createdAt: physics.createdAt,
        schedule: physics.schedule,
      ),
    );
    await pair();

    await laptop.reminders.delete('r1');
    final at = DateTime.utc(2026, 10, 26, 13, 30);
    await phone.reminders.markDone('r2', at);
    await laptop.sync.sync();
    await phone.sync.sync();
    await laptop.sync.sync();

    expect((await phone.reminders.byId('r1'))!.deleted, isTrue);
    final occurrences = await laptop.db.select(laptop.db.occurrences).get();
    expect(occurrences, hasLength(1));
    expect(occurrences.single.reminderId, 'r2');
  });

  test('an edit made while uploading is not lost', () async {
    await laptop.reminders.save(physics);
    await pair();

    final base = (await laptop.reminders.byId('r1'))!;
    await laptop.reminders.save(base.copyWith(title: 'Before upload'));
    api.duringPush = () async {
      api.duringPush = null;
      await laptop.reminders.save(base.copyWith(title: 'During upload'));
    };
    await laptop.sync.sync();
    await phone.sync.sync();

    expect(await laptop.title('r1'), 'During upload');
    expect(await phone.title('r1'), 'During upload');
    expect(await laptop.waiting(), 0);
  });

  test('a device whose clock runs ahead cannot block later edits', () async {
    // The phone's clock is an hour fast.
    final fastPhone = _Device(
      'Fast phone',
      api,
      phone: true,
      wall: tick,
      skewMs: const Duration(hours: 1).inMilliseconds,
    );
    addTearDown(fastPhone.db.close);
    await laptop.reminders.save(physics);
    await laptop.sync.sync();
    final code = await laptop.sync.createPairingCode();
    await fastPhone.sync.joinWithCode(code.code);

    final base = (await fastPhone.reminders.byId('r1'))!;
    await fastPhone.reminders.save(base.copyWith(title: 'From the phone'));
    await fastPhone.sync.sync();
    await laptop.sync.sync();
    // Seconds later by the laptop's clock, but after the phone's edit.
    final seen = (await laptop.reminders.byId('r1'))!;
    await laptop.reminders.save(seen.copyWith(title: 'From the laptop'));
    await laptop.sync.sync();
    await fastPhone.sync.sync();

    expect(await fastPhone.title('r1'), 'From the laptop');
  });

  test('a server that forgot this device gets everything again', () async {
    await laptop.reminders.save(physics);
    await laptop.subjects.save(
      const Subject(id: 's1', name: 'Maths', color: 0xFF2255AA),
    );
    await laptop.sync.sync();
    final oldSpace = await laptop.sync.spaceId();

    api.reset();
    final before = api.pushedRecords;
    await laptop.sync.sync();

    expect(await laptop.sync.spaceId(), isNot(oldSpace));
    expect(api.pushedRecords - before, 2);
    expect(await laptop.waiting(), 0);
  });

  test('unpairing stops changes but keeps everything', () async {
    await laptop.reminders.save(physics);
    await pair();

    await phone.sync.unpair();
    final base = (await laptop.reminders.byId('r1'))!;
    await laptop.reminders.save(base.copyWith(title: 'Laptop only'));
    await laptop.sync.sync();
    await phone.sync.sync();

    expect(await phone.title('r1'), 'Physics');
    expect(await laptop.sync.devices(), hasLength(1));
    expect(await phone.sync.devices(), hasLength(1));
  });

  test('a wrong or already used code is refused', () async {
    await laptop.sync.sync();
    await expectLater(
      phone.sync.joinWithCode('NOPE0000'),
      throwsA(
        isA<PairingException>().having(
          (e) => e.problem,
          'problem',
          PairingProblem.wrongCode,
        ),
      ),
    );

    final code = await laptop.sync.createPairingCode();
    await phone.sync.joinWithCode(code.code);
    final tablet = _Device('Tablet', api, phone: true, wall: tick);
    addTearDown(tablet.db.close);
    await expectLater(
      tablet.sync.joinWithCode(code.code),
      throwsA(isA<PairingException>()),
    );
  });

  test('offline syncs fail cleanly and catch up later', () async {
    await laptop.reminders.save(physics);
    await pair();
    final base = (await laptop.reminders.byId('r1'))!;
    await laptop.reminders.save(base.copyWith(title: 'Written offline'));

    api.offline = true;
    await expectLater(laptop.sync.sync(), throwsA(isA<SyncUnavailable>()));
    expect(await laptop.waiting(), 1);

    api.offline = false;
    await laptop.sync.sync();
    await phone.sync.sync();
    expect(await phone.title('r1'), 'Written offline');
  });

  test('a large backlog goes up and comes down in pages', () async {
    for (var i = 0; i < 650; i++) {
      await laptop.subjects.save(
        Subject(id: 's$i', name: 'Subject $i', color: 0xFF000000 + i),
      );
    }
    await laptop.sync.sync();
    expect(await laptop.waiting(), 0);
    expect(api.pushes, greaterThanOrEqualTo(4), reason: 'batches of 200');

    final code = await laptop.sync.createPairingCode();
    await phone.sync.joinWithCode(code.code);
    expect(await phone.db.select(phone.db.subjects).get(), hasLength(650));
    expect(await phone.waiting(), 0);
  });

  test('a join whose reply is lost is finished by the next sync', () async {
    await laptop.reminders.save(physics);
    await laptop.sync.sync();
    await phone.subjects.save(
      const Subject(id: 's1', name: 'Maths', color: 0xFF2255AA),
    );
    await phone.sync.sync();
    final code = await laptop.sync.createPairingCode();

    api.loseNextReply = true;
    await expectLater(
      phone.sync.joinWithCode(code.code),
      throwsA(isA<SyncUnavailable>()),
    );
    // The server moved the phone; the phone learns it on its next sync.
    await phone.sync.sync();
    await laptop.sync.sync();

    expect(await phone.sync.spaceId(), await laptop.sync.spaceId());
    expect(await phone.title('r1'), 'Physics');
    expect(await laptop.db.select(laptop.db.subjects).get(), hasLength(1));
  });

  test('pairing succeeds even if the first sync after it fails', () async {
    await laptop.reminders.save(physics);
    final code = await laptop.sync.createPairingCode();
    api.failPulls = 1;
    await phone.sync.joinWithCode(code.code);
    expect(await phone.sync.spaceId(), await laptop.sync.spaceId());
    await phone.sync.sync();
    expect(await phone.title('r1'), 'Physics');
  });

  test('a background sync cannot undo a move made meanwhile', () async {
    await laptop.reminders.save(physics);
    await laptop.sync.sync();
    await phone.subjects.save(
      const Subject(id: 's1', name: 'Maths', color: 0xFF2255AA),
    );
    await phone.sync.sync();
    final code = await laptop.sync.createPairingCode();

    // The Android background task: same database, its own service.
    final background = SyncService(
      db: phone.db,
      clock: phone.clock,
      api: api,
      isPhone: true,
      deviceName: 'Pixel',
    );
    // While it waits on its pull, the app joins the laptop, and the app's
    // own first pull fails.
    api.duringPull = () async {
      api.failPulls = 1;
      await phone.sync.joinWithCode(code.code);
    };
    await background.sync();

    // The background task's pull saw only the new space's newest records;
    // saving its cursor would hide the laptop's older ones for good.
    await phone.sync.sync();
    expect(await phone.title('r1'), 'Physics');
  });

  test('records of a newly known kind are fetched after an update', () async {
    await laptop.sync.sync();
    await laptop.db.writeSetting(SyncKeys.kinds, 'subject,reminder');
    final pulls = api.pullsAfter.length;
    await laptop.sync.sync();
    expect(api.pullsAfter.sublist(pulls), [0]);
  });

  test('stamps of fields this version does not know are not sent', () async {
    await laptop.sync.sync();
    final space = (await laptop.sync.spaceId())!;
    const fields = {
      'name': 'Maths',
      'color': 0xFF2255AA,
      'sort_order': 0,
      'deleted': false,
    };
    final stamp = laptop.clock.now();
    api.storeAsNewerApp(
      space,
      SyncRecord(
        kind: RecordKinds.subject,
        id: 's1',
        fields: {...fields, 'icon': 'calculator'},
        clock: FieldClock({
          for (final f in [...fields.keys, 'icon']) f: stamp,
        }),
      ),
    );
    await laptop.sync.sync();
    expect(await laptop.db.select(laptop.db.subjects).get(), hasLength(1));

    // Unpairing pushes everything into a new space.
    await laptop.sync.unpair();
    final fresh = (await laptop.sync.spaceId())!;
    final sent = api.storedClock(fresh, RecordKinds.subject, 's1')!;
    expect(sent.keys, isNot(contains('icon')));
    expect(sent.keys, contains('name'));
  });

  group('focus', () {
    Future<void> startOn(_Device d) => d.focus.start(
      length: const Duration(minutes: 25),
      target: FocusTarget.both,
      blockApps: true,
      quiet: true,
      strict: false,
      startedBy: d == laptop ? 'Laptop' : 'Pixel',
      now: DateTime.fromMillisecondsSinceEpoch(tick(), isUtc: true),
    );

    test('starting on the laptop wakes the phone with the session', () async {
      phone.token = 'phone-token';
      await pair();
      expect(api.wakes, isEmpty);

      await startOn(laptop);
      await laptop.sync.sync();
      expect(api.wakes, hasLength(1));
      final (tokens, sent) = api.wakes.single;
      expect(tokens, ['phone-token']);
      expect(sent?['active'], isTrue);
      expect(sent?['started_by'], 'Laptop');

      await phone.sync.sync();
      final there = await phone.focus.current();
      expect(there.active, isTrue);
      expect(there.startedBy, 'Laptop');
      expect(there.length, const Duration(minutes: 25));

      // Stopped on the phone: the laptop has no token, so nobody to wake.
      await phone.focus.stop();
      await phone.sync.sync();
      expect(api.wakes, hasLength(2));
      expect(api.wakes.last.$1, isEmpty);
      await laptop.sync.sync();
      expect((await laptop.focus.current()).active, isFalse);
    });

    test('other edits do not wake anyone', () async {
      phone.token = 'phone-token';
      await pair();
      await laptop.reminders.save(physics);
      await laptop.sync.sync();
      expect(api.wakes, isEmpty);
    });

    test('the push token is sent once, and again after a move', () async {
      phone.token = 't1';
      await phone.sync.sync();
      await phone.sync.sync();
      expect(api.tokenUpdates, 1);
      phone.token = 't2';
      await phone.sync.sync();
      expect(api.tokenUpdates, 2);
      await pair();
      expect(api.tokenUpdates, 3, reason: 'joined another space');
    });

    test('a server without push still syncs', () async {
      phone.token = 't1';
      api.failPushTokens = true;
      await phone.reminders.save(physics);
      await phone.sync.sync();
      expect(await phone.waiting(), 0);
      api.failPushTokens = false;
      await phone.sync.sync();
      expect(api.tokenUpdates, 1, reason: 'tried again');
    });
  });
}
