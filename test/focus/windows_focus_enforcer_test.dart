import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/data/desktop_windows.dart';
import 'package:study_reminder/features/focus/data/windows_focus_enforcer.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';
import 'package:study_reminder/features/focus/domain/focus_session.dart';
import 'package:study_reminder/features/focus/domain/laptop_block_rules.dart';

class _FakeWindows implements DesktopWindows {
  DesktopWindow? front;
  final actions = <String>[];

  @override
  DesktopWindow? foreground() => front;

  @override
  void minimize(int handle) => actions.add('minimize $handle');

  @override
  void close(int handle) => actions.add('close $handle');

  @override
  void closeTab(int handle) => actions.add('tab $handle');

  @override
  List<String> openPrograms() => const [];
}

void main() {
  late _FakeWindows windows;
  late DateTime now;
  late List<String> notices;
  late WindowsFocusEnforcer enforcer;
  const prefs = FocusPrefs(laptopApps: ['steam.exe'], sites: ['youtube.com']);

  FocusSession session({
    FocusTarget target = FocusTarget.both,
    bool strict = false,
    bool blockApps = true,
    bool active = true,
  }) => FocusSession(
    active: active,
    startedAt: now,
    endsAt: now.add(const Duration(minutes: 25)),
    target: target,
    blockApps: blockApps,
    strict: strict,
  );

  setUp(() {
    windows = _FakeWindows();
    now = DateTime.utc(2026, 10, 22, 10);
    notices = [];
    enforcer = WindowsFocusEnforcer(
      windows: windows,
      now: () => now,
      onBlocked: (BlockHit hit, _) => notices.add(hit.label),
    );
  });
  tearDown(() => enforcer.dispose());

  test('closes a blocked tab and minimises a blocked program', () async {
    await enforcer.apply(session(), prefs);
    expect(enforcer.watching, isTrue);

    windows.front = const DesktopWindow(
      1,
      r'C:\x\chrome.exe',
      'Song - YouTube - Google Chrome',
    );
    enforcer.check();
    windows.front = const DesktopWindow(2, r'C:\Steam\steam.exe', 'Steam');
    enforcer.check();
    windows.front = const DesktopWindow(3, r'C:\x\code.exe', 'notes.md');
    enforcer.check();

    expect(windows.actions, ['tab 1', 'minimize 2']);
    expect(notices, ['YouTube', 'steam']);
  });

  test('a strict session closes blocked programs', () async {
    await enforcer.apply(session(strict: true), prefs);
    windows.front = const DesktopWindow(2, r'C:\Steam\steam.exe', 'Steam');
    enforcer.check();
    expect(windows.actions, ['close 2']);
  });

  test('tells the user at most once a minute about the same thing', () async {
    await enforcer.apply(session(), prefs);
    windows.front = const DesktopWindow(2, r'C:\Steam\steam.exe', 'Steam');
    enforcer.check();
    now = now.add(const Duration(seconds: 30));
    enforcer.check();
    now = now.add(const Duration(seconds: 31));
    enforcer.check();
    expect(windows.actions, hasLength(3));
    expect(notices, hasLength(2));
  });

  test('only watches while a session for the laptop blocks things', () async {
    await enforcer.apply(session(target: FocusTarget.phone), prefs);
    expect(enforcer.watching, isFalse);
    await enforcer.apply(session(blockApps: false), prefs);
    expect(enforcer.watching, isFalse);
    await enforcer.apply(session(), prefs);
    expect(enforcer.watching, isTrue);
    await enforcer.apply(session(active: false), prefs);
    expect(enforcer.watching, isFalse);
  });

  test('stops by itself when the session runs out', () async {
    await enforcer.apply(session(), prefs);
    now = now.add(const Duration(minutes: 26));
    windows.front = const DesktopWindow(2, r'C:\Steam\steam.exe', 'Steam');
    enforcer.check();
    expect(windows.actions, isEmpty);
    expect(enforcer.watching, isFalse);
  });
}
