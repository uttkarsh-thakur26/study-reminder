import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/sync_providers.dart';

/// Decides when to sync while the app runs: at start, when it comes back to
/// the foreground, shortly after a local edit, when another device pings,
/// and every couple of minutes as a safety net. On Windows the app lives in
/// the tray, so it keeps syncing while the window is hidden.
class SyncCoordinator extends ConsumerStatefulWidget {
  const SyncCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncCoordinator> createState() => _SyncCoordinatorState();
}

class _SyncCoordinatorState extends ConsumerState<SyncCoordinator> {
  static const _editDelay = Duration(milliseconds: 1500);
  static const _every = Duration(minutes: 2);

  late final AppLifecycleListener _lifecycle;
  StreamSubscription<int>? _edits;
  StreamSubscription<void>? _pings;
  String? _pingSpace;
  Timer? _soon;
  Timer? _timer;
  bool _foreground = true;

  bool get _enabled => ref.read(syncServiceProvider) != null;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        _sync();
      },
      onHide: () => _foreground = false,
    );
    if (!_enabled) return;
    _edits = _pendingEdits().listen((n) {
      if (n > 0) _syncSoon();
    });
    _timer = Timer.periodic(_every, (_) {
      final desktop = defaultTargetPlatform == TargetPlatform.windows;
      if (_foreground || desktop) _sync();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _edits?.cancel();
    _pings?.cancel();
    _soon?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  /// How many records wait to be pushed, live.
  Stream<int> _pendingEdits() {
    final db = ref.read(databaseProvider);
    return db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM reminders WHERE dirty = 1)'
          ' + (SELECT COUNT(*) FROM subjects WHERE dirty = 1)'
          ' + (SELECT COUNT(*) FROM occurrences WHERE dirty = 1) AS n',
          variables: const <Variable<Object>>[],
          readsFrom: {db.reminders, db.subjects, db.occurrences},
        )
        .watchSingle()
        .map((row) => row.read<int>('n'));
  }

  void _syncSoon() {
    _soon?.cancel();
    _soon = Timer(_editDelay, _sync);
  }

  Future<void> _sync() async {
    if (!mounted || !_enabled) return;
    await ref.read(syncStatusProvider.notifier).syncNow();
    if (mounted) await _listenForPings();
  }

  /// Listens for pings from the other devices in this device's space, and
  /// moves the listener when pairing changes the space.
  Future<void> _listenForPings() async {
    final service = ref.read(syncServiceProvider);
    final space = await service?.spaceId();
    if (!mounted || space == null || space == _pingSpace) return;
    await _pings?.cancel();
    _pingSpace = space;
    _pings = service!.api.changes(space).listen((_) => _syncSoon());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
