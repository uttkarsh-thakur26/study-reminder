import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/app/providers.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/desktop/focus_hotkey.dart';
import 'package:study_reminder/desktop/global_hotkeys.dart';
import 'package:study_reminder/features/focus/application/focus_providers.dart';
import 'package:study_reminder/features/focus/data/focus_repository.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';
import 'package:study_reminder/features/reminders/domain/reminder.dart';
import 'package:study_reminder/features/sync/application/sync_providers.dart';
import 'package:study_reminder/shell/shell_requests.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(hotkeyChannelName);

  late AppDatabase db;
  late List<String> calls;
  late List<String> taken;
  late int windowShown;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    calls = [];
    taken = [];
    windowShown = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'enable' ? taken : null;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await db.close();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        hlcClockProvider.overrideWithValue(HlcClock('testdevice01')),
        deviceNameProvider.overrideWithValue('DESKTOP-1'),
        hotkeyActionsProvider.overrideWith(
          (ref) => HotkeyActions(ref, showWindow: () async => windowShown++),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// The runner reporting a press, as Windows' WM_HOTKEY makes it.
  Future<void> press(String id) async {
    await messenger.handlePlatformMessage(
      hotkeyChannelName,
      const StandardMethodCodec().encodeMethodCall(MethodCall('pressed', id)),
      (_) {},
    );
  }

  group('channel', () {
    test('shortcuts are on by default, with the taken ones listed', () async {
      taken = ['focus'];
      final state = await container().read(globalHotkeysProvider.future);
      expect(calls, ['enable']);
      expect(state.enabled, isTrue);
      expect(state.taken, {GlobalHotkey.focus});
    });

    test('turning them off gives them back and lasts', () async {
      final c = container();
      await c.read(globalHotkeysProvider.future);
      await c.read(globalHotkeysProvider.notifier).setEnabled(false);
      expect(calls, ['enable', 'disable']);
      expect(c.read(globalHotkeysProvider).value?.enabled, isFalse);
      expect(await db.readSetting(GlobalHotkeys.settingKey), 'off');

      // The next start leaves them off.
      calls.clear();
      final next = await container().read(globalHotkeysProvider.future);
      expect(calls, ['disable']);
      expect(next.enabled, isFalse);
    });

    test('trying again picks up a shortcut another app let go', () async {
      taken = ['quickAdd', 'focus'];
      final c = container();
      expect((await c.read(globalHotkeysProvider.future)).taken, hasLength(2));
      taken = [];
      await c.read(globalHotkeysProvider.notifier).retry();
      expect(c.read(globalHotkeysProvider).value?.taken, isEmpty);
    });

    test(
      'a runner without the channel shows them all as unavailable',
      () async {
        messenger.setMockMethodCallHandler(channel, null);
        final state = await container().read(globalHotkeysProvider.future);
        expect(state.enabled, isTrue);
        expect(state.taken, GlobalHotkey.values.toSet());
      },
    );

    test(
      'quick add shows the window and asks the shell for the field',
      () async {
        final c = container();
        await c.read(globalHotkeysProvider.future);
        await press('quickAdd');
        expect(windowShown, 1);
        expect(c.read(shellRequestsProvider)?.request, ShellRequest.quickAdd);

        // A second press reaches the shell again.
        final first = c.read(shellRequestsProvider);
        await press('quickAdd');
        expect(c.read(shellRequestsProvider), isNot(first));
      },
    );

    test('an unknown shortcut does nothing', () async {
      final c = container();
      await c.read(globalHotkeysProvider.future);
      await press('somethingElse');
      expect(windowShown, 0);
      expect(c.read(shellRequestsProvider), isNull);
    });

    test('the focus shortcut starts and stops the laptop session', () async {
      final c = container();
      final repo = c.read(focusRepositoryProvider);
      await repo.savePrefs(const FocusPrefs(minutes: 40, strict: false));
      await c.read(globalHotkeysProvider.future);

      await press('focus');
      var sessions = await repo.current();
      expect(sessions.laptop.runningAt(DateTime.now()), isTrue);
      expect(sessions.laptop.length, const Duration(minutes: 40));
      expect(sessions.laptop.startedBy, 'DESKTOP-1');
      expect(sessions.phone.active, isFalse);
      // No notifications in tests, so the window says it instead.
      expect(c.read(shellRequestsProvider)?.request, ShellRequest.focus);

      await press('focus');
      sessions = await repo.current();
      expect(sessions.laptop.runningAt(DateTime.now()), isFalse);
    });
  });

  group('focus shortcut', () {
    final now = DateTime(2026, 10, 22, 10);
    late FocusRepository repo;

    setUp(() => repo = FocusRepository(db, HlcClock('testdevice01')));

    FocusSession running({bool strict = false}) => FocusSession(
      active: true,
      startedAt: now.subtract(const Duration(minutes: 5)),
      endsAt: now.add(const Duration(minutes: 30)),
      target: FocusTarget.laptop,
      strict: strict,
    );

    test('decides from the laptop session', () {
      expect(focusHotkeyStep(FocusSession.idle, now), FocusHotkeyStep.start);
      expect(focusHotkeyStep(running(), now), FocusHotkeyStep.stop);
      expect(focusHotkeyStep(running(strict: true), now), FocusHotkeyStep.show);
      // One that ran out counts as none.
      expect(
        focusHotkeyStep(running(), now.add(const Duration(hours: 1))),
        FocusHotkeyStep.start,
      );
    });

    test('starts on the laptop only, with the saved defaults', () async {
      await repo.savePrefs(
        const FocusPrefs(
          minutes: 50,
          target: FocusTarget.both,
          blockApps: false,
          strict: true,
        ),
      );
      final result = await toggleLaptopFocus(
        repo,
        startedBy: 'DESKTOP-1',
        now: now,
      );
      expect(result.step, FocusHotkeyStep.start);
      expect(result.laptop.runningAt(now), isTrue);
      expect(
        result.laptop.endsAt,
        now.add(const Duration(minutes: 50)).toUtc(),
      );
      expect(result.laptop.blockApps, isFalse);
      expect(result.laptop.strict, isTrue);
      expect(result.laptop.target, FocusTarget.laptop);
      expect((await repo.current()).phone.active, isFalse);
    });

    test('leaves a running phone session alone', () async {
      await repo.start(
        on: {DeviceKind.phone},
        length: const Duration(minutes: 25),
        blockApps: true,
        quiet: true,
        strict: false,
        startedBy: 'Pixel',
        now: now,
      );
      await toggleLaptopFocus(repo, startedBy: 'DESKTOP-1', now: now);
      await toggleLaptopFocus(repo, startedBy: 'DESKTOP-1', now: now);
      final sessions = await repo.current();
      expect(sessions.phone.runningAt(now), isTrue);
      expect(sessions.laptop.runningAt(now), isFalse);
    });

    test('a strict session keeps running', () async {
      await repo.savePrefs(const FocusPrefs(strict: true));
      await toggleLaptopFocus(repo, startedBy: 'DESKTOP-1', now: now);
      final result = await toggleLaptopFocus(
        repo,
        startedBy: 'DESKTOP-1',
        now: now,
      );
      expect(result.step, FocusHotkeyStep.show);
      expect(result.laptop.runningAt(now), isTrue);
    });

    test('says what it did', () {
      final started = focusHotkeyNote(
        FocusHotkeyStep.start,
        running(),
        keys: 'Ctrl+Alt+F',
        now: now,
      );
      expect(started?.title, startsWith('Focus on until 10:30'));
      expect(started?.body, 'Press Ctrl+Alt+F again to stop early.');
      expect(
        focusHotkeyNote(
          FocusHotkeyStep.start,
          running(strict: true),
          keys: 'Ctrl+Alt+F',
          now: now,
        )?.body,
        'Strict session: it runs to the end.',
      );
      expect(
        focusHotkeyNote(
          FocusHotkeyStep.stop,
          FocusSession.idle,
          keys: 'Ctrl+Alt+F',
        )?.title,
        'Focus stopped on this laptop',
      );
      expect(
        focusHotkeyNote(
          FocusHotkeyStep.show,
          running(strict: true),
          keys: 'Ctrl+Alt+F',
        ),
        isNull,
      );
    });
  });
}
