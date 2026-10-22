import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/application/sync_providers.dart';
import '../application/focus_providers.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';

/// Keeps this device following the shared focus session while the app runs:
/// applies it whenever it or the block lists change (also when another
/// device started it), again when it ends and when the app comes back, and
/// starts one when the phone is put down screen first, if the user turned
/// that on.
class FocusCoordinator extends ConsumerStatefulWidget {
  const FocusCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FocusCoordinator> createState() => _FocusCoordinatorState();
}

class _FocusCoordinatorState extends ConsumerState<FocusCoordinator> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<FocusSession>? _sessions;
  StreamSubscription<FocusPrefs>? _prefsSub;
  StreamSubscription<void>? _flips;
  FocusSession? _session;
  FocusPrefs? _prefs;
  Timer? _end;
  bool _foreground = true;
  Future<void> _applying = Future.value();

  @override
  void initState() {
    super.initState();
    final repo = ref.read(focusRepositoryProvider);
    _sessions = repo.watch().listen((s) {
      _session = s;
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
      },
      onHide: () {
        _foreground = false;
        _updateFlip();
      },
    );
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
    _scheduleEnd(session);
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

  void _scheduleEnd(FocusSession session) {
    _end?.cancel();
    final left = session.remainingAt(DateTime.now());
    if (left > Duration.zero) {
      _end = Timer(left + const Duration(milliseconds: 200), _apply);
    }
  }

  /// Listens for the phone going face down only while that could start a
  /// session: turned on, the app in front, and nothing running.
  void _updateFlip() {
    final guard = ref.read(focusGuardProvider);
    final prefs = _prefs;
    final idle = !(_session?.runningAt(DateTime.now()) ?? false);
    final want =
        guard != null &&
        prefs != null &&
        prefs.flipToFocus &&
        _foreground &&
        idle;
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
    if (prefs == null || (_session?.runningAt(DateTime.now()) ?? false)) return;
    await HapticFeedback.heavyImpact();
    await ref
        .read(focusRepositoryProvider)
        .start(
          length: Duration(minutes: prefs.minutes),
          target: prefs.target,
          blockApps: prefs.blockApps,
          quiet: prefs.quiet,
          strict: prefs.strict,
          startedBy: ref.read(deviceNameProvider),
        );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
