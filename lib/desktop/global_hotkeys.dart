import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../features/alerts/application/alert_providers.dart';
import '../features/focus/application/focus_providers.dart';
import '../features/sync/application/sync_providers.dart';
import '../shell/shell_requests.dart';
import 'desktop_window.dart';
import 'focus_hotkey.dart';

/// The Windows app's system-wide shortcuts. They work from any app, also
/// while the window is closed to the tray. The runner registers them, see
/// windows/runner/flutter_window.cpp, and knows them by [id].
enum GlobalHotkey {
  quickAdd('quickAdd', 'Ctrl+Alt+N', 'Quick add a reminder'),
  focus('focus', 'Ctrl+Alt+F', 'Start or stop focus on this laptop');

  const GlobalHotkey(this.id, this.keys, this.label);

  final String id;
  final String keys;
  final String label;

  static GlobalHotkey? byId(Object? id) =>
      values.where((h) => h.id == id).firstOrNull;
}

/// The channel to the runner:
/// - `enable` registers every shortcut and answers with the ids of those
///   another app already holds, as a list of strings;
/// - `disable` gives them all back to Windows;
/// - the runner calls `pressed` with a shortcut's id when it is pressed.
const hotkeyChannelName = 'study_reminder/hotkeys';

final hotkeyChannelProvider = Provider<MethodChannel>(
  (ref) => const MethodChannel(hotkeyChannelName),
);

@immutable
class GlobalHotkeysState {
  const GlobalHotkeysState({required this.enabled, this.taken = const {}});

  final bool enabled;

  /// Shortcuts another app holds, so they do nothing here.
  final Set<GlobalHotkey> taken;
}

/// Whether the shortcuts are on (they are by default), and which of them
/// Windows gave to this app. Read once at startup on Windows, which turns
/// them on.
final globalHotkeysProvider =
    AsyncNotifierProvider<GlobalHotkeys, GlobalHotkeysState>(GlobalHotkeys.new);

class GlobalHotkeys extends AsyncNotifier<GlobalHotkeysState> {
  static const settingKey = 'global_shortcuts';

  MethodChannel get _channel => ref.read(hotkeyChannelProvider);

  @override
  Future<GlobalHotkeysState> build() async {
    final channel = ref.watch(hotkeyChannelProvider);
    channel.setMethodCallHandler(_onCall);
    ref.onDispose(() => channel.setMethodCallHandler(null));
    final choice = await ref.read(databaseProvider).readSetting(settingKey);
    return _register(choice != 'off');
  }

  Future<void> setEnabled(bool on) async {
    state = AsyncData(GlobalHotkeysState(enabled: on));
    await ref
        .read(databaseProvider)
        .writeSetting(settingKey, on ? 'on' : 'off');
    state = AsyncData(await _register(on));
  }

  /// Asks Windows again, for when the other app has let go.
  Future<void> retry() async => state = AsyncData(await _register(true));

  Future<GlobalHotkeysState> _register(bool on) async {
    try {
      if (!on) {
        await _channel.invokeMethod<void>('disable');
        return const GlobalHotkeysState(enabled: false);
      }
      final taken = await _channel.invokeListMethod<String>('enable');
      return GlobalHotkeysState(
        enabled: true,
        taken: {for (final id in taken ?? const []) ?GlobalHotkey.byId(id)},
      );
    } on Object catch (e) {
      // A runner without the channel. Never stops the app from opening.
      debugPrint('global shortcuts unavailable: $e');
      return GlobalHotkeysState(
        enabled: on,
        taken: on ? GlobalHotkey.values.toSet() : const {},
      );
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'pressed') throw MissingPluginException();
    final hotkey = GlobalHotkey.byId(call.arguments);
    if (hotkey == null) return null;
    try {
      await ref.read(hotkeyActionsProvider).run(hotkey);
    } on Object catch (e) {
      debugPrint('global shortcut ${hotkey.keys} failed: $e');
    }
    return null;
  }
}

/// What each shortcut does.
final hotkeyActionsProvider = Provider<HotkeyActions>(HotkeyActions.new);

class HotkeyActions {
  HotkeyActions(this._ref, {Future<void> Function()? showWindow})
    : _showWindow = showWindow ?? showDesktopWindow;

  final Ref _ref;
  final Future<void> Function() _showWindow;

  Future<void> run(GlobalHotkey hotkey) => switch (hotkey) {
    GlobalHotkey.quickAdd => _quickAdd(),
    GlobalHotkey.focus => _focus(),
  };

  /// The window comes forward with the cursor in the quick add field.
  Future<void> _quickAdd() async {
    await _showWindow();
    _ref.read(shellRequestsProvider.notifier).send(ShellRequest.quickAdd);
  }

  /// Starts or stops focus on this laptop and says so in a notification,
  /// without bringing the window up. A strict session cannot stop early, so
  /// its page opens instead.
  Future<void> _focus() async {
    final (:step, :laptop) = await toggleLaptopFocus(
      _ref.read(focusRepositoryProvider),
      startedBy: _ref.read(deviceNameProvider),
    );
    final note = focusHotkeyNote(step, laptop, keys: GlobalHotkey.focus.keys);
    final notifications = _ref.read(localNotificationsProvider);
    if (note != null && notifications != null) {
      try {
        await notifications.showInfo(title: note.title, body: note.body);
        return;
      } on Object catch (e) {
        debugPrint('focus shortcut notice failed: $e');
      }
    }
    await _showWindow();
    _ref.read(shellRequestsProvider.notifier).send(ShellRequest.focus);
  }
}
