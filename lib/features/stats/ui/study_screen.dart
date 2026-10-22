import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/formatters.dart';
import '../../../core/ui/minutes_dialog.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/recurrence.dart';
import '../../subjects/ui/subject_editor.dart';
import '../../subjects/ui/subjects_screen.dart';
import '../application/study_providers.dart';
import '../domain/study_session.dart';
import '../domain/study_stats.dart';

/// How the studying goes: this week's focus time by day and by subject, the
/// streak, the latest sessions, and the subjects themselves.
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Counts up while a session runs, and not otherwise.
  void _syncTicker(List<StudySession> sessions, DateTime now) {
    final running = sessions.any(
      (s) => !s.deleted && s.endedAt.isAfter(now) && !s.startedAt.isAfter(now),
    );
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final sessions = ref.watch(studySessionsProvider).value ?? const [];
    final goal = ref.watch(studyGoalProvider).value ?? 25;
    _syncTicker(sessions, now);
    final stats = StudyStats.compute(
      sessions,
      now: now,
      goal: Duration(minutes: goal),
    );
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final week = _WeekCard(stats: stats, now: now);
    final streak = _StreakCard(stats: stats, now: now);

    return SafeArea(
      bottom: false,
      child: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, Gap.l, 96),
          children: [
            Text('Study', style: theme.textTheme.headlineMedium),
            const SizedBox(height: Gap.l),
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: week),
                    const SizedBox(width: Gap.m),
                    Expanded(flex: 2, child: streak),
                  ],
                ),
              )
            else ...[
              week,
              const SizedBox(height: Gap.m),
              streak,
            ],
            SectionHeader(
              'SUBJECTS',
              trailing: TextButton.icon(
                onPressed: () => showSubjectEditor(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ),
            SubjectsSection(studied: stats.bySubject),
            if (sessions.any((s) => s.countsAt(now))) ...[
              const SectionHeader('RECENT SESSIONS'),
              _RecentSessions(
                sessions: sessions
                    .where((s) => s.countsAt(now))
                    .take(8)
                    .toList(),
                now: now,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.stats, required this.now});

  final StudyStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final diff = stats.week - stats.lastWeek;
    final compare = stats.lastWeek == Duration.zero
        ? (stats.week == Duration.zero
              ? 'Start a focus session to see it here'
              : 'Your first week of focus here')
        : diff.inMinutes == 0
        ? 'Same as last week'
        : diff.isNegative
        ? '${formatStudyTime(-diff)} less than last week'
        : '${formatStudyTime(diff)} more than last week';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              formatStudyTime(stats.week),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              compare,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.l),
            _WeekBars(stats: stats, now: now),
          ],
        ),
      ),
    );
  }
}

