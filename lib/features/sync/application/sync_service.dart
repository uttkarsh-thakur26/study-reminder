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

  /// The record kinds the cursor was moved with; see
  /// [SyncService._pullAgainIfKindsChanged].
  static const kinds = 'sync_kinds';

  /// The push token last given to the server, with the space it was given
  /// in; see [SyncService._sendPushToken].
  static const pushTokenSent = 'sync_push_token_sent';
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
    this._pushToken,
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

  /// This phone's push token, so the others can wake it for focus sessions.
  final Future<String?> Function()? _pushToken;
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
      await _forgetRegistration();
      await _ensureRegistered(secret);
      return _exchange(secret);
    }
  }

  /// Makes the next call register again and so learn which space the server
  /// has this device in. Set before any call that moves the device, in case
  /// the reply is lost or the app stops before the move is saved here.
  Future<void> _forgetRegistration() =>
      _db.writeSetting(SyncKeys.registeredName, '');

  Future<int> _exchange(String secret) async {
    final space = await spaceId();
    try {
      return await _exchangeIn(space, secret);
    } on _SpaceChanged {
      // Moved meanwhile by the other isolate, whose own sync takes over.
      return 0;
    }
  }

  /// Saves what [body] writes in one transaction, unless this device has
  /// moved since [space] was read: then it belongs to the old space and is
  /// dropped. The Android background task syncs from another isolate, so a
  /// move can land in the middle of an exchange.
  Future<void> _inSpace(String? space, Future<void> Function() body) =>
      _db.transaction(() async {
        if (await spaceId() != space) throw const _SpaceChanged();
        await body();
      });

  Future<int> _exchangeIn(String? space, String secret) async {
    await _pullAgainIfKindsChanged(space);

    var pushedFocus = false;
    // Bounded, so rows edited faster than they upload cannot keep this going.
    for (var round = 0; round < 50; round++) {
      final batch = await _store.dirty();
      if (batch.isEmpty) break;
      await api.push(secret, [for (final p in batch) p.record]);
      await _inSpace(space, () => _store.markPushed(batch));
      pushedFocus |= _hasFocus(batch);
      if (batch.length < 200) break;
    }
    // Right away: the server has the session now, and a failed pull below
    // must not cost the wake, which nothing would send again.
    if (pushedFocus) await _wakeOthers(secret);

    var received = 0;
    var cursor =
        int.tryParse(await _db.readSetting(SyncKeys.cursor) ?? '') ?? 0;
    while (true) {
      final page = await api.pull(secret, after: cursor, limit: 500);
      if (page.isEmpty) break;
      final next = page.map((r) => r.seq).reduce(max);
      await _inSpace(space, () async {
        await _store.apply(page);
        await _db.writeSetting(SyncKeys.cursor, '$next');
      });
      cursor = next;
      received += page.length;
      if (page.length < 500) break;
    }

    // A pull can leave records queued (local fields that were newer).
    final leftover = await _store.dirty(limit: 200);
    if (leftover.isNotEmpty) {
      await api.push(secret, [for (final p in leftover) p.record]);
      await _inSpace(space, () => _store.markPushed(leftover));
      if (_hasFocus(leftover)) await _wakeOthers(secret);
    }
    await _db.writeSetting(
      SyncKeys.lastSynced,
      _now().toUtc().toIso8601String(),
    );
    await _sendPushToken(secret, space);
    return received;
  }

  static bool _hasFocus(List<PendingPush> batch) =>
      batch.any((p) => p.record.kind == RecordKinds.focus);

  /// A phone with the app closed only hears about a focus session this way;
  /// the next regular sync catches up if it fails.
  Future<void> _wakeOthers(String secret) async {
    try {
      await api.wakeOtherDevices(secret);
    } on SyncUnavailable catch (e) {
      debugPrint('Could not wake the other devices: $e');
    }
  }

  /// Gives the server this phone's push token. Sent again when the token
  /// changes or the device moves, since the server may then have none.
  Future<void> _sendPushToken(String secret, String? space) async {
    final String? token;
    try {
      token = await _pushToken?.call();
    } on Object catch (e) {
      debugPrint('No push token: $e');
      return;
    }
    if (token == null || token.isEmpty) return;
    final sent = '$space $token';
    if (await _db.readSetting(SyncKeys.pushTokenSent) == sent) return;
    try {
      await api.setPushToken(secret, token);
    } on SyncUnavailable catch (e) {
      // Also when the server does not have push yet. Tried again next sync.
      debugPrint('Could not send the push token: $e');
      return;
    }
    await _db.writeSetting(SyncKeys.pushTokenSent, sent);
  }

  /// Records of a kind this version does not know are skipped while the
  /// cursor moves past them. Once an update teaches the app a new kind,
  /// pull everything again so the skipped ones arrive.
  Future<void> _pullAgainIfKindsChanged(String? space) async {
    final kinds = _store.kinds.join(',');
    if (await _db.readSetting(SyncKeys.kinds) == kinds) return;
    await _inSpace(space, () async {
      await _db.writeSetting(SyncKeys.cursor, '0');
      await _db.writeSetting(SyncKeys.kinds, kinds);
    });
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
    await _forgetRegistration();
    final String space;
    try {
      space = await api.joinSpace(secret, code);
    } on PairingException {
      await _db.writeSetting(SyncKeys.registeredName, deviceName);
      rethrow;
    }
    await _moveTo(space);
    await _exchangeAfterMove(secret);
  });

  /// Stops syncing with the other devices. Everything stays on this device.
  Future<void> unpair() => _serial(() async {
    final secret = await _secret();
    await _ensureRegistered(secret);
    await _forgetRegistration();
    await _moveTo(await api.leaveSpace(secret));
    await _exchangeAfterMove(secret);
  });

  /// The move is done once saved here. If the first exchange in the new
  /// space fails, the next sync does it.
  Future<void> _exchangeAfterMove(String secret) async {
    try {
      await _exchange(secret);
    } on SyncUnavailable {
      // Offline again; nothing is lost.
    }
  }

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
    if (r.spaceId != space) {
      await _moveTo(r.spaceId);
    } else {
      await _db.writeSetting(SyncKeys.registeredName, deviceName);
    }
  }

  /// Starts over in [space]: pull from the beginning, push everything. One
  /// transaction, so a crash cannot leave half a move.
  Future<void> _moveTo(String space) => _db.transaction(() async {
    await _db.writeSetting(SyncKeys.space, space);
    await _db.writeSetting(SyncKeys.cursor, '0');
    await _store.markAllDirty();
    await _db.writeSetting(SyncKeys.registeredName, deviceName);
  });

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

/// The device moved to another space while an exchange was running.
class _SpaceChanged implements Exception {
  const _SpaceChanged();
}
