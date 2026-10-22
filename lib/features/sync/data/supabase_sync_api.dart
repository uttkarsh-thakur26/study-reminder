import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:postgrest/postgrest.dart';
import 'package:realtime_client/realtime_client.dart';

import '../domain/sync_record.dart';
import 'sync_api.dart';

/// [SyncApi] on a Supabase project, through the functions in
/// `supabase/schema.sql`. Uses only the project URL and its public key.
class SupabaseSyncApi implements SyncApi {
  SupabaseSyncApi({required String url, required String publicKey})
    : _http = http.Client(),
      _publicKey = publicKey,
      _functionsUrl = '$url/functions/v1',
      _realtimeUrl = '$url/realtime/v1'.replaceFirst('http', 'ws') {
    _rest = PostgrestClient(
      '$url/rest/v1',
      headers: {'apikey': publicKey, 'Authorization': 'Bearer $publicKey'},
      httpClient: _http,
      requestTimeout: const Duration(seconds: 20),
    );
  }

  final http.Client _http;
  final String _publicKey;
  final String _functionsUrl;
  final String _realtimeUrl;
  late final PostgrestClient _rest;
  RealtimeClient? _realtime;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _rest.rpc<Object?>(fn, params: params);
    } on PostgrestException catch (e) {
      if (e.code == 'SR401') throw const UnknownDeviceException();
      if (e.code == 'SR429') {
        throw const PairingException(PairingProblem.tooManyTries);
      }
      throw SyncUnavailable(e);
    } on UnknownDeviceException {
      rethrow;
    } on PairingException {
      rethrow;
    } on Object catch (e) {
      throw SyncUnavailable(e);
    }
  }

  @override
  Future<Registration> register({
    required String secret,
    required String name,
    required bool isPhone,
  }) async {
    final r = await _call('register_device', {
      'p_secret': secret,
      'p_name': name,
      'p_kind': isPhone ? 'phone' : 'laptop',
    });
    final map = _map(r);
    return Registration(
      deviceId: map['device_id']! as String,
      spaceId: map['space_id']! as String,
    );
  }

  @override
  Future<PairingCode> createPairingCode(String secret) async {
    // Codes last 10 minutes on the server. Count them down from when this
    // device asked, by its own clock, so a clock that is off cannot show a
    // fresh code as expired.
    final asked = DateTime.now().toUtc();
    final map = _map(await _call('create_pairing_code', {'p_secret': secret}));
    return PairingCode(
      map['code']! as String,
      asked.add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<String> joinSpace(String secret, String code) async {
    final map = _map(
      await _call('join_space', {'p_secret': secret, 'p_code': code}),
    );
    if (map['error'] != null) {
      throw const PairingException(PairingProblem.wrongCode);
    }
    return map['space_id']! as String;
  }

  @override
  Future<String> leaveSpace(String secret) async =>
      _map(await _call('leave_space', {'p_secret': secret}))['space_id']!
          as String;

  @override
  Future<List<SyncedDevice>> listDevices(String secret) async => [
    for (final row in _rows(await _call('list_devices', {'p_secret': secret})))
      SyncedDevice(
        id: row['id']! as String,
        name: row['name']! as String,
        isPhone: row['kind'] == 'phone',
        lastSeen: DateTime.parse(row['last_seen']! as String).toUtc(),
        isMe: row['is_me'] == true,
      ),
  ];

  @override
  Future<int> push(String secret, List<SyncRecord> records) async {
    final r = await _call('push_records', {
      'p_secret': secret,
      'p_records': [for (final rec in records) rec.toJson()],
    });
    return (r as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<SyncRecord>> pull(
    String secret, {
    required int after,
    int limit = 500,
  }) async => [
    for (final row in _rows(
      await _call('pull_records', {
        'p_secret': secret,
        'p_after': after,
        'p_limit': limit,
      }),
    ))
      SyncRecord.fromJson(row),
  ];

  @override
  Future<void> setPushToken(String secret, String? token) =>
      _call('set_push_token', {'p_secret': secret, 'p_token': token ?? ''});

  @override
  Future<void> wakeOtherDevices(String secret) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$_functionsUrl/focus-push'),
            headers: {
              'apikey': _publicKey,
              'Authorization': 'Bearer $_publicKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'secret': secret}),
          )
          .timeout(const Duration(seconds: 15));
    } on Object catch (e) {
      throw SyncUnavailable(e);
    }
    if (res.statusCode >= 300) {
      throw SyncUnavailable('focus-push ${res.statusCode}: ${res.body}');
    }
  }

  @override
  Stream<void> changes(String spaceId) {
    final realtime = _realtime ??= RealtimeClient(
      _realtimeUrl,
      params: {'apikey': _publicKey},
      headers: {'apikey': _publicKey},
    );
    late final StreamController<void> out;
    RealtimeChannel? channel;
    out = StreamController<void>(
      onListen: () {
        channel = realtime.channel('space:$spaceId')
          ..onBroadcast(event: 'changed', callback: (_) => out.add(null))
          ..onBroadcast(event: 'devices', callback: (_) => out.add(null))
          ..subscribe();
      },
      onCancel: () async {
        final c = channel;
        if (c != null) await realtime.removeChannel(c);
      },
    );
    return out.stream;
  }

  @override
  Future<void> close() async {
    await _realtime?.disconnect();
    _http.close();
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    throw SyncUnavailable('unexpected reply: $value');
  }

  static List<Map<String, Object?>> _rows(Object? value) {
    if (value is List) {
      return [for (final row in value) (row as Map).cast<String, Object?>()];
    }
    throw SyncUnavailable('unexpected reply: $value');
  }
}
