import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../reminders/domain/reminder.dart';
import '../settings_controller.dart';

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
                    const SizedBox(height: Gap.l),
                    Text('Accent colour', style: theme.textTheme.titleSmall),
                    const SizedBox(height: Gap.s),
                    Wrap(
                      spacing: Gap.m,
                      runSpacing: Gap.m,
                      children: [
                        for (final (i, choice) in accentChoices.indexed)
                          Tooltip(
                            message: choice.name,
                            excludeFromSemantics: true,
                            child: Semantics(
                              button: true,
                              selected: settings.accentIndex == i,
                              label: choice.name,
                              child: InkResponse(
                                onTap: () => controller.setAccent(i),
                                radius: 24,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: choice.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: settings.accentIndex == i
                                          ? scheme.onSurface
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: settings.accentIndex == i
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
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
            const Card(
              child: ListTile(
                leading: Icon(Icons.school_rounded),
                title: Text('Study Reminder'),
                subtitle: Text('Version 0.1.0'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
