# Study Reminder

Study reminders, alarms and focus sessions that stay in sync between an Android phone and a Windows laptop.

## Highlights

- **Reminders and alarms** with flexible repeats: daily, weekdays, chosen days, every N days or weeks, monthly.
- **Quick add** in plain language, for example `Revise chemistry every Mon 7pm #chem`.
- **Offline first.** Every device keeps its own copy and schedules its own alarms, so they ring without internet.
- **Sync** through Supabase. Edits from both devices merge field by field, so nothing is lost.
- **Focus mode** that silences notifications and blocks distracting apps, switchable from either device.

## Tech

| Layer | Choice |
| --- | --- |
| App | Flutter (Android + Windows) |
| Local storage | Drift (SQLite) |
| State | Riverpod |
| Sync | Supabase (Postgres, auth, realtime) |

## Development

```sh
flutter pub get
dart run build_runner build   # regenerate database code after editing tables
flutter analyze
flutter test
flutter run -d windows        # or an Android device
```

To publish a release with the APK and the Windows installer, see [RELEASING.md](RELEASING.md).

## Project layout

```
lib/
  core/        database, sync clocks, time helpers, theme
  features/    reminders, subjects, focus, settings
  shell/       navigation that adapts to phone and desktop
test/          unit and widget tests
```

## Roadmap

| Milestone | Scope |
| --- | --- |
| M1 | Foundations: app shell, local database, design system |
| M2 | Android reminders: repeats, exact alarms, snooze, permission setup |
| M3 | Windows app: tray, start at login, notifications, shortcuts |
| M4 | Sync and pairing: account, outbox, live feed, QR pairing |
| M5 | Focus mode: Do Not Disturb, app and site blocking, remote switch |
| M6 | Study tools and release: focus timer, stats, widget, themes, installers |
