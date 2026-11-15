import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/motion/transitions.dart';

/// The ring around a session's clock: how much of the round, break or
/// session is left.
///
/// The clock ticking moves it a hair at a time. Anything larger is shown
/// as a movement, so it reads as one event: the ring fills as a session
/// starts, refills for the next round or break, and takes up time that
/// was added. Its colour changes smoothly, and a new round or break gives
/// it a small bounce.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.size,
    required this.progress,
    required this.color,
    required this.track,
    required this.child,
    this.phase,
  });

  final double size;

  /// The share left, from 0 to 1.
  final double progress;
  final Color color;
  final Color track;

  /// What the ring counts down now. A new value sets off the bounce.
  final Object? phase;
  final Widget child;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing>
    with SingleTickerProviderStateMixin {
  /// A change in the share left above this is animated. Below it, it is
  /// the clock ticking, which is smooth as it is.
  static const _jump = 0.02;

  late final _sweep = AnimationController(
    vsync: this,
    duration: Durations.long4,
  );
  double _from = 0;
  late double _to = widget.progress;
  bool _shown = false;

  double get _progress =>
      lerpDouble(_from, _to, _curve.transform(_sweep.value))!;

  /// Material's curve for a movement that starts and ends on screen.
  static const _curve = Curves.easeInOutCubicEmphasized;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      // Also when motion is turned off while the ring is on its way.
      _shown = true;
      _sweep.value = 1;
    } else if (!_shown) {
      // The ring fills up to where the session is as it first shows.
      _shown = true;
      _sweep.forward();
    }
  }

  @override
  void didUpdateWidget(FocusRing old) {
    super.didUpdateWidget(old);
    final next = widget.progress;
    if (Motion.reduced(context)) {
      _to = next;
      _sweep.value = 1;
    } else if (_sweep.isAnimating || (next - _progress).abs() <= _jump) {
      // On its way already, or a tick: it follows.
      _to = next;
    } else {
      _from = _progress;
      _to = next;
      _sweep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Pop(
    trigger: widget.phase,
    from: 0.94,
    child: SizedBox.square(
      dimension: widget.size,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: widget.color),
        duration: Motion.of(context, Motion.enter),
        curve: Motion.change,
        builder: (context, color, child) => AnimatedBuilder(
          animation: _sweep,
          builder: (context, child) => CustomPaint(
            painter: _RingPainter(
              progress: _progress,
              track: widget.track,
              color: color ?? widget.color,
              stroke: widget.size / 18,
            ),
            child: child,
          ),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.stroke,
  });

  final double progress;
  final Color track;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(circle, 0, 2 * pi, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        circle,
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.color != color ||
      old.stroke != stroke;
}
