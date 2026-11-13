import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../desktop/desktop_integration.dart';
import '../../alerts/application/alert_providers.dart';
import '../../settings/ui/about_card.dart';
import '../application/update_providers.dart';
import '../data/update_installer.dart';
import '../domain/update_info.dart';

/// Asks whether to update to [update] now.
Future<void> showUpdatePrompt(BuildContext context, UpdateInfo update) async {
  final now = await showDialog<bool>(
    context: context,
    builder: (dialog) => _UpdatePrompt(update: update),
  );
  if (now == true && context.mounted) {
    await startUpdate(context, update);
  }
}

/// Downloads and installs [update], or opens its release page when this
/// copy can't install it itself.
Future<void> startUpdate(BuildContext context, UpdateInfo update) async {
  if (!UpdateInstaller.canInstall(update)) {
    await openReleasePage(update.pageUrl);
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateProgress(update: update),
  );
}

/// Opens [url] in the browser.
Future<void> openReleasePage(String url) async {
  if (url.isEmpty) return;
  try {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [url]);
    } else if (Platform.isAndroid) {
      await const MethodChannel('study_reminder/updates')
          .invokeMethod<void>('openUrl', {'url': url});
    }
  } on Object catch (e) {
    debugPrint('could not open $url: $e');
  }
}

class _UpdatePrompt extends StatelessWidget {
  const _UpdatePrompt({required this.update});

  final UpdateInfo update;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = appVersion.isEmpty ? 'dev' : appVersion;
    final self = UpdateInstaller.canInstall(update);
    return AlertDialog(
      icon: const Icon(Icons.system_update_rounded),
      title: Text('Version ${update.version} is out'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have $current. '
                '${self ? 'It downloads and installs from here, and your '
                          'reminders and settings stay.' : 'Get it from the download page.'}',
              ),
              if (update.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text("What's new", style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(update.notes, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(self ? 'Update now' : 'Open download page'),
        ),
      ],
    );
  }
}

enum _Stage { downloading, permission, installing, failed }

class _UpdateProgress extends ConsumerStatefulWidget {
  const _UpdateProgress({required this.update});

  final UpdateInfo update;

  @override
  ConsumerState<_UpdateProgress> createState() => _UpdateProgressState();
}

class _UpdateProgressState extends ConsumerState<_UpdateProgress> {
  var _stage = _Stage.downloading;
  double? _progress;
  String _error = '';
  File? _file;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final installer = ref.read(updateInstallerProvider);
    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
    });
    try {
      _file ??= await installer.download(
        widget.update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      await _install();
    } on Object catch (e) {
      debugPrint('update failed: $e');
      _file = null;
      if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _error = e is SocketException || e is TimeoutException
              ? 'No connection. Check the internet and try again.'
              : 'The download did not finish. Try again.';
        });
      }
    }
  }

  Future<void> _install() async {
    final installer = ref.read(updateInstallerProvider);
    final notifications = ref.read(localNotificationsProvider);
    setState(() => _stage = _Stage.installing);
    final result = await installer.install(
      _file!,
      quitApp: () => exitDesktopApp(notifications),
    );
    if (!mounted) return;
    switch (result) {
      case InstallStart.started:
        // Android shows its own installer on top; this closes behind it.
        Navigator.of(context).pop();
      case InstallStart.needsPermission:
        setState(() => _stage = _Stage.permission);
        // Back from Android's settings page: try again once.
        _lifecycle ??= AppLifecycleListener(
          onResume: () {
            if (_stage == _Stage.permission) unawaited(_install());
          },
        );
      case InstallStart.unsupported:
        Navigator.of(context).pop();
        await openReleasePage(widget.update.pageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.update.version;
    final (title, body) = switch (_stage) {
      _Stage.downloading => (
        'Downloading $version',
        _progress == null ? 'Starting…' : '${(_progress! * 100).round()}%',
      ),
      _Stage.installing => (
        'Installing $version',
        Platform.isWindows
            ? 'Study Reminder closes, updates and opens again by itself.'
            : 'Follow Android\'s installer to finish.',
      ),
      _Stage.permission => (
        'One-time permission',
        'Allow "Install unknown apps" for Study Reminder on the page that '
            'opened, then come back here. The update continues by itself.',
      ),
      _Stage.failed => ('Update failed', _error),
    };
    return AlertDialog(
      icon: Icon(
        _stage == _Stage.failed
            ? Icons.error_outline_rounded
            : Icons.system_update_rounded,
      ),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (_stage == _Stage.downloading || _stage == _Stage.installing) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _stage == _Stage.downloading ? _progress : null,
            ),
          ],
        ],
      ),
      actions: [
        if (_stage != _Stage.installing)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        if (_stage == _Stage.failed)
          FilledButton(onPressed: _run, child: const Text('Try again')),
        if (_stage == _Stage.permission)
          FilledButton(onPressed: _install, child: const Text('Continue')),
      ],
    );
  }
}
