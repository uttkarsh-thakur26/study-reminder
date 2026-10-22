import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/data/android_focus_enforcer.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('focus_guard');
  late List<MethodCall> calls;
  late Map<String, Object?>? running;
  late DateTime now;
  late AndroidFocusEnforcer enforcer;
  const prefs = FocusPrefs(phoneApps: {'com.instagram.android'});

  setUp(() {
    calls = [];
    running = null;
    now = DateTime.utc(2026, 10, 22, 10);
    enforcer = AndroidFocusEnforcer(now: () => now);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'running':
              return running;
            case 'start':
              final args = (call.arguments as Map).cast<String, Object?>();
              running = {
                'startedAt': args['startedAt'],
                'endsAt': args['endsAt'],
              };
            case 'stop':
              running = null;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  FocusSession session({
    DateTime? startedAt,
    FocusTarget target = FocusTarget.both,
    bool active = true,
  }) {
    final at = startedAt ?? now;
    return FocusSession(
      active: active,
      startedAt: at,
      endsAt: at.add(const Duration(minutes: 25)),
      target: target,
      startedBy: 'Laptop',
    );
  }

  List<String> methods() => [
    for (final c in calls)
      if (c.method != 'running' && c.method != 'setBlocklist') c.method,
  ];

  test(
    'starts a session for the phone once, with its own block list',
    () async {
      await enforcer.apply(session(), prefs);
      await enforcer.apply(session(), prefs);
      expect(methods(), ['start']);
      final start = calls.firstWhere((c) => c.method == 'start');
      expect((start.arguments as Map)['packages'], ['com.instagram.android']);
      expect((start.arguments as Map)['startedBy'], 'Laptop');
      final list = calls.firstWhere((c) => c.method == 'setBlocklist');
      expect((list.arguments as Map)['packages'], ['com.instagram.android']);
    },
  );

  test('stops a session stopped elsewhere or moved to the laptop', () async {
    await enforcer.apply(session(), prefs);
    await enforcer.apply(session(target: FocusTarget.laptop), prefs);
    expect(methods(), ['start', 'stop']);
    expect((calls.last.arguments as Map)['done'], isFalse);

    await enforcer.apply(session(), prefs);
    await enforcer.apply(session(active: false), prefs);
    expect(methods(), ['start', 'stop', 'start', 'stop']);
  });

  test(
    'a newer session pushed to the phone wins over an older synced one',
    () async {
      running = {
        'startedAt': now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
        'endsAt': now.add(const Duration(minutes: 26)).millisecondsSinceEpoch,
      };
      await enforcer.apply(session(active: false), prefs);
      await enforcer.apply(FocusSession.idle, prefs);
      expect(methods(), isEmpty);
    },
  );

  test('a session that ran out ends with Focus done', () async {
    await enforcer.apply(session(), prefs);
    now = now.add(const Duration(minutes: 26));
    await enforcer.apply(
      session(startedAt: now.subtract(const Duration(minutes: 26))),
      prefs,
    );
    expect(methods(), ['start', 'stop']);
    expect((calls.last.arguments as Map)['done'], isTrue);
  });
}
