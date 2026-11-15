import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/motion/animated_sliver_list.dart';
import 'package:study_reminder/core/motion/fade_through_stack.dart';
import 'package:study_reminder/core/motion/motion.dart';
import 'package:study_reminder/core/motion/transitions.dart';

/// [child] in an app, with motion reduced or not.
Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  home: ReduceMotion(
    reduce: reduce,
    child: Scaffold(body: child),
  ),
);

Widget _list(List<String> items, {bool reduce = false}) => _host(
  reduce: reduce,
  CustomScrollView(
    slivers: [
      AnimatedSliverList<String>(
        items: items,
        idOf: (item) => item,
        itemBuilder: (context, item) =>
            SizedBox(key: ValueKey('row $item'), height: 50, child: Text(item)),
      ),
    ],
  ),
);

/// A page that counts its taps, to tell whether it kept its state.
class _Counter extends StatefulWidget {
  const _Counter(this.name);

  final String name;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => _taps++),
      child: Text('${widget.name} $_taps'),
    ),
  );
}

Widget _pages(int index, {bool reduce = false}) => _host(
  reduce: reduce,
  FadeThroughStack(
    index: index,
    children: const [_Counter('first'), _Counter('second')],
  ),
);

void main() {
  double top(WidgetTester tester, String item) =>
      tester.getTopLeft(find.byKey(ValueKey('row $item'))).dy;

  group('the animated list', () {
    testWidgets('shows what it starts with at once', (tester) async {
      await tester.pumpWidget(_list(['a', 'b']));
      expect(top(tester, 'b'), 50);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('opens up room for a new item', (tester) async {
      await tester.pumpWidget(_list(['a', 'c']));
      await tester.pumpWidget(_list(['a', 'b', 'c']));
      expect(top(tester, 'c'), 50, reason: 'nothing has moved yet');

      await tester.pump(const Duration(milliseconds: 100));
      expect(top(tester, 'c'), allOf(greaterThan(50), lessThan(100)));

      await tester.pumpAndSettle();
      expect(top(tester, 'c'), 100);
    });

    testWidgets('keeps an item where it was while it leaves', (tester) async {
      await tester.pumpWidget(_list(['a', 'b', 'c']));
      await tester.pumpWidget(_list(['a', 'c']));
      expect(find.text('b'), findsOneWidget);
      expect(top(tester, 'c'), 100);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('b'), findsOneWidget);
      expect(top(tester, 'c'), allOf(greaterThan(50), lessThan(100)));

      await tester.pumpAndSettle();
      expect(find.text('b'), findsNothing);
      expect(top(tester, 'c'), 50);
    });

    testWidgets('brings back an item that returns before it has gone', (
      tester,
    ) async {
      await tester.pumpWidget(_list(['a', 'b', 'c']));
      await tester.pumpWidget(_list(['a', 'c']));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_list(['a', 'b', 'c']));
      await tester.pumpAndSettle();

      expect(find.text('b'), findsOneWidget);
      expect(top(tester, 'b'), 50);
      expect(top(tester, 'c'), 100);
    });

    testWidgets('keeps the order of what leaves and what joins', (
      tester,
    ) async {
      await tester.pumpWidget(_list(['a', 'b', 'c', 'd']));
      await tester.pumpWidget(_list(['x', 'a', 'd', 'y']));
      await tester.pump();

      final shown = tester
          // A new one has no height yet, which finders take for hidden.
          .widgetList<Text>(find.byType(Text, skipOffstage: false))
          .map((t) => t.data)
          .toList();
      expect(shown, ['x', 'a', 'b', 'c', 'd', 'y']);

      await tester.pumpAndSettle();
      expect(find.text('b'), findsNothing);
      expect(find.text('c'), findsNothing);
    });

    testWidgets('changes at once with reduced motion', (tester) async {
      await tester.pumpWidget(_list(['a', 'c'], reduce: true));
      await tester.pumpWidget(_list(['a', 'b', 'c'], reduce: true));
      expect(top(tester, 'c'), 100);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(_list(['c'], reduce: true));
      expect(find.text('a'), findsNothing);
      expect(top(tester, 'c'), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('the pages', () {
    testWidgets('keep their state across a switch', (tester) async {
      await tester.pumpWidget(_pages(0));
      await tester.tap(find.text('first 0'));
      await tester.pump();
      expect(find.text('first 1'), findsOneWidget);

      await tester.pumpWidget(_pages(1));
      await tester.pumpAndSettle();
      expect(find.text('second 0'), findsOneWidget);
      expect(find.text('first 1'), findsNothing);

      await tester.pumpWidget(_pages(0));
      await tester.pumpAndSettle();
      expect(find.text('first 1'), findsOneWidget);
    });

    testWidgets('never show two at a time', (tester) async {
      await tester.pumpWidget(_pages(0));
      await tester.pumpWidget(_pages(1));

      // The old page fades out first.
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('first 0'), findsOneWidget);
      expect(find.text('second 0'), findsNothing);

      // Then the new one fades in.
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('first 0'), findsNothing);
      expect(find.text('second 0'), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('only the page shown takes taps', (tester) async {
      await tester.pumpWidget(_pages(0));
      await tester.pumpWidget(_pages(1));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text('first 0'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.pumpWidget(_pages(0));
      await tester.pumpAndSettle();
      expect(find.text('first 0'), findsOneWidget);
    });

    testWidgets('switch at once with reduced motion', (tester) async {
      await tester.pumpWidget(_pages(0, reduce: true));
      await tester.pumpWidget(_pages(1, reduce: true));
      expect(find.text('second 0'), findsOneWidget);
      expect(find.text('first 0'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('a part that comes and goes', () {
    Widget part(bool visible, {bool reduce = false}) => _host(
      reduce: reduce,
      Column(
        children: [
          Appear(
            visible: visible,
            child: const SizedBox(height: 40, child: Text('note')),
          ),
          const Text('below'),
        ],
      ),
    );

    testWidgets('is not built while hidden', (tester) async {
      await tester.pumpWidget(part(false));
      expect(find.text('note'), findsNothing);
      expect(tester.getTopLeft(find.text('below')).dy, 0);
    });

    testWidgets('opens and closes its room', (tester) async {
      await tester.pumpWidget(part(false));
      await tester.pumpWidget(part(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getTopLeft(find.text('below')).dy,
        allOf(greaterThan(0), lessThan(40)),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('below')).dy, 40);

      await tester.pumpWidget(part(false));
      expect(find.text('note'), findsOneWidget, reason: 'still leaving');
      await tester.pumpAndSettle();
      expect(find.text('note'), findsNothing);
      expect(tester.getTopLeft(find.text('below')).dy, 0);
    });

    testWidgets('comes and goes at once with reduced motion', (tester) async {
      await tester.pumpWidget(part(false, reduce: true));
      await tester.pumpWidget(part(true, reduce: true));
      expect(tester.getTopLeft(find.text('below')).dy, 40);
      await tester.pumpWidget(part(false, reduce: true));
      await tester.pump();
      expect(find.text('note'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('content that is swapped', () {
    Widget swap(String text, {bool reduce = false}) => _host(
      reduce: reduce,
      Column(
        children: [
          FadeThroughSwitcher(
            child: SizedBox(
              key: ValueKey(text),
              height: text.length * 10,
              child: Text(text),
            ),
          ),
          const Text('below'),
        ],
      ),
    );

    testWidgets('fades through, and the room it takes follows', (tester) async {
      await tester.pumpWidget(swap('one'));
      await tester.pumpWidget(swap('a longer one'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('one'), findsOneWidget, reason: 'still leaving');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('one'), findsNothing);
      expect(
        tester.getTopLeft(find.text('below')).dy,
        allOf(greaterThan(30), lessThan(120)),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('below')).dy, 120);
    });

    testWidgets('is swapped at once with reduced motion', (tester) async {
      await tester.pumpWidget(swap('one', reduce: true));
      await tester.pumpWidget(swap('a longer one', reduce: true));
      await tester.pump();
      expect(find.text('one'), findsNothing);
      expect(tester.getTopLeft(find.text('below')).dy, 120);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a number changes at once with reduced motion', (tester) async {
      await tester.pumpWidget(_host(const RollingNumber(25), reduce: true));
      await tester.pumpWidget(_host(const RollingNumber(30), reduce: true));
      await tester.pump();
      expect(find.text('25'), findsNothing);
      expect(find.text('30'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('feedback', () {
    testWidgets('a number rolls to its new value', (tester) async {
      await tester.pumpWidget(_host(const RollingNumber(25)));
      await tester.pumpWidget(_host(const RollingNumber(30)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('25'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      // Counting up, the new number comes from below.
      expect(
        tester.getCenter(find.text('30')).dy,
        greaterThan(tester.getCenter(find.text('25')).dy),
      );
      await tester.pumpAndSettle();
      expect(find.text('25'), findsNothing);
    });

    testWidgets('a bounce follows a change, and not with reduced motion', (
      tester,
    ) async {
      Widget pop(bool done, {bool reduce = false}) => _host(
        reduce: reduce,
        Center(
          child: Pop(trigger: done, child: const Text('tick')),
        ),
      );

      await tester.pumpWidget(pop(false));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(pop(true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();

      await tester.pumpWidget(pop(false, reduce: true));
      await tester.pumpWidget(pop(true, reduce: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
