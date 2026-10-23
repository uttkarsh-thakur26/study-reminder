import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/empty_state.dart';
import 'desktop_window.dart';
import 'global_hotkeys.dart';

/// Settings on Windows: the global shortcuts and a switch for them. Nothing
/// elsewhere.
class DesktopShortcutsSection extends StatelessWidget {
  const DesktopShortcutsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isWindowsApp) return const SizedBox.shrink();
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SectionHeader('SHORTCUTS'), DesktopShortcutsCard()],
    );
  }
}

/// Lists the shortcuts, with a warning for any another app holds.
class DesktopShortcutsCard extends ConsumerWidget {
  const DesktopShortcutsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hotkeys = ref.watch(globalHotkeysProvider);
    final state = hotkeys.value ?? const GlobalHotkeysState(enabled: true);
    final controller = ref.read(globalHotkeysProvider.notifier);
    final taken = state.enabled ? state.taken : const <GlobalHotkey>{};
    final takenKeys = [
      for (final h in GlobalHotkey.values)
        if (taken.contains(h)) h.keys,
    ];

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.keyboard_rounded),
            title: const Text('Global shortcuts'),
            subtitle: const Text(
              'Work from any app, also with the window closed to the tray',
            ),
            value: state.enabled,
            onChanged: hotkeys.isLoading ? null : controller.setEnabled,
          ),
          for (final hotkey in GlobalHotkey.values) ...[
            const Divider(indent: 56),
            ListTile(
              enabled: state.enabled && !taken.contains(hotkey),
              leading: Icon(switch (hotkey) {
                GlobalHotkey.quickAdd => Icons.edit_note_rounded,
                GlobalHotkey.focus => Icons.timer_outlined,
              }),
              title: Text(hotkey.label),
              trailing: _Keys(hotkey.keys),
            ),
          ],
          if (takenKeys.isNotEmpty) ...[
            const Divider(indent: 56),
            ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: scheme.error),
              title: Text(
                '${takenKeys.join(' and ')} '
                '${takenKeys.length == 1 ? 'is' : 'are'} taken by another app',
                style: TextStyle(color: scheme.error),
              ),
              subtitle: const Text(
                'Close that app or change its shortcut, then try again.',
              ),
              trailing: TextButton(
                onPressed: controller.retry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Keys extends StatelessWidget {
  const _Keys(this.keys);

  final String keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: 2),
        child: Text(keys, style: theme.textTheme.labelLarge),
      ),
    );
  }
}
