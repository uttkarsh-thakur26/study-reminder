import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../desktop/desktop_integration.dart';
import '../features/alerts/ui/alert_coordinator.dart';
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
      onResume: () => ref.read(deviceTimeZoneProvider.notifier).refresh(),
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
    return MaterialApp(
      title: 'Study Reminder',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildTheme(settings.accent, Brightness.light),
      darkTheme: buildTheme(settings.accent, Brightness.dark),
      home: const SyncCoordinator(
        child: AlertCoordinator(child: DesktopIntegration(child: AppShell())),
      ),
    );
  }
}
