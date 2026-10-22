import '../../../core/time/calendar_date.dart';
import 'recurrence.dart';

/// Gentle notification, or a full alarm that keeps ringing until handled.
enum ReminderStyle { notification, alarm }

/// Which devices ring for a reminder.
enum DeliveryTarget {
  everywhere,
  phone,
  laptop;

  String get label => switch (this) {
    everywhere => 'Phone and laptop',
    phone => 'Phone only',
    laptop => 'Laptop only',
  };
}

/// The kind of device the app runs on.
enum DeviceKind {
  phone,
  laptop;

  bool receives(DeliveryTarget target) =>
      target == DeliveryTarget.everywhere ||
      (this == phone && target == DeliveryTarget.phone) ||
      (this == laptop && target == DeliveryTarget.laptop);
}

class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.schedule,
    required this.createdAt,
    this.notes = '',
    this.subjectId,
    this.style = ReminderStyle.notification,
    this.deliverTo = DeliveryTarget.everywhere,
    this.enabled = true,
    this.deleted = false,
  });

  final String id;
  final String title;
  final String notes;
  final String? subjectId;
  final ReminderStyle style;
  final ReminderSchedule schedule;
  final DeliveryTarget deliverTo;
  final bool enabled;
  final DateTime createdAt;
  final bool deleted;

  Recurrence get recurrence => schedule.recurrence;

  Reminder copyWith({
    String? title,
    String? notes,
    String? subjectId,
    bool clearSubject = false,
    ReminderStyle? style,
    ReminderSchedule? schedule,
    DeliveryTarget? deliverTo,
    bool? enabled,
    bool? deleted,
  }) => Reminder(
    id: id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
    style: style ?? this.style,
    schedule: schedule ?? this.schedule,
    deliverTo: deliverTo ?? this.deliverTo,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
    deleted: deleted ?? this.deleted,
  );

  /// Flat field map with stable keys. Used for per-field sync stamps and as
  /// the row shape on the server.
  Map<String, Object?> toFields() => {
    'title': title,
    'notes': notes,
    'subject_id': subjectId,
    'style': style.name,
    'anchor_date': schedule.anchor.toIso(),
    'minute_of_day': schedule.minuteOfDay,
    'time_zone': schedule.timeZone,
    'repeat_kind': recurrence.kind.name,
    'repeat_interval': recurrence.interval,
    'repeat_weekdays': recurrence.weekdayMask,
    'repeat_until': recurrence.until?.toIso(),
    'deliver_to': deliverTo.name,
    'enabled': enabled,
    'created_at': createdAt.toUtc().millisecondsSinceEpoch,
    'deleted': deleted,
  };

  factory Reminder.fromFields(String id, Map<String, Object?> f) {
    final until = f['repeat_until'] as String?;
    return Reminder(
      id: id,
      title: f['title'] as String? ?? '',
      notes: f['notes'] as String? ?? '',
      subjectId: f['subject_id'] as String?,
      style: _byName(
        ReminderStyle.values,
        f['style'],
        ReminderStyle.notification,
      ),
      schedule: ReminderSchedule(
        anchor: CalendarDate.parse(f['anchor_date'] as String),
        minuteOfDay: (f['minute_of_day'] as num).toInt(),
        timeZone: f['time_zone'] as String? ?? 'UTC',
        recurrence: Recurrence(
          kind: _byName(RepeatKind.values, f['repeat_kind'], RepeatKind.once),
          interval: ((f['repeat_interval'] as num?) ?? 1).toInt().clamp(1, 365),
          weekdays: Recurrence.weekdaysFromMask(
            ((f['repeat_weekdays'] as num?) ?? 0).toInt(),
          ),
          until: until == null ? null : CalendarDate.parse(until),
        ),
      ),
      deliverTo: _byName(
        DeliveryTarget.values,
        f['deliver_to'],
        DeliveryTarget.everywhere,
      ),
      enabled: f['enabled'] as bool? ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((f['created_at'] as num?) ?? 0).toInt(),
        isUtc: true,
      ),
      deleted: f['deleted'] as bool? ?? false,
    );
  }
}

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
