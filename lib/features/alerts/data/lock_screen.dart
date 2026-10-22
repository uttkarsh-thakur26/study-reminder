import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app may show over the lock screen only while an alarm is on screen.
///
/// Android starts the app over the lock screen when an alarm rings (see
/// MainActivity). Once the alarm page closes, or the launch turns out not to
/// be an alarm, the app goes back behind the lock screen.
abstract final class LockScreen {
  static const _channel = MethodChannel('study_reminder/lock_screen');

  static Future<void> release() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('release');
    } on MissingPluginException {
      // Not wired up in this engine, such as in tests.
    } on PlatformException catch (e) {
      debugPrint('lock screen release failed: $e');
    }
  }
}
