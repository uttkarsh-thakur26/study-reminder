import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../reminders/application/reminder_providers.dart';
import '../domain/subject.dart';
import 'subject_editor.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsProvider);
    final reminders = ref.watch(remindersProvider).value ?? const [];
    final counts = <String, int>{};
    for (final r in reminders) {
      final id = r.subjectId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }

    return SafeArea(
      bottom: false,
      child: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, Gap.l, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Subjects',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => showSubjectEditor(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Colour-code reminders by subject. Type #name in quick add to tag one.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.l),
            ...subjects.when(
              loading: () => const [],
              error: (e, _) => [Text('$e')],
              data: (list) => list.isEmpty
                  ? [
                      EmptyState(
                        icon: Icons.menu_book_rounded,
                        title: 'No subjects yet',
                        message: 'Add the subjects you are studying, like Physics or History.',
                        action: FilledButton(
                          onPressed: () => showSubjectEditor(context),
                          child: const Text('Add a subject'),
                        ),
                      ),
                    ]
                  : [
                      Card(
                        child: Column(
                          children: [
                            for (final (i, s) in list.indexed) ...[
                              if (i > 0) const Divider(indent: 64),
                              _SubjectRow(subject: s, count: counts[s.id] ?? 0),
                            ],
                          ],
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectRow extends ConsumerWidget {
  const _SubjectRow({required this.subject, required this.count});

  final Subject subject;
  final int count;

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
      subtitle: Text(count == 1 ? '1 reminder' : '$count reminders'),
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
            await ref.read(subjectRepositoryProvider).delete(subject);
          }
        },
      ),
    );
  }
}
