import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/app/app.dart';
import 'package:study_reminder/app/providers.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/features/reminders/domain/occurrence.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late AppDatabase db;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(420, 900),
  }) async {
    tester.view.physicalSize = size;
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
  }

  // Drift does real async work, which never completes inside the fake clock
  // of a widget test, so direct database calls run through runAsync.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  testWidgets('quick add creates a reminder that shows on Today', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('A clear day'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Revise physics today 11:59pm',
    );
    await tester.pump();
    expect(find.text('Today'), findsWidgets); // preview chip
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Revise physics'), findsOneWidget);
    final rows = await real(tester, () => db.select(db.reminders).get());
    expect(rows.single.title, 'Revise physics');
    expect(rows.single.minuteOfDay, 23 * 60 + 59);
    await tearDownApp(tester);
  });

  testWidgets('tapping the circle marks an occurrence done', (tester) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byType(TextField).first,
      'Read chapter 2 today 11:59pm',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark as done'));
    await tester.pumpAndSettle();
    expect(find.text('DONE'), findsOneWidget);
    final states = await real(tester, () => db.select(db.occurrences).get());
    expect(states.single.status, OccurrenceStatus.done.name);
    await tearDownApp(tester);
  });

  testWidgets('the editor creates a weekly alarm', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('New reminder'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'What do you need to study?'),
      'Chemistry lab',
    );
    await tester.tap(find.text('Alarm'));
    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekdays (Mon to Fri)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();

    final row = (await real(
      tester,
      () => db.select(db.reminders).get(),
    )).single;
    expect(row.title, 'Chemistry lab');
    expect(row.style, 'alarm');
    expect(row.repeatKind, 'weekly');
    expect(row.repeatWeekdays, 0x1f);
    await tearDownApp(tester);
  });

  testWidgets('wide layout shows the side rail and switches pages', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('New reminder'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Accent colour'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('keyboard shortcuts keep working after a quick add', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 800));
    await tester.enterText(
      find.byType(TextField).first,
      'Revise physics today 11:59pm',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Accent colour'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('saving an untouched reminder keeps its repeat interval', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byType(TextField).first,
      'Maths every 2 months 11:59pm',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maths'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final row = (await real(
      tester,
      () => db.select(db.reminders).get(),
    )).single;
    expect(row.repeatKind, 'monthly');
    expect(row.repeatInterval, 2);
    await tearDownApp(tester);
  });
}
