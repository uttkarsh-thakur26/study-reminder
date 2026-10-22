import '../../../core/sync/field_clock.dart';

/// The kinds of record that sync, as named on the server.
abstract final class RecordKinds {
  static const subject = 'subject';
  static const reminder = 'reminder';
  static const occurrence = 'occurrence';
  static const focus = 'focus';
}

/// One record as it travels to and from the server: its fields and, for
/// each field, the stamp of its latest edit.
class SyncRecord {
  const SyncRecord({
    required this.kind,
    required this.id,
    required this.fields,
    required this.clock,
    this.seq = 0,
  });

  factory SyncRecord.fromJson(Map<String, Object?> json) => SyncRecord(
    kind: json['kind']! as String,
    id: json['id']! as String,
    fields: (json['fields']! as Map).cast<String, Object?>(),
    clock: FieldClock.fromJson((json['clock']! as Map).cast<String, Object?>()),
    seq: (json['seq'] as num?)?.toInt() ?? 0,
  );

  final String kind;
  final String id;
  final Map<String, Object?> fields;
  final FieldClock clock;

  /// The server's change number; 0 for a record not yet pushed.
  final int seq;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'fields': fields,
    'clock': clock.toJson(),
  };
}

/// A device in this device's sync space.
class SyncedDevice {
  const SyncedDevice({
    required this.id,
    required this.name,
    required this.isPhone,
    required this.lastSeen,
    required this.isMe,
  });

  final String id;
  final String name;
  final bool isPhone;
  final DateTime lastSeen;
  final bool isMe;
}

/// A short-lived code another device types or scans to pair with this one.
class PairingCode {
  const PairingCode(this.code, this.expiresAt);

  final String code;
  final DateTime expiresAt;

  /// `ABCD-EFGH`, easier to read out and type.
  String get display =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

  /// What the QR code holds, so a scan can tell it apart from other codes.
  String get qrText => '$qrPrefix$code';

  static const qrPrefix = 'studyreminder:pair:';

  /// The code inside a scanned QR text, or null if it is not one of ours.
  static String? fromQr(String text) =>
      text.startsWith(qrPrefix) ? text.substring(qrPrefix.length) : null;
}
