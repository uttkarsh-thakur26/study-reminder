import 'dart:convert';

import 'hlc.dart';

/// Per-field edit timestamps for one synced record.
///
/// Two devices can edit different fields of the same reminder while offline
/// and both edits survive: on merge, each field keeps the value with the
/// newest timestamp.
class FieldClock {
  const FieldClock(this.stamps);

  factory FieldClock.decode(String json) {
    if (json.isEmpty) return const FieldClock({});
    final raw = jsonDecode(json) as Map<String, dynamic>;
    return FieldClock({
      for (final e in raw.entries) e.key: Hlc.parse(e.value as String),
    });
  }

  static const empty = FieldClock({});

  final Map<String, Hlc> stamps;

  Hlc of(String field) => stamps[field] ?? Hlc.zero;

  /// The newest stamp across all fields.
  Hlc get latest => stamps.values.fold(Hlc.zero, (a, b) => b > a ? b : a);

  String encode() =>
      jsonEncode({for (final e in stamps.entries) e.key: e.value.pack()});

  /// Stamps every field whose value differs between [before] and [after].
  ///
  /// When [before] is null (a new record) every field is stamped.
  /// Returns null when nothing changed.
  static FieldClock? stamp({
    required Map<String, Object?>? before,
    required Map<String, Object?> after,
    required FieldClock current,
    required Hlc now,
  }) {
    final next = Map<String, Hlc>.of(current.stamps);
    var changed = false;
    for (final entry in after.entries) {
      if (before == null ||
          !before.containsKey(entry.key) ||
          !_same(before[entry.key], entry.value)) {
        next[entry.key] = now;
        changed = true;
      }
    }
    return changed ? FieldClock(next) : null;
  }

  static bool _same(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_same(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}

/// The result of merging a remote record into a local one.
class MergeResult {
  const MergeResult(this.values, this.clock, {required this.localWon});

  final Map<String, Object?> values;
  final FieldClock clock;

  /// True when at least one local field was newer than the remote one, so the
  /// merged record still has to be pushed.
  final bool localWon;
}

/// Merges two versions of the same record field by field.
///
/// Ties (identical stamps) keep the local value, which is the same value on
/// both sides because a stamp is only ever written together with its value.
MergeResult mergeRecords({
  required Map<String, Object?> local,
  required FieldClock localClock,
  required Map<String, Object?> remote,
  required FieldClock remoteClock,
}) {
  final values = <String, Object?>{};
  final stamps = <String, Hlc>{};
  var localWon = false;
  final fields = {...local.keys, ...remote.keys};
  for (final field in fields) {
    final l = localClock.of(field);
    final r = remoteClock.of(field);
    final useRemote = r > l || (!local.containsKey(field));
    if (useRemote && remote.containsKey(field)) {
      values[field] = remote[field];
      stamps[field] = r;
    } else {
      values[field] = local[field];
      stamps[field] = l;
      if (l > r) localWon = true;
    }
  }
  return MergeResult(values, FieldClock(stamps), localWon: localWon);
}
