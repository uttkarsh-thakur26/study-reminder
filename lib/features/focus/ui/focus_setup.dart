import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_guard/focus_guard.dart';

import '../../../core/theme/app_theme.dart';
import '../application/focus_providers.dart';
import '../domain/focus_prefs.dart';
import '../domain/laptop_block_rules.dart';

/// What the user has allowed Focus mode to do on this phone.
final focusAccessProvider = FutureProvider.autoDispose<FocusGuardAccess?>(
  (ref) async => ref.watch(focusGuardProvider)?.access(),
);

/// The apps on this phone the user can block, by name.
final installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>(
  (ref) async => await ref.watch(focusGuardProvider)?.installedApps() ?? [],
);

final appIconProvider = FutureProvider.autoDispose.family<Uint8List?, String>((
  ref,
  packageName,
) async {
  final icon = await ref.watch(focusGuardProvider)?.icon(packageName);
  ref.keepAlive();
  return icon;
});

/// The phone's permissions for Focus mode, each with a way to grant it.
/// Checked again whenever the user comes back from system settings.
class PhoneAccessCard extends ConsumerStatefulWidget {
  const PhoneAccessCard({super.key});

  @override
  ConsumerState<PhoneAccessCard> createState() => _PhoneAccessCardState();
}

class _PhoneAccessCardState extends ConsumerState<PhoneAccessCard> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(focusAccessProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final access = ref.watch(focusAccessProvider).value;
    final guard = ref.watch(focusGuardProvider);
    if (access == null || guard == null) return const SizedBox.shrink();

    Widget row(
      IconData icon,
      String title,
      String why,
      bool granted,
      FocusGuardPage page,
    ) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(why),
      trailing: granted
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : FilledButton.tonal(
              onPressed: () => guard.open(page),
              child: const Text('Allow'),
            ),
    );

    final restricted = !access.usage || !access.overlay || !access.media;
    return Card(
      child: Column(
        children: [
          row(
            Icons.query_stats_rounded,
            'Usage access',
            'See which app is open',
            access.usage,
            FocusGuardPage.usage,
          ),
          row(
            Icons.layers_rounded,
            'Display over other apps',
            'Cover a blocked app',
            access.overlay,
            FocusGuardPage.overlay,
          ),
          row(
            Icons.music_off_rounded,
            'Notification access',
            'Pause blocked apps playing in the background',
            access.media,
            FocusGuardPage.media,
          ),
          row(
            Icons.do_not_disturb_on_rounded,
            'Do Not Disturb access',
            'Silence notifications during focus',
            access.quiet,
            FocusGuardPage.quiet,
          ),
          row(
            Icons.battery_charging_full_rounded,
            'Unrestricted battery',
            'Start right away when the laptop starts a session',
            access.battery,
            FocusGuardPage.battery,
          ),
          if (restricted)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text:
                            'Setting greyed out? Android limits it for apps '
                            'installed outside the Play Store. In App info, '
                            'tap the menu at the top right, choose Allow '
                            'restricted settings, then try again. ',
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: InkWell(
                              onTap: () => guard.open(FocusGuardPage.appInfo),
                              child: Text(
                                'Open App info',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AppIcon extends ConsumerWidget {
  const _AppIcon(this.packageName);

  final String packageName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(appIconProvider(packageName)).value;
    return SizedBox.square(
      dimension: 36,
      child: bytes == null
          ? const Icon(Icons.apps_rounded)
          : Image.memory(bytes, gaplessPlayback: true),
    );
  }
}

/// The apps this phone blocks during focus.
class PhoneBlockListCard extends ConsumerWidget {
  const PhoneBlockListCard({super.key, required this.prefs});

  final FocusPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(installedAppsProvider).value;
    final names = {
      for (final a in apps ?? const <InstalledApp>[]) a.packageName: a.label,
    };
    final repo = ref.read(focusRepositoryProvider);
    final chosen = prefs.phoneApps.toList()
      ..sort(
        (a, b) => (names[a] ?? a).toLowerCase().compareTo(
          (names[b] ?? b).toLowerCase(),
        ),
      );

    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Blocked apps'),
            trailing: TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _AppPicker(),
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Choose'),
            ),
          ),
          for (final p in chosen)
            ListTile(
              leading: _AppIcon(p),
              title: Text(names[p] ?? p),
              subtitle: apps != null && !names.containsKey(p)
                  ? const Text('Not installed')
                  : null,
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => repo.savePrefs(
                  prefs.copyWith(phoneApps: {...prefs.phoneApps}..remove(p)),
                ),
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.sports_esports_rounded),
            title: const Text('Also block games'),
            value: prefs.blockGames,
            onChanged: (v) => repo.savePrefs(prefs.copyWith(blockGames: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screen_rotation_alt_rounded),
            title: const Text('Flip to focus'),
            subtitle: const Text(
              'With the app open, put the phone down screen first to start',
            ),
            value: prefs.flipToFocus,
            onChanged: (v) => repo.savePrefs(prefs.copyWith(flipToFocus: v)),
          ),
        ],
      ),
    );
  }
}

