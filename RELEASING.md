# Releasing

A release is a GitHub Release with the Android APK and the Windows installer
and zip, built and published by `.github/workflows/release.yml`.

## Cut a release

1. Set the new version in `pubspec.yaml`, for example `version: 1.2.0+1`,
   and merge that to `main`. Releases are numbered `X.Y.Z`; the number after
   `+` does not matter for them.
2. Tag the merge commit and push the tag:

   ```sh
   git checkout main && git pull
   git tag v1.2.0
   git push origin v1.2.0
   ```

   Or run **Release** from the Actions tab with the version `1.2.0`. It tags
   the commit it runs on.
3. The workflow checks that the tag matches `pubspec.yaml`, runs the tests,
   builds both apps and publishes the release.

A tag that does not match `pubspec.yaml` stops the run before anything is
built. Delete the tag on GitHub and here, fix the version, merge that, then
tag the new commit:

```sh
git push --delete origin v1.2.0
git tag -d v1.2.0
# fix pubspec.yaml, merge to main, then:
git checkout main && git pull
git tag v1.2.0
git push origin v1.2.0
```

A run from the Actions tab also stops if the tag already exists on another
commit. Re-running a failed run replaces the files of a release it already
made.

**Server first.** When a release changes `supabase/schema.sql`, run the new
SQL in the Supabase SQL editor before installing it on any device. Until
then, the new version's sync uploads are refused (for example the study
sessions the Study tab keeps), and they go through on their own once the SQL
has run.

## Where the files appear

On the repository's Releases page, as **Study Reminder 1.2.0**, with notes
made from the pull requests merged since the last release:

| File | For |
| --- | --- |
| `StudyReminder-1.2.0.apk` | The phone. Installs over the previous version. |
| `StudyReminder-Setup-1.2.0.exe` | The laptop. Installs for the current user, no admin needed, into `%LOCALAPPDATA%\Programs\Study Reminder`, with a Start menu shortcut. |
| `StudyReminder-1.2.0-windows.zip` | The laptop, without installing. Unzip and run `study_reminder.exe`. |

Every CI run on `main` and on pull requests also keeps an APK, a zip and an
installer for 30 days, as artifacts of the run. Those show a version like
`1.2.0-ci.57` in Settings > About.

## Things to know

- **Android signing.** The release APK is signed with the release key from
  the `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` secrets, and the run fails
  without them. Keep the same keystore for good: Android only installs an
  update signed with the same key.
- **Android version code.** Every build, CI or release, uses the minutes
  since 2025 as its version code, so a newer APK always installs over an
  older one. The number after `+` in `pubspec.yaml` is not used for it.
- **Windows SmartScreen.** The installer and the app are not code signed, so
  Windows warns the first time they run ("Windows protected your PC"). Click
  **More info**, then **Run anyway**. Browsers may also ask before keeping
  the download.
- **Updating on the laptop.** Run the new installer. If Study Reminder is
  running, Setup asks to quit it first, from its tray icon. Reminders and
  settings are kept. Uninstalling (Settings > Apps) also removes "Start with
  Windows".
