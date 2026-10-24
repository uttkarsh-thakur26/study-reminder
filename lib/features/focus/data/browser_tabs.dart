import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

import '../domain/laptop_block_rules.dart';
import '../domain/study_videos.dart';
import 'desktop_windows.dart';

/// The browser tabs on the laptop, as Focus mode needs them beyond the
/// window in front.
abstract interface class BrowserTabs {
  /// Closes the tabs showing one of [sites] in browsers playing sound,
  /// background tabs and windows behind others or minimised too. The tab in
  /// front of the window in front is left to the check of that window.
  /// YouTube tabs whose title is one of [studyTitles] (as
  /// [StudyVideoRules.cleanTitle] gives them) stay open. Gives back what it
  /// closed.
  Future<List<BlockHit>> closeBlockedTabs(
    List<String> sites, {
    Set<String> studyTitles = const {},
  });

  /// The address in the address bar of the browser window [hwnd], as the
  /// browser shows it (often without https://). Null when it can't be read.
  Future<String?> addressOf(int hwnd);
}

/// [BrowserTabs] through Core Audio and UI Automation.
///
/// Only Chromium browsers are looked at ([LaptopBlockRules.tabBrowsers]), and
/// only while one plays sound: reading a browser's tabs turns on its
/// accessibility support, which slows it down a little, so this is kept to
/// the moments a background tab may be playing a blocked site. Web pages
/// themselves are never read.
class Win32BrowserTabs implements BrowserTabs {
  const Win32BrowserTabs();

  @override
  Future<List<BlockHit>> closeBlockedTabs(
    List<String> sites, {
    Set<String> studyTitles = const {},
  }) {
    final list = List.of(sites);
    final titles = Set.of(studyTitles);
    // A new isolate for each sweep, so the UI thread never waits on another
    // program, and so COM is set up, used and torn down in one synchronous
    // call on one thread: a long-lived isolate can move between threads
    // from one message to the next, and CoUninitialize must run on the
    // thread that called CoInitializeEx. Starting one every few seconds
    // costs little next to the sweep.
    return Isolate.run(() => _sweep(list, titles), debugName: 'focus tabs');
  }

  @override
  Future<String?> addressOf(int hwnd) =>
      Isolate.run(() => _readAddress(hwnd), debugName: 'focus address');
}

/// The address bar's text of the browser window [hwnd], in the worker
/// isolate: the first edit field outside the page whose text looks like an
/// address. Chromium names it "Address and search bar"; Firefox has its own
/// name, so the text is what counts.
String? _readAddress(int hwnd) {
  if (FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) return null;
  try {
    return using((arena) {
      final automation = arena.own(CUIAutomation.createInstance());
      final walker = arena.own(
        IUIAutomationTreeWalker(automation.controlViewWalker),
      );
      final root = _take(
        arena,
        (out) => automation.elementFromHandle(hwnd, out),
        IUIAutomationElement.new,
      );
      if (root == null) return null;
      var budget = _maxNodes;
      String? visit(IUIAutomationElement element, int depth) => using((arena) {
        IUIAutomationElement? child;
        while (budget-- > 0) {
          final previous = child;
          child = _take(
            arena,
            (out) => previous == null
                ? walker.getFirstChildElement(_raw(element), out)
                : walker.getNextSiblingElement(_raw(previous), out),
            IUIAutomationElement.new,
          );
          if (child == null) return null;
          final type = _controlType(child);
          if (type == UIA_EditControlTypeId) {
            final value = _value(child);
            if (value != null && _looksLikeAddress(value)) return value;
          } else if (type != UIA_DocumentControlTypeId && depth < _maxDepth) {
            // A document is a web page, which is never read.
            if (visit(child, depth + 1) case final String found) return found;
          }
        }
        return null;
      });
      return visit(root, 0);
    });
  } on Object catch (e) {
    debugPrint('focus: could not read the address bar: $e');
    return null;
  } finally {
    CoUninitialize();
  }
}

bool _looksLikeAddress(String text) {
  final t = text.trim();
  return t.isNotEmpty && !t.contains(' ') && t.contains('.');
}

/// The text of an edit field, or null.
String? _value(IUIAutomationElement element) => using((arena) {
  final iid = convertToIID(IID_IUIAutomationValuePattern, allocator: arena);
  final pattern = _take(
    arena,
    (out) => element.getCurrentPatternAs(UIA_ValuePatternId, iid, out.cast()),
    IUIAutomationValuePattern.new,
  );
  if (pattern == null) return null;
  final Pointer<Utf16> value;
  try {
    value = pattern.currentValue;
  } on WindowsException {
    return null;
  }
  if (value.address == 0) return null;
  try {
    return value.toDartString();
  } finally {
    SysFreeString(value);
  }
});

/// How deep into a window's controls to look for its tabs.
const _maxDepth = 12;

