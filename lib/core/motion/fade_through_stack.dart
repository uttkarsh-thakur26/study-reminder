import 'package:flutter/material.dart';

import 'motion.dart';

/// The pages of the app's top level, one shown at a time, all kept alive.
///
/// Moving to another page is Material's "fade through": the old page fades
/// out first, then the new one fades in while growing the last few percent
/// to its size. The two never share the screen, which suits pages that
/// have nothing to do with each other.
class FadeThroughStack extends StatefulWidget {
  const FadeThroughStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<FadeThroughStack>
    with SingleTickerProviderStateMixin {
  /// The share of the time the old page takes to leave.
  static const _handover = 0.3;

  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.enter,
    value: 1,
  );
  late final _out = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, _handover, curve: Motion.leave),
  );
  late final _in = CurvedAnimation(
    parent: _controller,
    curve: const Interval(_handover, 1, curve: Motion.arrive),
  );

  /// The page being left, while it is still fading out.
  int? _from;

  /// How far in the page being left had come when it was left: all the
  /// way, unless another change cut its arrival short.
  double _fromIn = 1;

  static double _scale(double shown) => 0.94 + 0.06 * shown;

  @override
  void didUpdateWidget(FadeThroughStack old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (Motion.reduced(context)) {
      _from = null;
      _controller.value = 1;
    } else if (_controller.value < _handover) {
      // A page is still on its way out, and the one asked for before has
      // not shown yet: the newest takes its place when the old has gone.
    } else {
      // The page being left goes from where it is, even part way in.
      _from = old.index;
      _fromIn = _in.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _out.dispose();
    _in.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final leaving = _controller.value < _handover ? _from : null;
      return Stack(
        fit: StackFit.expand,
        children: [
          for (final (i, page) in widget.children.indexed)
            _Page(
              key: ValueKey(i),
              // Until the old page is gone, the new one waits unseen.
              shown: i == leaving || (i == widget.index && leaving == null),
              current: i == widget.index,
              opacity: i == leaving ? _fromIn * (1 - _out.value) : _in.value,
              scale: i == leaving ? _scale(_fromIn) : _scale(_in.value),
              child: page,
            ),
        ],
      );
    },
  );
}

/// One page, built the same way whether it shows or not, so it keeps its
/// state. Hidden, it is not laid out for show, takes no taps or keyboard
/// focus, and its animations rest.
class _Page extends StatelessWidget {
  const _Page({
    super.key,
    required this.shown,
    required this.current,
    required this.opacity,
    required this.scale,
    required this.child,
  });

  final bool shown;
  final bool current;
  final double opacity;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !shown,
    child: TickerMode(
      enabled: shown,
      child: IgnorePointer(
        ignoring: !current,
        child: ExcludeFocus(
          excluding: !current,
          child: Opacity(
            opacity: shown ? opacity.clamp(0.0, 1.0) : 1,
            child: Transform.scale(scale: shown ? scale : 1, child: child),
          ),
        ),
      ),
    ),
  );
}
