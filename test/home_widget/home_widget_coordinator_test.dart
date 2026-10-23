import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/app/app.dart';
import 'package:study_reminder/app/providers.dart';
import 'package:study_reminder/core/db/app_database.dart';
import 'package:study_reminder/core/sync/hlc.dart';
import 'package:study_reminder/features/home_widget/application/home_widget_providers.dart';
import 'package:study_widget/study_widget.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The widget without Android: records what the app sends it and plays
/// taps on its "+".
class FakeStudyWidget implements StudyWidget {
  final sent = <StudyWidgetData>[];
  final _taps = StreamController<void>.broadcast();
  StudyWidgetRequest? _pending;

  /// The "+" was tapped before the app started.
  void tappedBeforeStart() => _pending = StudyWidgetRequest.quickAdd;

  /// The "+" was tapped while the app runs.
  void tap() {
    _pending = StudyWidgetRequest.quickAdd;
    _taps.add(null);
  }

  @override
  Future<void> update(StudyWidgetData data) async => sent.add(data);

  @override
  Future<StudyWidgetRequest?> takeRequest() async {
    final request = _pending;
    _pending = null;
    return request;
  }

  @override
  Stream<void> requests() => _taps.stream;
}

void main() {
  late AppDatabase db;
  late FakeStudyWidget home;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    home = FakeStudyWidget();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
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
          studyWidgetProvider.overrideWithValue(home),
        ],
        child: const StudyReminderApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  bool quickAddFocused() =>
      FocusManager.instance.primaryFocus?.debugLabel == 'quick-add';

  testWidgets('the "+" that started the app opens quick add', (tester) async {
    home.tappedBeforeStart();
    await pumpApp(tester);
    expect(quickAddFocused(), isTrue);
    await tearDownApp(tester);
  });

  testWidgets('the "+" opens quick add on Today while the app runs', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(quickAddFocused(), isFalse);

    home.tap();
    await tester.pumpAndSettle();
    expect(quickAddFocused(), isTrue);
    expect(find.text('A clear day'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('a new reminder reaches the widget once, shortly after', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(home.sent.last.items, isEmpty);

    await tester.enterText(
      find.byType(TextField).first,
      'Revise physics tomorrow 9am',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    final item = home.sent.last.items.single;
    expect(item.title, 'Revise physics');
    expect(item.at.hour, 9);
    // Nothing new to show, nothing sent again.
    final count = home.sent.length;
    await tester.pump(const Duration(seconds: 1));
    expect(home.sent.length, count);
    await tearDownApp(tester);
  });
}
