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
