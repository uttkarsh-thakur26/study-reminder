import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../reminders/domain/reminder.dart';
import '../data/sync_api.dart';
import 'sync_service.dart';

/// Set at startup when this build knows its sync server.
final syncApiProvider = Provider<SyncApi?>((ref) => null);

/// What other devices call this one. Set at startup.
final deviceNameProvider = Provider<String>((ref) => 'This device');

final syncServiceProvider = Provider<SyncService?>((ref) {
  final api = ref.watch(syncApiProvider);
  if (api == null) return null;
  return SyncService(
    db: ref.watch(databaseProvider),
    clock: ref.watch(hlcClockProvider),
    api: api,
    isPhone: ref.watch(deviceKindProvider) == DeviceKind.phone,
    deviceName: ref.watch(deviceNameProvider),
  );
});

enum SyncPhase {
  /// This build has no sync server.
  off,
  idle,
  syncing,

  /// The last try could not reach the server. Edits wait on this device.
  offline,
}

class SyncStatus {
  const SyncStatus(this.phase, {this.lastSynced});

  final SyncPhase phase;
  final DateTime? lastSynced;
}

/// The sync state shown in Settings, and the one way to start a sync.
final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  bool _again = false;

  @override
  SyncStatus build() {
    final service = ref.watch(syncServiceProvider);
    if (service == null) return const SyncStatus(SyncPhase.off);
    service.lastSynced().then((at) {
      if (state.phase == SyncPhase.idle && state.lastSynced == null) {
        state = SyncStatus(SyncPhase.idle, lastSynced: at);
      }
    });
    return const SyncStatus(SyncPhase.idle);
  }

  /// Syncs now. A call while a sync runs makes one more run afterwards, so
  /// an edit made mid-sync is not left waiting.
  Future<void> syncNow() async {
    final service = ref.read(syncServiceProvider);
    if (service == null) return;
    if (state.phase == SyncPhase.syncing) {
      _again = true;
      return;
    }
    do {
      _again = false;
      state = SyncStatus(SyncPhase.syncing, lastSynced: state.lastSynced);
      try {
        await service.sync();
        state = SyncStatus(SyncPhase.idle, lastSynced: DateTime.now());
      } on Object catch (e) {
        if (e is! SyncUnavailable) debugPrint('sync failed: $e');
        state = SyncStatus(SyncPhase.offline, lastSynced: state.lastSynced);
        _again = false;
      }
    } while (_again);
  }
}
