import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/calendar_date.dart';
import '../../../core/ui/formatters.dart';
import '../../subjects/domain/subject.dart';
import '../../subjects/ui/subject_editor.dart';
import '../application/reminder_providers.dart';
import '../domain/quick_add_parser.dart';
import '../domain/recurrence.dart';
import '../domain/reminder.dart';
import 'reminder_actions.dart';

/// Opens the editor as a bottom sheet on phones and a dialog on wide screens.
/// Completes with true when the reminder was saved.
Future<bool?> openReminderEditor(
  BuildContext context, {
  Reminder? existing,
  QuickAddResult? prefill,
}) {
  final editor = ReminderEditor(existing: existing, prefill: prefill);
  if (isWide(context)) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(Gap.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: editor,
        ),
      ),
    );
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The sheet's own context, so it moves up when the keyboard opens.
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: editor,
    ),
  );
}

enum _RepeatChoice {
  none('Does not repeat'),
  daily('Every day'),
  weekdays('Weekdays (Mon to Fri)'),
  weekly('Weekly on chosen days'),
  everyNDays('Every few days'),
  everyNWeeks('Every few weeks'),
  monthly('Every month');

  const _RepeatChoice(this.label);
  final String label;

  static _RepeatChoice of(Recurrence r) {
    switch (r.kind) {
      case RepeatKind.once:
        return none;
      case RepeatKind.daily:
        return r.interval == 1 ? daily : everyNDays;
      case RepeatKind.weekly:
        if (r.interval > 1) return everyNWeeks;
        if (r == Recurrence.weekdaysOnly) return weekdays;
        return weekly;
      case RepeatKind.monthly:
        return monthly;
    }
  }
}

class ReminderEditor extends ConsumerStatefulWidget {
  const ReminderEditor({super.key, this.existing, this.prefill});

  final Reminder? existing;
  final QuickAddResult? prefill;

