import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../desktop/desktop_window.dart';
import '../../../desktop/mini_timer.dart';
import '../../alerts/application/alert_providers.dart';
import '../../alerts/data/local_notifications.dart';
import '../../focus/application/focus_providers.dart';
import '../application/update_providers.dart';
import 'update_dialog.dart';

/// Checks for a new version once a day, and asks the user about it at most
/// once a day: at start, when the app comes back, and every hour while it
/// runs (the laptop app stays open in the tray for days). Never during a
/// focus session, so studying isn't interrupted.
///
/// While the laptop app sits hidden in the tray, a toast says the update is
/// out instead (once per version), and a click on it opens the prompt.
class UpdateCoordinator extends ConsumerStatefulWidget {
  const UpdateCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateCoordinator> createState() => _UpdateCoordinatorState();
}

class _UpdateCoordinatorState extends ConsumerState<UpdateCoordinator> {
  AppLifecycleListener? _lifecycle;
  StreamSubscription<NotificationResponse>? _taps;
  Timer? _start;
  Timer? _hourly;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(updateServiceProvider).enabled) return;
    // After startup settles, so the first frame and sync go first.
    _start = Timer(const Duration(seconds: 8), _check);
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => _check());
    _lifecycle = AppLifecycleListener(onResume: _check);
    // A click on the update notification opens the prompt, while the app
    // runs or when the click started it.
    _taps = ref
        .read(localNotificationsProvider)
        ?.taps
        .where(_isUpdateTap)
        .listen((_) => unawaited(_openFromNotification()));
    final launch = ref.read(launchResponseProvider);
    if (launch != null && _isUpdateTap(launch)) {
      _start?.cancel();
      _start = Timer(
        const Duration(seconds: 1),
        () => unawaited(_openFromNotification()),
      );
    }
  }

  static bool _isUpdateTap(NotificationResponse r) =>
      r.payload == updatePayload || r.id == updateNotificationId;

  @override
  void dispose() {
    _start?.cancel();
    _hourly?.cancel();
    _lifecycle?.dispose();
    _taps?.cancel();
    super.dispose();
  }

  Future<void> _check() => _run(() async {
    if (await _focusing()) return;
    final service = ref.read(updateServiceProvider);
    if (isWindowsApp && !await windowManager.isVisible()) {
      final notifications = ref.read(localNotificationsProvider);
      final update = await service.toNotify();
      if (update != null && notifications != null) {
        await notifications.showUpdate('${update.version}');
        await service.markNotified(update);
      }
      return;
    }
    final update = await service.toPrompt();
    // A focus session may have started while GitHub answered.
    if (update == null || !mounted || await _focusing()) return;
    await service.markPrompted();
    if (mounted) await showUpdatePrompt(context, update);
  });

  /// A click on the notification is never dropped: while a check runs, it
  /// waits for the check to finish.
  Future<void> _openFromNotification() async {
    while (_busy && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await _run(_openPrompt);
  }

  Future<void> _openPrompt() async {
    if (isWindowsApp) {
      await showFullWindow(ref.read(miniTimerProvider.notifier));
    }
    final update = await ref.read(updateServiceProvider).available();
    if (update != null && mounted) await showUpdatePrompt(context, update);
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      await body();
    } on Object catch (e) {
      debugPrint('update check failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<bool> _focusing() async {
    if (ref.read(miniTimerProvider)) return true;
    final sessions = await ref.read(focusRepositoryProvider).current();
    final now = DateTime.now();
    return sessions.phone.runningAt(now) || sessions.laptop.runningAt(now);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
