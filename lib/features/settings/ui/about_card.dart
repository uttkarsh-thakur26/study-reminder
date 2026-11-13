import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../updates/application/update_providers.dart';
import '../../updates/domain/update_info.dart';
import '../../updates/ui/update_dialog.dart';

/// The version CI and release builds pass in with
/// `--dart-define=APP_VERSION=1.2.0`. Empty in a local build.
const appVersion = String.fromEnvironment('APP_VERSION');

/// Settings: the app's name, the version of this build, and a check for a
/// newer one.
class AboutCard extends ConsumerStatefulWidget {
  const AboutCard({super.key, this.version = appVersion});

  final String version;

  @override
  ConsumerState<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends ConsumerState<AboutCard> {
  var _checking = false;
  String? _status;
  UpdateInfo? _update;

  @override
  void initState() {
    super.initState();
    final service = ref.read(updateServiceProvider);
    if (!service.enabled) return;
    // The update the daily check already found, if any.
    service.available().then((u) {
      if (mounted && u != null) setState(() => _update = u);
    });
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
    });
    try {
      final update = await ref.read(updateServiceProvider).checkNow();
      if (!mounted) return;
      setState(() {
        _update = update;
        _status = update == null ? 'You have the latest version.' : null;
      });
    } on Object {
      if (mounted) {
        setState(() => _status = "Couldn't reach GitHub. Try again later.");
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.version;
    final enabled = ref.watch(updateServiceProvider).enabled;
    final update = _update;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.school_rounded),
            title: const Text('Study Reminder'),
            subtitle: Text('Version ${version.isEmpty ? 'dev' : version}'),
            trailing: !enabled || update != null
                ? null
                : _checking
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : TextButton(
                    onPressed: _check,
                    child: const Text('Check for updates'),
                  ),
          ),
          if (update != null)
            ListTile(
              leading: const Icon(Icons.system_update_rounded),
              title: Text('Version ${update.version} is available'),
              trailing: FilledButton(
                onPressed: () => showUpdatePrompt(context, update),
                child: const Text('Update'),
              ),
            )
          else if (_status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _status!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
