import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_guard/focus_guard.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../alerts/application/alert_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../sync/application/sync_providers.dart';
import '../application/focus_providers.dart';
import '../domain/focus_plan.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';
import 'study_player.dart';

/// Keeps this device following its focus session while the app runs:
/// applies it whenever it or the block lists change (also when another
/// device started it), again as each round or break begins (with a note on
/// the laptop; the phone posts its own), when it ends and when the app
/// comes back, and
/// starts one when the phone is put down screen first, if the user turned
/// that on, or when they asked for one from the note that the laptop quit a
/// strict session.
class FocusCoordinator extends ConsumerStatefulWidget {
  const FocusCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FocusCoordinator> createState() => _FocusCoordinatorState();
}

class _FocusCoordinatorState extends ConsumerState<FocusCoordinator> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<FocusSessions>? _sessions;
  StreamSubscription<FocusPrefs>? _prefsSub;
  StreamSubscription<void>? _flips;
  FocusSession? _session;
  FocusSessions? _all;
  FocusPrefs? _prefs;
  Timer? _end;

  /// The phase last applied and the start of its session, to tell the user
  /// when the next one begins.
  ({DateTime session, FocusPhase phase})? _phase;
  bool _foreground = true;
  bool _askedAtStart = false;
  Future<void> _applying = Future.value();

  @override
  void initState() {
    super.initState();
    final repo = ref.read(focusRepositoryProvider);
    final here = ref.read(deviceKindProvider);
    unawaited(repo.adoptLegacy());
    _sessions = repo.watch().listen((s) {
      _all = s;
      _session = s.of(here);
      _apply();
    });
    _prefsSub = repo.watchPrefs().listen((p) {
      _prefs = p;
      _apply();
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        _apply();
        unawaited(_takeRequest());
        unawaited(_takeOpenPage());
      },
      onHide: () {
        _foreground = false;
        _updateFlip();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_askedAtStart) {
      _askedAtStart = true;
      unawaited(_takeRequest());
      unawaited(_takeOpenPage());
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sessions?.cancel();
    _prefsSub?.cancel();
    _flips?.cancel();
    _end?.cancel();
    super.dispose();
  }

  /// One at a time and in order, so a quick start and stop cannot cross.
  void _apply() {
    final session = _session;
    final prefs = _prefs;
    if (session == null || prefs == null) return;
    _scheduleNext(session);
    _notePhase(session);
    _updateFlip();
    final enforcer = ref.read(focusEnforcerProvider);
    _applying = _applying.then((_) async {
      try {
        await enforcer.apply(session, prefs);
      } on Object catch (e) {
        debugPrint('focus: could not apply the session: $e');
      }
    });
  }

  /// Applies again when the next round or break begins, or the session ends.
  void _scheduleNext(FocusSession session) {
    _end?.cancel();
    final now = DateTime.now();
    final next = session.nextChangeAfter(now);
    if (next != null) {
      _end = Timer(
        next.difference(now) + const Duration(milliseconds: 200),
        _apply,
      );
    }
  }

  /// "Break time" or "Back to focus" on the laptop, as one begins. The
  /// phone tells the user itself, even with the app closed.
  void _notePhase(FocusSession session) {
    final now = DateTime.now();
    final here = ref.read(deviceKindProvider);
    final phase = session.runsOn(here, now) ? session.phaseAt(now) : null;
    final before = _phase;
    _phase = phase == null ? null : (session: session.startedAt!, phase: phase);
    if (phase == null || before == null || phase.rounds < 2) return;
    if (ref.read(focusGuardProvider) != null) return;
    if (before.session != session.startedAt) return;
    if (before.phase.onBreak == phase.onBreak &&
        before.phase.round == phase.round) {
      return;
    }
    if (now.difference(phase.startedAt) > const Duration(minutes: 2)) return;
    final at = DateFormat.jm().format(phase.endsAt.toLocal());
    final minutes = (phase.length.inSeconds / 60).round();
    ref
        .read(localNotificationsProvider)
        ?.showInfo(
          title: phase.onBreak ? 'Break time · $minutes min' : 'Back to focus',
          body: phase.onBreak
              ? 'Round ${phase.round} of ${phase.rounds} done. Next round at $at.'
              : 'Round ${phase.round} of ${phase.rounds}, until $at.',
        )
        .catchError((Object e) => debugPrint('focus: phase note failed: $e'));
  }

  /// Listens for the phone going face down only while that could start a
  /// session: turned on, the app in front, and nothing running.
  void _updateFlip() {
    final guard = ref.read(focusGuardProvider);
    final prefs = _prefs;
    final session = _session;
    // A paused session waits to be resumed; a flip does not start another.
    final idle =
        session == null ||
        !(session.runningAt(DateTime.now()) || session.isPaused);
    final want =
        guard != null &&
        prefs != null &&
        prefs.flipToFocus &&
        _foreground &&
        idle;
    ref.read(flipArmedProvider.notifier).set(want);
    if (!want) {
      _flips?.cancel();
      _flips = null;
    } else {
      _flips ??= guard.faceDown().listen(
        (_) => _startFromFlip(),
        onError: (Object e) => debugPrint('focus: flip unavailable: $e'),
      );
    }
  }

  Future<void> _startFromFlip() async {
    final prefs = _prefs;
    final now = DateTime.now();
    if (prefs == null || (_session?.runningAt(now) ?? false)) return;
    final on = (_all ?? FocusSessions.idle).startable(
      prefs.target,
      here: ref.read(deviceKindProvider),
      paired: ref.read(syncApiProvider) != null,
      now: now,
      // Nothing the user did not choose: after a laptop-only flip, the next
      // one must not start the phone.
      orFree: false,
    );
    if (on.isEmpty) return;
    final guard = ref.read(focusGuardProvider);
    // Felt through the table; a tap's haptics may be turned off. Before the
    // start, which turns Do Not Disturb on.
    try {
      await guard?.buzz();
    } on Object catch (e) {
      debugPrint('focus: no buzz: $e');
      await HapticFeedback.heavyImpact();
    }
    await ref
        .read(focusRepositoryProvider)
        .startWith(prefs, on: on, startedBy: ref.read(deviceNameProvider));
    if (guard == null || !prefs.flipLock) return;
    // The phone left face down locks soon after.
    try {
      if (!await guard.lock()) debugPrint('focus: lock is not allowed');
    } on Object catch (e) {
      debugPrint('focus: could not lock: $e');
    }
  }

  /// "Focus here" on the note that the laptop quit its strict session:
  /// focus on this phone until that session would have ended, with the
  /// user's own Focus settings.
  Future<void> _takeRequest() async {
    final guard = ref.read(focusGuardProvider);
    if (guard == null) return;
    final DateTime? until;
    try {
      until = await guard.takeFocusRequest();
    } on Object catch (e) {
      debugPrint('focus: could not read the request: $e');
      return;
    }
    if (until == null) return;
    final now = DateTime.now();
    final repo = ref.read(focusRepositoryProvider);
    final length = until.difference(now);
    if (length < const Duration(minutes: 1)) return;
    final phone = (await repo.current()).phone;
    if (phone.runningAt(now)) {
      final short = until.difference(phone.endsAt!);
      if (short > Duration.zero) await repo.extend({DeviceKind.phone}, short);
      return;
    }
    final prefs = await repo.prefs();
    await repo.start(
      on: {DeviceKind.phone},
      length: length,
      blockApps: prefs.blockApps,
      quiet: prefs.quiet,
      strict: prefs.strict,
      subjectId: prefs.subjectId,
      startedBy: ref.read(deviceNameProvider),
      now: now,
    );
  }

  /// "Watch study videos" on YouTube's block screen: opens the player,
  /// unless it is open already.
  Future<void> _takeOpenPage() async {
    final guard = ref.read(focusGuardProvider);
    if (guard == null) return;
    final String? page;
    try {
      page = await guard.takeOpenPage();
    } on Object catch (e) {
      debugPrint('focus: could not read the page to open: $e');
      return;
    }
    if (page != FocusGuard.studyVideosPage || !mounted) return;
    if (StudyPlayerScreen.openCount == 0) await openStudyPlayer(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
