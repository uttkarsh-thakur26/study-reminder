import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../reminders/application/reminder_providers.dart';
import '../domain/subject.dart';

/// Creates or edits a subject. Returns the saved subject, or null if
/// cancelled.
Future<Subject?> showSubjectEditor(BuildContext context, {Subject? existing}) =>
    showDialog<Subject>(
      context: context,
      builder: (_) => _SubjectDialog(existing: existing),
    );

class _SubjectDialog extends ConsumerStatefulWidget {
  const _SubjectDialog({this.existing});
  final Subject? existing;

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late int _color = widget.existing?.color ?? subjectPalette.first;

  @override
  void initState() {
    super.initState();
    if (widget.existing == null) {
      // Suggest a colour not used yet.
      final used = {
        for (final s in ref.read(subjectsProvider).value ?? const <Subject>[])
          s.color,
      };
      _color = subjectPalette.firstWhere(
        (c) => !used.contains(c),
        orElse: () => subjectPalette.first,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(subjectRepositoryProvider);
    final subject =
        widget.existing?.copyWith(name: name, color: _color) ??
        Subject(
          id: const Uuid().v4(),
          name: name,
          color: _color,
          sortOrder: await repo.nextSortOrder(),
        );
    await repo.save(subject);
    if (mounted) Navigator.of(context).pop(subject);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New subject' : 'Edit subject'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Physics'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Gap.l),
            Wrap(
              spacing: Gap.s,
              runSpacing: Gap.s,
              children: [
                for (final c in subjectPalette)
                  _Swatch(
                    color: Color(c),
                    selected: c == _color,
                    onTap: () => setState(() => _color = c),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
