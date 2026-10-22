import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app/providers.dart';
import '../core/ui/formatters.dart';
import '../features/alerts/application/alert_providers.dart';
import '../features/alerts/domain/alert_sync.dart';
import '../features/focus/application/focus_providers.dart';
import '../features/sync/application/sync_providers.dart';
import '../features/reminders/ui/reminder_editor.dart';
import 'desktop_window.dart';
import 'global_hotkeys.dart';
import 'mini_timer.dart';

const _openItem = 'open';
const _newItem = 'new';
const _quitItem = 'quit';
const _trayHintKey = 'tray_hint_shown';

/// The tray icon and close-to-tray behavior of the Windows app.
///
/// Closing the window hides it, so reminders keep ringing. Left-click on the
/// tray icon opens the app; right-click shows Open, New reminder and Quit.
/// A click on a notification's text opens the app too.
class DesktopIntegration extends ConsumerStatefulWidget {
  const DesktopIntegration({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DesktopIntegration> createState() => _DesktopIntegrationState();
}

class _DesktopIntegrationState extends ConsumerState<DesktopIntegration>
    with TrayListener, WindowListener {
  StreamSubscription<NotificationResponse>? _taps;

  @override
  void initState() {
    super.initState();
    if (!isWindowsApp) return;
    windowManager.addListener(this);
    trayManager.addListener(this);
    _taps = ref.read(localNotificationsProvider)?.taps.listen(_onTap);
    unawaited(_setUpTray());
    // Turns the global shortcuts on, unless the user turned them off.
    ref.read(globalHotkeysProvider);
  }

  @override
  void dispose() {
    if (isWindowsApp) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      _taps?.cancel();
    }
    super.dispose();
  }

  Future<void> _setUpTray() async {
    await trayManager.setIcon('assets/tray/tray_icon.ico');
    await trayManager.setToolTip('Study Reminder');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _openItem, label: 'Open Study Reminder'),
          MenuItem(key: _newItem, label: 'New reminder'),
          MenuItem.separator(),
          MenuItem(key: _quitItem, label: 'Quit'),
        ],
      ),
    );
  }

  /// The notification's buttons work in place; only its text opens the app.
  void _onTap(NotificationResponse response) {
    final (:payload, :action) = readResponse(
      payload: response.payload,
      actionId: response.actionId,
    );
    if (payload != null && action == null) unawaited(_showWindow());
  }

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(
    // Without bringing the app forward first, Windows leaves the menu open
    // after a click elsewhere.
    // ignore: deprecated_member_use
    trayManager.popUpContextMenu(bringAppToFront: true),
  );

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _openItem:
        unawaited(_showWindow());
      case _newItem:
        unawaited(_newReminder());
      case _quitItem:
        unawaited(_quit());
    }
  }

  /// Out of the small timer too: whatever brings the window up needs room.
  Future<void> _showWindow() =>
      showFullWindow(ref.read(miniTimerProvider.notifier));

  Future<void> _newReminder() async {
    await _showWindow();
    if (mounted) unawaited(openReminderEditor(context));
  }

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
    // Say once where the app went, so closing it does not look like quitting.
    final db = ref.read(databaseProvider);
    if (await db.readSetting(_trayHintKey) != null) return;
    await db.writeSetting(_trayHintKey, '1');
    await ref
        .read(localNotificationsProvider)
        ?.showInfo(
          title: 'Study Reminder is still running',
          body:
              'Reminders keep ringing from the tray. Right-click the tray '
              'icon to quit.',
        );
  }

  /// Quitting stops reminders on this laptop until the app opens again.
  /// Queued toasts are withdrawn, since their buttons need the app running;
  /// the next start queues them again. During a strict focus session the
  /// user is asked first, and the phone is told.
  Future<void> _quit() async {
    if (!await _mayQuitDuringFocus()) return;
    try {
      await ref.read(localNotificationsProvider)?.plugin.cancelAll();
    } on Object catch (e) {
      debugPrint('could not withdraw queued reminders: $e');
    }
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<bool> _mayQuitDuringFocus() async {
    final session = (await ref.read(focusRepositoryProvider).current()).laptop;
    if (!session.strict || !session.runningAt(DateTime.now())) return true;
    await _showWindow();
    if (!mounted) return false;
    final until = formatTime(context, session.endsAt!.toLocal());
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.timer_rounded),
        title: const Text('Strict focus is on'),
        content: Text(
          'It runs until $until. If you quit, this laptop stops blocking '
          'distractions and your phone is told.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Quit anyway'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep focusing'),
          ),
        ],
      ),
    );
    if (quit != true) return false;
    await ref.read(syncServiceProvider)?.tellOthers({
      'kind': 'left',
      'device': ref.read(deviceNameProvider),
      'endsAt': session.endsAt!.millisecondsSinceEpoch,
    });
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
