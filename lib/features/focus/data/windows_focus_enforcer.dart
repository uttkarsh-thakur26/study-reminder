import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../reminders/domain/reminder.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';
import '../domain/laptop_block_rules.dart';
import '../domain/study_videos.dart';
import 'browser_tabs.dart';
import 'desktop_windows.dart';
import 'focus_enforcer.dart';

/// Focus mode on the laptop: while a session runs, checks every second
/// which window is in front and puts a blocked one away. A blocked site's
/// tab is closed; a blocked program is minimised, or closed in a strict
/// session. Every few seconds it also closes blocked sites in browser tabs
/// that are not in front, such as music left playing in a background tab.
/// The user's study videos stay open on YouTube: the tab in front by its
/// address, read from the address bar, and other tabs by the titles of
/// study videos seen that way.
/// The app keeps running in the tray, so this works with its window hidden.
class WindowsFocusEnforcer implements FocusEnforcer {
  WindowsFocusEnforcer({
    required this._windows,
    this._tabs,
    required this.onBlocked,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DesktopWindows _windows;

  /// Without it, only the window in front is watched.
  final BrowserTabs? _tabs;
  final DateTime Function() _now;

  /// Tells the user what was put away. Called at most once a minute for
  /// the same thing.
  final void Function(BlockHit hit, FocusSession session) onBlocked;

  static const _every = Duration(seconds: 1);
  static const _sweepEvery = Duration(seconds: 3);
  static const _noticeEvery = Duration(minutes: 1);

  Timer? _timer;
  Timer? _sweepTimer;
  bool _sweeping = false;
  FocusSession? _session;
  LaptopBlockRules? _rules;
  List<String> _sites = const [];
  final _noticed = <String, DateTime>{};

  StudyVideoRules? _study;
  List<StudyVideo> _studyVideos = const [];
  String _studyKey = '';

  /// Background tabs found showing a study video, by UI Automation id.
  final _studyTabs = <String>{};

  /// The window in front and its title when its address was last found to
  /// be a study video, so it is not read again every second.
  ({int handle, String title})? _studyFront;
  bool _reading = false;

  @visibleForTesting
  bool get watching => _timer != null;

  @visibleForTesting
  bool get watchingTabs => _sweepTimer != null;

  @override
  Future<void> apply(FocusSession session, FocusPrefs prefs) async {
    if (session.blockApps && session.enforcesOn(DeviceKind.laptop, _now())) {
      final rules = LaptopBlockRules(
        programs: prefs.laptopApps,
        sites: prefs.sites,
      );
      _session = session;
      _rules = rules;
      _sites = prefs.sites;
      final studyKey = [
        for (final v in prefs.studyVideos) '${v.isPlaylist}:${v.id}:${v.title}',
      ].join('|');
      if (_study == null || studyKey != _studyKey) {
        _study = StudyVideoRules(prefs.studyVideos);
        _studyVideos = prefs.studyVideos;
        _studyKey = studyKey;
        _studyTabs.clear();
        _studyFront = null;
      }
      _timer ??= Timer.periodic(_every, (_) => check());
      if (_tabs != null && rules.blocksSites) {
        _sweepTimer ??= Timer.periodic(
          _sweepEvery,
          (_) => unawaited(sweepTabs()),
        );
      } else {
        _sweepTimer?.cancel();
        _sweepTimer = null;
      }
    } else {
      _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _session = null;
    _rules = null;
    _sites = const [];
    _noticed.clear();
    _study = null;
    _studyVideos = const [];
    _studyKey = '';
    _studyTabs.clear();
    _studyFront = null;
  }

  /// One look at the window in front.
  @visibleForTesting
  void check() {
    final session = _session;
    final rules = _rules;
    if (session == null || rules == null) return;
    final now = _now();
    if (!session.enforcesOn(DeviceKind.laptop, now)) {
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
    final study = _study;
    if (hit.isYouTube && study != null && !study.isEmpty) {
      if (study.allowsTitle(window.title)) return;
      if (_studyFront == (handle: window.handle, title: window.title)) return;
      if (_tabs != null) {
        unawaited(_checkStudyVideo(window, hit, session, study));
        return;
      }
    }
    if (hit.isSite) {
      // A sweep may be closing this very tab; pressing Ctrl+W as well would
      // close the one next to it. Tried again next second.
      if (_sweeping) return;
      if (!_windows.closeTab(window.handle)) return;
    } else if (session.strict) {
      _windows.close(window.handle);
    } else {
      _windows.minimize(window.handle);
    }
    _notice(hit, session, now);
  }

  /// Leaves the YouTube tab in [window] open when its address is a study
  /// video, and closes it otherwise. One at a time; the next second's check
  /// tries again.
  Future<void> _checkStudyVideo(
    DesktopWindow window,
    BlockHit hit,
    FocusSession session,
    StudyVideoRules study,
  ) async {
    if (_reading) return;
    _reading = true;
    String? address;
    try {
      address = await _tabs!.addressOf(window.handle);
    } on Object catch (e) {
      debugPrint('focus: could not read the address: $e');
    } finally {
      _reading = false;
    }
    // The session or the study videos may have changed meanwhile.
    if (_session == null || !identical(_study, study)) return;
    if (address != null && study.allowsAddress(address)) {
      _studyFront = (handle: window.handle, title: window.title);
      study.learn(window.title);
      return;
    }
    final DesktopWindow? front;
    try {
      front = _windows.foreground();
    } on Object {
      return;
    }
    // Only the same tab, still in front.
    if (front == null ||
        front.handle != window.handle ||
        front.title != window.title ||
        _sweeping) {
      return;
    }
    if (_windows.closeTab(window.handle)) _notice(hit, session, _now());
  }

  /// One look through the browsers' tabs for blocked sites the check of the
  /// window in front can't see. While one runs, more calls do nothing.
  @visibleForTesting
  Future<void> sweepTabs() async {
    final tabs = _tabs;
    final session = _session;
    final rules = _rules;
    if (tabs == null || session == null || rules == null) return;
    if (!rules.blocksSites || _sweeping) return;
    if (!session.enforcesOn(DeviceKind.laptop, _now())) {
      _stop();
      return;
    }
    _sweeping = true;
    final study = _study;
    final TabSweep result;
    try {
      result = await tabs.closeBlockedTabs(
        _sites,
        study: StudyTabs(
          videos: _studyVideos,
          titles: study?.titles ?? const {},
          tabs: Set.of(_studyTabs),
        ),
      );
    } on Object catch (e) {
      debugPrint('focus: could not look at the browser tabs: $e');
      return;
    } finally {
      _sweeping = false;
    }
    // The session may have ended meanwhile.
    final current = _session;
    if (current == null) return;
    if (study != null && identical(study, _study)) {
      _studyTabs.addAll(result.studyTabs);
      result.studyTitles.forEach(study.learn);
    }
    for (final hit in result.closed) {
      _notice(hit, current, _now());
    }
  }

  void _notice(BlockHit hit, FocusSession session, DateTime now) {
    final last = _noticed[hit.label];
    if (last == null || now.difference(last) >= _noticeEvery) {
      _noticed[hit.label] = now;
      onBlocked(hit, session);
    }
  }

  @override
  Future<void> dispose() async => _stop();
}
