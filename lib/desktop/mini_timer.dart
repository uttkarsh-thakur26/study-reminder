import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../app/providers.dart';
import '../core/theme/app_theme.dart';
import '../features/focus/application/focus_providers.dart';
import '../features/focus/domain/focus_session.dart';
import 'desktop_window.dart';

/// Whether the window is the small focus timer that stays on top.
final miniTimerProvider = NotifierProvider<MiniTimer, bool>(MiniTimer.new);

/// Shrinks the Windows app to a small timer above other windows, in the
/// top right corner, and back to the window it was.
class MiniTimer extends Notifier<bool> {
  static const size = Size(280, 128);

  Rect? _bounds;
  bool _wasMaximized = false;

  @override
  bool build() => false;

  Future<void> enter() async {
    if (state || !isWindowsApp) return;
    // A maximized window keeps its maximized layout through a resize, which
    // leaves the small window blank, so it is restored first.
    _wasMaximized = await windowManager.isMaximized();
    if (_wasMaximized) await windowManager.unmaximize();
    _bounds = await windowManager.getBounds();
    state = true;
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setMinimumSize(size);
    await windowManager.setSize(size);
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.setAlwaysOnTop(true);
  }

  Future<void> leave() async {
    if (!state) return;
    state = false;
    if (!isWindowsApp) return;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(desktopMinimumSize);
    final bounds = _bounds;
    if (bounds != null) {
      await windowManager.setBounds(bounds);
    } else {
      await windowManager.setSize(desktopDefaultSize);
      await windowManager.center();
    }
    if (_wasMaximized) await windowManager.maximize();
  }
}

/// Brings the window back from the tray as the whole app, out of the small
/// timer, for anything that needs more room than the timer has.
Future<void> showFullWindow(MiniTimer mini) async {
  await mini.leave();
  await showDesktopWindow();
}

/// The laptop's session as a small timer: what is left of the round or
/// break, 5 more minutes, and back to the full window. Drag it anywhere.
class MiniTimerView extends ConsumerStatefulWidget {
  const MiniTimerView({super.key});

  @override
  ConsumerState<MiniTimerView> createState() => _MiniTimerViewState();
}

class _MiniTimerViewState extends ConsumerState<MiniTimerView> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final here = ref.watch(deviceKindProvider);
    final sessions =
        ref.watch(focusSessionsProvider).value ?? FocusSessions.idle;
    final session = sessions.of(here);
    final paused = session.isPaused;
    final phase = session.phaseAt(now) ?? session.pausedPhase;
    final mini = ref.read(miniTimerProvider.notifier);
    final repo = ref.read(focusRepositoryProvider);
    // Every device in this session, so they stay alike.
    final on = sessions.sharing(here, now);

    final String clock;
    final String label;
    if (phase == null) {
      clock = 'Done';
      label = 'No focus session running';
    } else if (paused) {
      clock = _clock(
        phase.rounds > 1
            ? phase.endsAt.difference(session.pausedAt!)
            : session.pausedLeft,
      );
      label = phase.rounds > 1
          ? 'Paused · round ${phase.round} of ${phase.rounds}'
          : 'Paused';
    } else {
      final left = phase.rounds > 1
          ? phase.endsAt.difference(now)
          : session.remainingAt(now);
      clock = _clock(left);
      label = phase.rounds < 2
          ? 'Focus'
          : phase.onBreak
          ? 'Break · round ${phase.round} of ${phase.rounds} done'
          : 'Round ${phase.round} of ${phase.rounds}';
    }
    final color = paused
        ? scheme.outline
        : phase?.onBreak ?? false
        ? scheme.tertiary
        : scheme.primary;

    return Material(
      color: scheme.surfaceContainer,
      child: DragToMoveArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.s, Gap.m),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 64,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clock,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: mini.leave,
                    icon: const Icon(Icons.open_in_full_rounded, size: 20),
                    tooltip: 'Back to the full window',
                  ),
                  if (paused)
                    IconButton(
                      onPressed: () => repo.resume(on),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      tooltip: 'Resume',
                    )
                  else if (phase != null && !session.strict)
                    IconButton(
                      onPressed: () => repo.pause(on),
                      icon: const Icon(Icons.pause_rounded, size: 20),
                      tooltip: 'Pause',
                    )
                  else if (phase != null)
                    IconButton(
                      onPressed: () =>
                          repo.extend(on, const Duration(minutes: 5)),
                      icon: const Icon(Icons.more_time_rounded, size: 20),
                      tooltip: '5 minutes more',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _clock(Duration d) {
    final s = d.isNegative ? 0 : d.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return h > 0 ? '$h:${two(m)}:${two(s % 60)}' : '${two(m)}:${two(s % 60)}';
  }
}
