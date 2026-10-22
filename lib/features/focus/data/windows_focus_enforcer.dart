import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../reminders/domain/reminder.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';
import '../domain/laptop_block_rules.dart';
import 'desktop_windows.dart';
import 'focus_enforcer.dart';

/// Focus mode on the laptop: while a session runs, checks every second
/// which window is in front and puts a blocked one away. A blocked site's
/// tab is closed; a blocked program is minimised, or closed in a strict
/// session. The app keeps running in the tray, so this works with its
/// window hidden.
class WindowsFocusEnforcer implements FocusEnforcer {
  WindowsFocusEnforcer({
    required this._windows,
    required this.onBlocked,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DesktopWindows _windows;
  final DateTime Function() _now;

  /// Tells the user what was put away. Called at most once a minute for
  /// the same thing.
  final void Function(BlockHit hit, FocusSession session) onBlocked;

  static const _every = Duration(seconds: 1);
  static const _noticeEvery = Duration(minutes: 1);

  Timer? _timer;
  FocusSession? _session;
  LaptopBlockRules? _rules;
  final _noticed = <String, DateTime>{};

  @visibleForTesting
  bool get watching => _timer != null;

  @override
  Future<void> apply(FocusSession session, FocusPrefs prefs) async {
    if (session.blockApps && session.runsOn(DeviceKind.laptop, _now())) {
      _session = session;
      _rules = LaptopBlockRules(programs: prefs.laptopApps, sites: prefs.sites);
      _timer ??= Timer.periodic(_every, (_) => check());
    } else {
      _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _session = null;
    _rules = null;
    _noticed.clear();
  }

  /// One look at the window in front.
  @visibleForTesting
  void check() {
    final session = _session;
    final rules = _rules;
    if (session == null || rules == null) return;
    final now = _now();
    if (!session.runningAt(now)) {
      _stop();
      return;
    }
    final DesktopWindow? window;
    try {
      window = _windows.foreground();
    } on Object catch (e) {
      debugPrint('focus: could not read the window in front: $e');
      return;
    }
    if (window == null) return;
    final hit = rules.match(window.exePath, window.title);
    if (hit == null) return;
    if (hit.isSite) {
      if (!_windows.closeTab(window.handle)) return;
    } else if (session.strict) {
      _windows.close(window.handle);
    } else {
      _windows.minimize(window.handle);
    }
    final last = _noticed[hit.label];
    if (last == null || now.difference(last) >= _noticeEvery) {
      _noticed[hit.label] = now;
      onBlocked(hit, session);
    }
  }

  @override
  Future<void> dispose() async => _stop();
}
