import 'package:focus_guard/focus_guard.dart';

import '../../reminders/domain/reminder.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';
import 'focus_enforcer.dart';

/// Focus mode on the phone, through the focus_guard plugin, which keeps
/// enforcing the session with the app closed.
///
/// The plugin decides which news is newest, by the session's version, so a
/// stop pushed from the laptop is not undone by this phone's older copy and
/// the app and the background task can apply in any order.
class AndroidFocusEnforcer implements FocusEnforcer {
  AndroidFocusEnforcer({FocusGuard? guard, DateTime Function()? now})
    : _guard = guard ?? const FocusGuard(),
      _now = now ?? DateTime.now;

  final FocusGuard _guard;
  final DateTime Function() _now;

  @override
  Future<void> apply(FocusSession session, FocusPrefs prefs) async {
    // Kept on the phone for sessions pushed while the app is closed.
    await _guard.setBlocklist(prefs.phoneApps, blockGames: prefs.blockGames);
    if (session.version.isEmpty) return;
    final runsHere = session.runsOn(DeviceKind.phone, _now());
    await _guard.apply(
      version: session.version,
      session: runsHere
          ? FocusGuardSession(
              startedAt: session.startedAt!,
              endsAt: session.endsAt!,
              blockApps: session.blockApps,
              quiet: session.quiet,
              strict: session.strict,
              blockGames: prefs.blockGames,
              packages: prefs.phoneApps,
              startedBy: session.startedBy,
              workMinutes: session.workMinutes,
              breakMinutes: session.breakMinutes,
            )
          : null,
    );
  }

  @override
  Future<void> dispose() async {}
}
