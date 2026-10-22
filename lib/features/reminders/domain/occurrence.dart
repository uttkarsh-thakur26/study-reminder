enum OccurrenceStatus { pending, done, skipped, snoozed }

/// What happened to one occurrence of a reminder (done, snoozed, ...).
///
/// The id is derived from the reminder and the occurrence instant, so two
/// devices acting on the same occurrence write the same record.
class OccurrenceState {
  const OccurrenceState({
    required this.reminderId,
    required this.occurrenceAt,
    required this.status,
    this.snoozeUntil,
    this.deleted = false,
  });

  final String reminderId;
  final DateTime occurrenceAt;
  final OccurrenceStatus status;
  final DateTime? snoozeUntil;
  final bool deleted;

  String get id => occurrenceId(reminderId, occurrenceAt);

  Map<String, Object?> toFields() => {
    'reminder_id': reminderId,
    'occurrence_at': occurrenceAt.toUtc().millisecondsSinceEpoch,
    'status': status.name,
    'snooze_until': snoozeUntil?.toUtc().millisecondsSinceEpoch,
    'deleted': deleted,
  };

  factory OccurrenceState.fromFields(Map<String, Object?> f) {
    final snooze = f['snooze_until'] as num?;
    return OccurrenceState(
      reminderId: f['reminder_id'] as String,
      occurrenceAt: DateTime.fromMillisecondsSinceEpoch(
        (f['occurrence_at'] as num).toInt(),
        isUtc: true,
      ),
      status: OccurrenceStatus.values.firstWhere(
        (s) => s.name == f['status'],
        orElse: () => OccurrenceStatus.pending,
      ),
      snoozeUntil: snooze == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(snooze.toInt(), isUtc: true),
      deleted: f['deleted'] as bool? ?? false,
    );
  }
}

String occurrenceId(String reminderId, DateTime at) =>
    '$reminderId@${at.toUtc().millisecondsSinceEpoch}';
