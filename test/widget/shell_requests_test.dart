import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/app/app.dart';
import 'package:study_reminder/app/providers.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/shell/app_shell.dart';
import 'package:study_reminder/shell/shell_requests.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late AppDatabase db;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  testWidgets('a global shortcut opens quick add or the Focus page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test-device'),
          hlcClockProvider.overrideWithValue(HlcClock('testdevice01')),
          initialTimeZoneProvider.overrideWithValue('Asia/Kolkata'),
          minuteTickProvider.overrideWith(
            (ref) => Stream.value(DateTime.now()),
          ),
        ],
        child: const StudyReminderApp(),
      ),
    );
    await tester.pumpAndSettle();
    final requests = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    ).read(shellRequestsProvider.notifier);

    // From another page, and twice in a row.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      requests.send(ShellRequest.quickAdd);
      await tester.pumpAndSettle();
      expect(find.text('A clear day'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'quick-add');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    requests.send(ShellRequest.focus);
    await tester.pumpAndSettle();
    expect(find.text('Start focus'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
