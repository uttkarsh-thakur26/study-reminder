import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/formatters.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../subjects/domain/subject.dart';
import '../../sync/application/sync_providers.dart';
import '../application/focus_providers.dart';
import '../domain/focus_plan.dart';
import '../domain/focus_prefs.dart';
import '../domain/focus_session.dart';
import 'focus_setup.dart';

/// Start a focus session on this device, the paired one or both, follow
/// the ones running, and set up what each device blocks.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions =
        ref.watch(focusSessionsProvider).value ?? FocusSessions.idle;
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
            SessionCard(sessions: sessions, prefs: prefs),
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

/// The sessions running now, ticking down, and the form to start one where
/// none runs. This device's session, or the form, is shown large; the
/// other device's is a line above it.
class SessionCard extends ConsumerStatefulWidget {
  const SessionCard({super.key, required this.sessions, required this.prefs});

  final FocusSessions sessions;
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
    bool running() => widget.sessions.busyAt(DateTime.now()).isNotEmpty;
    if (running() && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!running()) {
          _tick?.cancel();
          _tick = null;
        }
        setState(() {});
      });
    } else if (!running()) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sessions = widget.sessions;
    final here = ref.watch(deviceKindProvider);
    final paired = ref.watch(syncApiProvider) != null;
    final busy = sessions.busyAt(now);
    final groups = <Set<DeviceKind>>[
      if (busy.length == 2 && sessions.phone.sameAs(sessions.laptop))
        busy
      else
        for (final k in busy) {k},
    ];
    final mine = groups.where((g) => g.contains(here)).firstOrNull;
    final free = (paired ? DeviceKind.values.toSet() : {here}).difference(busy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups)
          if (g != mine)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.m),
              child: _RunningSession(
                key: ValueKey('running ${g.map((k) => k.name).join()}'),
                session: sessions.of(g.first),
                on: g,
                now: now,
                compact: true,
              ),
            ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: mine != null
              ? _RunningSession(
                  key: ValueKey('running ${mine.map((k) => k.name).join()}'),
                  session: sessions.of(here),
                  on: mine,
                  now: now,
                )
              : _StartForm(
                  key: const ValueKey('start'),
                  prefs: widget.prefs,
                  free: free,
                ),
        ),
        if (mine != null && free.isNotEmpty) ...[
          const SizedBox(height: Gap.m),
          _StartElsewhere(free: free),
        ],
      ],
    );
  }
}

IconData _icon(Set<DeviceKind> on) => on.length > 1
    ? Icons.devices_rounded
    : on.single == DeviceKind.phone
    ? Icons.smartphone_rounded
    : Icons.laptop_rounded;

/// "the laptop", "this phone", or both.
String _devices(Set<DeviceKind> on, DeviceKind here) {
  if (on.length > 1) return 'phone and laptop';
  final k = on.single;
  final name = k == DeviceKind.phone ? 'phone' : 'laptop';
  return k == here ? 'this $name' : 'the $name';
}

class _RunningSession extends ConsumerWidget {
  const _RunningSession({
    super.key,
    required this.session,
    required this.on,
    required this.now,
    this.compact = false,
  });

  final FocusSession session;

  /// The devices it runs on, started together.
  final Set<DeviceKind> on;
  final DateTime now;

