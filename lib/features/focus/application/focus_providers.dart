import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:focus_guard/focus_guard.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../alerts/application/alert_providers.dart';
import '../data/android_focus_enforcer.dart';
import '../data/desktop_windows.dart';
import '../data/focus_enforcer.dart';
import '../data/focus_repository.dart';
import '../data/windows_focus_enforcer.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';
import '../domain/laptop_block_rules.dart';

final focusRepositoryProvider = Provider<FocusRepository>(
  (ref) =>
      FocusRepository(ref.watch(databaseProvider), ref.watch(hlcClockProvider)),
);

final focusSessionsProvider = StreamProvider<FocusSessions>(
  (ref) => ref.watch(focusRepositoryProvider).watch(),
);

final focusPrefsProvider = StreamProvider<FocusPrefs>(
  (ref) => ref.watch(focusRepositoryProvider).watchPrefs(),
);

/// The phone's focus features. Set at startup on Android.
final focusGuardProvider = Provider<FocusGuard?>((ref) => null);

/// The laptop's windows. Set at startup on Windows.
final desktopWindowsProvider = Provider<DesktopWindows?>((ref) => null);

/// What makes this device follow the focus session.
final focusEnforcerProvider = Provider<FocusEnforcer>((ref) {
  final guard = ref.watch(focusGuardProvider);
  final windows = ref.watch(desktopWindowsProvider);
  final FocusEnforcer enforcer;
  if (guard != null) {
    enforcer = AndroidFocusEnforcer(guard: guard);
  } else if (windows != null) {
    enforcer = WindowsFocusEnforcer(
      windows: windows,
      onBlocked: (hit, session) => _notice(ref, hit, session),
    );
  } else {
    enforcer = const NoopFocusEnforcer();
  }
  ref.onDispose(enforcer.dispose);
  return enforcer;
});

void _notice(Ref ref, BlockHit hit, FocusSession session) {
  final until = DateFormat.jm().format(session.endsAt!.toLocal());
  ref
      .read(localNotificationsProvider)
      ?.showInfo(
        title: hit.isSite ? 'Closed ${hit.label}' : '${hit.label} is blocked',
        body: 'Focus until $until. Back to it.',
      )
      .catchError((Object e) => debugPrint('focus notice failed: $e'));
}

/// The platform parts of Focus mode, for the root ProviderScope.
List<Override> focusPlatformOverrides() {
  if (kIsWeb) return [];
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => [
      focusGuardProvider.overrideWithValue(const FocusGuard()),
    ],
    TargetPlatform.windows => [
      desktopWindowsProvider.overrideWithValue(Win32Windows()),
    ],
    _ => [],
  };
}
