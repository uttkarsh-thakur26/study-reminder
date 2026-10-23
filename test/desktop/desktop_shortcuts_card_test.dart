import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/desktop/desktop_shortcuts_card.dart';
import 'package:study_reminder/desktop/global_hotkeys.dart';

class _FakeHotkeys extends GlobalHotkeys {
  _FakeHotkeys(this.initial);

  final GlobalHotkeysState initial;
  final changes = <bool>[];

  @override
  Future<GlobalHotkeysState> build() async => initial;

  @override
  Future<void> setEnabled(bool on) async {
    changes.add(on);
    state = AsyncData(GlobalHotkeysState(enabled: on));
  }
}

void main() {
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  /// The Settings section. The tests that use it run as on Windows.
  Future<_FakeHotkeys> pump(
    WidgetTester tester,
    GlobalHotkeysState initial,
  ) async {
    final fake = _FakeHotkeys(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [globalHotkeysProvider.overrideWith(() => fake)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DesktopShortcutsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('lists both shortcuts and warns about a taken one', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      const GlobalHotkeysState(enabled: true, taken: {GlobalHotkey.quickAdd}),
    );
    expect(find.text('Ctrl+Alt+N'), findsOneWidget);
    expect(find.text('Ctrl+Alt+F'), findsOneWidget);
    expect(find.text('Ctrl+Alt+N is taken by another app'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(fake.changes, [false]);
    // Off, nothing is taken.
    expect(find.textContaining('taken by another app'), findsNothing);
  }, variant: windows);

  testWidgets('no warning when Windows gave both', (tester) async {
    await pump(tester, const GlobalHotkeysState(enabled: true));
    expect(find.text('SHORTCUTS'), findsOneWidget);
    expect(find.textContaining('taken by another app'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  }, variant: windows);

  testWidgets('the section is left out on the phone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DesktopShortcutsSection())),
    );
    expect(find.text('SHORTCUTS'), findsNothing);
  });
}
