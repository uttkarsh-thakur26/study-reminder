import 'dart:async';

import 'package:study_reminder/core/sync/field_clock.dart';
import 'package:study_reminder/features/sync/data/sync_api.dart';
import 'package:study_reminder/features/sync/domain/sync_record.dart';

/// An in-memory server with the same rules as `supabase/schema.sql`: spaces,
/// one-time pairing codes, a per-field newest-stamp-wins merge, and a change
/// number on every stored change.
class FakeSyncApi implements SyncApi {
  FakeSyncApi({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _devices = <String, _Device>{};
  final _spaces = <String, Map<String, _Stored>>{};
  final _codes = <String, (String space, DateTime expires)>{};
  final _pings = <String, StreamController<void>>{};
  var _seq = 0;
  var _ids = 0;

  /// Calls made, for checking that a sync does no needless work.
  int pushes = 0;
  int pushedRecords = 0;

  /// While true, every call fails as if offline.
  bool offline = false;

  /// Makes the next join or leave happen on the server but fail on the way
  /// back, as when the connection drops before the reply arrives.
  bool loseNextReply = false;

  /// How many of the next pulls fail as if offline.
  int failPulls = 0;

  /// The `after` of every pull, oldest first.
  final pullsAfter = <int>[];

  /// Runs inside [pull] before the rows are read, once.
  Future<void> Function()? duringPull;

  /// Runs inside [push] before the records are stored, to act out an edit
  /// that lands while an upload is in flight.
  Future<void> Function()? duringPush;

  int get spaceCount => _spaces.length;

  /// Forgets every device and record, as if the project were reset.
  void reset() {
    _devices.clear();
    _spaces.clear();
    _codes.clear();
  }

  String _id(String prefix) => '$prefix${++_ids}';

  _Device _device(String secret) {
    if (offline) throw const SyncUnavailable('offline');
    final d = _devices[secret];
    if (d == null) throw const UnknownDeviceException();
    return d;
  }

  void _dropIfEmpty(String space) {
    if (_devices.values.every((d) => d.space != space)) _spaces.remove(space);
  }

  void _ping(String space) {
    final c = _pings[space];
    if (c != null && c.hasListener) c.add(null);
  }

  @override
  Future<Registration> register({
    required String secret,
    required String name,
    required bool isPhone,
  }) async {
    if (offline) throw const SyncUnavailable('offline');
    final existing = _devices[secret];
    if (existing != null) {
      existing.name = name;
      return Registration(deviceId: existing.id, spaceId: existing.space);
    }
    final space = _id('space');
    _spaces[space] = {};
    final d = _Device(_id('device'), space, name, isPhone);
    _devices[secret] = d;
    return Registration(deviceId: d.id, spaceId: space);
  }

  @override
  Future<PairingCode> createPairingCode(String secret) async {
    final d = _device(secret);
    final code = 'CODE${(++_ids).toString().padLeft(4, '0')}';
    final expires = _now().toUtc().add(const Duration(minutes: 10));
    _codes[code] = (d.space, expires);
    return PairingCode(code, expires);
  }

  @override
  Future<String> joinSpace(String secret, String code) async {
    final d = _device(secret);
    final clean = code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    final entry = _codes.remove(clean);
    if (entry == null || !_now().toUtc().isBefore(entry.$2)) {
      throw const PairingException(PairingProblem.wrongCode);
    }
    final old = d.space;
    d.space = entry.$1;
    _dropIfEmpty(old);
    _ping(d.space);
    _maybeLoseReply();
    return d.space;
  }

  void _maybeLoseReply() {
    if (!loseNextReply) return;
    loseNextReply = false;
    throw const SyncUnavailable('reply lost');
  }

  /// The stamps stored for one record, or null if there is none.
  Map<String, String>? storedClock(String space, String kind, String id) =>
      _spaces[space]?['$kind/$id']?.clock;

  /// Stores a record as a device of a newer app version would.
  void storeAsNewerApp(String space, SyncRecord r) {
    _spaces[space]!['${r.kind}/${r.id}'] = _Stored(
      r.kind,
      r.id,
      {...r.fields},
      r.clock.toJson(),
      ++_seq,
    );
  }

  @override
  Future<String> leaveSpace(String secret) async {
    final d = _device(secret);
    final old = d.space;
    d.space = _id('space');
    _spaces[d.space] = {};
    _dropIfEmpty(old);
    _ping(old);
    _maybeLoseReply();
    return d.space;
  }

  @override
  Future<List<SyncedDevice>> listDevices(String secret) async {
    final me = _device(secret);
    return [
      for (final d in _devices.values)
        if (d.space == me.space)
          SyncedDevice(
            id: d.id,
            name: d.name,
            isPhone: d.isPhone,
            lastSeen: _now().toUtc(),
            isMe: d == me,
          ),
    ];
  }

  @override
  Future<int> push(String secret, List<SyncRecord> records) async {
    final d = _device(secret);
    if (records.length > 500) throw const SyncUnavailable('too many');
    pushes++;
    pushedRecords += records.length;
    await duringPush?.call();
    final space = _spaces[d.space]!;
    var changed = 0;
    for (final r in records) {
      final key = '${r.kind}/${r.id}';
      final stored = space[key];
      final incoming = r.clock.toJson();
      if (stored == null) {
        space[key] = _Stored(r.kind, r.id, {...r.fields}, incoming, ++_seq);
        changed++;
        continue;
      }
      var moved = false;
      for (final MapEntry(key: field, value: theirs) in incoming.entries) {
        if (theirs.compareTo(stored.clock[field] ?? '') > 0) {
          stored.fields[field] = r.fields[field];
          stored.clock[field] = theirs;
          moved = true;
        }
      }
      if (moved) {
        stored.seq = ++_seq;
        changed++;
      }
    }
    if (changed > 0) _ping(d.space);
    return changed;
  }

  @override
  Future<List<SyncRecord>> pull(
    String secret, {
    required int after,
    int limit = 500,
  }) async {
    final d = _device(secret);
    if (failPulls > 0) {
      failPulls--;
      throw const SyncUnavailable('offline');
    }
    pullsAfter.add(after);
    final hook = duringPull;
    duringPull = null;
    await hook?.call();
    final rows = _spaces[d.space]!.values.where((s) => s.seq > after).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return [
      for (final s in rows.take(limit))
        SyncRecord(
          kind: s.kind,
          id: s.id,
          fields: {...s.fields},
          clock: FieldClock.fromJson({...s.clock}),
          seq: s.seq,
        ),
    ];
  }

  @override
  Stream<void> changes(String spaceId) =>
      (_pings[spaceId] ??= StreamController<void>.broadcast()).stream;

  @override
  Future<void> close() async {
    for (final c in _pings.values) {
      await c.close();
    }
  }
}

class _Device {
  _Device(this.id, this.space, this.name, this.isPhone);

  final String id;
  String space;
  String name;
  final bool isPhone;
}

class _Stored {
  _Stored(this.kind, this.id, this.fields, this.clock, this.seq);

  final String kind;
  final String id;
  final Map<String, Object?> fields;
  final Map<String, String> clock;
  int seq;
}
