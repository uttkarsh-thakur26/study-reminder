import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/stamped_write.dart';
import '../domain/subject.dart';

class SubjectRepository {
  SubjectRepository(this._db, this._clock);

  final AppDatabase _db;
  final HlcClock _clock;

  Stream<List<Subject>> watchAll() {
    final query = _db.select(_db.subjects)
      ..where((s) => s.deleted.equals(false))
      ..orderBy([
        (s) => OrderingTerm(expression: s.sortOrder),
        (s) => OrderingTerm(expression: s.name),
      ]);
    return query.watch().map((rows) => rows.map(subjectFromRow).toList());
  }

  Future<void> save(Subject subject) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.subjects,
    )..where((s) => s.id.equals(subject.id))).getSingleOrNull();
    final write = stampLocalEdit(
      before: existing == null ? null : subjectFromRow(existing).toFields(),
      beforeClock: existing?.fieldClock ?? '',
      after: subject.toFields(),
      clock: _clock,
    );
    if (write == null) return;
    await _db
        .into(_db.subjects)
        .insertOnConflictUpdate(subjectCompanion(subject.id, write));
  });

  Future<void> delete(Subject subject) => save(subject.copyWith(deleted: true));

  /// Next sort position, so new subjects go to the end of the list.
  Future<int> nextSortOrder() async {
    final max = _db.subjects.sortOrder.max();
    final row = await (_db.selectOnly(
      _db.subjects,
    )..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }
}

Subject subjectFromRow(SubjectRow row) => Subject(
  id: row.id,
  name: row.name,
  color: row.color,
  sortOrder: row.sortOrder,
  deleted: row.deleted,
);

SubjectsCompanion subjectCompanion(
  String id,
  StampedWrite w, {
  bool dirty = true,
}) {
  final s = Subject.fromFields(id, w.fields);
  return SubjectsCompanion.insert(
    id: id,
    name: s.name,
    color: s.color,
    sortOrder: Value(s.sortOrder),
    hlc: w.hlc.pack(),
    fieldClock: Value(w.clock.encode()),
    deleted: Value(s.deleted),
    dirty: Value(dirty),
  );
}
