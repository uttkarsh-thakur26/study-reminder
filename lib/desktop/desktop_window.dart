import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// The Windows build, which lives in the tray between reminders.
bool get isWindowsApp =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Sizes and centers the window while it is still hidden, and turns the close
/// button into "hide to tray". The runner shows the window on the first frame,
/// unless Windows started the app at sign-in.
Future<void> setUpDesktopWindow() async {
  if (!isWindowsApp) return;
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  await windowManager.setMinimumSize(const Size(420, 560));
  await windowManager.setSize(const Size(1100, 760));
  await windowManager.center();
}

/// Brings the window back from the tray.
Future<void> showDesktopWindow() async {
  await windowManager.show();
  if (await windowManager.isMinimized()) await windowManager.restore();
  await windowManager.focus();
}
