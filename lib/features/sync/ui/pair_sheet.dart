import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../reminders/domain/reminder.dart';
import '../application/sync_providers.dart';
import '../data/sync_api.dart';
import '../domain/sync_record.dart';
import 'qr_scan_page.dart';
import 'sync_card.dart';

/// Opens pairing as a bottom sheet on phones and a dialog on wide screens.
Future<void> openPairSheet(BuildContext context) {
  const sheet = PairSheet();
  if (isWide(context)) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(Gap.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: sheet,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: sheet,
    ),
  );
}

enum _Mode { show, enter }

/// Pairs this device with another: either shows a code (and QR) for the
/// other device, or takes the code the other device shows.
class PairSheet extends ConsumerStatefulWidget {
  const PairSheet({super.key});

  @override
  ConsumerState<PairSheet> createState() => _PairSheetState();
}

class _PairSheetState extends ConsumerState<PairSheet> {
  late _Mode _mode;

  @override
  void initState() {
    super.initState();
    // The laptop usually shows the code and the phone scans it.
    _mode = ref.read(deviceKindProvider) == DeviceKind.phone
        ? _Mode.enter
        : _Mode.show;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pair a device', style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.xs),
          Text(
            'Reminders, subjects and alarms are kept on both devices, and '
            'nothing on either one is lost.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.l),
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(
                value: _Mode.show,
                icon: Icon(Icons.qr_code_2_rounded),
                label: Text('Show a code'),
              ),
              ButtonSegment(
                value: _Mode.enter,
                icon: Icon(Icons.keyboard_rounded),
                label: Text('Enter a code'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: Gap.l),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topCenter,
            child: switch (_mode) {
              _Mode.show => const _ShowCode(),
              _Mode.enter => const _EnterCode(),
            },
          ),
        ],
      ),
    );
  }
}

String _problemText(Object e) => switch (e) {
  PairingException(problem: PairingProblem.wrongCode) =>
    'That code did not work. Check it, or make a new one on the other device.',
  PairingException(problem: PairingProblem.tooManyTries) =>
    'Too many tries. Wait 10 minutes and try again.',
  _ => 'Could not reach the sync server. Check the internet connection.',
};

/// Shows a fresh code and its QR, counts down to its expiry, and notices
/// when the other device has joined.
class _ShowCode extends ConsumerStatefulWidget {
  const _ShowCode();

  @override
  ConsumerState<_ShowCode> createState() => _ShowCodeState();
}

class _ShowCodeState extends ConsumerState<_ShowCode> {
  PairingCode? _code;
  Object? _error;
  Set<String>? _known;
  SyncedDevice? _joined;
  Timer? _tick;
  int _polls = 0;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _newCode();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _newCode() async {
    final service = ref.read(syncServiceProvider);
    if (service == null) return;
    setState(() {
      _code = null;
      _error = null;
    });
    try {
      final devices = await service.devices();
      final code = await service.createPairingCode();
      if (!mounted) return;
      setState(() {
        _known = {for (final d in devices) d.id};
        _code = code;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {}); // the countdown
    final code = _code;
    if (code == null || _joined != null || _expired(code)) return;
    // Every 3 seconds, look for a device that was not there before. One
    // look at a time, so a slow connection cannot pile them up.
    if (++_polls % 3 == 0 && !_polling) unawaited(_lookForNewDevice());
  }

  bool _expired(PairingCode code) => !DateTime.now().isBefore(code.expiresAt);

  Future<void> _lookForNewDevice() async {
    final known = _known;
    final service = ref.read(syncServiceProvider);
    if (known == null || service == null) return;
    _polling = true;
    try {
      final devices = await service.devices();
      final fresh = devices.where((d) => !known.contains(d.id)).firstOrNull;
      if (fresh == null || !mounted) return;
      setState(() => _joined = fresh);
      ref.invalidate(syncedDevicesProvider);
      unawaited(ref.read(syncStatusProvider.notifier).syncNow());
    } on SyncUnavailable {
      // Try again on the next poll.
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final joined = _joined;
    if (joined != null) {
      return _Done(
        title: 'Paired with ${joined.name}',
        detail: 'Everything is syncing now.',
      );
    }
    if (_error != null) {
      return _Problem(text: _problemText(_error!), onRetry: _newCode);
    }
    final code = _code;
    if (code == null) {
      return const Padding(
        padding: EdgeInsets.all(Gap.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final left = code.expiresAt.difference(DateTime.now());
    final expired = left.isNegative || left == Duration.zero;
    final mm = left.inMinutes;
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: expired ? 0.2 : 1,
          child: Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: code.qrText,
              size: 200,
              padding: EdgeInsets.zero,
              semanticsLabel: 'Pairing QR code',
            ),
          ),
        ),
        const SizedBox(height: Gap.l),
        SelectableText(
          code.display,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Gap.s),
        Text(
          expired
              ? 'This code has expired.'
              : 'On the other device, open Settings, then Pair a device, and '
                    'scan this or type the code. Expires in $mm:$ss.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (expired) ...[
          const SizedBox(height: Gap.m),
          FilledButton.tonal(
            onPressed: _newCode,
            child: const Text('New code'),
          ),
        ],
      ],
    );
  }
}

/// Takes the code the other device shows, typed or scanned.
class _EnterCode extends ConsumerStatefulWidget {
  const _EnterCode();

  @override
  ConsumerState<_EnterCode> createState() => _EnterCodeState();
}

class _EnterCodeState extends ConsumerState<_EnterCode> {
  final _text = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _problem;

  static final _canScan =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _clean =>
      _text.text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  Future<void> _scan() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));
    if (code == null || !mounted) return;
    _text.text = PairingCode(code, DateTime.now()).display;
    await _join();
  }

  Future<void> _join() async {
    final service = ref.read(syncServiceProvider);
    if (service == null || _busy || _clean.length != 8) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await service.joinWithCode(_clean);
      if (!mounted) return;
      setState(() => _done = true);
      ref.invalidate(syncedDevicesProvider);
      unawaited(ref.read(syncStatusProvider.notifier).syncNow());
    } on Object catch (e) {
      if (mounted) setState(() => _problem = _problemText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return const _Done(
        title: 'Paired',
        detail: 'Reminders from both devices now show on both.',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canScan) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR code'),
          ),
          const SizedBox(height: Gap.l),
        ],
        TextField(
          controller: _text,
          autofocus: !_canScan,
          enabled: !_busy,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 9,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
          ],
          style: const TextStyle(letterSpacing: 2),
          decoration: InputDecoration(
            labelText: 'Code from the other device',
            hintText: 'ABCD-EFGH',
            errorText: _problem,
            errorMaxLines: 3,
            counterText: '',
          ),
          onChanged: (_) => setState(() => _problem = null),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: Gap.m),
        FilledButton.tonal(
          onPressed: _busy || _clean.length != 8 ? null : _join,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Pair'),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Gap.m),
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.xs),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: Gap.l),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: Gap.m),
        FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
