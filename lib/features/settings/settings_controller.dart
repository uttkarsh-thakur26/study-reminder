import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';

abstract final class SettingKeys {
  static const deviceId = 'device_id';
  static const themeMode = 'theme_mode';
  static const accent = 'accent';
  static const pureBlack = 'pure_black';
}

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.accentIndex = 0,
    this.pureBlack = false,
  });

  /// [accentIndex] for the device's own accent colour.
  static const systemAccent = -1;

  final ThemeMode themeMode;

  /// One of [accentChoices], or [systemAccent].
  final int accentIndex;

  /// A black background in the dark theme, for OLED screens.
  final bool pureBlack;

  bool get usesSystemAccent => accentIndex == systemAccent;

  /// The accent to build the theme from; [system] is the device's own, for
  /// [systemAccent], and the first choice stands in when there is none.
  Color accentWith(Color? system) => usesSystemAccent
      ? system ?? accentChoices.first.color
      : accentChoices[accentIndex.clamp(0, accentChoices.length - 1)].color;

  Color get accent => accentWith(null);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? accentIndex,
    bool? pureBlack,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accentIndex: accentIndex ?? this.accentIndex,
    pureBlack: pureBlack ?? this.pureBlack,
  );

  static Future<AppSettings> load(AppDatabase db) async {
    final mode = await db.readSetting(SettingKeys.themeMode);
    final accent = await db.readSetting(SettingKeys.accent);
    final black = await db.readSetting(SettingKeys.pureBlack);
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[mode] ?? ThemeMode.system,
      accentIndex: int.tryParse(accent ?? '') ?? 0,
      pureBlack: black == 'true',
    );
  }
}

/// Settings read before the first frame, so the theme never flashes.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _db.writeSetting(SettingKeys.themeMode, mode.name);
  }

  Future<void> setAccent(int index) async {
    state = state.copyWith(accentIndex: index);
    await _db.writeSetting(SettingKeys.accent, '$index');
  }

  Future<void> setPureBlack(bool on) async {
    state = state.copyWith(pureBlack: on);
    await _db.writeSetting(SettingKeys.pureBlack, '$on');
  }
}