class _AppPicker extends ConsumerStatefulWidget {
  const _AppPicker();

  @override
  ConsumerState<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends ConsumerState<_AppPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(installedAppsProvider);
    final prefs = ref.watch(focusPrefsProvider).value ?? const FocusPrefs();
    final repo = ref.read(focusRepositoryProvider);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final a in apps.value ?? const <InstalledApp>[])
        if (q.isEmpty || a.label.toLowerCase().contains(q)) a,
    ];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search apps',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: apps.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final a = shown[i];
                      final on = prefs.phoneApps.contains(a.packageName);
                      return CheckboxListTile(
                        secondary: _AppIcon(a.packageName),
                        title: Text(a.label),
                        subtitle: a.isGame ? const Text('Game') : null,
                        value: on,
                        onChanged: (v) {
                          final next = {...prefs.phoneApps};
                          v == true
                              ? next.add(a.packageName)
                              : next.remove(a.packageName);
                          repo.savePrefs(prefs.copyWith(phoneApps: next));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The programs and sites this laptop blocks during focus.
class LaptopBlockListCard extends ConsumerWidget {
  const LaptopBlockListCard({super.key, required this.prefs});

  final FocusPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repo = ref.read(focusRepositoryProvider);

    Widget chips(
      List<String> items,
      void Function(List<String>) save,
      VoidCallback add,
    ) => Wrap(
      spacing: Gap.s,
      runSpacing: Gap.s,
      children: [
        for (final item in items)
          InputChip(
            label: Text(item),
            onDeleted: () => save([...items]..remove(item)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded),
          label: const Text('Add'),
          onPressed: add,
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blocked programs', style: theme.textTheme.titleSmall),
            const SizedBox(height: Gap.xs),
            Text(
              'Minimised when opened, or closed in a strict session.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.m),
            chips(
              prefs.laptopApps,
              (v) => repo.savePrefs(prefs.copyWith(laptopApps: v)),
              () => _addProgram(context, ref),
            ),
            const SizedBox(height: Gap.xl),
            Text('Blocked sites', style: theme.textTheme.titleSmall),
            const SizedBox(height: Gap.xs),
            Text(
              'Their tabs close in any browser. Sites are recognised by the '
              'page title, which names the site on most pages.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.m),
            chips(
              prefs.sites,
              (v) => repo.savePrefs(prefs.copyWith(sites: v)),
              () => _addSite(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProgram(BuildContext context, WidgetRef ref) async {
    List<String> open;
    try {
      open = ref.read(desktopWindowsProvider)?.openPrograms() ?? const [];
    } on Object catch (e) {
      debugPrint('focus: could not list open programs: $e');
      open = const [];
    }
    final suggestions = open
        .where((p) => !prefs.laptopApps.contains(p))
        .toList();
    final added = await showDialog<String>(
      context: context,
      builder: (_) => _AddDialog(
        title: 'Block a program',
        hint: 'For example discord.exe',
        suggestionsLabel: 'Open now',
        suggestions: suggestions,
        normalize: normalizeProgram,
        problem: 'Type the program file name, like discord.exe',
      ),
    );
    if (added == null || prefs.laptopApps.contains(added)) return;
    await ref
        .read(focusRepositoryProvider)
        .savePrefs(prefs.copyWith(laptopApps: [...prefs.laptopApps, added]));
  }

  Future<void> _addSite(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<String>(
      context: context,
      builder: (_) => const _AddDialog(
        title: 'Block a site',
        hint: 'For example netflix.com',
        normalize: normalizeSite,
        problem: 'Type an address, like netflix.com',
      ),
    );
    if (added == null || prefs.sites.contains(added)) return;
    await ref
        .read(focusRepositoryProvider)
        .savePrefs(prefs.copyWith(sites: [...prefs.sites, added]));
  }
}

class _AddDialog extends StatefulWidget {
  const _AddDialog({
    required this.title,
    required this.hint,
    required this.normalize,
    required this.problem,
    this.suggestionsLabel = '',
    this.suggestions = const [],
  });

  final String title;
  final String hint;
  final String? Function(String) normalize;
  final String problem;
  final String suggestionsLabel;
  final List<String> suggestions;

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.normalize(_text.text);
    if (value == null) {
      setState(() => _error = widget.problem);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.suggestions.isNotEmpty) ...[
              const SizedBox(height: Gap.l),
              Text(widget.suggestionsLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: Gap.s),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: Gap.s,
                    runSpacing: Gap.s,
                    children: [
                      for (final s in widget.suggestions)
                        ActionChip(
                          label: Text(s),
                          onPressed: () => Navigator.pop(context, s),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
