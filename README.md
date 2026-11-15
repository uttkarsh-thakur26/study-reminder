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
