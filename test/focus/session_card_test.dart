import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/app/providers.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/features/focus/data/focus_repository.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';
import 'package:study_reminder/features/focus/ui/focus_screen.dart';
import 'package:study_reminder/features/reminders/application/reminder_providers.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:study_reminder/features/subjects/domain/subject.dart';
import 'package:study_reminder/features/sync/application/sync_providers.dart';

import '../sync/fake_sync_api.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  FocusSession running(
    DeviceKind kind, {
    int minutes = 25,
    bool strict = false,
  }) {
    final at = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    return FocusSession(
      active: true,
      startedAt: at,
      endsAt: at.add(Duration(minutes: minutes)),
      target: FocusTarget.only(kind),
      strict: strict,
      startedBy: kind == DeviceKind.laptop ? 'DESKTOP-1' : 'Pixel',
    );
  }

  Future<void> pump(
    WidgetTester tester,
    FocusSessions sessions, {
    bool paired = true,
  }) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hlcClockProvider.overrideWithValue(HlcClock('testdevice01')),
          deviceKindProvider.overrideWithValue(DeviceKind.phone),
          deviceNameProvider.overrideWithValue('Pixel'),
          if (paired) syncApiProvider.overrideWithValue(FakeSyncApi()),
          // Drift streams never settle under the test clock.
          subjectsProvider.overrideWith(
            (ref) => Stream.value(const <Subject>[]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionCard(sessions: sessions, prefs: const FocusPrefs()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  testWidgets('the phone can start its own while the laptop focuses', (
    tester,
  ) async {
    final laptop = running(DeviceKind.laptop, strict: true);
    await pump(tester, FocusSessions(laptop: laptop));
    expect(find.text('Laptop'), findsOneWidget);
    expect(find.textContaining('strict'), findsOneWidget);
    expect(find.text('On this phone'), findsOneWidget);
    expect(find.text('Both'), findsNothing, reason: 'the laptop is busy');

    await tester.tap(find.text('Start focus'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    final now = await tester.runAsync(
      () => FocusRepository(db, HlcClock('x')).current(),
    );
    expect(now!.phone.runningAt(DateTime.now()), isTrue);
    expect(now.phone.startedBy, 'Pixel');
    expect(now.laptop.active, isFalse, reason: 'not written from here');
    await done(tester);
  });

  testWidgets('a session started on both shows once', (tester) async {
    final phone = running(DeviceKind.phone);
    final laptop = phone.copyWith(target: FocusTarget.laptop);
    await pump(tester, FocusSessions(phone: phone, laptop: laptop));
    expect(find.text('left'), findsOneWidget);
    expect(find.textContaining('On phone and laptop'), findsOneWidget);
    expect(find.text('Start focus'), findsNothing);
    expect(find.textContaining('too'), findsNothing);
    await done(tester);
  });

  testWidgets('while the phone focuses, the laptop can start too', (
    tester,
  ) async {
    await pump(tester, FocusSessions(phone: running(DeviceKind.phone)));
    expect(find.text('left'), findsOneWidget);
    expect(find.textContaining('On this phone'), findsOneWidget);
    expect(find.text('Focus on the laptop too'), findsOneWidget);
    await done(tester);
  });

  testWidgets('a paused session shows its time and resumes', (tester) async {
    final at = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    final paused = FocusSession(
      startedAt: at.subtract(const Duration(minutes: 5)),
      endsAt: at.add(const Duration(minutes: 20)),
      target: FocusTarget.phone,
      startedBy: 'Pixel',
      pausedAt: at,
    );
    await pump(tester, FocusSessions(phone: paused));
    expect(find.text('paused'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Start focus'), findsNothing, reason: 'still held');
    expect(find.text('Focus on the laptop too'), findsOneWidget);
    await done(tester);
  });

  testWidgets("the laptop's session can be paused from the phone", (
    tester,
  ) async {
    await pump(tester, FocusSessions(laptop: running(DeviceKind.laptop)));
    expect(find.byTooltip('Pause on the laptop'), findsOneWidget);
    expect(find.byTooltip('Change the time on the laptop'), findsOneWidget);
    expect(find.byTooltip('More for the laptop'), findsOneWidget);
    await done(tester);
  });

  testWidgets('with nothing paired, there is no choice of device', (
    tester,
  ) async {
    await pump(tester, FocusSessions.idle, paired: false);
    expect(find.text('Start focus'), findsOneWidget);
    expect(find.text('Both'), findsNothing);
    expect(find.textContaining('On '), findsNothing);
    await done(tester);
  });

  test('a session can start only where none runs', () {
    final now = DateTime.now();
    final laptopBusy = FocusSessions(laptop: running(DeviceKind.laptop));
    expect(
      laptopBusy.startable(
        FocusTarget.both,
        here: DeviceKind.phone,
        paired: true,
        now: now,
      ),
      {DeviceKind.phone},
    );
    expect(
      FocusSessions.idle.startable(
        FocusTarget.laptop,
        here: DeviceKind.phone,
        paired: true,
        now: now,
      ),
      {DeviceKind.laptop},
    );
    expect(
      FocusSessions.idle.startable(
        FocusTarget.laptop,
        here: DeviceKind.phone,
        paired: false,
        now: now,
      ),
      {DeviceKind.phone},
    );
  });
}