  @override
  ConsumerState<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends ConsumerState<ReminderEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late CalendarDate _date;
  late int _minute;
  late _RepeatChoice _repeat;
  late int _interval;
  late Set<int> _weekdays;
  late ReminderStyle _style;
  late DeliveryTarget _deliverTo;
  String? _subjectId;
  CalendarDate? _until;
  late String _zone;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = widget.existing;
    if (existing != null) {
      _title = TextEditingController(text: existing.title);
      _notes = TextEditingController(text: existing.notes);
      _date = existing.schedule.anchor;
      _minute = existing.schedule.minuteOfDay;
      _style = existing.style;
      _deliverTo = existing.deliverTo;
      _subjectId = existing.subjectId;
      _zone = existing.schedule.timeZone;
      _setRecurrence(existing.recurrence);
    } else {
      final prefill = widget.prefill ?? parseQuickAdd('', now: now);
      final start = resolveStart(prefill, now: now);
      _title = TextEditingController(text: prefill.title);
      _notes = TextEditingController();
      _date = start.date;
      _minute = start.minuteOfDay;
      _style = prefill.style;
      _deliverTo = DeliveryTarget.everywhere;
      _zone = ref.read(deviceTimeZoneProvider);
      _setRecurrence(prefill.recurrence);
    }
  }

  void _setRecurrence(Recurrence r) {
    _repeat = _RepeatChoice.of(r);
    _interval = r.interval;
    _until = r.until;
    _weekdays = r.kind == RepeatKind.weekly && r.weekdays.isNotEmpty
        ? {...r.weekdays}
        : {_date.weekday};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Match a #tag from quick add to a subject once subjects are available.
    final tag = widget.prefill?.subjectTag?.toLowerCase();
    if (_isNew && _subjectId == null && tag != null) {
      final subjects = ref.read(subjectsProvider).value ?? const <Subject>[];
      for (final s in subjects) {
        if (s.name.toLowerCase().startsWith(tag)) {
          _subjectId = s.id;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// The chosen repeat, keeping an end date set elsewhere.
  Recurrence get _recurrence {
    final r = _baseRecurrence;
    return r.repeats && _until != null ? r.copyWith(until: _until) : r;
  }

  Recurrence get _baseRecurrence => switch (_repeat) {
    _RepeatChoice.none => Recurrence.once,
    _RepeatChoice.daily => const Recurrence.daily(),
    _RepeatChoice.weekdays => Recurrence.weekdaysOnly,
    _RepeatChoice.weekly => Recurrence.weekly({..._weekdays}),
    _RepeatChoice.everyNDays => Recurrence.daily(every: _interval),
    _RepeatChoice.everyNWeeks => Recurrence.weekly({
      ..._weekdays,
    }, every: _interval),
    _RepeatChoice.monthly => Recurrence.monthly(every: _interval),
  };

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final schedule = ReminderSchedule(
      anchor: _date,
      minuteOfDay: _minute,
      timeZone: _zone,
      recurrence: _recurrence,
    );
    final reminder =
        (widget.existing ??
                Reminder(
                  id: const Uuid().v4(),
                  title: title,
                  schedule: schedule,
                  createdAt: DateTime.now().toUtc(),
                ))
            .copyWith(
              title: title,
              notes: _notes.text.trim(),
              schedule: schedule,
              style: _style,
              deliverTo: _deliverTo,
              subjectId: _subjectId,
              clearSubject: _subjectId == null,
            );
    await ref
        .read(reminderRepositoryProvider)
        .save(reminder, base: widget.existing);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    final today = CalendarDate.fromDateTime(DateTime.now());
    final first = _date.isBefore(today) ? _date : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) {
      setState(() {
        final oldWeekday = _date.weekday;
        _date = CalendarDate.fromDateTime(picked);
        if (_weekdays.length == 1 && _weekdays.first == oldWeekday) {
          _weekdays = {_date.weekday};
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minute ~/ 60, minute: _minute % 60),
    );
    if (picked != null) {
      setState(() => _minute = picked.hour * 60 + picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = CalendarDate.fromDateTime(DateTime.now());
    final subjects = ref.watch(subjectsProvider).value ?? const <Subject>[];
    final wide = isWide(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      // Focus stays below the shortcuts even after clicking a button.
      child: FocusScope(
        autofocus: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Gap.xl,
                wide ? Gap.xl : 0,
                Gap.s,
                Gap.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isNew ? 'New reminder' : 'Edit reminder',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (!_isNew)
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () {
                        final existing = widget.existing!;
                        deleteReminder(
                          context,
                          ref,
                          existing.id,
                          existing.title,
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _title,
                      autofocus: _isNew,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      style: theme.textTheme.titleMedium,
                      decoration: const InputDecoration(
                        hintText: 'What do you need to study?',
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: Gap.s),
                    TextField(
                      controller: _notes,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const _SectionLabel('When'),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerButton(
                            icon: Icons.event_rounded,
                            label: formatDay(_date, today),
                            onPressed: _pickDate,
                          ),
                        ),
                        const SizedBox(width: Gap.s),
                        Expanded(
                          child: _PickerButton(
                            icon: Icons.schedule_rounded,
                            label: formatMinuteOfDay(context, _minute),
                            onPressed: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    if (_zone != ref.watch(deviceTimeZoneProvider))
                      _ZoneNote(
                        zone: _zone,
                        onUseLocal: () => setState(
                          () => _zone = ref.read(deviceTimeZoneProvider),
                        ),
                      ),
                    const SizedBox(height: Gap.s),
                    _RepeatPicker(
                      value: _repeat,
                      onChanged: (v) => setState(() {
                        _repeat = v;
                        if (v == _RepeatChoice.everyNDays ||
                            v == _RepeatChoice.everyNWeeks) {
                          if (_interval < 2) _interval = 2;
                        } else {
                          _interval = 1;
                        }
                      }),
                    ),
                    if (_repeat == _RepeatChoice.everyNDays ||
                        _repeat == _RepeatChoice.everyNWeeks ||
                        _repeat == _RepeatChoice.monthly) ...[
                      const SizedBox(height: Gap.s),
                      _IntervalStepper(
                        value: _interval,
                        min: _repeat == _RepeatChoice.monthly ? 1 : 2,
                        unit: switch (_repeat) {
                          _RepeatChoice.everyNDays => 'days',
                          _RepeatChoice.everyNWeeks => 'weeks',
                          _ => _interval == 1 ? 'month' : 'months',
                        },
                        onChanged: (v) => setState(() => _interval = v),
                      ),
                    ],
                    if (_repeat == _RepeatChoice.weekly ||
                        _repeat == _RepeatChoice.everyNWeeks) ...[
                      const SizedBox(height: Gap.s),
                      _WeekdayPicker(
                        selected: _weekdays,
                        onChanged: (v) => setState(() => _weekdays = v),
                      ),
                    ],
                    const _SectionLabel('How'),
                    SegmentedButton<ReminderStyle>(
                      segments: const [
                        ButtonSegment(
                          value: ReminderStyle.notification,
                          icon: Icon(Icons.notifications_none_rounded),
                          label: Text('Notification'),
                        ),
                        ButtonSegment(
                          value: ReminderStyle.alarm,
                          icon: Icon(Icons.alarm_rounded),
                          label: Text('Alarm'),
                        ),
                      ],
                      selected: {_style},
                      onSelectionChanged: (s) =>
                          setState(() => _style = s.first),
                    ),
                    const SizedBox(height: Gap.s),
                    SegmentedButton<DeliveryTarget>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: DeliveryTarget.everywhere,
                          icon: Icon(Icons.devices_rounded),
                          label: Text('Both'),
                        ),
                        ButtonSegment(
                          value: DeliveryTarget.phone,
                          icon: Icon(Icons.smartphone_rounded),
                          label: Text('Phone'),
                        ),
                        ButtonSegment(
                          value: DeliveryTarget.laptop,
                          icon: Icon(Icons.laptop_rounded),
                          label: Text('Laptop'),
                        ),
                      ],
                      selected: {_deliverTo},
                      onSelectionChanged: (s) =>
                          setState(() => _deliverTo = s.first),
                    ),
                    const _SectionLabel('Subject'),
                    Wrap(
                      spacing: Gap.s,
                      runSpacing: Gap.s,
                      children: [
                        ChoiceChip(
                          label: const Text('None'),
                          selected: _subjectId == null,
                          onSelected: (_) => setState(() => _subjectId = null),
                        ),
                        for (final s in subjects)
                          ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundColor: Color(s.color),
                              radius: 6,
                            ),
                            label: Text(s.name),
                            selected: _subjectId == s.id,
                            onSelected: (_) =>
                                setState(() => _subjectId = s.id),
                          ),
                        ActionChip(
                          avatar: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                          label: const Text('New subject'),
                          onPressed: () async {
                            final created = await showSubjectEditor(context);
                            if (created != null && mounted) {
                              setState(() => _subjectId = created.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.xl),
              child: Row(
                children: [
                  if (wide)
                    Text(
                      'Ctrl + Enter to save',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Gap.s),
                  FilledButton(
                    onPressed: _title.text.trim().isEmpty || _saving
                        ? null
                        : _save,
                    child: Text(_isNew ? 'Add reminder' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.s),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(alignment: Alignment.centerLeft),
    );
  }
}

class _RepeatPicker extends StatelessWidget {
  const _RepeatPicker({required this.value, required this.onChanged});

  final _RepeatChoice value;
  final ValueChanged<_RepeatChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, _) => _PickerButton(
        icon: Icons.repeat_rounded,
        label: value.label,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        for (final choice in _RepeatChoice.values)
          MenuItemButton(
            leadingIcon: Icon(
              choice == value ? Icons.check_rounded : null,
              size: 18,
            ),
            onPressed: () => onChanged(choice),
            child: Text(choice.label),
          ),
      ],
    );
  }
}

class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
    this.min = 2,
  });

  final int value;
  final int min;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text('Every', style: theme.textTheme.bodyLarge),
        const SizedBox(width: Gap.s),
        IconButton.filledTonal(
          tooltip: 'Fewer',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'More',
          onPressed: value < 60 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
        const SizedBox(width: Gap.s),
        Text(unit, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var day = 1; day <= 7; day++)
          Tooltip(
            message: weekdayShortNames[day - 1],
            excludeFromSemantics: true,
            child: _DayToggle(
              label: weekdayShortNames[day - 1],
              letter: _letters[day - 1],
              on: selected.contains(day),
              scheme: scheme,
              onTap: () {
                final next = {...selected};
                if (next.contains(day)) {
                  if (next.length > 1) next.remove(day);
                } else {
                  next.add(day);
                }
                onChanged(next);
              },
            ),
          ),
      ],
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.letter,
    required this.on,
    required this.scheme,
    required this.onTap,
  });

  final String label;
  final String letter;
  final bool on;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: on ? scheme.primary : scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the reminder keeps another zone's clock, e.g. it was made
/// before travelling, so the times above are not this device's local time.
class _ZoneNote extends StatelessWidget {
  const _ZoneNote({required this.zone, required this.onUseLocal});

  final String zone;
  final VoidCallback onUseLocal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: Row(
        children: [
          Icon(
            Icons.public_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Gap.xs),
          Expanded(
            child: Text(
              'Times are in $zone',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: onUseLocal, child: const Text('Use my zone')),
        ],
      ),
    );
  }
}
