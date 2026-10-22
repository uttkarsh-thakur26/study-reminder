# focus_guard

The Android side of Study Reminder's Focus mode, as a plugin so it also works
from the background sync task:

- Do Not Disturb while a session runs (needs Do Not Disturb access).
- A foreground service that sends blocked apps back to a "stay focused"
  screen (needs Usage access and Display over other apps).
- An exact alarm that ends the session on time, and a boot receiver that
  restores it after a restart.
- Face-down detection for flip to focus.
