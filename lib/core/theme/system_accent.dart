import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32_registry/win32_registry.dart';

/// The device's own accent colour: from the wallpaper on Android 12 and
/// later, or the accent colour chosen in Windows settings. Null where there
/// is none. Read again when the app comes back, since either can change.
final systemAccentProvider = NotifierProvider<SystemAccent, Color?>(
  SystemAccent.new,
);

class SystemAccent extends Notifier<Color?> {
  @override
  Color? build() {
    refresh();
    return null;
  }

  Future<void> refresh() async {
    final color = await readSystemAccent();
    if (ref.mounted && color != state) state = color;
  }
}

const _device = MethodChannel('study_reminder/device');

Future<Color?> readSystemAccent() async {
  if (kIsWeb) return null;
  try {
    if (Platform.isAndroid) {
      final argb = await _device.invokeMethod<int>('accent');
      // Kotlin's Int arrives signed.
      return argb == null ? null : Color(argb & 0xFFFFFFFF);
    }
    if (Platform.isWindows) return _windowsAccent();
  } on Object catch (e) {
    debugPrint('theme: no system accent: $e');
  }
  return null;
}

/// Windows keeps the accent as 0xAABBGGRR.
Color? _windowsAccent() {
  final key = Registry.openPath(
    RegistryHive.currentUser,
    path: r'Software\Microsoft\Windows\DWM',
  );
  try {
    final abgr = key.getIntValue('AccentColor');
    if (abgr == null) return null;
    final r = abgr & 0xFF;
    final g = (abgr >> 8) & 0xFF;
    final b = (abgr >> 16) & 0xFF;
    return Color.fromARGB(0xFF, r, g, b);
  } finally {
    key.close();
  }
}
