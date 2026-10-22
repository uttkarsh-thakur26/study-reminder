import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../reminders/domain/alert_planner.dart';
import '../domain/alert_sync.dart';
import 'alert_scheduler.dart';

/// Remembers what each queued alert carries, for schedulers that report only
/// ids. Windows is one: its queue returns ids with no payload, and queueing an
/// id twice keeps both copies, so each one would ring twice.
class PayloadTrackingScheduler implements AlertScheduler {
  PayloadTrackingScheduler(this.inner, this.db);

  final AlertScheduler inner;
  final AppDatabase db;

  static const ledgerKey = 'queued_alerts';

  @override
  Future<List<ScheduledAlert>> pending() async {
    final ledger = await _read();
    final queued = await inner.pending();
    final ids = {for (final a in queued) a.id};
    // Alerts that already rang are gone from the queue; forget them too.
    if (ledger.keys.any((id) => !ids.contains(id))) {
      ledger.removeWhere((id, _) => !ids.contains(id));
      await _write(ledger);
    }
    return [
      for (final a in queued)
        ScheduledAlert(a.id, AlertPayload.decode(ledger[a.id])),
    ];
  }

  @override
  Future<void> schedule(PlannedAlert alert) async {
    // Clear the old copy first, so a changed alert replaces it.
    await inner.cancel(alert.notificationId);
    await inner.schedule(alert);
    final ledger = await _read();
    ledger[alert.notificationId] = AlertPayload.of(alert).encode();
    await _write(ledger);
  }

  @override
  Future<void> cancel(int id) async {
    await inner.cancel(id);
    final ledger = await _read();
    if (ledger.remove(id) != null) await _write(ledger);
  }

  Map<int, String>? _ledger;

  Future<Map<int, String>> _read() async =>
      _ledger ??= _decode(await db.readSetting(ledgerKey));

  Future<void> _write(Map<int, String> ledger) => db.writeSetting(
    ledgerKey,
    jsonEncode({for (final e in ledger.entries) '${e.key}': e.value}),
  );

  static Map<int, String> _decode(String? raw) {
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, Object?>).entries)
          int.parse(e.key): e.value! as String,
      };
    } on Object {
      // A damaged ledger only costs one round of re-queueing.
      return {};
    }
  }
}
