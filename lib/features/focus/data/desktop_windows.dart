import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../domain/laptop_block_rules.dart';

/// A top-level window: its handle, the program behind it and its title.
class DesktopWindow {
  const DesktopWindow(this.handle, this.exePath, this.title);

  final int handle;
  final String exePath;
  final String title;
}

/// The windows on the laptop, as Focus mode needs them.
abstract interface class DesktopWindows {
  /// The window in front, unless it is this app's own or there is none.
  DesktopWindow? foreground();

  void minimize(int handle);

  /// Asks the window to close, as its close button would.
  void close(int handle);

  /// Closes the browser tab in front (Ctrl+W), if [handle] is still in front
  /// and no key the user holds would change the shortcut. False when it did
  /// nothing, to try again on the next check.
  bool closeTab(int handle);

  /// Programs with a window open now, for picking what to block.
  List<String> openPrograms();
}

/// [DesktopWindows] through the Win32 API.
class Win32Windows implements DesktopWindows {
  Win32Windows() : _ownPid = GetCurrentProcessId();

  final int _ownPid;

  static const _vkW = 0x57;
  static const _modifiers = [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN];

  /// Shell parts that have windows but are not programs anyone would block.
  static const _shell = {
    'explorer.exe',
    'applicationframehost.exe',
    'textinputhost.exe',
    'searchhost.exe',
    'shellexperiencehost.exe',
    'startmenuexperiencehost.exe',
    'systemsettings.exe',
    'lockapp.exe',
  };

  @override
  DesktopWindow? foreground() {
    final hwnd = GetForegroundWindow();
    return hwnd == 0 ? null : _describe(hwnd);
  }

  DesktopWindow? _describe(int hwnd) {
    final pid = calloc<Uint32>();
    try {
      GetWindowThreadProcessId(hwnd, pid);
      if (pid.value == 0 || pid.value == _ownPid) return null;
      final exe = exePathOf(pid.value);
      return exe == null ? null : DesktopWindow(hwnd, exe, _title(hwnd));
    } finally {
      free(pid);
    }
  }

  static String _title(int hwnd) {
    final length = GetWindowTextLength(hwnd);
    if (length == 0) return '';
    final buffer = wsalloc(length + 1);
    try {
      GetWindowText(hwnd, buffer, length + 1);
      return buffer.toDartString();
    } finally {
      free(buffer);
    }
  }

  @override
  void minimize(int handle) => ShowWindow(handle, SW_MINIMIZE);

  @override
  void close(int handle) => PostMessage(handle, WM_CLOSE, 0, 0);

  @override
  bool closeTab(int handle) {
    // Checked again right before, so the keys never land in another window.
    if (GetForegroundWindow() != handle) return false;
    // With Shift held, Ctrl+W would close the whole window.
    for (final key in _modifiers) {
      if (GetAsyncKeyState(key) & 0x8000 != 0) return false;
    }
    final inputs = calloc<INPUT>(4);
    try {
      void key(int i, int vk, {bool up = false}) {
        inputs[i].type = INPUT_KEYBOARD;
        inputs[i].ki.wVk = vk;
        inputs[i].ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
      }

      key(0, VK_CONTROL);
      key(1, _vkW);
      key(2, _vkW, up: true);
      key(3, VK_CONTROL, up: true);
      return SendInput(4, inputs, sizeOf<INPUT>()) == 4;
    } finally {
      free(inputs);
    }
  }

  @override
  List<String> openPrograms() {
    final found = <String>{};
    int visit(int hwnd, int _) {
      if (IsWindowVisible(hwnd) != 0 && GetWindowTextLength(hwnd) > 0) {
        final w = _describe(hwnd);
        if (w != null) found.add(programName(w.exePath));
      }
      return TRUE;
    }

    final callback = NativeCallable<WNDENUMPROC>.isolateLocal(
      visit,
      exceptionalReturn: 0,
    );
    try {
      EnumWindows(callback.nativeFunction, 0);
    } finally {
      callback.close();
    }
    return (found.difference(_shell).toList())..sort();
  }
}

/// The program file of process [pid], or null when it can't be read.
String? exePathOf(int pid) {
  final process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == 0) return null;
  final size = calloc<Uint32>()..value = 1024;
  final buffer = wsalloc(1024);
  try {
    if (QueryFullProcessImageName(process, 0, buffer, size) == 0) return null;
    return buffer.toDartString(length: size.value);
  } finally {
    free(buffer);
    free(size);
    CloseHandle(process);
  }
}
