import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/formatters.dart';
import '../../alerts/ui/alert_health.dart';
import '../application/reminder_providers.dart';
import '../domain/agenda.dart';
import 'widgets/quick_add_bar.dart';
import 'widgets/reminder_tile.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.quickAddFocus});

  final FocusNode? quickAddFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = ref.watch(minuteTickProvider).value ?? DateTime.now();
    final agenda = ref.watch(agendaProvider);

    return SafeArea(
      bottom: false,
      child: PageBody(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, Gap.l, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(now).toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      greetingFor(now),
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      _summary(agenda.value),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Gap.l),
                    QuickAddBar(focusNode: quickAddFocus),
                    const AlertPermissionBanner(),
                  ],
                ),
              ),
            ),
            ...agenda.when(
              loading: () => [
                const SliverToBoxAdapter(child: SizedBox.shrink()),
              ],
              error: (e, _) => [
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load reminders',
                    message: '$e',
                  ),
                ),
              ],
              data: (a) => _lists(context, a, now),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  String _summary(Agenda? a) {
    if (a == null) return ' ';
    final open = a.openToday;
    final overdue = a.overdue.length;
    if (open == 0 && overdue == 0) {
      return a.today.isEmpty
          ? 'Nothing planned for today yet.'
          : 'All done for today. Nice work.';
    }
    final parts = <String>[
      if (open > 0) '$open left today',
      if (overdue > 0) '$overdue overdue',
    ];
    return parts.join(' · ');
  }

  List<Widget> _lists(BuildContext context, Agenda a, DateTime now) {
    final scheme = Theme.of(context).colorScheme;
    if (a.today.isEmpty && a.overdue.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: 'A clear day',
            message: a.upcoming.isEmpty
                ? 'Add your first study reminder above. Try "Maths every day 6pm".'
                : 'Nothing today. Your next reminder is ${formatDay(a.upcoming.first.date, a.todayDate).toLowerCase()}.',
          ),
        ),
      ];
    }

    final open = a.today.where((i) => !i.isDone).toList();
    final done = a.today.where((i) => i.isDone).toList();

    return [
      if (a.overdue.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s),
            child: SectionHeader('OVERDUE', color: scheme.error),
          ),
        ),
        _ItemList(items: a.overdue, now: now),
      ],
      if (open.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Gap.s),
            child: SectionHeader('TODAY'),
          ),
        ),
        _ItemList(items: open, now: now),
      ],
      if (done.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Gap.s),
            child: SectionHeader('DONE'),
          ),
        ),
        _ItemList(items: done, now: now),
      ],
    ];
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.now});

  final List<AgendaItem> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.s),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => ReminderTile(
          key: ValueKey(items[i].occurrenceId),
          item: items[i],
          now: now,
        ),
      ),
    );
  }
}
