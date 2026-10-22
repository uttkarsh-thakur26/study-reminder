import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/data/android_focus_enforcer.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('focus_guard');
  late List<MethodCall> calls;
  late DateTime now;
  late AndroidFocusEnforcer enforcer;
  const prefs = FocusPrefs(phoneApps: {'com.instagram.android'});

  setUp(() {
    calls = [];
    now = DateTime.utc(2026, 10, 22, 10);
    enforcer = AndroidFocusEnforcer(now: () => now);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  FocusSession session({
    String version = 'v1',
    FocusTarget target = FocusTarget.both,
    bool active = true,
  }) => FocusSession(
    active: active,
    startedAt: now,
    endsAt: now.add(const Duration(minutes: 25)),
    target: target,
    startedBy: 'Laptop',
    version: version,
  );

  Map<Object?, Object?> lastApply() =>
      calls.lastWhere((c) => c.method == 'apply').arguments as Map;

  test('hands the phone the session with its version and block list', () async {
    await enforcer.apply(session(), prefs);
    final args = lastApply();
    expect(args['version'], 'v1');
    final s = args['session']! as Map;
    expect(s['packages'], ['com.instagram.android']);
    expect(s['startedBy'], 'Laptop');
    final list = calls.firstWhere((c) => c.method == 'setBlocklist');
    expect((list.arguments as Map)['packages'], ['com.instagram.android']);
  });

  test('a session that does not run here is applied as none', () async {
    for (final s in [
      session(target: FocusTarget.laptop, version: 'v2'),
      session(active: false, version: 'v3'),
    ]) {
      await enforcer.apply(s, prefs);
      expect(lastApply()['version'], s.version);
      expect(lastApply()['session'], isNull);
    }
    final earlier = session(version: 'v4');
    now = now.add(const Duration(minutes: 26));
    await enforcer.apply(earlier, prefs);
    expect(lastApply()['session'], isNull, reason: 'ran out');
  });

  test('a session never saved here is left to the phone', () async {
    await enforcer.apply(FocusSession.idle, prefs);
    expect(calls.where((c) => c.method == 'apply'), isEmpty);
  });
}
