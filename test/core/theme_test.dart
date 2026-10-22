import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/core/theme/app_theme.dart';
import 'package:study_reminder/features/settings/settings_controller.dart';

void main() {
  test('pure black only changes the dark theme', () {
    const accent = Color(0xFF5B5BD6);
    final black = buildTheme(accent, Brightness.dark, pureBlack: true);
    expect(black.colorScheme.surface, Colors.black);
    expect(black.scaffoldBackgroundColor, Colors.black);
    final light = buildTheme(accent, Brightness.light, pureBlack: true);
    expect(light.colorScheme.surface, isNot(Colors.black));
  });

  test('the system accent falls back to the first choice', () {
    const settings = AppSettings(accentIndex: AppSettings.systemAccent);
    const wallpaper = Color(0xFF00897B);
    expect(settings.accentWith(wallpaper), wallpaper);
    expect(settings.accentWith(null), accentChoices.first.color);
    expect(
      const AppSettings(accentIndex: 2).accentWith(wallpaper),
      accentChoices[2].color,
    );
  });
}
