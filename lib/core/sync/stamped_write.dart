import 'field_clock.dart';
import 'hlc.dart';

/// Field values plus their stamps, ready to be written to a synced table.
class StampedWrite {
  const StampedWrite(this.fields, this.clock);

  final Map<String, Object?> fields;
  final FieldClock clock;

  Hlc get hlc => clock.latest;
}

/// Stamps a local edit. Returns null when [after] matches [before] exactly,
/// so saving an unchanged record writes nothing and syncs nothing.
StampedWrite? stampLocalEdit({
  required Map<String, Object?>? before,
  required String beforeClock,
  required Map<String, Object?> after,
  required HlcClock clock,
}) {
  final current = FieldClock.decode(beforeClock);
  final next = FieldClock.stamp(
    before: before,
    after: after,
    current: current,
    now: clock.now(),
  );
  if (next == null) return null;
  return StampedWrite(after, next);
}

/// The record to write for a local edit: [current] with only the fields that
/// differ between [base] and [edited] replaced.
///
/// [base] is the version the edit started from. Fields the user did not touch
/// keep whatever is stored now, so a change that synced in while an editor
/// was open is not overwritten with a stale copy. With no stored record or no
/// base, [edited] is written whole.
Map<String, Object?> applyEdit({
  required Map<String, Object?>? current,
  required Map<String, Object?>? base,
  required Map<String, Object?> edited,
}) {
  if (current == null || base == null) return edited;
  return {
    ...current,
    for (final e in edited.entries)
      if (base[e.key] != e.value) e.key: e.value,
  };
}
