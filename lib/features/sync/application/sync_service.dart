import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../data/record_store.dart';
import '../data/sync_api.dart';
import '../domain/sync_record.dart';

/// Keys this feature keeps in the device-local settings table.
abstract final class SyncKeys {
  /// This device's credential. Never leaves the device except to the server.
  static const secret = 'sync_secret';
  static const space = 'sync_space';
  static const cursor = 'sync_cursor';

  /// The name the server has for this device, so a rename re-registers.
  static const registeredName = 'sync_registered_name';
  static const lastSynced = 'sync_last_synced';
}

/// Keeps this device's records in step with the other devices in its space,
/// and pairs it with them.
///
/// Every sync pushes local edits, then pulls what changed elsewhere since the
/// last pull. Both sides merge field by field, newest edit wins, so it does
/// not matter which device syncs first or how long one was offline.
class SyncService {
  SyncService({
    required AppDatabase db,
    required HlcClock clock,
    required this.api,
    required this.isPhone,
    required this.deviceName,
    DateTime Function()? now,
  }) : _db = db,
       _store = RecordStore(db, clock),
       _now = now ?? DateTime.now;

  final SyncApi api;
  final bool isPhone;

  /// What other devices see this one as, for example "Pixel 8".
  final String deviceName;

  final AppDatabase _db;
  final RecordStore _store;
  final DateTime Function() _now;

  Future<void> _last = Future.value();

  /// Runs [body] after every earlier call has finished, so a sync never
  /// overlaps a pairing change.
  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _last.then((_) => body());
    _last = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  /// The space this device is in, once registered.
  Future<String?> spaceId() => _db.readSetting(SyncKeys.space);

  /// When the last sync finished, if ever.
  Future<DateTime?> lastSynced() async {
    final raw = await _db.readSetting(SyncKeys.lastSynced);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Pushes local edits and pulls everything new. Returns how many records
  /// came in. Throws [SyncUnavailable] when offline.
  Future<int> sync() => _serial(_sync);

  Future<int> _sync() async {
    final secret = await _secret();
    await _ensureRegistered(secret);
    try {
      return await _exchange(secret);
    } on UnknownDeviceException {
      // The server lost us (for example the project was reset): start over
      // in a new space and send it everything.
      await _db.writeSetting(SyncKeys.registeredName, '');
      await _ensureRegistered(secret);
      return _exchange(secret);
    }
  }

  Future<int> _exchange(String secret) async {
    // Bounded, so rows edited faster than they upload cannot keep this going.
    for (var round = 0; round < 50; round++) {
      final batch = await _store.dirty();
      if (batch.isEmpty) break;
      await api.push(secret, [for (final p in batch) p.record]);
      await _store.markPushed(batch);
      if (batch.length < 200) break;
    }

    var received = 0;
    var cursor =
        int.tryParse(await _db.readSetting(SyncKeys.cursor) ?? '') ?? 0;
    while (true) {
      final page = await api.pull(secret, after: cursor, limit: 500);
      if (page.isEmpty) break;
      await _store.apply(page);
      received += page.length;
      cursor = page.map((r) => r.seq).reduce(max);
      await _db.writeSetting(SyncKeys.cursor, '$cursor');
      if (page.length < 500) break;
    }

    // A pull can leave records queued (local fields that were newer).
    final leftover = await _store.dirty(limit: 200);
    if (leftover.isNotEmpty) {
      await api.push(secret, [for (final p in leftover) p.record]);
      await _store.markPushed(leftover);
    }
    await _db.writeSetting(
      SyncKeys.lastSynced,
      _now().toUtc().toIso8601String(),
    );
    return received;
  }

  /// A code for another device to join this device's space. Syncs first, so
  /// the device that joins finds everything in its first pull.
  Future<PairingCode> createPairingCode() => _serial(() async {
    final secret = await _secret();
    await _ensureRegistered(secret);
    await _exchange(secret);
    return api.createPairingCode(secret);
  });

  /// Joins the space of the device showing [code], then sends it everything
  /// on this device and fetches everything it has.
  Future<void> joinWithCode(String code) => _serial(() async {
    final secret = await _secret();
    await _ensureRegistered(secret);
    final space = await api.joinSpace(secret, code);
    await _moveTo(space);
    await _exchange(secret);
  });

  /// Stops syncing with the other devices. Everything stays on this device.
  Future<void> unpair() => _serial(() async {
    final secret = await _secret();
    await _ensureRegistered(secret);
    await _moveTo(await api.leaveSpace(secret));
    await _exchange(secret);
  });

  Future<List<SyncedDevice>> devices() => _serial(() async {
    final secret = await _secret();
    await _ensureRegistered(secret);
    return api.listDevices(secret);
  });

  /// Fires when another device in the space changes something.
  Stream<void> remoteChanges() async* {
    final space = await spaceId();
    if (space != null) yield* api.changes(space);
  }

  Future<void> _ensureRegistered(String secret) async {
    final registered = await _db.readSetting(SyncKeys.registeredName);
    final space = await _db.readSetting(SyncKeys.space);
    if (registered == deviceName && space != null) return;
    final r = await api.register(
      secret: secret,
      name: deviceName,
      isPhone: isPhone,
    );
    if (r.spaceId != space) await _moveTo(r.spaceId);
    await _db.writeSetting(SyncKeys.registeredName, deviceName);
  }

  /// Starts over in [space]: pull from the beginning, push everything.
  Future<void> _moveTo(String space) async {
    await _db.writeSetting(SyncKeys.space, space);
    await _db.writeSetting(SyncKeys.cursor, '0');
    await _store.markAllDirty();
  }

  /// This device's secret, made once. Two isolates may ask at the same time,
  /// so it is written only if still missing and then read back.
  Future<String> _secret() async {
    final existing = await _db.readSetting(SyncKeys.secret);
    if (existing != null) return existing;
    final random = Random.secure();
    final fresh = base64Url
        .encode(List<int>.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    await _db.writeSettingIfAbsent(SyncKeys.secret, fresh);
    return (await _db.readSetting(SyncKeys.secret))!;
  }

  @visibleForTesting
  RecordStore get store => _store;
}
