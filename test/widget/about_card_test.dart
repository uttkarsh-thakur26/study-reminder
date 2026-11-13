import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/settings/ui/about_card.dart';
import 'package:study_reminder/features/updates/application/update_providers.dart';
import 'package:study_reminder/features/updates/application/update_service.dart';
import 'package:study_reminder/features/updates/domain/app_version.dart';
import 'package:study_reminder/features/updates/domain/update_info.dart';

UpdateService _service(String version, {UpdateInfo? latest}) {
  final store = <String, String>{
    if (latest != null) UpdateKeys.latest: latest.encode(),
  };
  return UpdateService(
    current: AppVersion.tryParse(version),
    platform: UpdatePlatform.android,
    fetch: (_) async => latest,
    read: (k) async => store[k],
    write: (k, v) async => store[k] = v,
  );
}

Widget _app(UpdateService service, List<Widget> cards) => ProviderScope(
  overrides: [updateServiceProvider.overrideWithValue(service)],
  child: MaterialApp(
    home: Scaffold(body: Column(children: cards)),
  ),
);

void main() {
  testWidgets('About shows the version, or dev in a local build', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_service(''), const [AboutCard(), AboutCard(version: '1.2.0')]),
    );
    expect(find.text('Study Reminder'), findsNWidgets(2));
    expect(find.text('Version dev'), findsOneWidget);
    expect(find.text('Version 1.2.0'), findsOneWidget);
    // A local build has nothing to compare, so no check.
    expect(find.text('Check for updates'), findsNothing);
  });

  testWidgets('About offers an update the daily check found', (tester) async {
    const newer = UpdateInfo(
      version: AppVersion(1, 2, 0),
      notes: '',
      pageUrl: '',
      downloadUrl: 'https://dl/StudyReminder-1.2.0.apk',
      size: 0,
    );
    await tester.pumpWidget(
      _app(_service('1.1.0', latest: newer), const [
        AboutCard(version: '1.1.0'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version 1.2.0 is available'), findsOneWidget);
  });

  testWidgets('About checks on request', (tester) async {
    await tester.pumpWidget(
      _app(_service('1.2.0'), const [AboutCard(version: '1.2.0')]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('You have the latest version.'), findsOneWidget);
  });
}
