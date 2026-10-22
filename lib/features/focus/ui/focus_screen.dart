import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/formatters.dart';
import '../../reminders/domain/reminder.dart';
import '../../sync/application/sync_providers.dart';
import '../application/focus_providers.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';
import 'focus_setup.dart';

/// Start a focus session for this device and the paired ones, follow the
/// one running, and set up what each device blocks.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(focusSessionProvider).value ?? FocusSession.idle;
    final prefs = ref.watch(focusPrefsProvider).value ?? const FocusPrefs();
    final hasGuard = ref.watch(focusGuardProvider) != null;
    final hasWindows = ref.watch(desktopWindowsProvider) != null;

    return SafeArea(
      bottom: false,
      child: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, Gap.l, 96),
          children: [
            Text('Focus', style: theme.textTheme.headlineMedium),
            const SizedBox(height: Gap.l),
            SessionCard(session: session, prefs: prefs),
            if (hasGuard) ...[
              const SectionHeader('THIS PHONE'),
              const PhoneAccessCard(),
              const SizedBox(height: Gap.m),
              PhoneBlockListCard(prefs: prefs),
            ],
            if (hasWindows) ...[
              const SectionHeader('THIS LAPTOP'),
              LaptopBlockListCard(prefs: prefs),
            ],
          ],
        ),
      ),
    );
  }
}

/// The session running now, ticking down, or the form to start one.
class SessionCard extends ConsumerStatefulWidget {
  const SessionCard({super.key, required this.session, required this.prefs});

  final FocusSession session;
  final FocusPrefs prefs;

  @override
  ConsumerState<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<SessionCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(SessionCard old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Ticks once a second while a session runs, and not otherwise.
  void _syncTicker() {
    final running = widget.session.runningAt(DateTime.now());
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!widget.session.runningAt(DateTime.now())) {
          _tick?.cancel();
          _tick = null;
        }
        setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: widget.session.runningAt(now)
          ? _RunningSession(
              key: const ValueKey('running'),
              session: widget.session,
              now: now,
            )
          : _StartForm(key: const ValueKey('start'), prefs: widget.prefs),
    );
  }
}

class _RunningSession extends ConsumerWidget {
  const _RunningSession({super.key, required this.session, required this.now});

  final FocusSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = session.remainingAt(now);
    final total = session.length.inMilliseconds;
    final progress = total <= 0 ? 0.0 : left.inMilliseconds / total;
    final repo = ref.read(focusRepositoryProvider);
    final here = ref.watch(deviceKindProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, Gap.l, Gap.l),
        child: Column(
          children: [
            SizedBox.square(
              dimension: 220,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  track: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _clock(left),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'left',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.l),
            Text(
              'Until ${formatTime(context, session.endsAt!.toLocal())}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              [
                _where(session.target),
                if (session.startedBy.isNotEmpty)
                  'started on ${session.startedBy}',
              ].join(', '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (!session.target.includes(here)) ...[
              const SizedBox(height: Gap.xs),
              Text(
                'Nothing is blocked on this ${here == DeviceKind.phone ? 'phone' : 'laptop'}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: Gap.l),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gap.m,
              runSpacing: Gap.s,
              children: [
                OutlinedButton.icon(
                  onPressed: () => repo.extend(const Duration(minutes: 5)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('5 min'),
                ),
                if (!session.strict)
                  FilledButton.tonalIcon(
                    onPressed: repo.stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop'),
                  ),
              ],
            ),
            if (session.strict) ...[
              const SizedBox(height: Gap.s),
              Text(
                'Strict session: it runs to the end.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _clock(Duration d) {
    final s = d.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return h > 0 ? '$h:${two(m)}:${two(s % 60)}' : '${two(m)}:${two(s % 60)}';
  }

  static String _where(FocusTarget t) => switch (t) {
    FocusTarget.both => 'On phone and laptop',
    FocusTarget.phone => 'On the phone',
    FocusTarget.laptop => 'On the laptop',
  };
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
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
      old.progress != progress || old.track != track || old.color != color;
}

class _StartForm extends ConsumerWidget {
  const _StartForm({super.key, required this.prefs});

  final FocusPrefs prefs;

  static const _presets = [15, 25, 45, 60, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repo = ref.read(focusRepositoryProvider);
    final paired = ref.watch(syncApiProvider) != null;
    void save(FocusPrefs p) => repo.savePrefs(p);
    void setMinutes(int m) => save(prefs.copyWith(minutes: m.clamp(5, 240)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: prefs.minutes > 5
                      ? () => setMinutes(prefs.minutes - 5)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: '5 minutes less',
                ),
                SizedBox(
                  width: 150,
                  child: Column(
                    children: [
                      Text(
                        '${prefs.minutes}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'minutes',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: prefs.minutes < 240
                      ? () => setMinutes(prefs.minutes + 5)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: '5 minutes more',
                ),
              ],
            ),
            const SizedBox(height: Gap.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gap.s,
              children: [
                for (final m in _presets)
                  ChoiceChip(
                    label: Text('$m'),
                    selected: prefs.minutes == m,
                    onSelected: (_) => setMinutes(m),
                  ),
              ],
            ),
            if (paired) ...[
              const SizedBox(height: Gap.l),
              SegmentedButton<FocusTarget>(
                segments: const [
                  ButtonSegment(
                    value: FocusTarget.both,
                    icon: Icon(Icons.devices_rounded),
                    label: Text('Both'),
                  ),
                  ButtonSegment(
                    value: FocusTarget.phone,
                    icon: Icon(Icons.smartphone_rounded),
                    label: Text('Phone'),
                  ),
                  ButtonSegment(
                    value: FocusTarget.laptop,
                    icon: Icon(Icons.laptop_rounded),
                    label: Text('Laptop'),
                  ),
                ],
                selected: {prefs.target},
                onSelectionChanged: (s) =>
                    save(prefs.copyWith(target: s.first)),
              ),
            ],
            const SizedBox(height: Gap.s),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Block distractions'),
              subtitle: const Text("The apps and sites on each device's list"),
              value: prefs.blockApps,
              onChanged: (v) => save(prefs.copyWith(blockApps: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Do Not Disturb on the phone'),
              value: prefs.quiet,
              onChanged: (v) => save(prefs.copyWith(quiet: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Strict'),
              subtitle: const Text(
                'No stopping early, and blocked programs close',
              ),
              value: prefs.strict,
              onChanged: (v) => save(prefs.copyWith(strict: v)),
            ),
            const SizedBox(height: Gap.m),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => repo.start(
                length: Duration(minutes: prefs.minutes),
                target: paired ? prefs.target : FocusTarget.both,
                blockApps: prefs.blockApps,
                quiet: prefs.quiet,
                strict: prefs.strict,
                startedBy: ref.read(deviceNameProvider),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start focus'),
            ),
          ],
        ),
      ),
    );
  }
}
