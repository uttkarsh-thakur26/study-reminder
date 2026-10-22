import 'package:focus_guard/focus_guard.dart';

import '../../reminders/domain/reminder.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';
import 'focus_enforcer.dart';

/// Focus mode on the phone, through the focus_guard plugin, which keeps
/// enforcing the session with the app closed.
class AndroidFocusEnforcer implements FocusEnforcer {
  AndroidFocusEnforcer({FocusGuard? guard, DateTime Function()? now})
    : _guard = guard ?? const FocusGuard(),
      _now = now ?? DateTime.now;

  final FocusGuard _guard;
  final DateTime Function() _now;
  FocusGuardSession? _started;

  @override
  Future<void> apply(FocusSession session, FocusPrefs prefs) async {
    // Kept on the phone for sessions pushed while the app is closed.
    await _guard.setBlocklist(prefs.phoneApps, blockGames: prefs.blockGames);
    final since = await _guard.runningSince();
    final syncedStart = session.startedAt;
    // A session pushed from another device can be newer than the one synced
    // here. It wins until the sync catches up.
    if (since != null && (syncedStart == null || since.isAfter(syncedStart))) {
      return;
    }
    final now = _now();
    if (session.runsOn(DeviceKind.phone, now)) {
      final want = FocusGuardSession(
        startedAt: syncedStart!,
        endsAt: session.endsAt!,
        blockApps: session.blockApps,
        quiet: session.quiet,
        strict: session.strict,
        blockGames: prefs.blockGames,
        packages: prefs.phoneApps,
        startedBy: session.startedBy,
      );
      if (since != null && want == _started) return;
      await _guard.start(want);
      _started = want;
    } else {
      _started = null;
      // Usually the phone has already ended a session that ran out, with
      // its own alarm; this covers an alarm that is running late.
      final ranOut = session.active && !session.runningAt(now);
      if (since != null) await _guard.stop(done: ranOut);
    }
  }

  @override
  Future<void> dispose() async {}
}
