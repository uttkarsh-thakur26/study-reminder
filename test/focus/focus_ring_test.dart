import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/motion/motion.dart';
import 'package:study_reminder/features/focus/ui/focus_ring.dart';

Widget _ring(double progress, {Object? phase, bool reduce = false}) =>
    MaterialApp(
      home: ReduceMotion(
        reduce: reduce,
        child: Center(
          child: FocusRing(
            size: 200,
            progress: progress,
            color: Colors.indigo,
            track: Colors.grey,
            phase: phase,
            child: const Text('24:59'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('the ring fills as it first shows', (tester) async {
    await tester.pumpWidget(_ring(1));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the clock ticking does not set it moving', (tester) async {
    await tester.pumpWidget(_ring(1));
    await tester.pumpAndSettle();
    // A second off a 25 minute round.
    await tester.pumpWidget(_ring(1 - 1 / 1500));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a new round refills it and gives it a bounce', (tester) async {
    await tester.pumpWidget(_ring(0.01, phase: 1));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_ring(1, phase: 2));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    final scale = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(FocusRing),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    expect(scale, isNot(1));
    await tester.pumpAndSettle();
  });

  testWidgets('turning motion off stops a ring on its way', (tester) async {
    await tester.pumpWidget(_ring(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_ring(1, reduce: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('nothing moves with reduced motion', (tester) async {
    await tester.pumpWidget(_ring(0.01, phase: 1, reduce: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_ring(1, phase: 2, reduce: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
