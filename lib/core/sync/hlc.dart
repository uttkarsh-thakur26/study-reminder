/// Hybrid logical clock timestamp.
///
/// Orders edits across devices even when their wall clocks disagree a little.
/// The packed string form sorts the same way as the timestamps themselves, so
/// it can be compared as text locally and in Postgres.
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.node);

  /// The smallest possible timestamp, used for fields never edited.
  static const zero = Hlc(0, 0, '');

  /// Parses the output of [pack].
  factory Hlc.parse(String packed) {
    final first = packed.indexOf('-');
    final second = packed.indexOf('-', first + 1);
    if (first != 15 || second != 20) {
      throw FormatException('Bad HLC', packed);
    }
    return Hlc(
      int.parse(packed.substring(0, first)),
      int.parse(packed.substring(first + 1, second), radix: 36),
      packed.substring(second + 1),
    );
  }

  final int millis;
  final int counter;
  final String node;

  static const _maxCounter = 36 * 36 * 36 * 36 - 1;

  String pack() =>
      '${millis.toString().padLeft(15, '0')}-${counter.toRadixString(36).padLeft(4, '0')}-$node';

  @override
  int compareTo(Hlc other) {
    if (millis != other.millis) return millis.compareTo(other.millis);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return node.compareTo(other.node);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.node == node;

  @override
  int get hashCode => Object.hash(millis, counter, node);

  @override
  String toString() => pack();
}

/// Issues increasing [Hlc] timestamps for one device.
class HlcClock {
  HlcClock(this.node, {DateTime Function()? wallClock, Hlc? last})
      : _wall = wallClock ?? DateTime.now,
        _last = last ?? Hlc(0, 0, node);

  final String node;
  final DateTime Function() _wall;
  Hlc _last;

  Hlc get last => _last;

  /// A timestamp for a local edit, always later than any seen so far.
  Hlc now() {
    final wall = _wall().millisecondsSinceEpoch;
    if (wall > _last.millis) {
      _last = Hlc(wall, 0, node);
    } else {
      _last = _bump(_last.millis, _last.counter);
    }
    return _last;
  }

  /// Moves the clock past a timestamp received from another device, so the
  /// next local edit sorts after it.
  void receive(Hlc remote) {
    final wall = _wall().millisecondsSinceEpoch;
    final top = [wall, _last.millis, remote.millis].reduce((a, b) => a > b ? a : b);
    if (top == _last.millis && top == remote.millis) {
      final counter = _last.counter > remote.counter ? _last.counter : remote.counter;
      _last = _bump(top, counter);
    } else if (top == _last.millis) {
      _last = _bump(top, _last.counter);
    } else if (top == remote.millis) {
      _last = _bump(top, remote.counter);
    } else {
      _last = Hlc(top, 0, node);
    }
  }

  Hlc _bump(int millis, int counter) {
    if (counter >= Hlc._maxCounter) return Hlc(millis + 1, 0, node);
    return Hlc(millis, counter + 1, node);
  }
}
