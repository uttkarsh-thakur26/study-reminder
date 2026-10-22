import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/system_accent.dart';
import '../desktop/desktop_integration.dart';
import '../desktop/mini_timer.dart';
import '../features/alerts/ui/alert_coordinator.dart';
import '../features/focus/ui/focus_coordinator.dart';
import '../features/home_widget/ui/home_widget_coordinator.dart';
import '../features/settings/settings_controller.dart';
import '../features/sync/ui/sync_coordinator.dart';
import '../shell/app_shell.dart';
import 'providers.dart';

class StudyReminderApp extends ConsumerStatefulWidget {
  const StudyReminderApp({super.key});

  @override
  ConsumerState<StudyReminderApp> createState() => _StudyReminderAppState();
}

class _StudyReminderAppState extends ConsumerState<StudyReminderApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(deviceTimeZoneProvider.notifier).refresh();
        ref.read(systemAccentProvider.notifier).refresh();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final accent = settings.accentWith(
      settings.usesSystemAccent ? ref.watch(systemAccentProvider) : null,
    );
    return MaterialApp(
      title: 'Study Reminder',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildTheme(accent, Brightness.light),
      darkTheme: buildTheme(
        accent,
        Brightness.dark,
        pureBlack: settings.pureBlack,
      ),
      home: const SyncCoordinator(
        child: FocusCoordinator(
          child: AlertCoordinator(
            child: HomeWidgetCoordinator(
              child: DesktopIntegration(child: _Shell()),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app, or the small focus timer on Windows. The app stays built
/// underneath, so it comes back as it was.
class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mini = ref.watch(miniTimerProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: mini, child: const AppShell()),
        if (mini) const MiniTimerView(),
      ],
    );
  }
}
