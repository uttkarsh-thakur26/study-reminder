import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../features/focus/ui/focus_screen.dart';
import '../features/reminders/ui/reminder_editor.dart';
import '../features/reminders/ui/today_screen.dart';
import '../features/reminders/ui/upcoming_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/subjects/ui/subjects_screen.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Today', Icons.wb_sunny_outlined, Icons.wb_sunny_rounded),
  _Destination(
    'Upcoming',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  _Destination('Focus', Icons.timer_outlined, Icons.timer_rounded),
  _Destination('Subjects', Icons.menu_book_outlined, Icons.menu_book_rounded),
  _Destination('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

/// Bottom navigation on phones, a side rail on laptops.
///
/// Keyboard: Ctrl+N new reminder, Ctrl+K quick add, Ctrl+1..5 switch pages.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _quickAddFocus = FocusNode(debugLabel: 'quick-add');

  late final _pages = [
    TodayScreen(quickAddFocus: _quickAddFocus),
    const UpcomingScreen(),
    const FocusScreen(),
    const SubjectsScreen(),
    const SettingsScreen(),
  ];

  @override
  void dispose() {
    _quickAddFocus.dispose();
    super.dispose();
  }

  void _select(int i) => setState(() => _index = i);

  void _newReminder() => openReminderEditor(context);

  void _focusQuickAdd() {
    _select(0);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _quickAddFocus.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final scheme = Theme.of(context).colorScheme;
    final body = IndexedStack(index: _index, children: _pages);

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          _newReminder,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          _focusQuickAdd,
      for (var i = 0; i < _destinations.length; i++)
        SingleActivator(
          LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
          control: true,
        ): () =>
            _select(i),
    };

    final Widget scaffold;
    if (wide) {
      final extended = MediaQuery.sizeOf(context).width >= 1100;
      scaffold = Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              extended: extended,
              minExtendedWidth: 220,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: Gap.l, bottom: Gap.xl),
                child: extended
                    ? FloatingActionButton.extended(
                        onPressed: _newReminder,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New reminder'),
                        tooltip: 'New reminder (Ctrl+N)',
                      )
                    : FloatingActionButton(
                        onPressed: _newReminder,
                        tooltip: 'New reminder (Ctrl+N)',
                        child: const Icon(Icons.add_rounded),
                      ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(
              width: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        body: body,
        floatingActionButton: _index <= 1
            ? FloatingActionButton(
                onPressed: _newReminder,
                tooltip: 'New reminder',
                child: const Icon(Icons.add_rounded),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: shortcuts,
      // A scope below the shortcuts: when a text field lets go of focus it
      // lands here, so the shortcuts keep working.
      child: FocusScope(autofocus: true, child: scaffold),
    );
  }
}
