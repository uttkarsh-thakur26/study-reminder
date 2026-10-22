import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/calendar_date.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/formatters.dart';
import '../application/reminder_providers.dart';
import '../domain/agenda.dart';
import '../domain/recurrence.dart';
import 'widgets/reminder_tile.dart';

class UpcomingScreen extends ConsumerStatefulWidget {
  const UpcomingScreen({super.key});

  @override
  ConsumerState<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends ConsumerState<UpcomingScreen> {
  final _dayKeys = <CalendarDate, GlobalKey>{};

  void _jumpTo(CalendarDate day) {
    final ctx = _dayKeys[day]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = ref.watch(minuteTickProvider).value ?? DateTime.now();
    final agenda = ref.watch(agendaProvider);

    return SafeArea(
      bottom: false,
      child: PageBody(
        child: agenda.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load reminders',
            message: '$e',
          ),
          data: (a) {
            final days = [AgendaDay(a.todayDate, a.today), ...a.upcoming];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.l,
                    Gap.xl,
                    Gap.l,
                    Gap.s,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Upcoming',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _WeekStrip(
                    today: a.todayDate,
                    counts: {
                      for (final d in days)
                        d.date: d.items.where((i) => !i.isDone).length,
                    },
                    onTap: _jumpTo,
                  ),
                ),
                if (a.upcoming.isEmpty && a.today.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.event_available_rounded,
                      title: 'Nothing coming up',
                      message: 'Reminders for the next two weeks show here.',
                    ),
                  ),
                for (final day in days)
                  if (day.items.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      key: _dayKeys.putIfAbsent(day.date, GlobalKey.new),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                        child: SectionHeader(
                          formatDay(day.date, a.todayDate).toUpperCase(),
                          // Today and Tomorrow also get the date itself.
                          trailing: a.todayDate.daysUntil(day.date) <= 1
                              ? Text(
                                  '${weekdayShortNames[day.date.weekday - 1]}, ${DateFormat('d MMM').format(DateTime(day.date.year, day.date.month, day.date.day))}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                      sliver: SliverList.builder(
                        itemCount: day.items.length,
                        itemBuilder: (context, i) => ReminderTile(
                          key: ValueKey(day.items[i].occurrenceId),
                          item: day.items[i],
                          now: now,
                        ),
                      ),
                    ),
                  ],
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Two weeks of day pills; a dot shows how many open reminders each has.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.today,
    required this.counts,
    required this.onTap,
  });

  final CalendarDate today;
  final Map<CalendarDate, int> counts;
  final ValueChanged<CalendarDate> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.s),
        scrollDirection: Axis.horizontal,
        itemCount: Agenda.horizonDays + 1,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.s),
        itemBuilder: (context, i) {
          final day = today.addDays(i);
          final count = counts[day] ?? 0;
          final isToday = i == 0;
          return Material(
            color: isToday ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Radii.m),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.m),
              onTap: count > 0 ? () => onTap(day) : null,
              child: SizedBox(
                width: 52,
                // Shrinks rather than overflows with large text sizes.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekdayShortNames[day.weekday - 1],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isToday
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isToday ? scheme.onPrimary : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: count == 0
                              ? Colors.transparent
                              : (isToday ? scheme.onPrimary : scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