/// How many controls of one window to look at, at most.
const _maxNodes = 400;

/// How many controls of one tab to look at for its close button.
const _maxTabParts = 8;

/// One sweep, start to end, in the worker isolate.
List<BlockHit> _sweep(List<String> sites, Set<String> studyTitles) {
  final rules = LaptopBlockRules(programs: const [], sites: sites);
  if (!rules.blocksSites) return const [];
  if (FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) return const [];
  try {
    final playing = _playingBrowsers();
    if (playing.isEmpty) return const [];
    final windows = _windowsOf(playing);
    if (windows.isEmpty) return const [];
    return _TabSweep(rules, studyTitles).run(windows);
  } on Object catch (e) {
    debugPrint('focus: could not sweep browser tabs: $e');
    return const [];
  } finally {
    CoUninitialize();
  }
}

/// The Chromium browsers with sound playing now, by program name.
///
/// Chrome plays sound from a helper process, not the one with the windows,
/// so this goes by program and not by process.
Set<String> _playingBrowsers() => using((arena) {
  final found = <String>{};
  final enumerator = arena.own(MMDeviceEnumerator.createInstance());
  final devices = _take(
    arena,
    (out) => enumerator.enumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, out),
    IMMDeviceCollection.new,
  );
  final count = arena<Uint32>();
  if (devices == null || FAILED(devices.getCount(count))) return found;
  for (var i = 0; i < count.value; i++) {
    using((arena) {
      final device = _take(arena, (out) => devices.item(i, out), IMMDevice.new);
      if (device != null) _addPlaying(device, found);
    });
  }
  return found;
});

/// Adds to [found] the browsers playing sound on [device].
void _addPlaying(IMMDevice device, Set<String> found) => using((arena) {
  final iid = convertToIID(IID_IAudioSessionManager2, allocator: arena);
  final manager = _take(
    arena,
    (out) => device.activate(iid, CLSCTX_ALL, nullptr, out.cast()),
    IAudioSessionManager2.new,
  );
  if (manager == null) return;
  final sessions = _take(
    arena,
    manager.getSessionEnumerator,
    IAudioSessionEnumerator.new,
  );
  final count = arena<Int32>();
  if (sessions == null || FAILED(sessions.getCount(count))) return;
  final iid2 = convertToIID(IID_IAudioSessionControl2, allocator: arena);
  for (var i = 0; i < count.value; i++) {
    using((arena) {
      final control = _take(
        arena,
        (out) => sessions.getSession(i, out),
        IAudioSessionControl.new,
      );
      final state = arena<Int32>();
      if (control == null ||
          FAILED(control.getState(state)) ||
          state.value != AudioSessionStateActive) {
        return;
      }
      final control2 = _take(
        arena,
        (out) => control.queryInterface(iid2, out.cast()),
        IAudioSessionControl2.new,
      );
      final pid = arena<Uint32>();
      if (control2 == null ||
          FAILED(control2.getProcessId(pid)) ||
          pid.value == 0) {
        return;
      }
      if (exePathOf(pid.value) case final String path) {
        final program = programName(path);
        if (LaptopBlockRules.tabBrowsers.contains(program)) found.add(program);
      }
    });
  }
});

