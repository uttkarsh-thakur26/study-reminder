import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/system_accent.dart';
import '../../../core/ui/empty_state.dart';
import '../../../desktop/desktop_shortcuts_card.dart';
import '../../alerts/ui/alert_health.dart';
import '../../reminders/domain/reminder.dart';
import '../../sync/ui/sync_card.dart';
import '../settings_controller.dart';
import 'about_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final device = ref.watch(deviceKindProvider);
    final zone = ref.watch(deviceTimeZoneProvider);
    final system = ref.watch(systemAccentProvider);
    final swatches = <({int index, String name, Color color})>[
      if (system != null)
        (
          index: AppSettings.systemAccent,
          name: device == DeviceKind.phone ? 'Wallpaper' : 'Windows accent',
          color: system,
        ),
      for (final (i, c) in accentChoices.indexed)
        (index: i, name: c.name, color: c.color),
    ];

    return SafeArea(
      bottom: false,
      child: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, Gap.l, 96),
          children: [
            Text('Settings', style: theme.textTheme.headlineMedium),
            const SectionHeader('APPEARANCE'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: theme.textTheme.titleSmall),
                    const SizedBox(height: Gap.s),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded),
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (s) =>
                            controller.setThemeMode(s.first),
                      ),
                    ),
                    if (settings.themeMode != ThemeMode.light)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pure black'),
                        subtitle: const Text(
                          'A black dark theme, easier on OLED screens',
                        ),
                        value: settings.pureBlack,
                        onChanged: controller.setPureBlack,
                      )
                    else
                      const SizedBox(height: Gap.s),
                    const SizedBox(height: Gap.s),
                    Text('Accent colour', style: theme.textTheme.titleSmall),
                    const SizedBox(height: Gap.s),
                    Wrap(
                      spacing: Gap.m,
                      runSpacing: Gap.m,
                      children: [
                        for (final (:index, :name, :color) in swatches)
                          Tooltip(
                            message: name,
                            excludeFromSemantics: true,
                            child: Semantics(
                              button: true,
                              selected: settings.accentIndex == index,
                              label: name,
                              child: InkResponse(
                                onTap: () => controller.setAccent(index),
                                radius: 24,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: settings.accentIndex == index
                                          ? scheme.onSurface
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: Icon(
                                    settings.accentIndex == index
                                        ? Icons.check_rounded
                                        : index == AppSettings.systemAccent
                                        ? Icons.auto_awesome_rounded
                                        : null,
                                    color:
                                        ThemeData.estimateBrightnessForColor(
                                              color,
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SectionHeader('SYNC'),
            const SyncCard(),
            const SectionHeader('ALERTS'),
            const AlertHealthCard(),
            const DesktopShortcutsSection(),
            const SectionHeader('THIS DEVICE'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      device == DeviceKind.phone
                          ? Icons.smartphone_rounded
                          : Icons.laptop_rounded,
                    ),
                    title: Text(
                      device == DeviceKind.phone ? 'Phone' : 'Laptop',
                    ),
                    subtitle: Text(
                      device == DeviceKind.phone
                          ? 'Rings for reminders set to Phone or Both'
                          : 'Rings for reminders set to Laptop or Both',
                    ),
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.public_rounded),
                    title: const Text('Time zone'),
                    subtitle: Text(zone),
                  ),
                ],
              ),
            ),
            const SectionHeader('ABOUT'),
            const AboutCard(),
          ],
        ),
      ),
    );
  }
}
