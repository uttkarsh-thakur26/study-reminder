import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../application/alert_providers.dart';
import '../data/alert_scheduler.dart';
import '../data/lock_screen.dart';
import '../domain/alert_sync.dart';
import 'alarm_screen.dart';

/// Keeps the phone's alarm queue current and opens the alarm page when a
/// notification is tapped or rings full screen.
///
/// Replans on launch, on resume (the user may have changed permissions or the
/// clock), and shortly after any reminder, subject or occurrence change.
class AlertCoordinator extends ConsumerStatefulWidget {
  const AlertCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AlertCoordinator> createState() => _AlertCoordinatorState();
}

class _AlertCoordinatorState extends ConsumerState<AlertCoordinator> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<NotificationResponse>? _taps;
  Timer? _debounce;
  bool _alarmOpen = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _taps = ref.read(localNotificationsProvider)?.taps.listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final launch = ref.read(launchResponseProvider);
      if (launch != null) {
        _open(launch);
      } else {
        unawaited(LockScreen.release());
      }
      _replan(verify: true);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _taps?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _onResume() {
    ref.invalidate(alertHealthProvider);
    _replan();
  }

  void _replanSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _replan);
  }

  void _replan({bool verify = false}) {
    // Nothing to keep in step where the platform has no alerts wired up.
    if (!mounted || ref.read(alertSchedulerProvider) is NoopAlertScheduler) {
      return;
    }
    unawaited(ref.read(alertServiceProvider).replan(verify: verify));
  }

  void _open(NotificationResponse response) {
    if (!mounted) return;
    final payload = AlertPayload.decode(response.payload);
    final action = response.actionId;
    final ringing =
        payload != null &&
        action == null &&
        payload.style == ReminderStyle.alarm;
    if (!ringing) {
      if (!_alarmOpen) unawaited(LockScreen.release());
      if (payload != null && action != null) {
        unawaited(ref.read(alertServiceProvider).handleAction(action, payload));
      }
      return;
    }
    if (_alarmOpen) return;
    _alarmOpen = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => AlarmScreen(payload: payload),
          ),
        )
        .whenComplete(() {
          _alarmOpen = false;
          unawaited(LockScreen.release());
        });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(remindersProvider, (_, _) => _replanSoon());
    ref.listen(occurrenceStatesProvider, (_, _) => _replanSoon());
    ref.listen(subjectsProvider, (_, _) => _replanSoon());
    return widget.child;
  }
}