/// The top-level windows of [programs], minimised ones too.
List<int> _windowsOf(Set<String> programs) {
  final found = <int>[];
  final programOf = <int, String?>{};
  final pid = calloc<Uint32>();
  int visit(int hwnd, int _) {
    if (IsWindowVisible(hwnd) != 0 && GetWindowTextLength(hwnd) > 0) {
      GetWindowThreadProcessId(hwnd, pid);
      final program = programOf.putIfAbsent(pid.value, () {
        final path = exePathOf(pid.value);
        return path == null ? null : programName(path);
      });
      if (programs.contains(program)) found.add(hwnd);
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
    free(pid);
  }
  return found;
}

/// One look through the tab strips of some browser windows.
class _TabSweep {
  _TabSweep(this.rules, this.studyTitles);

  final LaptopBlockRules rules;
  final Set<String> studyTitles;
  final _closed = <BlockHit>[];
  late IUIAutomationTreeWalker _walker;
  var _budget = 0;

  List<BlockHit> run(List<int> windows) => using((arena) {
    final automation = arena.own(CUIAutomation.createInstance());
    _walker = arena.own(IUIAutomationTreeWalker(automation.controlViewWalker));
    for (final hwnd in windows) {
      try {
        using((arena) {
          final root = _take(
            arena,
            (out) => automation.elementFromHandle(hwnd, out),
            IUIAutomationElement.new,
          );
          _budget = _maxNodes;
          if (root != null) _visit(root, hwnd, 0);
        });
      } on Object catch (e) {
        debugPrint('focus: could not look at a browser window: $e');
      }
    }
    return _closed;
  });

  /// Looks for tabs under [element], depth first.
  void _visit(IUIAutomationElement element, int hwnd, int depth) =>
      using((arena) {
        final children = _children(arena, element, _budget);
        _budget -= children.length;
        for (final child in children) {
          final type = _controlType(child);
          if (type == UIA_TabItemControlTypeId) {
            _tab(child, hwnd);
          } else if (type != UIA_DocumentControlTypeId && depth < _maxDepth) {
            // A document is a web page, which is never read.
            _visit(child, hwnd, depth + 1);
          }
        }
      });

  void _tab(IUIAutomationElement tab, int hwnd) {
    final title = _name(tab);
    final hit = rules.matchTab(title);
    if (hit == null) return;
    if (hit.isYouTube &&
        studyTitles.contains(StudyVideoRules.cleanTitle(title))) {
      return;
    }
    // The check of the window in front closes its tab in front. Closing it
    // here as well could close the tab next to it.
    if (GetForegroundWindow() == hwnd && _isSelected(tab)) return;
    if (_pressClose(tab)) _closed.add(hit);
  }

  /// Whether [tab] is the one shown in its window. True when it can't tell,
  /// so that such a tab is left alone.
  bool _isSelected(IUIAutomationElement tab) => using((arena) {
    final iid = convertToIID(
      IID_IUIAutomationSelectionItemPattern,
      allocator: arena,
    );
    final pattern = _take(
      arena,
      (out) =>
          tab.getCurrentPatternAs(UIA_SelectionItemPatternId, iid, out.cast()),
      IUIAutomationSelectionItemPattern.new,
    );
    if (pattern == null) return true;
    try {
      return pattern.currentIsSelected != FALSE;
    } on WindowsException {
      return true;
    }
  });

  /// Presses the close button of [tab]: the button named so, or else the
  /// last of two or more buttons, which is where Chromium puts it. A lone
  /// unnamed button may be the sound button of a pinned tab, so it is left
  /// alone. False when there is none or pressing failed.
  bool _pressClose(IUIAutomationElement tab) => using((arena) {
    final buttons = [
      for (final child in _children(arena, tab, _maxTabParts))
        if (_controlType(child) == UIA_ButtonControlTypeId) child,
    ];
    final named = buttons
        .where((b) => _name(b).toLowerCase().contains('close'))
        .firstOrNull;
    final button = named ?? (buttons.length >= 2 ? buttons.last : null);
    if (button == null) return false;
    final iid = convertToIID(IID_IUIAutomationInvokePattern, allocator: arena);
    final invoke = _take(
      arena,
      (out) => button.getCurrentPatternAs(UIA_InvokePatternId, iid, out.cast()),
      IUIAutomationInvokePattern.new,
    );
    return invoke != null && SUCCEEDED(invoke.invoke());
  });

  /// Up to [max] children of [element] in the control view, released with
  /// [arena].
  List<IUIAutomationElement> _children(
    Arena arena,
    IUIAutomationElement element,
    int max,
  ) {
    final children = <IUIAutomationElement>[];
    IUIAutomationElement? child;
    while (children.length < max) {
      final previous = child;
      child = _take(
        arena,
        (out) => previous == null
            ? _walker.getFirstChildElement(_raw(element), out)
            : _walker.getNextSiblingElement(_raw(previous), out),
        IUIAutomationElement.new,
      );
      if (child == null) break;
      children.add(child);
    }
    return children;
  }
}

int _controlType(IUIAutomationElement element) {
  try {
    return element.currentControlType;
  } on WindowsException {
    return 0;
  }
}

String _name(IUIAutomationElement element) {
  final Pointer<Utf16> name;
  try {
    name = element.currentName;
  } on WindowsException {
    return '';
  }
  if (name.address == 0) return '';
  try {
    return name.toDartString();
  } finally {
    SysFreeString(name);
  }
}

/// Runs a COM [call] that hands back an object, wrapped by [wrap] and
/// released with [arena]. Null when the call failed or gave nothing.
T? _take<T extends IUnknown>(
  Arena arena,
  int Function(Pointer<Pointer<COMObject>> out) call,
  T Function(Pointer<COMObject> ptr) wrap,
) {
  final out = calloc<COMObject>();
  if (FAILED(call(out.cast())) || out.ref.isNull) {
    free(out);
    return null;
  }
  return arena.own(wrap(out));
}

/// The interface pointer itself, as COM calls take another object.
Pointer<COMObject> _raw(IUnknown object) =>
    object.ptr.cast<Pointer<COMObject>>().value;

extension on Arena {
  /// Releases the COM [object] with the rest of the arena, rather than
  /// whenever Dart collects it.
  T own<T extends IUnknown>(T object) => this.using(object, (o) {
    o
      ..detach()
      ..release();
    free(o.ptr);
  });
}
