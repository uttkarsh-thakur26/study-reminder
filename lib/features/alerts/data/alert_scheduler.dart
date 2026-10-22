import '../../reminders/domain/alert_planner.dart';
import '../domain/alert_sync.dart';

/// The operating system's notification queue, as the app sees it.
abstract interface class AlertScheduler {
  Future<List<ScheduledAlert>> pending();

  Future<void> schedule(PlannedAlert alert);

  Future<void> cancel(int id);
}

/// Used where the platform has no notification support wired up yet.
class NoopAlertScheduler implements AlertScheduler {
  const NoopAlertScheduler();

  @override
  Future<List<ScheduledAlert>> pending() async => const [];

  @override
  Future<void> schedule(PlannedAlert alert) async {}

  @override
  Future<void> cancel(int id) async {}
}
