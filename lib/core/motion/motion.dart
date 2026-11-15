import 'package:flutter/material.dart';

/// How things move in the app, in one place, so every change of state
/// feels like the same hand made it.
///
/// The values are Material 3's: its duration and easing tokens for
/// things that fade or change size, and its springs for things that move
/// or give feedback. Things arrive slower than they leave, and they slow
/// down as they arrive.
///
/// Every animation in the app asks [reduced] first: with the device's
/// "Remove animations" setting or the app's own Reduce motion switch on,
/// state changes land at once, with nothing moving.
abstract final class Motion {
  /// A small change in place: a tick, a colour, a number.
  static const fast = Durations.short3;

  /// Something leaving.
  static const exit = Durations.short4;

  /// Something arriving, or a change of size.
  static const enter = Durations.medium2;

  /// A large change, like the focus ring refilling for the next round.
  static const slow = Durations.long2;

  /// For what arrives: quick off the mark, then a long, soft landing.
  static const Curve arrive = Easing.emphasizedDecelerate;

  /// For what leaves: a gentle start, then gone.
  static const Curve leave = Easing.emphasizedAccelerate;

  /// For what changes in place.
  static const Curve change = Easing.standard;

  /// Material 3's spring for small things that move.
  static final springFast = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1400,
    ratio: 0.9,
  );

  /// Material 3's spring for parts of the screen that move.
  static final spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 700,
    ratio: 0.9,
  );

  /// A livelier spring for a short bounce that says "that happened": a
  /// reminder ticked off, a round begun.
  static final springBouncy = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 700,
    ratio: 0.5,
  );

  /// Whether to leave the motion out.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or none at all with reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Turns the app's motion off below it when [reduce] is set, the way the
/// device's own setting does.
class ReduceMotion extends StatelessWidget {
  const ReduceMotion({super.key, required this.reduce, required this.child});

  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) => reduce
      ? MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child,
        )
      : child;
}
