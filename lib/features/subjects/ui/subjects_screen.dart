import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../reminders/application/reminder_providers.dart';
import '../domain/subject.dart';
import 'subject_editor.dart';

/// The subjects, each with its study time this week and its reminders.
/// Part of the Study page.
class SubjectsSection extends ConsumerWidget {
  const SubjectsSection({super.key, this.studied = const {}});

  /// Study time this week per subject id.
  final Map<String?, Duration> studied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);
    final reminders = ref.watch(remindersProvider).value ?? const [];
    final counts = <String, int>{};
    for (final r in reminders) {
      final id = r.subjectId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    final most = studied.values.fold(Duration.zero, (a, b) => a > b ? a : b);

    return subjects.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('$e'),
      data: (list) => list.isEmpty
          ? EmptyState(
              icon: Icons.menu_book_rounded,
              title: 'No subjects yet',
              message:
                  'Add the subjects you are studying, like Physics or History. '
                  'Type #name in quick add to tag a reminder.',
              action: FilledButton(
                onPressed: () => showSubjectEditor(context),
                child: const Text('Add a subject'),
              ),
            )
          : Card(
              child: Column(
                children: [
                  for (final (i, s) in list.indexed) ...[
                    if (i > 0) const Divider(indent: 64),
                    _SubjectRow(
                      subject: s,
                      count: counts[s.id] ?? 0,
                      studied: studied[s.id] ?? Duration.zero,
                      most: most,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// "1 h 20 min", "45 min".
String formatStudyTime(Duration d) {
  if (d > Duration.zero && d < const Duration(minutes: 1)) return '<1 min';
  final minutes = d.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// A plain bar, filled by [fraction] in [color].
class _TimeBar extends StatelessWidget {
  const _TimeBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 6,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(3),
    ),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: fraction.clamp(0.02, 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );
}

class _SubjectRow extends ConsumerWidget {
  const _SubjectRow({
    required this.subject,
    required this.count,
    required this.studied,
    required this.most,
  });

  final Subject subject;
  final int count;
  final Duration studied;

  /// The most any subject was studied this week, for the bar.
  final Duration most;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Color(subject.color).withValues(alpha: 0.18),
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Color(subject.color),
            shape: BoxShape.circle,
          ),
        ),
      ),
      title: Text(subject.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (studied > Duration.zero)
                '${formatStudyTime(studied)} this week',
              count == 1 ? '1 reminder' : '$count reminders',
            ].join(' · '),
          ),
          if (studied >= const Duration(minutes: 1) &&
              most > Duration.zero) ...[
            const SizedBox(height: Gap.xs),
            // Against the subject studied most this week.
            _TimeBar(
              fraction: studied.inSeconds / most.inSeconds,
              color: Color(subject.color),
            ),
          ],
        ],
      ),
      onTap: () => showSubjectEditor(context, existing: subject),
      trailing: IconButton(
        tooltip: 'Delete subject',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Delete ${subject.name}?'),
              content: const Text(
                'Its reminders stay, they just lose the subject tag.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (ok == true) {
            await ref.read(subjectRepositoryProvider).delete(subject.id);
          }
        },
      ),
    );
  }
}