  /// One line, for the other device's session.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phase = session.phaseAt(now) ?? session.plan.phaseAt(now);
    final rounds = phase.rounds > 1;
    // With rounds, the clock and the ring follow the round or break.
    final left = rounds
        ? phase.endsAt.difference(now)
        : session.remainingAt(now);
    final total = (rounds ? phase.length : session.length).inMilliseconds;
    final progress = total <= 0
        ? 0.0
        : (left.inMilliseconds / total).clamp(0.0, 1.0);
    final repo = ref.read(focusRepositoryProvider);
    final here = ref.watch(deviceKindProvider);
    final until = formatTime(context, session.endsAt!.toLocal());
    final phaseEnd = formatTime(context, phase.endsAt.toLocal());
    final where = _devices(on, here);
    final subject = ref.watch(subjectsByIdProvider)[session.subjectId];
    Widget ring(double size, Widget child) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          track: scheme.surfaceContainerHighest,
          color: phase.onBreak ? scheme.tertiary : scheme.primary,
          stroke: size / 18,
        ),
        child: Center(child: child),
      ),
    );
    final clock = _clock(left.isNegative ? Duration.zero : left);

    if (compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.s, Gap.m),
          child: Row(
            children: [
              ring(56, Icon(_icon(on), size: 22, color: scheme.primary)),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      on.length > 1
                          ? 'Phone and laptop'
                          : on.single == DeviceKind.phone
                          ? 'Phone'
                          : 'Laptop',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      [
                        if (phase.onBreak)
                          'break, $clock left'
                        else
                          '$clock left',
                        if (rounds) 'round ${phase.round} of ${phase.rounds}',
                        if (subject != null) subject.name,
                        'until $until',
                        if (session.strict) 'strict',
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => repo.extend(on, const Duration(minutes: 5)),
                icon: const Icon(Icons.more_time_rounded),
                tooltip: '5 minutes more on $where',
              ),
              if (!session.strict)
                IconButton(
                  onPressed: () => repo.stop(on),
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: 'Stop on $where',
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, Gap.l, Gap.l),
        child: Column(
          children: [
            ring(
              220,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clock,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    !rounds
                        ? 'left'
                        : phase.onBreak
                        ? 'break'
                        : 'round ${phase.round} of ${phase.rounds}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (rounds) ...[
              const SizedBox(height: Gap.m),
              _RoundDots(phase: phase),
            ],
            const SizedBox(height: Gap.l),
            Text(
              !rounds || phase.isLastRound && !phase.onBreak
                  ? 'Until $until'
                  : phase.onBreak
                  ? 'Back to focus at $phaseEnd'
                  : 'Break at $phaseEnd',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              [
                'On $where',
                if (session.startedBy.isNotEmpty)
                  'started on ${session.startedBy}',
                if (rounds && !phase.isLastRound) 'ends $until',
              ].join(', '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.m),
            _SubjectButton(
              subject: subject,
              onPick: (id) => repo.setSubject(on, id),
            ),
            const SizedBox(height: Gap.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gap.m,
              runSpacing: Gap.s,
              children: [
                OutlinedButton.icon(
                  onPressed: () => repo.extend(on, const Duration(minutes: 5)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('5 min'),
                ),
                if (!session.strict)
                  FilledButton.tonalIcon(
                    onPressed: () => repo.stop(on),
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
}

/// While this device focuses: a way to start the other one too.
class _StartElsewhere extends ConsumerWidget {
  const _StartElsewhere({required this.free});

  final Set<DeviceKind> free;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final here = ref.watch(deviceKindProvider);
    final where = _devices(free, here);
    return Card(
      child: ListTile(
        leading: Icon(_icon(free)),
        title: Text('Focus on $where too'),
        subtitle: const Text('Nothing runs there now'),
        trailing: FilledButton.tonal(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (sheet) => Consumer(
              builder: (context, ref, _) {
                // A session may start there while the sheet is open.
                final sessions =
                    ref.watch(focusSessionsProvider).value ??
                    FocusSessions.idle;
                final stillFree = free.difference(
                  sessions.busyAt(DateTime.now()),
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
                  child: stillFree.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(Gap.l),
                          child: Text(
                            'A session started there meanwhile.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : _StartForm(
                          prefs:
                              ref.watch(focusPrefsProvider).value ??
                              const FocusPrefs(),
                          free: stillFree,
                          flat: true,
                          onStarted: () => Navigator.of(sheet).pop(),
                        ),
                );
              },
            ),
          ),
          child: const Text('Start'),
        ),
      ),
    );
  }
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

class _StartForm extends ConsumerWidget {
  const _StartForm({
    super.key,
    required this.prefs,
    required this.free,
    this.flat = false,
    this.onStarted,
  });

  final FocusPrefs prefs;

  /// The devices with no session running, where this can start one.
  final Set<DeviceKind> free;

  /// Without its card, in a sheet.
  final bool flat;
  final VoidCallback? onStarted;

  static const _presets = [15, 25, 45, 60, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repo = ref.read(focusRepositoryProvider);
    final here = ref.watch(deviceKindProvider);
    final wanted = prefs.target.kinds.intersection(free);
    final on = wanted.isEmpty ? free : wanted;
    void save(FocusPrefs p) => repo.savePrefs(p);
    void setMinutes(int m) => save(prefs.copyWith(minutes: m.clamp(5, 240)));
    final subjects = ref.watch(subjectsProvider).value ?? const <Subject>[];
    final rounds = prefs.rounds;

    final form = Padding(
      padding: flat ? EdgeInsets.zero : const EdgeInsets.all(Gap.l),
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
                      rounds > 1 ? 'minutes a round' : 'minutes',
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
          const SizedBox(height: Gap.m),
          _RoundsPicker(prefs: prefs, onChanged: save),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: Gap.s),
            _SubjectChips(
              subjects: subjects,
              selected: subjects.any((s) => s.id == prefs.subjectId)
                  ? prefs.subjectId
                  : null,
              onSelected: (id) => save(prefs.withSubject(id)),
            ),
          ],
          if (free.length > 1) ...[
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
              onSelectionChanged: (s) => save(prefs.copyWith(target: s.first)),
            ),
          ] else if (ref.watch(syncApiProvider) != null) ...[
            const SizedBox(height: Gap.m),
            Text(
              'On ${_devices(on, here)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
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
          if (on.contains(DeviceKind.phone))
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
            onPressed: () async {
              final subjectGone =
                  prefs.subjectId != null &&
                  !subjects.any((s) => s.id == prefs.subjectId);
              await repo.startWith(
                subjectGone ? prefs.withSubject(null) : prefs,
                on: on,
                startedBy: ref.read(deviceNameProvider),
              );
              onStarted?.call();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start focus'),
          ),
        ],
      ),
    );
    return flat ? form : Card(child: form);
  }
}

/// Rounds per session and the break between two.
class _RoundsPicker extends StatelessWidget {
  const _RoundsPicker({required this.prefs, required this.onChanged});

  final FocusPrefs prefs;
  final ValueChanged<FocusPrefs> onChanged;

  static const _breaks = [5, 10, 15];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rounds = prefs.rounds;
    final end = formatTime(context, DateTime.now().add(prefs.length));
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.s, Gap.s),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text('Rounds', style: theme.textTheme.titleSmall),
              ),
              IconButton(
                onPressed: rounds > 1
                    ? () => onChanged(prefs.copyWith(rounds: rounds - 1))
                    : null,
                icon: const Icon(Icons.remove_rounded),
                tooltip: 'One round less',
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$rounds',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                onPressed: rounds < FocusPrefs.maxRounds
                    ? () => onChanged(prefs.copyWith(rounds: rounds + 1))
                    : null,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'One round more',
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: rounds < 2
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: Gap.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_cafe_outlined,
                              size: 20,
                              color: scheme.tertiary,
                            ),
                            const SizedBox(width: Gap.s),
                            Expanded(
                              child: Text(
                                'Breaks',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            for (final m in _breaks)
                              Padding(
                                padding: const EdgeInsets.only(left: Gap.xs),
                                child: ChoiceChip(
                                  label: Text('$m min'),
                                  selected: prefs.breakMinutes == m,
                                  onSelected: (_) => onChanged(
                                    prefs.copyWith(breakMinutes: m),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: Gap.s),
                        Text(
                          '$rounds rounds of ${prefs.minutes} min with '
                          '${prefs.breakMinutes} min breaks, until $end. '
                          'Nothing is blocked during a break.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// What a session is for, picked from the subjects.
class _SubjectChips extends StatelessWidget {
  const _SubjectChips({
    required this.subjects,
    required this.selected,
    required this.onSelected,
  });

  final List<Subject> subjects;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.s,
      runSpacing: Gap.xs,
      children: [
        ChoiceChip(
          label: const Text('No subject'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final s in subjects)
          ChoiceChip(
            avatar: _Dot(Color(s.color)),
            label: Text(s.name),
            selected: selected == s.id,
            onSelected: (_) => onSelected(s.id),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// The running session's subject, tap to change it.
class _SubjectButton extends ConsumerWidget {
  const _SubjectButton({required this.subject, required this.onPick});

  final Subject? subject;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider).value ?? const <Subject>[];
    if (subjects.isEmpty) return const SizedBox.shrink();
    final current = subject;
    return ActionChip(
      avatar: current == null
          ? const Icon(Icons.menu_book_outlined, size: 18)
          : _Dot(Color(current.color)),
      label: Text(current?.name ?? 'Add a subject'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What are you studying?',
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
              const SizedBox(height: Gap.m),
              _SubjectChips(
                subjects: subjects,
                selected: current?.id,
                onSelected: (id) {
                  onPick(id);
                  Navigator.of(sheet).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One dot per round: done, running and still to come.
class _RoundDots extends StatelessWidget {
  const _RoundDots({required this.phase});

  final FocusPhase phase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: phase.onBreak
          ? 'Break after round ${phase.round} of ${phase.rounds}'
          : 'Round ${phase.round} of ${phase.rounds}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= phase.rounds; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == phase.round && !phase.onBreak ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i < phase.round || (i == phase.round && phase.onBreak)
                    ? scheme.primary
                    : i == phase.round
                    ? scheme.primary.withValues(alpha: 0.6)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
