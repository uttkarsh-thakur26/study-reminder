import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/updates/application/update_service.dart';
import 'package:study_reminder/features/updates/data/update_installer.dart';
import 'package:study_reminder/features/updates/domain/app_version.dart';
import 'package:study_reminder/features/updates/domain/update_info.dart';

Map<String, Object?> release(String tag, {List<String>? files}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/o/r/releases/tag/$tag',
  'body':
      "## What's Changed\n* Add the update prompt by @someone in https://x/1\n"
      '* Fix [breaks](https://x/2)\n\n**Full Changelog**: https://x/compare',
  'draft': false,
  'prerelease': false,
  'assets': [
    for (final f
        in files ??
            [
              'StudyReminder-${tag.substring(1)}.apk',
              'StudyReminder-Setup-${tag.substring(1)}.exe',
              'StudyReminder-${tag.substring(1)}-windows.zip',
            ])
      {'name': f, 'browser_download_url': 'https://dl/$f', 'size': 1234},
  ],
};

void main() {
  group('AppVersion', () {
    test('reads releases and CI builds', () {
      expect(AppVersion.tryParse('1.2.0'), const AppVersion(1, 2, 0));
      expect(AppVersion.tryParse('v1.10.3'), const AppVersion(1, 10, 3));
      expect(AppVersion.tryParse('1.2.0-ci.57'), const AppVersion(1, 2, 0));
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('dev'), isNull);
    });

    test('compares numbers, not text', () {
      expect(
        AppVersion.tryParse('1.10.0')! > AppVersion.tryParse('1.9.9')!,
        isTrue,
      );
      expect(
        AppVersion.tryParse('2.0.0')! > AppVersion.tryParse('1.99.99')!,
        isTrue,
      );
      expect(
        AppVersion.tryParse('1.2.0')! > AppVersion.tryParse('1.2.0-ci.4')!,
        isFalse,
      );
    });
  });

  group('UpdateInfo', () {
    test('picks the file for each device', () {
      final android = UpdateInfo.fromGitHub(
        release('v1.2.0'),
        UpdatePlatform.android,
      )!;
      expect(android.version, const AppVersion(1, 2, 0));
      expect(android.downloadUrl, 'https://dl/StudyReminder-1.2.0.apk');
      final windows = UpdateInfo.fromGitHub(
        release('v1.2.0'),
        UpdatePlatform.windows,
      )!;
      expect(windows.downloadUrl, 'https://dl/StudyReminder-Setup-1.2.0.exe');
      expect(windows.size, 1234);
    });

    test('has no file while the release has none for the device', () {
      final info = UpdateInfo.fromGitHub(
        release('v1.2.0', files: ['StudyReminder-1.2.0.apk']),
        UpdatePlatform.windows,
      )!;
      expect(info.downloadUrl, isNull);
    });

    test('skips drafts, pre-releases and odd tags', () {
      expect(
        UpdateInfo.fromGitHub({
          ...release('v1.2.0'),
          'prerelease': true,
        }, UpdatePlatform.android),
        isNull,
      );
      expect(
        UpdateInfo.fromGitHub(release('nightly'), UpdatePlatform.android),
        isNull,
      );
    });

    test('notes become plain lines', () {
      final info = UpdateInfo.fromGitHub(
        release('v1.2.0'),
        UpdatePlatform.android,
      )!;
      expect(info.notes, '• Add the update prompt\n• Fix breaks');
    });

    test('round-trips through settings', () {
      final info = UpdateInfo.fromGitHub(
        release('v1.2.0'),
        UpdatePlatform.android,
      )!;
      final back = UpdateInfo.decode(info.encode())!;
      expect(back.version, info.version);
      expect(back.downloadUrl, info.downloadUrl);
      expect(UpdateInfo.decode(''), isNull);
      expect(UpdateInfo.decode('not json'), isNull);
    });
  });

  group('UpdateService', () {
    late Map<String, String> store;
    late DateTime now;
    late int fetches;
    late Map<String, Object?>? latest;
    var failing = false;

    UpdateService service({String version = '1.1.0'}) => UpdateService(
      current: AppVersion.tryParse(version),
      platform: UpdatePlatform.android,
      fetch: (p) async {
        fetches++;
        if (failing) throw Exception('offline');
        return latest == null ? null : UpdateInfo.fromGitHub(latest!, p);
      },
      read: (k) async => store[k],
      write: (k, v) async => store[k] = v,
      now: () => now,
    );

    setUp(() {
      store = {};
      now = DateTime(2026, 11, 13, 9);
      fetches = 0;
      latest = release('v1.2.0');
      failing = false;
    });

    test('asks GitHub at most once a day', () async {
      final s = service();
      expect((await s.checkIfDue())!.version, const AppVersion(1, 2, 0));
      now = now.add(const Duration(hours: 23));
      await s.checkIfDue();
      expect(fetches, 1);
      now = now.add(const Duration(hours: 1));
      await s.checkIfDue();
      expect(fetches, 2);
    });

    test('prompts once a day until updated', () async {
      final s = service();
      expect(await s.toPrompt(), isNotNull);
      now = now.add(const Duration(hours: 5));
      expect(await s.toPrompt(), isNull);
      now = now.add(const Duration(hours: 19));
      expect(await s.toPrompt(), isNotNull);
    });

    test('says nothing when up to date or newer', () async {
      expect(await service(version: '1.2.0').toPrompt(), isNull);
      store.clear();
      expect(await service(version: '1.3.0-ci.9').toPrompt(), isNull);
    });

    test('a local build never checks', () async {
      final s = service(version: '');
      expect(s.enabled, isFalse);
      expect(await s.toPrompt(), isNull);
      expect(fetches, 0);
    });

    test('offline keeps what it knew and tries again next time', () async {
      final s = service();
      await s.checkIfDue();
      failing = true;
      now = now.add(const Duration(days: 1));
      expect((await s.checkIfDue())!.version, const AppVersion(1, 2, 0));
      expect(fetches, 2);
      now = now.add(const Duration(minutes: 5));
      await s.checkIfDue();
      expect(fetches, 3);
    });

    test('notifies once per version', () async {
      final s = service();
      expect(await s.toNotify(), isNotNull);
      now = now.add(const Duration(days: 2));
      expect(await s.toNotify(), isNull);
      latest = release('v1.3.0');
      now = now.add(const Duration(days: 1));
      expect((await s.toNotify())!.version, const AppVersion(1, 3, 0));
    });

    test('a clock set back still checks', () async {
      final s = service();
      await s.checkIfDue();
      now = now.subtract(const Duration(days: 3));
      await s.checkIfDue();
      expect(fetches, 2);
    });
  });

  group('Windows update script', () {
    test('waits for the app, runs Setup quietly, starts the app again', () {
      final script = windowsUpdateScript(
        appPid: 42,
        setup: r"C:\Users\O'Neil\AppData\Local\Temp\updates\StudyReminder-Setup-1.2.0.exe",
        app: r'C:\Users\x\AppData\Local\Programs\Study Reminder\study_reminder.exe',
      );
      expect(script, startsWith('Wait-Process -Id 42'));
      expect(script, contains(r"'C:\Users\O''Neil\AppData"));
      expect(script, contains("'/SILENT'"));
      expect(
        script,
        endsWith(
          r"Start-Process -FilePath 'C:\Users\x\AppData\Local\Programs\Study Reminder\study_reminder.exe'",
        ),
      );
    });

    test('encodes as UTF-16LE base64', () {
      expect(
        utf8.decode(
          base64Decode(encodePowerShell('ab')).where((b) => b != 0).toList(),
        ),
        'ab',
      );
      expect(base64Decode(encodePowerShell('ab')), [97, 0, 98, 0]);
    });
  });
}
