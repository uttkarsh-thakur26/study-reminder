// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SubjectsTable extends Subjects
    with TableInfo<$SubjectsTable, SubjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldClockMeta = const VerificationMeta(
    'fieldClock',
  );
  @override
  late final GeneratedColumn<String> fieldClock = GeneratedColumn<String>(
    'field_clock',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    hlc,
    fieldClock,
    deleted,
    dirty,
    id,
    name,
    color,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('field_clock')) {
      context.handle(
        _fieldClockMeta,
        fieldClock.isAcceptableOrUnknown(data['field_clock']!, _fieldClockMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubjectRow(
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      fieldClock: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clock'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $SubjectsTable createAlias(String alias) {
    return $SubjectsTable(attachedDatabase, alias);
  }
}

class SubjectRow extends DataClass implements Insertable<SubjectRow> {
  /// Newest edit stamp across all fields (packed HLC).
  final String hlc;

  /// JSON map of field name to packed HLC, see `FieldClock`.
  final String fieldClock;
  final bool deleted;

  /// Changed locally and not yet pushed to the server.
  final bool dirty;
  final String id;
  final String name;
  final int color;
  final int sortOrder;
  const SubjectRow({
    required this.hlc,
    required this.fieldClock,
    required this.deleted,
    required this.dirty,
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hlc'] = Variable<String>(hlc);
    map['field_clock'] = Variable<String>(fieldClock);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SubjectsCompanion toCompanion(bool nullToAbsent) {
    return SubjectsCompanion(
      hlc: Value(hlc),
      fieldClock: Value(fieldClock),
      deleted: Value(deleted),
      dirty: Value(dirty),
      id: Value(id),
      name: Value(name),
      color: Value(color),
      sortOrder: Value(sortOrder),
    );
  }

  factory SubjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubjectRow(
      hlc: serializer.fromJson<String>(json['hlc']),
      fieldClock: serializer.fromJson<String>(json['fieldClock']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hlc': serializer.toJson<String>(hlc),
      'fieldClock': serializer.toJson<String>(fieldClock),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SubjectRow copyWith({
    String? hlc,
    String? fieldClock,
    bool? deleted,
    bool? dirty,
    String? id,
    String? name,
    int? color,
    int? sortOrder,
  }) => SubjectRow(
    hlc: hlc ?? this.hlc,
    fieldClock: fieldClock ?? this.fieldClock,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  SubjectRow copyWithCompanion(SubjectsCompanion data) {
    return SubjectRow(
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      fieldClock: data.fieldClock.present
          ? data.fieldClock.value
          : this.fieldClock,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubjectRow(')
          ..write('hlc: $hlc, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(hlc, fieldClock, deleted, dirty, id, name, color, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectRow &&
          other.hlc == this.hlc &&
          other.fieldClock == this.fieldClock &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder);
}

class SubjectsCompanion extends UpdateCompanion<SubjectRow> {
  final Value<String> hlc;
  final Value<String> fieldClock;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const SubjectsCompanion({
    this.hlc = const Value.absent(),
    this.fieldClock = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubjectsCompanion.insert({
    required String hlc,
    this.fieldClock = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String id,
    required String name,
    required int color,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : hlc = Value(hlc),
       id = Value(id),
       name = Value(name),
       color = Value(color);
  static Insertable<SubjectRow> custom({
    Expression<String>? hlc,
    Expression<String>? fieldClock,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hlc != null) 'hlc': hlc,
      if (fieldClock != null) 'field_clock': fieldClock,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubjectsCompanion copyWith({
    Value<String>? hlc,
    Value<String>? fieldClock,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? name,
    Value<int>? color,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return SubjectsCompanion(
      hlc: hlc ?? this.hlc,
      fieldClock: fieldClock ?? this.fieldClock,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (fieldClock.present) {
      map['field_clock'] = Variable<String>(fieldClock.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectsCompanion(')
          ..write('hlc: $hlc, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldClockMeta = const VerificationMeta(
    'fieldClock',
  );
  @override
  late final GeneratedColumn<String> fieldClock = GeneratedColumn<String>(
    'field_clock',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _anchorDateMeta = const VerificationMeta(
    'anchorDate',
  );
  @override
  late final GeneratedColumn<String> anchorDate = GeneratedColumn<String>(
    'anchor_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteOfDayMeta = const VerificationMeta(
    'minuteOfDay',
  );
  @override
  late final GeneratedColumn<int> minuteOfDay = GeneratedColumn<int>(
    'minute_of_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatKindMeta = const VerificationMeta(
    'repeatKind',
  );
  @override
  late final GeneratedColumn<String> repeatKind = GeneratedColumn<String>(
    'repeat_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatIntervalMeta = const VerificationMeta(
    'repeatInterval',
  );
  @override
  late final GeneratedColumn<int> repeatInterval = GeneratedColumn<int>(
    'repeat_interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _repeatWeekdaysMeta = const VerificationMeta(
    'repeatWeekdays',
  );
  @override
  late final GeneratedColumn<int> repeatWeekdays = GeneratedColumn<int>(
    'repeat_weekdays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repeatUntilMeta = const VerificationMeta(
    'repeatUntil',
  );
  @override
  late final GeneratedColumn<String> repeatUntil = GeneratedColumn<String>(
    'repeat_until',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deliverToMeta = const VerificationMeta(
    'deliverTo',
  );
  @override
  late final GeneratedColumn<String> deliverTo = GeneratedColumn<String>(
    'deliver_to',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    hlc,
    fieldClock,
    deleted,
    dirty,
    id,
    title,
    notes,
    subjectId,
    style,
    anchorDate,
    minuteOfDay,
    timeZone,
    repeatKind,
    repeatInterval,
    repeatWeekdays,
    repeatUntil,
    deliverTo,
    enabled,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('field_clock')) {
      context.handle(
        _fieldClockMeta,
        fieldClock.isAcceptableOrUnknown(data['field_clock']!, _fieldClockMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    } else if (isInserting) {
      context.missing(_styleMeta);
    }
    if (data.containsKey('anchor_date')) {
      context.handle(
        _anchorDateMeta,
        anchorDate.isAcceptableOrUnknown(data['anchor_date']!, _anchorDateMeta),
      );
    } else if (isInserting) {
      context.missing(_anchorDateMeta);
    }
    if (data.containsKey('minute_of_day')) {
      context.handle(
        _minuteOfDayMeta,
        minuteOfDay.isAcceptableOrUnknown(
          data['minute_of_day']!,
          _minuteOfDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minuteOfDayMeta);
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timeZoneMeta);
    }
    if (data.containsKey('repeat_kind')) {
      context.handle(
        _repeatKindMeta,
        repeatKind.isAcceptableOrUnknown(data['repeat_kind']!, _repeatKindMeta),
      );
    } else if (isInserting) {
      context.missing(_repeatKindMeta);
    }
    if (data.containsKey('repeat_interval')) {
      context.handle(
        _repeatIntervalMeta,
        repeatInterval.isAcceptableOrUnknown(
          data['repeat_interval']!,
          _repeatIntervalMeta,
        ),
      );
    }
    if (data.containsKey('repeat_weekdays')) {
      context.handle(
        _repeatWeekdaysMeta,
        repeatWeekdays.isAcceptableOrUnknown(
          data['repeat_weekdays']!,
          _repeatWeekdaysMeta,
        ),
      );
    }
    if (data.containsKey('repeat_until')) {
      context.handle(
        _repeatUntilMeta,
        repeatUntil.isAcceptableOrUnknown(
          data['repeat_until']!,
          _repeatUntilMeta,
        ),
      );
    }
    if (data.containsKey('deliver_to')) {
      context.handle(
        _deliverToMeta,
        deliverTo.isAcceptableOrUnknown(data['deliver_to']!, _deliverToMeta),
      );
    } else if (isInserting) {
      context.missing(_deliverToMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      fieldClock: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clock'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      )!,
      anchorDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor_date'],
      )!,
      minuteOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute_of_day'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      )!,
      repeatKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_kind'],
      )!,
      repeatInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_interval'],
      )!,
      repeatWeekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_weekdays'],
      )!,
      repeatUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_until'],
      ),
      deliverTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deliver_to'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  /// Newest edit stamp across all fields (packed HLC).
  final String hlc;

  /// JSON map of field name to packed HLC, see `FieldClock`.
  final String fieldClock;
  final bool deleted;

  /// Changed locally and not yet pushed to the server.
  final bool dirty;
  final String id;
  final String title;
  final String notes;
  final String? subjectId;
  final String style;
  final String anchorDate;
  final int minuteOfDay;
  final String timeZone;
  final String repeatKind;
  final int repeatInterval;
  final int repeatWeekdays;
  final String? repeatUntil;
  final String deliverTo;
  final bool enabled;
  final int createdAt;
  const ReminderRow({
    required this.hlc,
    required this.fieldClock,
    required this.deleted,
    required this.dirty,
    required this.id,
    required this.title,
    required this.notes,
    this.subjectId,
    required this.style,
    required this.anchorDate,
    required this.minuteOfDay,
    required this.timeZone,
    required this.repeatKind,
    required this.repeatInterval,
    required this.repeatWeekdays,
    this.repeatUntil,
    required this.deliverTo,
    required this.enabled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hlc'] = Variable<String>(hlc);
    map['field_clock'] = Variable<String>(fieldClock);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    map['style'] = Variable<String>(style);
    map['anchor_date'] = Variable<String>(anchorDate);
    map['minute_of_day'] = Variable<int>(minuteOfDay);
    map['time_zone'] = Variable<String>(timeZone);
    map['repeat_kind'] = Variable<String>(repeatKind);
    map['repeat_interval'] = Variable<int>(repeatInterval);
    map['repeat_weekdays'] = Variable<int>(repeatWeekdays);
    if (!nullToAbsent || repeatUntil != null) {
      map['repeat_until'] = Variable<String>(repeatUntil);
    }
    map['deliver_to'] = Variable<String>(deliverTo);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      hlc: Value(hlc),
      fieldClock: Value(fieldClock),
      deleted: Value(deleted),
      dirty: Value(dirty),
      id: Value(id),
      title: Value(title),
      notes: Value(notes),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      style: Value(style),
      anchorDate: Value(anchorDate),
      minuteOfDay: Value(minuteOfDay),
      timeZone: Value(timeZone),
      repeatKind: Value(repeatKind),
      repeatInterval: Value(repeatInterval),
      repeatWeekdays: Value(repeatWeekdays),
      repeatUntil: repeatUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatUntil),
      deliverTo: Value(deliverTo),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      hlc: serializer.fromJson<String>(json['hlc']),
      fieldClock: serializer.fromJson<String>(json['fieldClock']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      style: serializer.fromJson<String>(json['style']),
      anchorDate: serializer.fromJson<String>(json['anchorDate']),
      minuteOfDay: serializer.fromJson<int>(json['minuteOfDay']),
      timeZone: serializer.fromJson<String>(json['timeZone']),
      repeatKind: serializer.fromJson<String>(json['repeatKind']),
      repeatInterval: serializer.fromJson<int>(json['repeatInterval']),
      repeatWeekdays: serializer.fromJson<int>(json['repeatWeekdays']),
      repeatUntil: serializer.fromJson<String?>(json['repeatUntil']),
      deliverTo: serializer.fromJson<String>(json['deliverTo']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hlc': serializer.toJson<String>(hlc),
      'fieldClock': serializer.toJson<String>(fieldClock),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'subjectId': serializer.toJson<String?>(subjectId),
      'style': serializer.toJson<String>(style),
      'anchorDate': serializer.toJson<String>(anchorDate),
      'minuteOfDay': serializer.toJson<int>(minuteOfDay),
      'timeZone': serializer.toJson<String>(timeZone),
      'repeatKind': serializer.toJson<String>(repeatKind),
      'repeatInterval': serializer.toJson<int>(repeatInterval),
      'repeatWeekdays': serializer.toJson<int>(repeatWeekdays),
      'repeatUntil': serializer.toJson<String?>(repeatUntil),
      'deliverTo': serializer.toJson<String>(deliverTo),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ReminderRow copyWith({
    String? hlc,
    String? fieldClock,
    bool? deleted,
    bool? dirty,
    String? id,
    String? title,
    String? notes,
    Value<String?> subjectId = const Value.absent(),
    String? style,
    String? anchorDate,
    int? minuteOfDay,
    String? timeZone,
    String? repeatKind,
    int? repeatInterval,
    int? repeatWeekdays,
    Value<String?> repeatUntil = const Value.absent(),
    String? deliverTo,
    bool? enabled,
    int? createdAt,
  }) => ReminderRow(
    hlc: hlc ?? this.hlc,
    fieldClock: fieldClock ?? this.fieldClock,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    style: style ?? this.style,
    anchorDate: anchorDate ?? this.anchorDate,
    minuteOfDay: minuteOfDay ?? this.minuteOfDay,
    timeZone: timeZone ?? this.timeZone,
    repeatKind: repeatKind ?? this.repeatKind,
    repeatInterval: repeatInterval ?? this.repeatInterval,
    repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
    repeatUntil: repeatUntil.present ? repeatUntil.value : this.repeatUntil,
    deliverTo: deliverTo ?? this.deliverTo,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      fieldClock: data.fieldClock.present
          ? data.fieldClock.value
          : this.fieldClock,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      style: data.style.present ? data.style.value : this.style,
      anchorDate: data.anchorDate.present
          ? data.anchorDate.value
          : this.anchorDate,
      minuteOfDay: data.minuteOfDay.present
          ? data.minuteOfDay.value
          : this.minuteOfDay,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      repeatKind: data.repeatKind.present
          ? data.repeatKind.value
          : this.repeatKind,
      repeatInterval: data.repeatInterval.present
          ? data.repeatInterval.value
          : this.repeatInterval,
      repeatWeekdays: data.repeatWeekdays.present
          ? data.repeatWeekdays.value
          : this.repeatWeekdays,
      repeatUntil: data.repeatUntil.present
          ? data.repeatUntil.value
          : this.repeatUntil,
      deliverTo: data.deliverTo.present ? data.deliverTo.value : this.deliverTo,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('hlc: $hlc, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('subjectId: $subjectId, ')
          ..write('style: $style, ')
          ..write('anchorDate: $anchorDate, ')
          ..write('minuteOfDay: $minuteOfDay, ')
          ..write('timeZone: $timeZone, ')
          ..write('repeatKind: $repeatKind, ')
          ..write('repeatInterval: $repeatInterval, ')
          ..write('repeatWeekdays: $repeatWeekdays, ')
          ..write('repeatUntil: $repeatUntil, ')
          ..write('deliverTo: $deliverTo, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    hlc,
    fieldClock,
    deleted,
    dirty,
    id,
    title,
    notes,
    subjectId,
    style,
    anchorDate,
    minuteOfDay,
    timeZone,
    repeatKind,
    repeatInterval,
    repeatWeekdays,
    repeatUntil,
    deliverTo,
    enabled,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.hlc == this.hlc &&
          other.fieldClock == this.fieldClock &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.subjectId == this.subjectId &&
          other.style == this.style &&
          other.anchorDate == this.anchorDate &&
          other.minuteOfDay == this.minuteOfDay &&
          other.timeZone == this.timeZone &&
          other.repeatKind == this.repeatKind &&
          other.repeatInterval == this.repeatInterval &&
          other.repeatWeekdays == this.repeatWeekdays &&
          other.repeatUntil == this.repeatUntil &&
          other.deliverTo == this.deliverTo &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<String> hlc;
  final Value<String> fieldClock;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> title;
  final Value<String> notes;
  final Value<String?> subjectId;
  final Value<String> style;
  final Value<String> anchorDate;
  final Value<int> minuteOfDay;
  final Value<String> timeZone;
  final Value<String> repeatKind;
  final Value<int> repeatInterval;
  final Value<int> repeatWeekdays;
  final Value<String?> repeatUntil;
  final Value<String> deliverTo;
  final Value<bool> enabled;
  final Value<int> createdAt;
  final Value<int> rowid;
  const RemindersCompanion({
    this.hlc = const Value.absent(),
    this.fieldClock = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.style = const Value.absent(),
    this.anchorDate = const Value.absent(),
    this.minuteOfDay = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.repeatKind = const Value.absent(),
    this.repeatInterval = const Value.absent(),
    this.repeatWeekdays = const Value.absent(),
    this.repeatUntil = const Value.absent(),
    this.deliverTo = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String hlc,
    this.fieldClock = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String id,
    required String title,
    this.notes = const Value.absent(),
    this.subjectId = const Value.absent(),
    required String style,
    required String anchorDate,
    required int minuteOfDay,
    required String timeZone,
    required String repeatKind,
    this.repeatInterval = const Value.absent(),
    this.repeatWeekdays = const Value.absent(),
    this.repeatUntil = const Value.absent(),
    required String deliverTo,
    this.enabled = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : hlc = Value(hlc),
       id = Value(id),
       title = Value(title),
       style = Value(style),
       anchorDate = Value(anchorDate),
       minuteOfDay = Value(minuteOfDay),
       timeZone = Value(timeZone),
       repeatKind = Value(repeatKind),
       deliverTo = Value(deliverTo),
       createdAt = Value(createdAt);
  static Insertable<ReminderRow> custom({
    Expression<String>? hlc,
    Expression<String>? fieldClock,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? subjectId,
    Expression<String>? style,
    Expression<String>? anchorDate,
    Expression<int>? minuteOfDay,
    Expression<String>? timeZone,
    Expression<String>? repeatKind,
    Expression<int>? repeatInterval,
    Expression<int>? repeatWeekdays,
    Expression<String>? repeatUntil,
    Expression<String>? deliverTo,
    Expression<bool>? enabled,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hlc != null) 'hlc': hlc,
      if (fieldClock != null) 'field_clock': fieldClock,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (subjectId != null) 'subject_id': subjectId,
      if (style != null) 'style': style,
      if (anchorDate != null) 'anchor_date': anchorDate,
      if (minuteOfDay != null) 'minute_of_day': minuteOfDay,
      if (timeZone != null) 'time_zone': timeZone,
      if (repeatKind != null) 'repeat_kind': repeatKind,
      if (repeatInterval != null) 'repeat_interval': repeatInterval,
      if (repeatWeekdays != null) 'repeat_weekdays': repeatWeekdays,
      if (repeatUntil != null) 'repeat_until': repeatUntil,
      if (deliverTo != null) 'deliver_to': deliverTo,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? hlc,
    Value<String>? fieldClock,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? title,
    Value<String>? notes,
    Value<String?>? subjectId,
    Value<String>? style,
    Value<String>? anchorDate,
    Value<int>? minuteOfDay,
    Value<String>? timeZone,
    Value<String>? repeatKind,
    Value<int>? repeatInterval,
    Value<int>? repeatWeekdays,
    Value<String?>? repeatUntil,
    Value<String>? deliverTo,
    Value<bool>? enabled,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      hlc: hlc ?? this.hlc,
      fieldClock: fieldClock ?? this.fieldClock,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      subjectId: subjectId ?? this.subjectId,
      style: style ?? this.style,
      anchorDate: anchorDate ?? this.anchorDate,
      minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      timeZone: timeZone ?? this.timeZone,
      repeatKind: repeatKind ?? this.repeatKind,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      repeatUntil: repeatUntil ?? this.repeatUntil,
      deliverTo: deliverTo ?? this.deliverTo,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (fieldClock.present) {
      map['field_clock'] = Variable<String>(fieldClock.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (anchorDate.present) {
      map['anchor_date'] = Variable<String>(anchorDate.value);
    }
    if (minuteOfDay.present) {
      map['minute_of_day'] = Variable<int>(minuteOfDay.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (repeatKind.present) {
      map['repeat_kind'] = Variable<String>(repeatKind.value);
    }
    if (repeatInterval.present) {
      map['repeat_interval'] = Variable<int>(repeatInterval.value);
    }
    if (repeatWeekdays.present) {
      map['repeat_weekdays'] = Variable<int>(repeatWeekdays.value);
    }
    if (repeatUntil.present) {
      map['repeat_until'] = Variable<String>(repeatUntil.value);
    }
    if (deliverTo.present) {
      map['deliver_to'] = Variable<String>(deliverTo.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('hlc: $hlc, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('subjectId: $subjectId, ')
          ..write('style: $style, ')
          ..write('anchorDate: $anchorDate, ')
          ..write('minuteOfDay: $minuteOfDay, ')
          ..write('timeZone: $timeZone, ')
          ..write('repeatKind: $repeatKind, ')
          ..write('repeatInterval: $repeatInterval, ')
          ..write('repeatWeekdays: $repeatWeekdays, ')
          ..write('repeatUntil: $repeatUntil, ')
          ..write('deliverTo: $deliverTo, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OccurrencesTable extends Occurrences
    with TableInfo<$OccurrencesTable, OccurrenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldClockMeta = const VerificationMeta(
    'fieldClock',
  );
  @override
  late final GeneratedColumn<String> fieldClock = GeneratedColumn<String>(
    'field_clock',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceAtMeta = const VerificationMeta(
    'occurrenceAt',
  );
  @override
  late final GeneratedColumn<int> occurrenceAt = GeneratedColumn<int>(
    'occurrence_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snoozeUntilMeta = const VerificationMeta(
    'snoozeUntil',
  );
  @override
  late final GeneratedColumn<int> snoozeUntil = GeneratedColumn<int>(
    'snooze_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    hlc,
    fieldClock,
    deleted,
    dirty,
    id,
    reminderId,
    occurrenceAt,
    status,
    snoozeUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'occurrences';
  @override
  VerificationContext validateIntegrity(
    Insertable<OccurrenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('field_clock')) {
      context.handle(
        _fieldClockMeta,
        fieldClock.isAcceptableOrUnknown(data['field_clock']!, _fieldClockMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('occurrence_at')) {
      context.handle(
        _occurrenceAtMeta,
        occurrenceAt.isAcceptableOrUnknown(
          data['occurrence_at']!,
          _occurrenceAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('snooze_until')) {
      context.handle(
        _snoozeUntilMeta,
        snoozeUntil.isAcceptableOrUnknown(
          data['snooze_until']!,
          _snoozeUntilMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OccurrenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OccurrenceRow(
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      fieldClock: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clock'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      )!,
      occurrenceAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      snoozeUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_until'],
      ),
    );
  }

  @override
  $OccurrencesTable createAlias(String alias) {
    return $OccurrencesTable(attachedDatabase, alias);
  }
}

class OccurrenceRow extends DataClass implements Insertable<OccurrenceRow> {
  /// Newest edit stamp across all fields (packed HLC).
  final String hlc;

  /// JSON map of field name to packed HLC, see `FieldClock`.
  final String fieldClock;
  final bool deleted;

  /// Changed locally and not yet pushed to the server.
  final bool dirty;

  /// `<reminderId>@<occurrence epoch ms>`, identical on every device.
  final String id;
  final String reminderId;
  final int occurrenceAt;
  final String status;
  final int? snoozeUntil;
  const OccurrenceRow({
    required this.hlc,
    required this.fieldClock,
    required this.deleted,
    required this.dirty,
    required this.id,
    required this.reminderId,
    required this.occurrenceAt,
    required this.status,
    this.snoozeUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hlc'] = Variable<String>(hlc);
    map['field_clock'] = Variable<String>(fieldClock);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['reminder_id'] = Variable<String>(reminderId);
    map['occurrence_at'] = Variable<int>(occurrenceAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || snoozeUntil != null) {
      map['snooze_until'] = Variable<int>(snoozeUntil);
    }
    return map;
  }

  OccurrencesCompanion toCompanion(bool nullToAbsent) {
    return OccurrencesCompanion(
      hlc: Value(hlc),
      fieldClock: Value(fieldClock),
      deleted: Value(deleted),
      dirty: Value(dirty),
      id: Value(id),
      reminderId: Value(reminderId),
      occurrenceAt: Value(occurrenceAt),
      status: Value(status),
      snoozeUntil: snoozeUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozeUntil),
    );
  }

  factory OccurrenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OccurrenceRow(
      hlc: serializer.fromJson<String>(json['hlc']),
      fieldClock: serializer.fromJson<String>(json['fieldClock']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      reminderId: serializer.fromJson<String>(json['reminderId']),
      occurrenceAt: serializer.fromJson<int>(json['occurrenceAt']),
      status: serializer.fromJson<String>(json['status']),
      snoozeUntil: serializer.fromJson<int?>(json['snoozeUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hlc': serializer.toJson<String>(hlc),
      'fieldClock': serializer.toJson<String>(fieldClock),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'reminderId': serializer.toJson<String>(reminderId),
      'occurrenceAt': serializer.toJson<int>(occurrenceAt),
      'status': serializer.toJson<String>(status),
      'snoozeUntil': serializer.toJson<int?>(snoozeUntil),
    };
  }

  OccurrenceRow copyWith({
    String? hlc,
    String? fieldClock,
    bool? deleted,
    bool? dirty,
    String? id,
    String? reminderId,
    int? occurrenceAt,
    String? status,
    Value<int?> snoozeUntil = const Value.absent(),
  }) => OccurrenceRow(
    hlc: hlc ?? this.hlc,
    fieldClock: fieldClock ?? this.fieldClock,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    reminderId: reminderId ?? this.reminderId,
    occurrenceAt: occurrenceAt ?? this.occurrenceAt,
    status: status ?? this.status,
    snoozeUntil: snoozeUntil.present ? snoozeUntil.value : this.snoozeUntil,
  );
  OccurrenceRow copyWithCompanion(OccurrencesCompanion data) {
    return OccurrenceRow(
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      fieldClock: data.fieldClock.present
          ? data.fieldClock.value
          : this.fieldClock,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
      occurrenceAt: data.occurrenceAt.present
          ? data.occurrenceAt.value
          : this.occurrenceAt,
      status: data.status.present ? data.status.value : this.status,
      snoozeUntil: data.snoozeUntil.present
          ? data.snoozeUntil.value
          : this.snoozeUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceRow(')
          ..write('hlc: $hlc, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('occurrenceAt: $occurrenceAt, ')
          ..write('status: $status, ')
          ..write('snoozeUntil: $snoozeUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    hlc,
    fieldClock,
    deleted,
    dirty,
    id,
    reminderId,
    occurrenceAt,
    status,
    snoozeUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OccurrenceRow &&
          other.hlc == this.hlc &&
          other.fieldClock == this.fieldClock &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.reminderId == this.reminderId &&
          other.occurrenceAt == this.occurrenceAt &&
          other.status == this.status &&
          other.snoozeUntil == this.snoozeUntil);
}

class OccurrencesCompanion extends UpdateCompanion<OccurrenceRow> {
  final Value<String> hlc;
  final Value<String> fieldClock;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> reminderId;
  final Value<int> occurrenceAt;
  final Value<String> status;
  final Value<int?> snoozeUntil;
  final Value<int> rowid;
  const OccurrencesCompanion({
    this.hlc = const Value.absent(),
    this.fieldClock = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.occurrenceAt = const Value.absent(),
    this.status = const Value.absent(),
    this.snoozeUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OccurrencesCompanion.insert({
    required String hlc,
    this.fieldClock = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String id,
    required String reminderId,
    required int occurrenceAt,
    required String status,
    this.snoozeUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : hlc = Value(hlc),
       id = Value(id),
       reminderId = Value(reminderId),
       occurrenceAt = Value(occurrenceAt),
       status = Value(status);
  static Insertable<OccurrenceRow> custom({
    Expression<String>? hlc,
    Expression<String>? fieldClock,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? reminderId,
    Expression<int>? occurrenceAt,
    Expression<String>? status,
    Expression<int>? snoozeUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hlc != null) 'hlc': hlc,
      if (fieldClock != null) 'field_clock': fieldClock,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (reminderId != null) 'reminder_id': reminderId,
      if (occurrenceAt != null) 'occurrence_at': occurrenceAt,
      if (status != null) 'status': status,
      if (snoozeUntil != null) 'snooze_until': snoozeUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OccurrencesCompanion copyWith({
    Value<String>? hlc,
    Value<String>? fieldClock,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? reminderId,
    Value<int>? occurrenceAt,
    Value<String>? status,
    Value<int?>? snoozeUntil,
    Value<int>? rowid,
  }) {
    return OccurrencesCompanion(
      hlc: hlc ?? this.hlc,
      fieldClock: fieldClock ?? this.fieldClock,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      occurrenceAt: occurrenceAt ?? this.occurrenceAt,
      status: status ?? this.status,
      snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (fieldClock.present) {
      map['field_clock'] = Variable<String>(fieldClock.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (occurrenceAt.present) {
      map['occurrence_at'] = Variable<int>(occurrenceAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (snoozeUntil.present) {
      map['snooze_until'] = Variable<int>(snoozeUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OccurrencesCompanion(')
          ..write('hlc: $hlc, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('occurrenceAt: $occurrenceAt, ')
          ..write('status: $status, ')
          ..write('snoozeUntil: $snoozeUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldClockMeta = const VerificationMeta(
    'fieldClock',
  );
  @override
  late final GeneratedColumn<String> fieldClock = GeneratedColumn<String>(
    'field_clock',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<int> endsAt = GeneratedColumn<int>(
    'ends_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('both'),
  );
  static const VerificationMeta _blockAppsMeta = const VerificationMeta(
    'blockApps',
  );
  @override
  late final GeneratedColumn<bool> blockApps = GeneratedColumn<bool>(
    'block_apps',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("block_apps" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _quietMeta = const VerificationMeta('quiet');
  @override
  late final GeneratedColumn<bool> quiet = GeneratedColumn<bool>(
    'quiet',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("quiet" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _strictMeta = const VerificationMeta('strict');
  @override
  late final GeneratedColumn<bool> strict = GeneratedColumn<bool>(
    'strict',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("strict" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _startedByMeta = const VerificationMeta(
    'startedBy',
  );
  @override
  late final GeneratedColumn<String> startedBy = GeneratedColumn<String>(
    'started_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    hlc,
    fieldClock,
    deleted,
    dirty,
    id,
    active,
    startedAt,
    endsAt,
    target,
    blockApps,
    quiet,
    strict,
    startedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('field_clock')) {
      context.handle(
        _fieldClockMeta,
        fieldClock.isAcceptableOrUnknown(data['field_clock']!, _fieldClockMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    }
    if (data.containsKey('block_apps')) {
      context.handle(
        _blockAppsMeta,
        blockApps.isAcceptableOrUnknown(data['block_apps']!, _blockAppsMeta),
      );
    }
    if (data.containsKey('quiet')) {
      context.handle(
        _quietMeta,
        quiet.isAcceptableOrUnknown(data['quiet']!, _quietMeta),
      );
    }
    if (data.containsKey('strict')) {
      context.handle(
        _strictMeta,
        strict.isAcceptableOrUnknown(data['strict']!, _strictMeta),
      );
    }
    if (data.containsKey('started_by')) {
      context.handle(
        _startedByMeta,
        startedBy.isAcceptableOrUnknown(data['started_by']!, _startedByMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSessionRow(
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      fieldClock: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clock'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ends_at'],
      ),
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      blockApps: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}block_apps'],
      )!,
      quiet: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}quiet'],
      )!,
      strict: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}strict'],
      )!,
      startedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_by'],
      )!,
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }
}

class FocusSessionRow extends DataClass implements Insertable<FocusSessionRow> {
  /// Newest edit stamp across all fields (packed HLC).
  final String hlc;

  /// JSON map of field name to packed HLC, see `FieldClock`.
  final String fieldClock;
  final bool deleted;

  /// Changed locally and not yet pushed to the server.
  final bool dirty;
  final String id;
  final bool active;
  final int? startedAt;
  final int? endsAt;
  final String target;
  final bool blockApps;
  final bool quiet;
  final bool strict;
  final String startedBy;
  const FocusSessionRow({
    required this.hlc,
    required this.fieldClock,
    required this.deleted,
    required this.dirty,
    required this.id,
    required this.active,
    this.startedAt,
    this.endsAt,
    required this.target,
    required this.blockApps,
    required this.quiet,
    required this.strict,
    required this.startedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hlc'] = Variable<String>(hlc);
    map['field_clock'] = Variable<String>(fieldClock);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || endsAt != null) {
      map['ends_at'] = Variable<int>(endsAt);
    }
    map['target'] = Variable<String>(target);
    map['block_apps'] = Variable<bool>(blockApps);
    map['quiet'] = Variable<bool>(quiet);
    map['strict'] = Variable<bool>(strict);
    map['started_by'] = Variable<String>(startedBy);
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      hlc: Value(hlc),
      fieldClock: Value(fieldClock),
      deleted: Value(deleted),
      dirty: Value(dirty),
      id: Value(id),
      active: Value(active),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      endsAt: endsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endsAt),
      target: Value(target),
      blockApps: Value(blockApps),
      quiet: Value(quiet),
      strict: Value(strict),
      startedBy: Value(startedBy),
    );
  }

  factory FocusSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSessionRow(
      hlc: serializer.fromJson<String>(json['hlc']),
      fieldClock: serializer.fromJson<String>(json['fieldClock']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      active: serializer.fromJson<bool>(json['active']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      endsAt: serializer.fromJson<int?>(json['endsAt']),
      target: serializer.fromJson<String>(json['target']),
      blockApps: serializer.fromJson<bool>(json['blockApps']),
      quiet: serializer.fromJson<bool>(json['quiet']),
      strict: serializer.fromJson<bool>(json['strict']),
      startedBy: serializer.fromJson<String>(json['startedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hlc': serializer.toJson<String>(hlc),
      'fieldClock': serializer.toJson<String>(fieldClock),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'active': serializer.toJson<bool>(active),
      'startedAt': serializer.toJson<int?>(startedAt),
      'endsAt': serializer.toJson<int?>(endsAt),
      'target': serializer.toJson<String>(target),
      'blockApps': serializer.toJson<bool>(blockApps),
      'quiet': serializer.toJson<bool>(quiet),
      'strict': serializer.toJson<bool>(strict),
      'startedBy': serializer.toJson<String>(startedBy),
    };
  }

  FocusSessionRow copyWith({
    String? hlc,
    String? fieldClock,
    bool? deleted,
    bool? dirty,
    String? id,
    bool? active,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> endsAt = const Value.absent(),
    String? target,
    bool? blockApps,
    bool? quiet,
    bool? strict,
    String? startedBy,
  }) => FocusSessionRow(
    hlc: hlc ?? this.hlc,
    fieldClock: fieldClock ?? this.fieldClock,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    active: active ?? this.active,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    endsAt: endsAt.present ? endsAt.value : this.endsAt,
    target: target ?? this.target,
    blockApps: blockApps ?? this.blockApps,
    quiet: quiet ?? this.quiet,
    strict: strict ?? this.strict,
    startedBy: startedBy ?? this.startedBy,
  );
  FocusSessionRow copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSessionRow(
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      fieldClock: data.fieldClock.present
          ? data.fieldClock.value
          : this.fieldClock,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      active: data.active.present ? data.active.value : this.active,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      target: data.target.present ? data.target.value : this.target,
      blockApps: data.blockApps.present ? data.blockApps.value : this.blockApps,
      quiet: data.quiet.present ? data.quiet.value : this.quiet,
      strict: data.strict.present ? data.strict.value : this.strict,
      startedBy: data.startedBy.present ? data.startedBy.value : this.startedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionRow(')
          ..write('hlc: $hlc, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('active: $active, ')
          ..write('startedAt: $startedAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('target: $target, ')
          ..write('blockApps: $blockApps, ')
          ..write('quiet: $quiet, ')
          ..write('strict: $strict, ')
          ..write('startedBy: $startedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    hlc,
    fieldClock,
    deleted,
    dirty,
    id,
    active,
    startedAt,
    endsAt,
    target,
    blockApps,
    quiet,
    strict,
    startedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSessionRow &&
          other.hlc == this.hlc &&
          other.fieldClock == this.fieldClock &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.active == this.active &&
          other.startedAt == this.startedAt &&
          other.endsAt == this.endsAt &&
          other.target == this.target &&
          other.blockApps == this.blockApps &&
          other.quiet == this.quiet &&
          other.strict == this.strict &&
          other.startedBy == this.startedBy);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSessionRow> {
  final Value<String> hlc;
  final Value<String> fieldClock;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> id;
  final Value<bool> active;
  final Value<int?> startedAt;
  final Value<int?> endsAt;
  final Value<String> target;
  final Value<bool> blockApps;
  final Value<bool> quiet;
  final Value<bool> strict;
  final Value<String> startedBy;
  final Value<int> rowid;
  const FocusSessionsCompanion({
    this.hlc = const Value.absent(),
    this.fieldClock = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.active = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.target = const Value.absent(),
    this.blockApps = const Value.absent(),
    this.quiet = const Value.absent(),
    this.strict = const Value.absent(),
    this.startedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    required String hlc,
    this.fieldClock = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String id,
    this.active = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.target = const Value.absent(),
    this.blockApps = const Value.absent(),
    this.quiet = const Value.absent(),
    this.strict = const Value.absent(),
    this.startedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : hlc = Value(hlc),
       id = Value(id);
  static Insertable<FocusSessionRow> custom({
    Expression<String>? hlc,
    Expression<String>? fieldClock,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<bool>? active,
    Expression<int>? startedAt,
    Expression<int>? endsAt,
    Expression<String>? target,
    Expression<bool>? blockApps,
    Expression<bool>? quiet,
    Expression<bool>? strict,
    Expression<String>? startedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hlc != null) 'hlc': hlc,
      if (fieldClock != null) 'field_clock': fieldClock,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (active != null) 'active': active,
      if (startedAt != null) 'started_at': startedAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (target != null) 'target': target,
      if (blockApps != null) 'block_apps': blockApps,
      if (quiet != null) 'quiet': quiet,
      if (strict != null) 'strict': strict,
      if (startedBy != null) 'started_by': startedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionsCompanion copyWith({
    Value<String>? hlc,
    Value<String>? fieldClock,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? id,
    Value<bool>? active,
    Value<int?>? startedAt,
    Value<int?>? endsAt,
    Value<String>? target,
    Value<bool>? blockApps,
    Value<bool>? quiet,
    Value<bool>? strict,
    Value<String>? startedBy,
    Value<int>? rowid,
  }) {
    return FocusSessionsCompanion(
      hlc: hlc ?? this.hlc,
      fieldClock: fieldClock ?? this.fieldClock,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      active: active ?? this.active,
      startedAt: startedAt ?? this.startedAt,
      endsAt: endsAt ?? this.endsAt,
      target: target ?? this.target,
      blockApps: blockApps ?? this.blockApps,
      quiet: quiet ?? this.quiet,
      strict: strict ?? this.strict,
      startedBy: startedBy ?? this.startedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (fieldClock.present) {
      map['field_clock'] = Variable<String>(fieldClock.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<int>(endsAt.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (blockApps.present) {
      map['block_apps'] = Variable<bool>(blockApps.value);
    }
    if (quiet.present) {
      map['quiet'] = Variable<bool>(quiet.value);
    }
    if (strict.present) {
      map['strict'] = Variable<bool>(strict.value);
    }
    if (startedBy.present) {
      map['started_by'] = Variable<String>(startedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('hlc: $hlc, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('active: $active, ')
          ..write('startedAt: $startedAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('target: $target, ')
          ..write('blockApps: $blockApps, ')
          ..write('quiet: $quiet, ')
          ..write('strict: $strict, ')
          ..write('startedBy: $startedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSettingsTable extends LocalSettings
    with TableInfo<$LocalSettingsTable, LocalSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $LocalSettingsTable createAlias(String alias) {
    return $LocalSettingsTable(attachedDatabase, alias);
  }
}

class LocalSetting extends DataClass implements Insertable<LocalSetting> {
  final String key;
  final String value;
  const LocalSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory LocalSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalSetting copyWith({String? key, String? value}) =>
      LocalSetting(key: key ?? this.key, value: value ?? this.value);
  LocalSetting copyWithCompanion(LocalSettingsCompanion data) {
    return LocalSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class LocalSettingsCompanion extends UpdateCompanion<LocalSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return LocalSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SubjectsTable subjects = $SubjectsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $OccurrencesTable occurrences = $OccurrencesTable(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final $LocalSettingsTable localSettings = $LocalSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    subjects,
    reminders,
    occurrences,
    focusSessions,
    localSettings,
  ];
}

typedef $$SubjectsTableCreateCompanionBuilder = SubjectsCompanion Function({
  required String hlc,
  Value<String> fieldClock,
  Value<bool> deleted,
  Value<bool> dirty,
  required String id,
  required String name,
  required int color,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$SubjectsTableUpdateCompanionBuilder = SubjectsCompanion Function({
  Value<String> hlc,
  Value<String> fieldClock,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<String> id,
  Value<String> name,
  Value<int> color,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$SubjectsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$SubjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectsTable,
          SubjectRow,
          $$SubjectsTableFilterComposer,
          $$SubjectsTableOrderingComposer,
          $$SubjectsTableAnnotationComposer,
          $$SubjectsTableCreateCompanionBuilder,
          $$SubjectsTableUpdateCompanionBuilder,
          (
            SubjectRow,
            BaseReferences<_$AppDatabase, $SubjectsTable, SubjectRow>,
          ),
          SubjectRow,
          PrefetchHooks Function()
        > {
  $$SubjectsTableTableManager(_$AppDatabase db, $SubjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hlc = const Value.absent(),
                Value<String> fieldClock = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion(
                hlc: hlc,
                fieldClock: fieldClock,
                deleted: deleted,
                dirty: dirty,
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hlc,
                Value<String> fieldClock = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String name,
                required int color,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion.insert(
                hlc: hlc,
                fieldClock: fieldClock,
                deleted: deleted,
                dirty: dirty,
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubjectsTable, SubjectRow>(table),
                  BaseReferences<_$AppDatabase, $SubjectsTable, SubjectRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectsTable,
      SubjectRow,
      $$SubjectsTableFilterComposer,
      $$SubjectsTableOrderingComposer,
      $$SubjectsTableAnnotationComposer,
      $$SubjectsTableCreateCompanionBuilder,
      $$SubjectsTableUpdateCompanionBuilder,
      (SubjectRow, BaseReferences<_$AppDatabase, $SubjectsTable, SubjectRow>),
      SubjectRow,
      PrefetchHooks Function()
    >;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  required String hlc,
  Value<String> fieldClock,
  Value<bool> deleted,
  Value<bool> dirty,
  required String id,
  required String title,
  Value<String> notes,
  Value<String?> subjectId,
  required String style,
  required String anchorDate,
  required int minuteOfDay,
  required String timeZone,
  required String repeatKind,
  Value<int> repeatInterval,
  Value<int> repeatWeekdays,
  Value<String?> repeatUntil,
  required String deliverTo,
  Value<bool> enabled,
  required int createdAt,
  Value<int> rowid,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<String> hlc,
  Value<String> fieldClock,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<String> id,
  Value<String> title,
  Value<String> notes,
  Value<String?> subjectId,
  Value<String> style,
  Value<String> anchorDate,
  Value<int> minuteOfDay,
  Value<String> timeZone,
  Value<String> repeatKind,
  Value<int> repeatInterval,
  Value<int> repeatWeekdays,
  Value<String?> repeatUntil,
  Value<String> deliverTo,
  Value<bool> enabled,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anchorDate => $composableBuilder(
    column: $table.anchorDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minuteOfDay => $composableBuilder(
    column: $table.minuteOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatKind => $composableBuilder(
    column: $table.repeatKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatWeekdays => $composableBuilder(
    column: $table.repeatWeekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatUntil => $composableBuilder(
    column: $table.repeatUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deliverTo => $composableBuilder(
    column: $table.deliverTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anchorDate => $composableBuilder(
    column: $table.anchorDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minuteOfDay => $composableBuilder(
    column: $table.minuteOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatKind => $composableBuilder(
    column: $table.repeatKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatWeekdays => $composableBuilder(
    column: $table.repeatWeekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatUntil => $composableBuilder(
    column: $table.repeatUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deliverTo => $composableBuilder(
    column: $table.deliverTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<String> get anchorDate => $composableBuilder(
    column: $table.anchorDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minuteOfDay => $composableBuilder(
    column: $table.minuteOfDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<String> get repeatKind => $composableBuilder(
    column: $table.repeatKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatInterval => $composableBuilder(
    column: $table.repeatInterval,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatWeekdays => $composableBuilder(
    column: $table.repeatWeekdays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatUntil => $composableBuilder(
    column: $table.repeatUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deliverTo =>
      $composableBuilder(column: $table.deliverTo, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (
            ReminderRow,
            BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>,
          ),
          ReminderRow,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hlc = const Value.absent(),
                Value<String> fieldClock = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String> style = const Value.absent(),
                Value<String> anchorDate = const Value.absent(),
                Value<int> minuteOfDay = const Value.absent(),
                Value<String> timeZone = const Value.absent(),
                Value<String> repeatKind = const Value.absent(),
                Value<int> repeatInterval = const Value.absent(),
                Value<int> repeatWeekdays = const Value.absent(),
                Value<String?> repeatUntil = const Value.absent(),
                Value<String> deliverTo = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                hlc: hlc,
                fieldClock: fieldClock,
                deleted: deleted,
                dirty: dirty,
                id: id,
                title: title,
                notes: notes,
                subjectId: subjectId,
                style: style,
                anchorDate: anchorDate,
                minuteOfDay: minuteOfDay,
                timeZone: timeZone,
                repeatKind: repeatKind,
                repeatInterval: repeatInterval,
                repeatWeekdays: repeatWeekdays,
                repeatUntil: repeatUntil,
                deliverTo: deliverTo,
                enabled: enabled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hlc,
                Value<String> fieldClock = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String title,
                Value<String> notes = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                required String style,
                required String anchorDate,
                required int minuteOfDay,
                required String timeZone,
                required String repeatKind,
                Value<int> repeatInterval = const Value.absent(),
                Value<int> repeatWeekdays = const Value.absent(),
                Value<String?> repeatUntil = const Value.absent(),
                required String deliverTo,
                Value<bool> enabled = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                hlc: hlc,
                fieldClock: fieldClock,
                deleted: deleted,
                dirty: dirty,
                id: id,
                title: title,
                notes: notes,
                subjectId: subjectId,
                style: style,
                anchorDate: anchorDate,
                minuteOfDay: minuteOfDay,
                timeZone: timeZone,
                repeatKind: repeatKind,
                repeatInterval: repeatInterval,
                repeatWeekdays: repeatWeekdays,
                repeatUntil: repeatUntil,
                deliverTo: deliverTo,
                enabled: enabled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, ReminderRow>(table),
                  BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (
        ReminderRow,
        BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>,
      ),
      ReminderRow,
      PrefetchHooks Function()
    >;
typedef $$OccurrencesTableCreateCompanionBuilder =
    OccurrencesCompanion Function({
      required String hlc,
      Value<String> fieldClock,
      Value<bool> deleted,
      Value<bool> dirty,
      required String id,
      required String reminderId,
      required int occurrenceAt,
      required String status,
      Value<int?> snoozeUntil,
      Value<int> rowid,
    });
typedef $$OccurrencesTableUpdateCompanionBuilder =
    OccurrencesCompanion Function({
      Value<String> hlc,
      Value<String> fieldClock,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<String> id,
      Value<String> reminderId,
      Value<int> occurrenceAt,
      Value<String> status,
      Value<int?> snoozeUntil,
      Value<int> rowid,
    });

class $$OccurrencesTableFilterComposer
    extends Composer<_$AppDatabase, $OccurrencesTable> {
  $$OccurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceAt => $composableBuilder(
    column: $table.occurrenceAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeUntil => $composableBuilder(
    column: $table.snoozeUntil,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OccurrencesTableOrderingComposer
    extends Composer<_$AppDatabase, $OccurrencesTable> {
  $$OccurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceAt => $composableBuilder(
    column: $table.occurrenceAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeUntil => $composableBuilder(
    column: $table.snoozeUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OccurrencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OccurrencesTable> {
  $$OccurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get occurrenceAt => $composableBuilder(
    column: $table.occurrenceAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get snoozeUntil => $composableBuilder(
    column: $table.snoozeUntil,
    builder: (column) => column,
  );
}

class $$OccurrencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OccurrencesTable,
          OccurrenceRow,
          $$OccurrencesTableFilterComposer,
          $$OccurrencesTableOrderingComposer,
          $$OccurrencesTableAnnotationComposer,
          $$OccurrencesTableCreateCompanionBuilder,
          $$OccurrencesTableUpdateCompanionBuilder,
          (
            OccurrenceRow,
            BaseReferences<_$AppDatabase, $OccurrencesTable, OccurrenceRow>,
          ),
          OccurrenceRow,
          PrefetchHooks Function()
        > {
  $$OccurrencesTableTableManager(_$AppDatabase db, $OccurrencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OccurrencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OccurrencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OccurrencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hlc = const Value.absent(),
                Value<String> fieldClock = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> reminderId = const Value.absent(),
                Value<int> occurrenceAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> snoozeUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OccurrencesCompanion(
                hlc: hlc,
                fieldClock: fieldClock,
                deleted: deleted,
                dirty: dirty,
                id: id,
                reminderId: reminderId,
                occurrenceAt: occurrenceAt,
                status: status,
                snoozeUntil: snoozeUntil,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hlc,
                Value<String> fieldClock = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String reminderId,
                required int occurrenceAt,
                required String status,
                Value<int?> snoozeUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OccurrencesCompanion.insert(
                hlc: hlc,
                fieldClock: fieldClock,
                deleted: deleted,
                dirty: dirty,
                id: id,
                reminderId: reminderId,
                occurrenceAt: occurrenceAt,
                status: status,
                snoozeUntil: snoozeUntil,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OccurrencesTable, OccurrenceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OccurrencesTable,
                    OccurrenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OccurrencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OccurrencesTable,
      OccurrenceRow,
      $$OccurrencesTableFilterComposer,
      $$OccurrencesTableOrderingComposer,
      $$OccurrencesTableAnnotationComposer,
      $$OccurrencesTableCreateCompanionBuilder,
      $$OccurrencesTableUpdateCompanionBuilder,
      (
        OccurrenceRow,
        BaseReferences<_$AppDatabase, $OccurrencesTable, OccurrenceRow>,
      ),
      OccurrenceRow,
      PrefetchHooks Function()
    >;
typedef $$FocusSessionsTableCreateCompanionBuilder =
    FocusSessionsCompanion Function({
      required String hlc,
      Value<String> fieldClock,
      Value<bool> deleted,
      Value<bool> dirty,
      required String id,
      Value<bool> active,
      Value<int?> startedAt,
      Value<int?> endsAt,
      Value<String> target,
      Value<bool> blockApps,
      Value<bool> quiet,
      Value<bool> strict,
      Value<String> startedBy,
      Value<int> rowid,
    });
typedef $$FocusSessionsTableUpdateCompanionBuilder =
    FocusSessionsCompanion Function({
      Value<String> hlc,
      Value<String> fieldClock,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<String> id,
      Value<bool> active,
      Value<int?> startedAt,
      Value<int?> endsAt,
      Value<String> target,
      Value<bool> blockApps,
      Value<bool> quiet,
      Value<bool> strict,
      Value<String> startedBy,
      Value<int> rowid,
    });

class $$FocusSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blockApps => $composableBuilder(
    column: $table.blockApps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get quiet => $composableBuilder(
    column: $table.quiet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get strict => $composableBuilder(
    column: $table.strict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedBy => $composableBuilder(
    column: $table.startedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blockApps => $composableBuilder(
    column: $table.blockApps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get quiet => $composableBuilder(
    column: $table.quiet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get strict => $composableBuilder(
    column: $table.strict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedBy => $composableBuilder(
    column: $table.startedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<bool> get blockApps =>
      $composableBuilder(column: $table.blockApps, builder: (column) => column);

  GeneratedColumn<bool> get quiet =>
      $composableBuilder(column: $table.quiet, builder: (column) => column);

  GeneratedColumn<bool> get strict =>
      $composableBuilder(column: $table.strict, builder: (column) => column);

  GeneratedColumn<String> get startedBy =>
      $composableBuilder(column: $table.startedBy, builder: (column) => column);
}

class $$FocusSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FocusSessionsTable,
          FocusSessionRow,
          $$FocusSessionsTableFilterComposer,
          $$FocusSessionsTableOrderingComposer,
          $$FocusSessionsTableAnnotationComposer,
          $$FocusSessionsTableCreateCompanionBuilder,
          $$FocusSessionsTableUpdateCompanionBuilder,
          (
            FocusSessionRow,
            BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSessionRow>,
          ),
          FocusSessionRow,
          PrefetchHooks Function()
        > {
  $$FocusSessionsTableTableManager(_$AppDatabase db, $FocusSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hlc = const Value.absent(),
                Value<String> fieldClock = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> endsAt = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<bool> blockApps = const Value.absent(),
                Value<bool> quiet = const Value.absent(),
                Value<bool> strict = const Value.absent(),
                Value<String> startedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion(
                hlc: hlc,
                fieldClock: fieldClock,
                deleted: deleted,
                dirty: dirty,
                id: id,
                active: active,
                startedAt: startedAt,
                endsAt: endsAt,
                target: target,
                blockApps: blockApps,
                quiet: quiet,
                strict: strict,
                startedBy: startedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hlc,
                Value<String> fieldClock = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String id,
                Value<bool> active = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> endsAt = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<bool> blockApps = const Value.absent(),
                Value<bool> quiet = const Value.absent(),
                Value<bool> strict = const Value.absent(),
                Value<String> startedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion.insert(
                hlc: hlc,
                fieldClock: fieldClock,
                deleted: deleted,
                dirty: dirty,
                id: id,
                active: active,
                startedAt: startedAt,
                endsAt: endsAt,
                target: target,
                blockApps: blockApps,
                quiet: quiet,
                strict: strict,
                startedBy: startedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FocusSessionsTable, FocusSessionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FocusSessionsTable,
                    FocusSessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FocusSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FocusSessionsTable,
      FocusSessionRow,
      $$FocusSessionsTableFilterComposer,
      $$FocusSessionsTableOrderingComposer,
      $$FocusSessionsTableAnnotationComposer,
      $$FocusSessionsTableCreateCompanionBuilder,
      $$FocusSessionsTableUpdateCompanionBuilder,
      (
        FocusSessionRow,
        BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSessionRow>,
      ),
      FocusSessionRow,
      PrefetchHooks Function()
    >;
typedef $$LocalSettingsTableCreateCompanionBuilder =
    LocalSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$LocalSettingsTableUpdateCompanionBuilder =
    LocalSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$LocalSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSettingsTable,
          LocalSetting,
          $$LocalSettingsTableFilterComposer,
          $$LocalSettingsTableOrderingComposer,
          $$LocalSettingsTableAnnotationComposer,
          $$LocalSettingsTableCreateCompanionBuilder,
          $$LocalSettingsTableUpdateCompanionBuilder,
          (
            LocalSetting,
            BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>,
          ),
          LocalSetting,
          PrefetchHooks Function()
        > {
  $$LocalSettingsTableTableManager(_$AppDatabase db, $LocalSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => LocalSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSettingsTable, LocalSetting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSettingsTable,
                    LocalSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSettingsTable,
      LocalSetting,
      $$LocalSettingsTableFilterComposer,
      $$LocalSettingsTableOrderingComposer,
      $$LocalSettingsTableAnnotationComposer,
      $$LocalSettingsTableCreateCompanionBuilder,
      $$LocalSettingsTableUpdateCompanionBuilder,
      (
        LocalSetting,
        BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>,
      ),
      LocalSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db, _db.subjects);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$OccurrencesTableTableManager get occurrences =>
      $$OccurrencesTableTableManager(_db, _db.occurrences);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
  $$LocalSettingsTableTableManager get localSettings =>
      $$LocalSettingsTableTableManager(_db, _db.localSettings);
}
