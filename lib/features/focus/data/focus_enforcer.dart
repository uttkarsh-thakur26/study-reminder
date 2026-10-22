import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';

/// Makes this device do what the shared focus session asks of it.
abstract interface class FocusEnforcer {
  /// Called whenever the session or this device's Focus settings change, when
  /// the session ends, and when the app comes back. Safe to repeat.
  Future<void> apply(FocusSession session, FocusPrefs prefs);

  Future<void> dispose();
}

/// For platforms without device features: the session only shows in the app.
class NoopFocusEnforcer implements FocusEnforcer {
  const NoopFocusEnforcer();

  @override
  Future<void> apply(FocusSession session, FocusPrefs prefs) async {}

  @override
  Future<void> dispose() async {}
}
