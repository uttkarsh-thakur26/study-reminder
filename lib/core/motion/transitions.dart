import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'motion.dart';

/// Swaps one piece of content for another with Material's "fade through":
/// the old fades out, then the new fades in, growing slightly into place.
/// The room they take changes smoothly when they differ in size.
///
/// The [child] needs a key that changes when the content is another.
class FadeThroughSwitcher extends StatelessWidget {
  const FadeThroughSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.resize = true,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  /// Whether to animate the room taken. Not needed where both are one size.
  final bool resize;

  /// The share of the time the old content takes to leave.
  static const _handover = 0.3;

  @override
  Widget build(BuildContext context) {
    final switcher = AnimatedSwitcher(
      duration: Motion.of(context, Motion.enter),
      // The old is gone by the time the new starts to show.
      reverseDuration: Motion.of(context, Motion.enter * _handover),
      switchInCurve: const Interval(_handover, 1, curve: Motion.arrive),
      switchOutCurve: Motion.leave.flipped,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
    if (!resize) return switcher;
    return SizeChange(alignment: alignment, child: switcher);
  }
}

/// Changes the room its [child] takes smoothly as the child changes size.
class SizeChange extends StatelessWidget {
  const SizeChange({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Motion.reduced(context)
      // Left out whole: an AnimatedSize cannot take no time at all.
      ? child
      : AnimatedSize(
          duration: Motion.enter,
          curve: Motion.change,
          alignment: alignment,
          child: child,
        );
}

/// A short text or icon that changes in place: the old slides out one way
/// as the new slides in from the other, both fading. With [up] set, the
/// new comes from below, as a number counting up does.
///
/// The [child] needs a key that changes when the content is another.
class SlideSwitcher extends StatelessWidget {
  const SlideSwitcher({super.key, required this.child, this.up = true});

  final Widget child;
  final bool up;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.of(context, Motion.exit),
    transitionBuilder: (child, animation) {
      // The one on its way out runs backwards, so it mirrors the way in,
      // and it has faded by half way, before the new one shows clearly.
      final incoming = child.key == this.child.key;
      final from = Offset(0, (up ? 1 : -1) * (incoming ? 0.5 : -0.5));
      // Driven, not wrapped in a CurvedAnimation: this runs on every
      // rebuild, and those would pile up on the animation.
      return FadeTransition(
        opacity: animation.drive(
          CurveTween(
            curve: incoming ? const Interval(0.3, 1) : const Interval(0.5, 1),
          ),
        ),
        child: SlideTransition(
          position: animation
              .drive(
                CurveTween(
                  curve: incoming ? Motion.arrive : const Cubic(0, 0, 0.7, 1),
                ),
              )
              .drive(Tween(begin: from, end: Offset.zero)),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// A whole number that rolls up or down to its new value.
class RollingNumber extends StatefulWidget {
  const RollingNumber(this.value, {super.key, this.style, this.textAlign});

  final int value;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  bool _up = true;

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _up = widget.value > old.value;
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: SlideSwitcher(
      up: _up,
      child: Text(
        '${widget.value}',
        key: ValueKey(widget.value),
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    ),
  );
}

/// Shows or hides its [child] by opening or closing the room it takes,
/// fading it as it goes. Hidden, the child is not built.
class Appear extends StatefulWidget {
  const Appear({
    super.key,
    required this.visible,
    required this.child,
    this.axis = Axis.vertical,
  });

  final bool visible;
  final Widget child;
  final Axis axis;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.enter,
    reverseDuration: Motion.exit,
    value: widget.visible ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));
  late final _size = CurvedAnimation(
    parent: _controller,
    curve: Motion.change,
    reverseCurve: const Cubic(0, 0, 0.7, 1),
  );
  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1),
    reverseCurve: const Interval(0.4, 1),
  );

  @override
  void didUpdateWidget(Appear old) {
    super.didUpdateWidget(old);
    if (old.visible == widget.visible) return;
    if (Motion.reduced(context)) {
      _controller.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isDismissed && !widget.visible) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      ignoring: !widget.visible,
      // The child is laid out as it would be without the animation: as
      // wide, or as high, as it has to be here.
      child: LayoutBuilder(
        builder: (context, box) => SizeTransition(
          sizeFactor: _size,
          axis: widget.axis,
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: widget.axis == Axis.vertical
                ? BoxConstraints(minWidth: box.minWidth)
                : BoxConstraints(minHeight: box.minHeight),
            child: FadeTransition(opacity: _fade, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Gives its [child] a short springy bounce each time [trigger] changes,
/// to say "that happened". Nothing bounces when it first shows.
class Pop extends StatefulWidget {
  const Pop({
    super.key,
    required this.trigger,
    required this.child,
    this.from = 0.8,
  });

  /// A new value sets the bounce off.
  final Object? trigger;
  final Widget child;

  /// The size it springs back from, as a share of its own.
  final double from;

  @override
  State<Pop> createState() => _PopState();
}

class _PopState extends State<Pop> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void didUpdateWidget(Pop old) {
    super.didUpdateWidget(old);
    if (old.trigger == widget.trigger || Motion.reduced(context)) return;
    _controller.animateWith(
      SpringSimulation(Motion.springBouncy, widget.from, 1, 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _controller, child: widget.child);
}
