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
  Completer<void>? _cancel;
  Future<void>? _downloading;

  @override
  void initState() {
    super.initState();
    _downloading = _run();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _cancel?.complete();
    super.dispose();
  }

  Future<void> _run() async {
    final installer = ref.read(updateInstallerProvider);
    final cancel = _cancel = Completer<void>();
    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
    });
    try {
      _file ??= await installer.download(
        widget.update,
        cancel: cancel.future,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } on Object catch (e) {
      debugPrint('update download failed: $e');
      _file = null;
      if (mounted && !cancel.isCompleted) {
        _fail(
          e is SocketException || e is TimeoutException
              ? 'No connection. Check the internet and try again.'
              : 'The download did not finish. Try again.',
        );
      }
      return;
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
    if (mounted) await _install();
  }

  void _fail(String message) => setState(() {
    _stage = _Stage.failed;
    _error = message;
  });

  /// Stops a running download before closing, so the next update starts
  /// with a clean download folder.
  Future<void> _close() async {
    _cancel?.complete();
    _cancel = null;
    await _downloading;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _install() async {
    final installer = ref.read(updateInstallerProvider);
    final notifications = ref.read(localNotificationsProvider);
    // The laptop app quits to update: during strict focus, ask first.
    if (Platform.isWindows &&
        !await mayQuitDuringFocus(context, ref, action: 'update')) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() => _stage = _Stage.installing);
    final InstallStart result;
    try {
      result = await installer.install(
        _file!,
        quitApp: () => exitDesktopApp(notifications),
      );
    } on Object catch (e) {
      debugPrint('update install failed: $e');
      if (mounted) _fail('The installer did not start. Try again.');
      return;
    }
    if (!mounted) return;
    switch (result) {
      case InstallStart.started:
        // Android shows its own installer on top; this closes behind it.
        Navigator.of(context).pop();
      case InstallStart.needsPermission:
        setState(() => _stage = _Stage.permission);
        // Back from Android's settings page: go on if it was allowed. If
        // not, stay here; Continue opens the page again.
        _lifecycle ??= AppLifecycleListener(
          onResume: () async {
            if (_stage != _Stage.permission) return;
            if (await installer.mayInstall() && mounted) {
              unawaited(_install());
            }
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
          TextButton(onPressed: _close, child: const Text('Cancel')),
        if (_stage == _Stage.failed)
          FilledButton(
            onPressed: () => _downloading = _file == null ? _run() : _install(),
            child: const Text('Try again'),
          ),
        if (_stage == _Stage.permission)
          FilledButton(onPressed: _install, child: const Text('Continue')),
      ],
    );
  }
}
