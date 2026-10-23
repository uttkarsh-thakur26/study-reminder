import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/formatters.dart';
import '../../../core/ui/minutes_dialog.dart';
import '../../reminders/domain/reminder.dart';
import '../application/focus_providers.dart';
import '../data/focus_repository.dart';
import '../domain/focus_session.dart';

/// More or less time for the session on [on], running or paused. A strict
/// session only gets more.
Future<void> showFocusTimeSheet(
  BuildContext context, {
  required Set<DeviceKind> on,
  required String where,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) => _FocusTimeSheet(on: on, where: where),
);

class _FocusTimeSheet extends ConsumerWidget {
  const _FocusTimeSheet({required this.on, required this.where});

  final Set<DeviceKind> on;
  final String where;

  static const _steps = [-10, -5, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions =
        ref.watch(focusSessionsProvider).value ?? FocusSessions.idle;
    final session = sessions.of(on.first);
    final now = DateTime.now();
    final live = session.runningAt(now) || session.isPaused;
    final repo = ref.read(focusRepositoryProvider);
    // What a session keeps at least, from now or from its pause.
    final left = session.isPaused
        ? session.pausedLeft
        : session.remainingAt(now);
    final canTakeOff = !session.strict && left > FocusRepository.minimumLeft;

    Future<void> change(int minutes) async {
      await repo.extend(on, Duration(minutes: minutes));
      if (context.mounted) Navigator.of(context).pop();
    }

    Future<void> other(BuildContext context, {required bool add}) async {
      final minutes = await showMinutesDialog(
        context,
        title: add ? 'Minutes to add' : 'Minutes to take off',
        initial: 5,
        max: add ? 240 : (left.inMinutes - 1).clamp(1, 240),
      );
      if (minutes != null) await change(add ? minutes : -minutes);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Change the time', style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            !live
                ? 'The session on $where has ended.'
                : session.isPaused
                ? 'Paused on $where with ${_amount(left)} left.'
                : 'On $where, until ${formatTime(context, session.endsAt!.toLocal())}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Gap.m),
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.s,
            children: [
              for (final m in _steps)
                ActionChip(
                  label: Text(m < 0 ? '−${-m} min' : '+$m min'),
                  onPressed: !live || (m < 0 && !canTakeOff)
                      ? null
                      : () => change(m),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Other'),
                onPressed: !live ? null : () => other(context, add: true),
              ),
              if (canTakeOff)
                ActionChip(
                  avatar: const Icon(Icons.remove_rounded, size: 18),
                  label: const Text('Other'),
                  onPressed: !live ? null : () => other(context, add: false),
                ),
            ],
          ),
          if (session.strict) ...[
            const SizedBox(height: Gap.m),
            Text(
              'Strict session: time can only be added.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  static String _amount(Duration d) {
    final m = d.inMinutes;
    if (m < 1) return 'under a minute';
    if (m < 60) return '$m min';
    return m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min';
  }
}
