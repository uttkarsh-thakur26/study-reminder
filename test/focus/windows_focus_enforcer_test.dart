import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/data/browser_tabs.dart';
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

  /// False acts out a modifier key held by the user.
  bool tabsClose = true;

  @override
  bool closeTab(int handle) {
    if (tabsClose) actions.add('tab $handle');
    return tabsClose;
  }

  @override
  List<String> openPrograms() => const [];
}

class _FakeTabs implements BrowserTabs {
  /// The sites each sweep was asked to close.
  final sweeps = <List<String>>[];

  /// What each sweep closes.
  var closes = <BlockHit>[];

  /// While set, sweeps wait for it.
  Completer<void>? hold;

  /// Set to make sweeps fail.
  Object? error;

  @override
  Future<List<BlockHit>> closeBlockedTabs(List<String> sites) async {
    sweeps.add(sites);
    await hold?.future;
    if (error case final e?) throw e;
    return closes;
  }
}

void main() {
  late _FakeWindows windows;
  late _FakeTabs tabs;
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
    tabs = _FakeTabs();
    now = DateTime.utc(2026, 10, 22, 10);
    notices = [];
    enforcer = WindowsFocusEnforcer(
      windows: windows,
      tabs: tabs,
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

  test('a tab it could not close is tried again without a notice', () async {
    await enforcer.apply(session(), prefs);
    windows.front = const DesktopWindow(
      1,
      r'C:\x\chrome.exe',
      'Song - YouTube',
    );
    windows.tabsClose = false;
    enforcer.check();
    expect(notices, isEmpty);
    windows.tabsClose = true;
    enforcer.check();
    expect(windows.actions, ['tab 1']);
    expect(notices, ['YouTube']);
  });

  const youtube = BlockHit('YouTube', isSite: true);

  test(
    'sweeps tabs only while a session for the laptop blocks sites',
    () async {
      await enforcer.apply(session(target: FocusTarget.phone), prefs);
      expect(enforcer.watchingTabs, isFalse);
      await enforcer.apply(session(blockApps: false), prefs);
      expect(enforcer.watchingTabs, isFalse);
      await enforcer.apply(
        session(),
        const FocusPrefs(laptopApps: ['steam.exe'], sites: ['localhost']),
      );
      expect(enforcer.watching, isTrue);
      expect(enforcer.watchingTabs, isFalse);
      await enforcer.sweepTabs();
      expect(tabs.sweeps, isEmpty);

      await enforcer.apply(session(), prefs);
      expect(enforcer.watchingTabs, isTrue);
      await enforcer.sweepTabs();
      expect(tabs.sweeps, [
        ['youtube.com'],
      ]);

      await enforcer.apply(session(active: false), prefs);
      expect(enforcer.watchingTabs, isFalse);
      await enforcer.sweepTabs();
      expect(tabs.sweeps, hasLength(1));
    },
  );

  test('without browser tabs only the window in front is watched', () async {
    final alone = WindowsFocusEnforcer(
      windows: windows,
      now: () => now,
      onBlocked: (_, _) {},
    );
    await alone.apply(session(), prefs);
    expect(alone.watching, isTrue);
    expect(alone.watchingTabs, isFalse);
    await alone.dispose();
  });

  test('waits with Ctrl+W while a sweep may close the same tab', () async {
    await enforcer.apply(session(), prefs);
    final hold = tabs.hold = Completer<void>();
    final sweep = enforcer.sweepTabs();
    windows.front = const DesktopWindow(
      1,
      r'C:\x\chrome.exe',
      'Song - YouTube - Google Chrome',
    );
    enforcer.check();
    expect(windows.actions, isEmpty);
    hold.complete();
    await sweep;
    enforcer.check();
    expect(windows.actions, ['tab 1']);
  });

  test('never runs two sweeps at once', () async {
    await enforcer.apply(session(), prefs);
    final hold = tabs.hold = Completer<void>();
    final first = enforcer.sweepTabs();
    await enforcer.sweepTabs();
    expect(tabs.sweeps, hasLength(1));

    hold.complete();
    await first;
    await enforcer.sweepTabs();
    expect(tabs.sweeps, hasLength(2));
  });

  testWidgets('sweeps every few seconds, one at a time', (tester) async {
    await enforcer.apply(session(), prefs);
    await tester.pump(const Duration(seconds: 3));
    expect(tabs.sweeps, hasLength(1));

    // A slow sweep holds back the ones after it.
    final hold = tabs.hold = Completer<void>();
    await tester.pump(const Duration(seconds: 6));
    expect(tabs.sweeps, hasLength(2));
    tabs.hold = null;
    hold.complete();
    await tester.pump(const Duration(seconds: 3));
    expect(tabs.sweeps, hasLength(3));

    await enforcer.apply(session(active: false), prefs);
    await tester.pump(const Duration(seconds: 9));
    expect(tabs.sweeps, hasLength(3));
  });

  test('tells the user about closed tabs at most once a minute', () async {
    await enforcer.apply(session(), prefs);
    tabs.closes = [youtube];
    await enforcer.sweepTabs();
    expect(notices, ['YouTube']);

    // The same site closed in front counts as the same thing.
    now = now.add(const Duration(seconds: 10));
    windows.front = const DesktopWindow(
      1,
      r'C:\x\chrome.exe',
      'Song - YouTube',
    );
    enforcer.check();
    expect(windows.actions, ['tab 1']);
    now = now.add(const Duration(seconds: 20));
    await enforcer.sweepTabs();
    expect(notices, ['YouTube']);

    now = now.add(const Duration(seconds: 31));
    await enforcer.sweepTabs();
    expect(notices, ['YouTube', 'YouTube']);
  });

  test('stops sweeping when the session runs out', () async {
    await enforcer.apply(session(), prefs);
    now = now.add(const Duration(minutes: 26));
    await enforcer.sweepTabs();
    expect(tabs.sweeps, isEmpty);
    expect(enforcer.watchingTabs, isFalse);
    expect(enforcer.watching, isFalse);
  });

  test('a sweep that ends after the session gives no notice', () async {
    await enforcer.apply(session(), prefs);
    tabs.closes = [youtube];
    final hold = tabs.hold = Completer<void>();
    final sweep = enforcer.sweepTabs();
    await enforcer.apply(session(active: false), prefs);
    hold.complete();
    await sweep;
    expect(notices, isEmpty);
  });

  test('a failed sweep is let go and the next one runs', () async {
    await enforcer.apply(session(), prefs);
    tabs.error = Exception('no access');
    await enforcer.sweepTabs();
    tabs
      ..error = null
      ..closes = [youtube];
    await enforcer.sweepTabs();
    expect(tabs.sweeps, hasLength(2));
    expect(notices, ['YouTube']);
  });
}