/// A bar per day, with the daily goal as a line.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.stats, required this.now});

  final StudyStats stats;
  final DateTime now;

  static const _height = 112.0;

  /// The tallest bar, with room above it for its time.
  static const _barMax = _height - 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateTime(now.year, now.month, now.day);
    final most = stats.days.fold(Duration.zero, (a, b) => a > b ? a : b);
    // Up to the goal, unless that would leave the bars too small to see:
    // then up to the busiest day, and the goal line is left out.
    final showGoal = most * 3 >= stats.goal;
    final top = showGoal
        ? (most > stats.goal ? most : stats.goal)
        : (most * 1.3 > const Duration(minutes: 30)
              ? most * 1.3
              : const Duration(minutes: 30));
    final goalAt = top == Duration.zero || !showGoal
        ? 0.0
        : _barMax * stats.goal.inSeconds / top.inSeconds;

    return SizedBox(
      height: _height + 24,
      child: Stack(
        children: [
          if (showGoal)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24 + goalAt,
              child: Container(
                height: 1,
                color: scheme.tertiary.withValues(alpha: 0.6),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _DayBar(
                    day: DateTime(
                      stats.weekStart.year,
                      stats.weekStart.month,
                      stats.weekStart.day + i,
                    ),
                    studied: stats.days[i],
                    goal: stats.goal,
                    height: top == Duration.zero
                        ? 0
                        : _barMax * stats.days[i].inSeconds / top.inSeconds,
                    today: today,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.studied,
    required this.goal,
    required this.height,
    required this.today,
  });

  final DateTime day;
  final Duration studied;
  final Duration goal;
  final double height;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = day == today;
    final met = studied >= goal && goal > Duration.zero;
    final name = weekdayShortNames[day.weekday - 1];
    return Tooltip(
      message: '$name: ${formatStudyTime(studied)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (studied >= const Duration(minutes: 1))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                _short(studied),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 22,
            height: studied > Duration.zero ? height.clamp(4.0, 200.0) : 4,
            decoration: BoxDecoration(
              color: studied == Duration.zero
                  ? scheme.surfaceContainerHighest
                  : met
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: Gap.xs),
          SizedBox(
            height: 20,
            child: Text(
              name.substring(0, 1),
              style: theme.textTheme.labelMedium?.copyWith(
                color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "8m", "1h", "1h20": short enough to sit above a bar.
String _short(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '${m}m';
  final rest = m % 60;
  return rest == 0
      ? '${m ~/ 60}h'
      : '${m ~/ 60}h${rest.toString().padLeft(2, '0')}';
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard({required this.stats, required this.now});

  final StudyStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Rounded, as a week with a clock change has a 23 or 25 hour day.
    final todayIndex =
        (DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).difference(stats.weekStart).inHours /
                24)
            .round()
            .clamp(0, 6);
    final today = stats.days[todayIndex];
    final goal = stats.goal;
    final progress = goal == Duration.zero
        ? 0.0
        : (today.inSeconds / goal.inSeconds).clamp(0.0, 1.0);
    final streak = stats.streak;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: streak > 0
                      ? scheme.tertiary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: Gap.s),
                Text(
                  streak == 1 ? '1 day' : '$streak days',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            Text(
              stats.bestStreak > streak
                  ? 'In a row. Best: ${stats.bestStreak} days'
                  : streak > 0
                  ? 'In a row, your best yet'
                  : 'Meet your daily goal to start a streak',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.l),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Today ${formatStudyTime(today)} of ${formatStudyTime(goal)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (progress >= 1)
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
              ],
            ),
            const SizedBox(height: Gap.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: Gap.s),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                ),
                onPressed: () => _pickGoal(context, ref, goal.inMinutes),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Daily goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _goals = [15, 25, 45, 60, 90, 120, 180];

  Future<void> _pickGoal(BuildContext context, WidgetRef ref, int current) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily goal', style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: Gap.xs),
              Text(
                'A day counts towards your streak once you focus this long.',
                style: Theme.of(sheet).textTheme.bodyMedium,
              ),
              const SizedBox(height: Gap.m),
              Wrap(
                spacing: Gap.s,
                runSpacing: Gap.xs,
                children: [
                  for (final m in _goals)
                    ChoiceChip(
                      label: Text(formatStudyTime(Duration(minutes: m))),
                      selected: m == current,
                      onSelected: (_) {
                        ref.read(studyRepositoryProvider).saveGoalMinutes(m);
                        Navigator.of(sheet).pop();
                      },
                    ),
                  ChoiceChip(
                    avatar: _goals.contains(current)
                        ? const Icon(Icons.edit_outlined)
                        : null,
                    label: Text(
                      _goals.contains(current)
                          ? 'Other'
                          : formatStudyTime(Duration(minutes: current)),
                    ),
                    selected: !_goals.contains(current),
                    onSelected: (_) async {
                      final m = await showMinutesDialog(
                        sheet,
                        title: 'Daily goal',
                        initial: current,
                        min: 5,
                        max: 600,
                        help: 'In minutes: 90 is 1 h 30 min',
                      );
                      if (m == null) return;
                      await ref
                          .read(studyRepositoryProvider)
                          .saveGoalMinutes(m);
                      if (sheet.mounted) Navigator.of(sheet).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _RecentSessions extends ConsumerWidget {
  const _RecentSessions({required this.sessions, required this.now});

  final List<StudySession> sessions;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subjects = ref.watch(subjectsByIdProvider);
    final today = DateTime(now.year, now.month, now.day);
    return Card(
      child: Column(
        children: [
          for (final (i, s) in sessions.indexed) ...[
            if (i > 0) const Divider(indent: Gap.l, endIndent: Gap.l),
            Builder(
              builder: (context) {
                final subject = subjects[s.subjectId];
                final start = s.startedAt.toLocal();
                final day = DateTime(start.year, start.month, start.day);
                final dayLabel = day == today
                    ? 'Today'
                    : day == DateTime(today.year, today.month, today.day - 1)
                    ? 'Yesterday'
                    : DateFormat('EEE d MMM').format(start);
                final focused = s.focusedUntil(now);
                final running = s.endedAt.isAfter(now);
                return ListTile(
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: subject == null
                          ? scheme.outline
                          : Color(subject.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  minLeadingWidth: 10,
                  title: Text(subject?.name ?? 'Focus'),
                  subtitle: Text(
                    [
                      '$dayLabel, ${formatTime(context, start)}',
                      if (s.plan.rounds > 1) '${s.plan.rounds} rounds',
                      if (s.resumed) 'after a pause',
                      if (running) 'running',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatStudyTime(focused),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (!running)
                        IconButton(
                          tooltip: 'Remove from stats',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            final repo = ref.read(studyRepositoryProvider);
                            repo.delete(s.id);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Removed from your stats',
                                  ),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () => repo.restore(s.id),
                                  ),
                                ),
                              );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
