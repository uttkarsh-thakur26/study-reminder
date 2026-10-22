import 'package:intl/intl.dart';

import '../features/focus/data/focus_repository.dart';
import '../features/focus/domain/focus_session.dart';
import '../features/reminders/domain/reminder.dart';

/// What the focus shortcut does with the laptop's session.
enum FocusHotkeyStep {
  /// None runs: start one with this laptop's Focus defaults.
  start,

  /// One runs that may stop early: stop it.
  stop,

  /// A strict one runs, which cannot stop early: show it.
  show,
}

FocusHotkeyStep focusHotkeyStep(FocusSession laptop, DateTime now) {
  if (!laptop.runningAt(now)) return FocusHotkeyStep.start;
  return laptop.strict ? FocusHotkeyStep.show : FocusHotkeyStep.stop;
}

/// Takes that step on the laptop only, whatever the phone does, and returns
/// it with the laptop's session afterwards.
Future<({FocusHotkeyStep step, FocusSession laptop})> toggleLaptopFocus(
  FocusRepository repo, {
  required String startedBy,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  const laptop = {DeviceKind.laptop};
  final step = focusHotkeyStep((await repo.current()).laptop, at);
  switch (step) {
    case FocusHotkeyStep.start:
      final prefs = await repo.prefs();
      await repo.start(
        on: laptop,
        length: Duration(minutes: prefs.minutes),
        blockApps: prefs.blockApps,
        quiet: prefs.quiet,
        strict: prefs.strict,
        startedBy: startedBy,
        now: at,
      );
    case FocusHotkeyStep.stop:
      await repo.stop(laptop);
    case FocusHotkeyStep.show:
      break;
  }
  return (step: step, laptop: (await repo.current()).laptop);
}

/// The notification that says what [step] did, with [keys] the shortcut.
/// Null when the Focus page should show instead.
({String title, String body})? focusHotkeyNote(
  FocusHotkeyStep step,
  FocusSession laptop, {
  required String keys,
  DateTime? now,
}) {
  switch (step) {
    case FocusHotkeyStep.start:
      if (!laptop.runningAt(now ?? DateTime.now())) return null;
      final until = DateFormat.jm().format(laptop.endsAt!.toLocal());
      return (
        title: 'Focus on until $until',
        body: laptop.strict
            ? 'Strict session: it runs to the end.'
            : 'Press $keys again to stop early.',
      );
    case FocusHotkeyStep.stop:
      return (
        title: 'Focus stopped on this laptop',
        body: 'Press $keys to start again.',
      );
    case FocusHotkeyStep.show:
      return null;
  }
}
