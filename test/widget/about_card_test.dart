import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/settings/ui/about_card.dart';

void main() {
  testWidgets('About shows the version, or dev in a local build', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AboutCard(),
              AboutCard(version: '1.2.0'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Study Reminder'), findsNWidgets(2));
    expect(find.text('Version dev'), findsOneWidget);
    expect(find.text('Version 1.2.0'), findsOneWidget);
  });
}
