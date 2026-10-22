import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/formatters.dart';
import '../../application/reminder_providers.dart';
import '../../domain/agenda.dart';
import '../../domain/occurrence.dart';
import '../../domain/reminder.dart';
import '../reminder_actions.dart';
import '../reminder_editor.dart';

enum _Menu { snooze5, snooze10, snooze30, snooze60, skip, edit, delete }

/// One occurrence in a list: check circle, title, details and time.
///
/// On phones, swipe right to mark done and left to snooze 10 minutes.
class ReminderTile extends ConsumerWidget {
  const ReminderTile({super.key, required this.item, required this.now});

  final AgendaItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reminder = item.reminder;
    final subject = reminder.subjectId == null
        ? null
        : ref.watch(subjectsByIdProvider)[reminder.subjectId];
    final accent = subject != null ? Color(subject.color) : scheme.primary;
    final missed = item.isMissed(now);
    final done = item.isDone;
    final status = statusLabel(item, now, (t) => formatTime(context, t));
    final upcomingSoon =
        !done && !missed && item.dueAt.difference(now).inMinutes < 120;

    final details = <Widget>[
      if (reminder.recurrence.repeats)
        _Meta(icon: Icons.repeat_rounded, text: reminder.recurrence.describe()),
      if (reminder.style == ReminderStyle.alarm)
        const _Meta(icon: Icons.alarm_rounded, text: 'Alarm'),
      if (reminder.deliverTo != DeliveryTarget.everywhere)
        _Meta(
          icon: reminder.deliverTo == DeliveryTarget.phone
              ? Icons.smartphone_rounded
              : Icons.laptop_rounded,
          text: reminder.deliverTo == DeliveryTarget.phone ? 'Phone' : 'Laptop',
        ),
      if (subject != null) _SubjectTag(name: subject.name, color: accent),
    ];

    Widget tile = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.m),
        onTap: () => openReminderEditor(context, existing: reminder),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.s, Gap.m, Gap.xs, Gap.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CheckCircle(
                done: done,
                color: accent,
                tooltip: done ? 'Mark as not done' : 'Mark as done',
                onTap: () => toggleDone(ref, item),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: Gap.xs),
                      Wrap(
                        spacing: Gap.m,
                        runSpacing: Gap.xs,
                        children: details,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTime(context, item.at),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: missed
                          ? scheme.error
                          : done
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  if (status.isNotEmpty || upcomingSoon)
                    Text(
                      status.isNotEmpty
                          ? status
                          : formatRelative(item.dueAt, now),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: missed ? scheme.error : scheme.primary,
                      ),
                    ),
                ],
              ),
              _MoreMenu(item: item),
            ],
          ),
        ),
      ),
    );

    if (!isWide(context)) {
      tile = Dismissible(
        key: ValueKey('swipe-${item.occurrenceId}'),
        background: _SwipeBackground(
          color: scheme.primaryContainer,
          icon: done ? Icons.undo_rounded : Icons.check_rounded,
          label: done ? 'Undo' : 'Done',
          alignment: Alignment.centerLeft,
          foreground: scheme.onPrimaryContainer,
        ),
        secondaryBackground: _SwipeBackground(
          color: scheme.tertiaryContainer,
          icon: Icons.snooze_rounded,
          label: '10 min',
          alignment: Alignment.centerRight,
          foreground: scheme.onTertiaryContainer,
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await toggleDone(ref, item);
          } else if (!done) {
            await snoozeItem(ref, item, const Duration(minutes: 10));
          }
          return false; // the list updates itself; keep the tile in place
        },
        child: tile,
      );
    }
    return tile;
  }
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.item});
  final AgendaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_Menu>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (choice) {
        switch (choice) {
          case _Menu.snooze5:
            snoozeItem(ref, item, snoozeChoices[0]);
          case _Menu.snooze10:
            snoozeItem(ref, item, snoozeChoices[1]);
          case _Menu.snooze30:
            snoozeItem(ref, item, snoozeChoices[2]);
          case _Menu.snooze60:
            snoozeItem(ref, item, snoozeChoices[3]);
          case _Menu.skip:
            skipItem(ref, item);
          case _Menu.edit:
            openReminderEditor(context, existing: item.reminder);
          case _Menu.delete:
            deleteReminder(context, ref, item.reminder.id, item.reminder.title);
        }
      },
      itemBuilder: (context) => [
        if (!item.isDone) ...[
          for (final (i, d) in snoozeChoices.indexed)
            PopupMenuItem(
              value: _Menu.values[i],
              child: ListTile(
                leading: const Icon(Icons.snooze_rounded),
                title: Text('Snooze ${snoozeLabel(d)}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (item.status != OccurrenceStatus.skipped)
            const PopupMenuItem(
              value: _Menu.skip,
              child: ListTile(
                leading: Icon(Icons.redo_rounded),
                title: Text('Skip this time'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: _Menu.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: _Menu.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Delete'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.done,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final bool done;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 26,
          height: 26,
          margin: const EdgeInsets.all(Gap.s),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    key: ValueKey(true),
                    size: 18,
                    color: Colors.white,
                  )
                : const SizedBox.shrink(key: ValueKey(false)),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(text, style: theme.textTheme.labelMedium?.copyWith(color: color)),
      ],
    );
  }
}

class _SubjectTag extends StatelessWidget {
  const _SubjectTag({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          name,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
    required this.foreground,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: Gap.s),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
