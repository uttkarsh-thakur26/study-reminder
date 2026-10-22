import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../app/providers.dart';
import '../core/db/app_database.dart';

const _configuredKey = 'start_with_windows_set';

/// Registers the app to open quietly in the tray at sign-in. It is on by
/// default because reminders can only ring while the app runs. Release builds
/// only, so a debug run never registers itself.
Future<void> setUpStartWithWindows(AppDatabase db) async {
  launchAtStartup.setup(
    appName: 'Study Reminder',
    // Quoted so the sign-in launch survives spaces in the install path.
    appPath: '"${Platform.resolvedExecutable}"',
    args: const ['--minimized'],
  );
  if (!kReleaseMode || await db.readSetting(_configuredKey) != null) return;
  await launchAtStartup.enable();
  await db.writeSetting(_configuredKey, '1');
}

/// Whether the app starts at sign-in. Windows can also turn this off from
/// Task Manager, so the value is read back after every change.
final startWithWindowsProvider = AsyncNotifierProvider<StartWithWindows, bool>(
  StartWithWindows.new,
);

class StartWithWindows extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => launchAtStartup.isEnabled();

  Future<void> set(bool enabled) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      enabled
          ? await launchAtStartup.enable()
          : await launchAtStartup.disable();
      await ref.read(databaseProvider).writeSetting(_configuredKey, '1');
      return launchAtStartup.isEnabled();
    });
  }
}
