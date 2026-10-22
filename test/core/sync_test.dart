import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/sync/field_clock.dart';
import 'package:study_reminder/core/sync/hlc.dart';

void main() {
  group('Hlc', () {
    test('packs and parses losslessly, and text order matches time order', () {
      const a = Hlc(1761100000000, 5, 'phone1');
      expect(Hlc.parse(a.pack()), a);

      final stamps = [
        const Hlc(1761100000001, 0, 'a'),
        const Hlc(1761100000000, 12, 'b'),
        const Hlc(1761100000000, 2, 'z'),
        const Hlc(999, 0, 'x'),
      ];
      final byValue = [...stamps]..sort();
      final byText = [...stamps]..sort((x, y) => x.pack().compareTo(y.pack()));
      expect(byText, byValue);
    });

    test('clock never goes backwards when the wall clock does', () {
      var wall = DateTime.fromMillisecondsSinceEpoch(10000);
      final clock = HlcClock('dev', wallClock: () => wall);
      final first = clock.now();
      wall = DateTime.fromMillisecondsSinceEpoch(5000);
      final second = clock.now();
      final third = clock.now();
      expect(second > first, isTrue);
      expect(third > second, isTrue);
      expect(second.millis, 10000);
    });

    test('receiving a remote stamp moves the clock past it', () {
      final clock = HlcClock(
        'a',
        wallClock: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      const remote = Hlc(50000, 7, 'b');
      clock.receive(remote);
      expect(clock.now() > remote, isTrue);
    });

    test('counter overflow rolls into the next millisecond', () {
      final clock = HlcClock(
        'a',
        wallClock: () => DateTime.fromMillisecondsSinceEpoch(1),
        last: const Hlc(100, 36 * 36 * 36 * 36 - 1, 'a'),
      );
      final next = clock.now();
      expect(next.millis, 101);
      expect(next.counter, 0);
    });
  });

  group('FieldClock', () {
    const t1 = Hlc(1000, 0, 'a');
    const t2 = Hlc(2000, 0, 'b');
    const t3 = Hlc(3000, 0, 'a');

    test('a new record stamps every field', () {
      final clock = FieldClock.stamp(
        before: null,
        after: {'title': 'Physics', 'minute': 600},
        current: FieldClock.empty,
        now: t1,
      )!;
      expect(clock.of('title'), t1);
      expect(clock.of('minute'), t1);
    });

    test('only changed fields get a new stamp; no change returns null', () {
      final start = FieldClock(const {'title': t1, 'minute': t1});
      final next = FieldClock.stamp(
        before: {'title': 'Physics', 'minute': 600},
        after: {'title': 'Physics', 'minute': 630},
        current: start,
        now: t2,
      )!;
      expect(next.of('title'), t1);
      expect(next.of('minute'), t2);
      expect(next.latest, t2);

      expect(
        FieldClock.stamp(
          before: {'title': 'Physics'},
          after: {'title': 'Physics'},
          current: start,
          now: t3,
        ),
        isNull,
      );
    });

    test('encodes and decodes', () {
      final clock = FieldClock(const {'title': t1, 'notes': t2});
      final back = FieldClock.decode(clock.encode());
      expect(back.of('title'), t1);
      expect(back.of('notes'), t2);
      expect(FieldClock.decode('').stamps, isEmpty);
    });

    test('merge keeps the newest value of each field', () {
      // Laptop renamed the reminder, phone changed its time, both offline.
      final result = mergeRecords(
        local: {'title': 'Physics', 'minute': 630},
        localClock: FieldClock(const {'title': t1, 'minute': t3}),
        remote: {'title': 'Physics revision', 'minute': 600},
        remoteClock: FieldClock(const {'title': t2, 'minute': t1}),
      );
      expect(result.values, {'title': 'Physics revision', 'minute': 630});
      expect(result.clock.of('title'), t2);
      expect(result.clock.of('minute'), t3);
      expect(result.localWon, isTrue);
    });

    test('merge with an all-newer remote takes everything and reports no local win', () {
      final result = mergeRecords(
        local: {'title': 'Old', 'deleted': false},
        localClock: FieldClock(const {'title': t1, 'deleted': t1}),
        remote: {'title': 'New', 'deleted': true},
        remoteClock: FieldClock(const {'title': t2, 'deleted': t2}),
      );
      expect(result.values, {'title': 'New', 'deleted': true});
      expect(result.localWon, isFalse);
    });

    test('merge adds fields only the remote knows about', () {
      final result = mergeRecords(
        local: {'title': 'A'},
        localClock: FieldClock(const {'title': t2}),
        remote: {'title': 'B', 'notes': 'n'},
        remoteClock: FieldClock(const {'title': t1, 'notes': t1}),
      );
      expect(result.values, {'title': 'A', 'notes': 'n'});
    });
  });
}
