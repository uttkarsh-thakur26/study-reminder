import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';

abstract final class SettingKeys {
  static const deviceId = 'device_id';
  static const themeMode = 'theme_mode';
  static const accent = 'accent';
}

@immutable
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.system, this.accentIndex = 0});

  final ThemeMode themeMode;
  final int accentIndex;

  Color get accent =>
      accentChoices[accentIndex.clamp(0, accentChoices.length - 1)].color;

  AppSettings copyWith({ThemeMode? themeMode, int? accentIndex}) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accentIndex: accentIndex ?? this.accentIndex,
  );

  static Future<AppSettings> load(AppDatabase db) async {
    final mode = await db.readSetting(SettingKeys.themeMode);
    final accent = await db.readSetting(SettingKeys.accent);
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[mode] ?? ThemeMode.system,
      accentIndex: int.tryParse(accent ?? '') ?? 0,
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
}
