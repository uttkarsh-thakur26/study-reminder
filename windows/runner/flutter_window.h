#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <vector>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Registers the global shortcuts with Windows, again if they already are.
  // Returns the names of those another app already holds.
  flutter::EncodableList RegisterHotkeys();

  // Gives the global shortcuts back to Windows.
  void UnregisterHotkeys();

  // Tells Dart that the shortcut with |id| was pressed.
  void OnHotkey(int id);

  // Shows the window, also from the tray, and brings it to the front.
  void BringToFront();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Dart turns the global shortcuts on and off here, and hears when one is
  // pressed. See lib/desktop/global_hotkeys.dart.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      hotkey_channel_;

  // The window the shortcuts are registered to. Kept, because GetHandle() is
  // already null by the time OnDestroy runs.
  HWND hotkey_window_ = nullptr;

  // The ids of the shortcuts registered now.
  std::vector<int> registered_hotkeys_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
