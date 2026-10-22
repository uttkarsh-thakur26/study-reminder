import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/calendar_date.dart';
import '../../../../core/ui/formatters.dart';
import '../../../subjects/domain/subject.dart';
import '../../application/reminder_providers.dart';
import '../../domain/quick_add_parser.dart';
import '../../domain/recurrence.dart';
import '../../domain/reminder.dart';
import '../reminder_editor.dart';

/// Type a reminder in plain words and press Enter.
///
/// Shows what it understood (day, time, repeat, alarm, subject) as you type.
class QuickAddBar extends ConsumerStatefulWidget {
  const QuickAddBar({super.key, this.focusNode});

  final FocusNode? focusNode;

  @override
  ConsumerState<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends ConsumerState<QuickAddBar> {
  final _controller = TextEditingController();
  QuickAddResult? _parsed;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {
      _parsed = text.trim().isEmpty
          ? null
          : parseQuickAdd(text, now: DateTime.now());
    });
  }

  Subject? _matchSubject(String? tag, List<Subject> subjects) {
    if (tag == null) return null;
    final t = tag.toLowerCase();
    for (final s in subjects) {
      if (s.name.toLowerCase().startsWith(t)) return s;
    }
    return null;
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final parsed = parseQuickAdd(text, now: now);
    if (parsed.title.isEmpty) {
      await openReminderEditor(context, prefill: parsed);
      return;
    }
    final start = resolveStart(parsed, now: now);
    final subjects = ref.read(subjectsProvider).value ?? const <Subject>[];
    final reminder = Reminder(
      id: const Uuid().v4(),
      title: parsed.title,
      style: parsed.style,
      subjectId: _matchSubject(parsed.subjectTag, subjects)?.id,
      createdAt: now.toUtc(),
      schedule: ReminderSchedule(
        anchor: start.date,
        minuteOfDay: start.minuteOfDay,
        timeZone: ref.read(deviceTimeZoneProvider),
        recurrence: parsed.recurrence,
      ),
    );
    final repo = ref.read(reminderRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final when = _whenLabel(
      context,
      start.date,
      start.minuteOfDay,
      parsed.recurrence,
    );
    await repo.save(reminder);
    if (!mounted) return;
    _controller.clear();
    setState(() => _parsed = null);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Added for $when'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.delete(reminder.id),
          ),
        ),
      );
  }

  String _whenLabel(
    BuildContext context,
    CalendarDate date,
    int minute,
    Recurrence r,
  ) {
    final today = CalendarDate.fromDateTime(DateTime.now());
    final time = formatMinuteOfDay(context, minute);
    if (r.repeats) return '${r.describe()} at $time';
    final day = formatDay(date, today);
    final dayText = day == 'Today' || day == 'Tomorrow'
        ? day.toLowerCase()
        : day;
    return '$dayText at $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parsed = _parsed;
    final subjects = ref.watch(subjectsProvider).value ?? const <Subject>[];

    final chips = <Widget>[];
    if (parsed != null) {
      final now = DateTime.now();
      final start = resolveStart(parsed, now: now);
      final today = CalendarDate.fromDateTime(now);
      if (parsed.recurrence.repeats) {
        chips.add(
          _PreviewChip(Icons.repeat_rounded, parsed.recurrence.describe()),
        );
      } else {
        chips.add(
          _PreviewChip(Icons.event_rounded, formatDay(start.date, today)),
        );
      }
      chips.add(
        _PreviewChip(
          Icons.schedule_rounded,
          formatMinuteOfDay(context, start.minuteOfDay),
        ),
      );
      if (parsed.style == ReminderStyle.alarm) {
        chips.add(const _PreviewChip(Icons.alarm_rounded, 'Alarm'));
      }
      final subject = _matchSubject(parsed.subjectTag, subjects);
      if (subject != null) {
        chips.add(
          _PreviewChip(
            Icons.circle,
            subject.name,
            iconColor: Color(subject.color),
          ),
        );
      } else if (parsed.subjectTag != null) {
        chips.add(
          _PreviewChip(
            Icons.help_outline_rounded,
            'No subject "${parsed.subjectTag}"',
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Add a reminder, e.g. "Physics revision tomorrow 7pm"',
            prefixIcon: Icon(Icons.add_task_rounded, color: scheme.primary),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'More options',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () async {
                    final prefill = _parsed;
                    await openReminderEditor(context, prefill: prefill);
                    if (prefill != null && mounted) {
                      _controller.clear();
                      setState(() => _parsed = null);
                    }
                  },
                ),
                if (parsed != null)
                  IconButton(
                    tooltip: 'Add',
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      color: scheme.primary,
                    ),
                    onPressed: _submit,
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: chips.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Gap.s, left: Gap.xs),
                  child: Wrap(
                    spacing: Gap.s,
                    runSpacing: Gap.xs,
                    children: chips,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip(this.icon, this.label, {this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.s + 2, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Radii.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: icon == Icons.circle ? 10 : 15,
            color: iconColor ?? scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
