import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32_registry/win32_registry.dart';

import '../app/providers.dart';
import '../core/db/app_database.dart';

const _choiceKey = 'start_with_windows';
const _entry = 'Study Reminder';
const _runPath = r'Software\Microsoft\Windows\CurrentVersion\Run';

/// Where Task Manager records startup apps the user turned off.
const _approvedPath =
    r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';

/// What Windows runs at sign-in: this copy, quietly in the tray. Quoted so a
/// space in the install path does not break it.
String get _command => '"${Platform.resolvedExecutable}" --minimized';

/// Keeps the sign-in entry pointing at this copy of the app. It is on by
/// default, because reminders only ring while the app runs. Release builds
/// only, so a debug run never registers itself. Never throws: a registry
/// problem must not stop the app from opening.
Future<void> setUpStartWithWindows(AppDatabase db) async {
  if (!kReleaseMode) return;
  try {
    final choice = await db.readSetting(_choiceKey);
    if (choice == null) {
      _enable();
      await db.writeSetting(_choiceKey, 'on');
    } else if (choice == 'on' && _registered() != _command) {
      // The app moved, for example a fresh copy of the zip. Only the path is
      // rewritten; a "disabled" set in Task Manager stays as the user left it.
      _register();
    }
  } on Object catch (e) {
    debugPrint('start with Windows unavailable: $e');
  }
}

/// Whether the app starts at sign-in. Task Manager can also turn this off,
/// so the value is read back from Windows after every change.
final startWithWindowsProvider = AsyncNotifierProvider<StartWithWindows, bool>(
  StartWithWindows.new,
);

class StartWithWindows extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => _isEnabled();

  Future<void> set(bool enabled) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      enabled ? _enable() : _disable();
      await ref
          .read(databaseProvider)
          .writeSetting(_choiceKey, enabled ? 'on' : 'off');
      return _isEnabled();
    });
  }
}

bool _isEnabled() {
  try {
    return _registered() == _command && !_turnedOffInTaskManager();
  } on Object {
    return false;
  }
}

String? _registered() => _withKey(_runPath, (k) => k.getStringValue(_entry));

void _register() => _withKey(
  _runPath,
  (k) => k.createValue(RegistryValue.string(_entry, _command)),
);

void _enable() {
  _register();
  // Clear an "off" left by Task Manager, so the switch means what it says.
  _withKey(_approvedPath, (k) {
    if (k.getValue(_entry) != null) k.deleteValue(_entry);
  });
}

void _disable() {
  for (final path in [_runPath, _approvedPath]) {
    _withKey(path, (k) {
      if (k.getValue(_entry) != null) k.deleteValue(_entry);
    });
  }
}

/// Task Manager stores 12 bytes per app; an odd first byte means "off".
bool _turnedOffInTaskManager() => _withKey(_approvedPath, (k) {
  final bytes = k.getBinaryValue(_entry);
  return bytes != null && bytes.isNotEmpty && bytes[0].isOdd;
});

/// Opens (creating if needed) a key under the current user, runs [body] and
/// closes the key again.
T _withKey<T>(String path, T Function(RegistryKey key) body) {
  final user = Registry.currentUser;
  try {
    final key = user.createKey(path);
    try {
      return body(key);
    } finally {
      key.close();
    }
  } finally {
    user.close();
  }
}
