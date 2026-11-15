import 'package:flutter/material.dart';

import 'motion.dart';

/// A sliver list that animates what joins and leaves it.
///
/// Give it the list as it is now. An item whose id is new opens up its
/// space and fades in; one whose id is gone fades and closes up, staying
/// where it was until then. The rest make room as that happens, so the
/// eye can follow what changed.
///
/// What is there when the list first shows comes with no animation.
class AnimatedSliverList<T> extends StatefulWidget {
  const AnimatedSliverList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
  });

  final List<T> items;

  /// What makes an item the same one from one build to the next. No two
  /// items may share one.
  final Object Function(T item) idOf;

  /// Also builds an item on its way out, from how it last was.
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  State<AnimatedSliverList<T>> createState() => _AnimatedSliverListState<T>();
}

class _Entry<T> {
  _Entry(this.id, this.item);

  final Object id;
  T item;

  /// Runs from 0, out of the list, to 1, in it. None while it rests in it.
  AnimationController? controller;
  bool leaving = false;
}

class _AnimatedSliverListState<T> extends State<AnimatedSliverList<T>>
    with TickerProviderStateMixin {
  late var _entries = [
    for (final item in widget.items) _Entry<T>(widget.idOf(item), item),
  ];

  @override
  void didUpdateWidget(AnimatedSliverList<T> old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.controller?.dispose();
    }
    super.dispose();
  }

  void _sync() {
    final reduced = Motion.reduced(context);
    final known = {for (final e in _entries) e.id: e};
    final next = <_Entry<T>>[];
    final kept = <Object>{};
    for (final item in widget.items) {
      final id = widget.idOf(item);
      final isNew = kept.add(id);
      assert(isNew, 'Two items share the id $id');
      if (!isNew) continue;
      var entry = known[id];
      if (entry == null) {
        entry = _Entry<T>(id, item);
        if (!reduced) _enter(entry, from: 0);
      } else {
        entry.item = item;
        // Back before it had gone: it opens up again from where it got to.
        if (entry.leaving) _enter(entry, from: entry.controller?.value ?? 0);
      }
      next.add(entry);
    }
    // What left keeps its place, after the neighbour that was before it.
    var after = -1;
    for (final entry in _entries) {
      if (kept.contains(entry.id)) {
        after = next.indexOf(entry);
      } else if (reduced) {
        entry.controller?.dispose();
      } else {
        if (!entry.leaving) _leave(entry);
        next.insert(++after, entry);
      }
    }
    _entries = next;
  }

  void _enter(_Entry<T> entry, {required double from}) {
    entry.leaving = false;
    entry.controller?.dispose();
    final controller = entry.controller = AnimationController(
      vsync: this,
      duration: Motion.enter,
      value: from,
    );
    controller.forward().whenComplete(() {
      if (!mounted || entry.controller != controller) return;
      entry.controller = null;
      controller.dispose();
    });
  }

  void _leave(_Entry<T> entry) {
    entry.leaving = true;
    final from = entry.controller?.value ?? 1.0;
    entry.controller?.dispose();
    final controller = entry.controller = AnimationController(
      vsync: this,
      duration: Motion.enter,
      value: from,
    );
    controller.reverse().whenComplete(() {
      if (!mounted || entry.controller != controller) return;
      setState(() => _entries.remove(entry));
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: _entries.length,
    itemBuilder: (context, i) {
      final entry = _entries[i];
      return _ItemTransition(
        key: ValueKey(entry.id),
        animation: entry.controller ?? kAlwaysCompleteAnimation,
        leaving: entry.leaving,
        child: widget.itemBuilder(context, entry.item),
      );
    },
  );
}

/// Opens or closes the room an item takes, and fades it.
class _ItemTransition extends AnimatedWidget {
  const _ItemTransition({
    super.key,
    required Animation<double> animation,
    required this.leaving,
    required this.child,
  }) : super(listenable: animation);

  final bool leaving;
  final Widget child;

  // On the way out the item holds for a moment, so a change that sent it
  // off (a tick, say) can be seen, then fades before its room has closed.
  // The animation runs backwards for these two, so the curve of the room
  // closing is an accelerating one, mirrored.
  static const _leaveSize = Interval(0, 0.8, curve: Cubic(0, 0, 0.7, 1));
  static const _leaveFade = Interval(0.35, 0.8);
  static const _enterFade = Interval(0.3, 1, curve: Easing.standardDecelerate);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final settled = t >= 1;
    return IgnorePointer(
      ignoring: leaving,
      child: ClipRect(
        clipBehavior: settled ? Clip.none : Clip.hardEdge,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: settled
              ? 1
              : leaving
              ? _leaveSize.transform(t)
              : Motion.change.transform(t),
          child: Opacity(
            opacity: settled
                ? 1
                : leaving
                ? _leaveFade.transform(t)
                : _enterFade.transform(t),
            // As wide as the list, as it would be without the animation.
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}
