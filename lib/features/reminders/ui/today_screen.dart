import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/motion/animated_sliver_list.dart';
import '../../../core/motion/transitions.dart';
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
    final open = a.today.where((i) => !i.isDone).toList();
    final done = a.today.where((i) => i.isDone).toList();
    // A tile on its way out of a list shows the reminder as it is now, so
    // one that was ticked off closes up with its tick.
    final latest = {
      for (final i in a.overdue.followedBy(a.today)) i.occurrenceId: i,
    };

    // Every part is always there, shown or not, so each can animate in
    // and out as the day's reminders change.
    Widget header(String title, bool visible, {Color? color}) =>
        SliverToBoxAdapter(
          child: Appear(
            visible: visible,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.s),
              child: SectionHeader(title, color: color),
            ),
          ),
        );
    Widget list(List<AgendaItem> items) =>
        _ItemList(items: items, latest: latest, now: now);

    return [
      SliverToBoxAdapter(
        child: Appear(
          visible: a.today.isEmpty && a.overdue.isEmpty,
          child: EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: 'A clear day',
            message: a.upcoming.isEmpty
                ? 'Add your first study reminder above. Try "Maths every day 6pm".'
                : 'Nothing today. Your next reminder is ${formatDay(a.upcoming.first.date, a.todayDate).toLowerCase()}.',
          ),
        ),
      ),
      header('OVERDUE', a.overdue.isNotEmpty, color: scheme.error),
      list(a.overdue),
      header('TODAY', open.isNotEmpty),
      list(open),
      header('DONE', done.isNotEmpty),
      list(done),
    ];
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.latest,
    required this.now,
  });

  final List<AgendaItem> items;

  /// Every reminder on the page by its occurrence, as it is now.
  final Map<String, AgendaItem> latest;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.s),
      sliver: AnimatedSliverList<AgendaItem>(
        items: items,
        idOf: (item) => item.occurrenceId,
        itemBuilder: (context, item) =>
            ReminderTile(item: latest[item.occurrenceId] ?? item, now: now),
      ),
    );
  }
}
