import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/settings/settings_controller.dart';
import '../shell/app_shell.dart';

class StudyReminderApp extends ConsumerWidget {
  const StudyReminderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Study Reminder',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildTheme(settings.accent, Brightness.light),
      darkTheme: buildTheme(settings.accent, Brightness.dark),
      home: const AppShell(),
    );
  }
}
