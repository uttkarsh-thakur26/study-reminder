#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

#ifndef MOD_NOREPEAT
#define MOD_NOREPEAT 0x4000
#endif

// A system-wide shortcut. |name| is how Dart knows it, see GlobalHotkey in
// lib/desktop/global_hotkeys.dart.
struct Hotkey {
  int id;
  UINT modifiers;
  UINT key;
  const char* name;
  // Brought forward at once: Windows lets the app that owns a shortcut take
  // the front while it handles the press, so this does not wait for Dart.
  bool shows_window;
};

constexpr Hotkey kHotkeys[] = {
    {1, MOD_CONTROL | MOD_ALT, 'N', "quickAdd", true},
    {2, MOD_CONTROL | MOD_ALT, 'F', "focus", false},
};

const Hotkey* FindHotkey(int id) {
  for (const Hotkey& hotkey : kHotkeys) {
    if (hotkey.id == id) {
      return &hotkey;
    }
  }
  return nullptr;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  // Quit from the tray ends the message loop, and the window is destroyed
  // only after this, so OnDestroy does not run. Let go of the shortcuts and
  // the channel here, while the engine is still there.
  UnregisterHotkeys();
  if (hotkey_channel_) {
    hotkey_channel_->SetMethodCallHandler(nullptr);
  }
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // The shortcuts belong to this top-level window. Windows posts WM_HOTKEY to
  // it also while it is hidden in the tray.
  hotkey_window_ = GetHandle();
  hotkey_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "study_reminder/hotkeys",
          &flutter::StandardMethodCodec::GetInstance());
  hotkey_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "enable") {
          result->Success(flutter::EncodableValue(RegisterHotkeys()));
        } else if (call.method_name() == "disable") {
          UnregisterHotkeys();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (!StartsMinimized()) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  UnregisterHotkeys();
  if (hotkey_channel_) {
    hotkey_channel_->SetMethodCallHandler(nullptr);
    hotkey_channel_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

flutter::EncodableList FlutterWindow::RegisterHotkeys() {
  // Registering a shortcut this window already holds fails, for example
  // after a hot restart, so start from none.
  UnregisterHotkeys();
  flutter::EncodableList taken;
  for (const Hotkey& hotkey : kHotkeys) {
    if (hotkey_window_ != nullptr &&
        ::RegisterHotKey(hotkey_window_, hotkey.id,
                         hotkey.modifiers | MOD_NOREPEAT, hotkey.key)) {
      registered_hotkeys_.push_back(hotkey.id);
    } else {
      taken.push_back(flutter::EncodableValue(std::string(hotkey.name)));
    }
  }
  return taken;
}

void FlutterWindow::UnregisterHotkeys() {
  for (int id : registered_hotkeys_) {
    ::UnregisterHotKey(hotkey_window_, id);
  }
  registered_hotkeys_.clear();
}

void FlutterWindow::OnHotkey(int id) {
  const Hotkey* hotkey = FindHotkey(id);
  if (hotkey == nullptr || !hotkey_channel_) {
    return;
  }
  if (hotkey->shows_window) {
    BringToFront();
  }
  hotkey_channel_->InvokeMethod(
      "pressed",
      std::make_unique<flutter::EncodableValue>(std::string(hotkey->name)));
}

void FlutterWindow::BringToFront() {
  HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }
  ::ShowWindow(window, ::IsIconic(window) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(window);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // A global shortcut. Handled before the plugins, which have no use for it.
  if (message == WM_HOTKEY) {
    OnHotkey(static_cast<int>(wparam));
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
