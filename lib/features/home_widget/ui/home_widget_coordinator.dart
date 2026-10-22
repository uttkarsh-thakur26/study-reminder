import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_widget/study_widget.dart';

import '../../../shell/shell_requests.dart';
import '../application/home_widget_providers.dart';

/// Keeps the home screen widget in step while the app runs: sends it the
/// next reminders shortly after they change, and again when the app comes
/// back, and opens quick add when the user tapped the widget's "+".
class HomeWidgetCoordinator extends ConsumerStatefulWidget {
  const HomeWidgetCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeWidgetCoordinator> createState() =>
      _HomeWidgetCoordinatorState();
}

class _HomeWidgetCoordinatorState extends ConsumerState<HomeWidgetCoordinator> {
  static const _delay = Duration(milliseconds: 500);

  AppLifecycleListener? _lifecycle;
  StreamSubscription<void>? _requests;
  Timer? _soon;
  StudyWidgetData? _sent;

  @override
  void initState() {
    super.initState();
    final home = ref.read(studyWidgetProvider);
    if (home == null) return;
    ref.listenManual(
      homeWidgetDataProvider,
      (_, _) => _updateSoon(),
      fireImmediately: true,
    );
    _requests = home.requests().listen((_) => unawaited(_takeRequest()));
    _lifecycle = AppLifecycleListener(
      onResume: () {
        // The background sync may have drawn the widget since.
        _sent = null;
        _updateSoon();
        unawaited(_takeRequest());
      },
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_takeRequest()),
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _requests?.cancel();
    _soon?.cancel();
    super.dispose();
  }

  void _updateSoon() {
    _soon?.cancel();
    _soon = Timer(_delay, () => unawaited(_update()));
  }

  Future<void> _update() async {
    if (!mounted) return;
    final home = ref.read(studyWidgetProvider);
    final data = ref.read(homeWidgetDataProvider);
    if (home == null || data == null || data == _sent) return;
    _sent = data;
    try {
      await home.update(data);
    } on Object catch (e) {
      _sent = null;
      debugPrint('home widget update failed: $e');
    }
  }

  Future<void> _takeRequest() async {
    if (!mounted) return;
    final home = ref.read(studyWidgetProvider);
    if (home == null) return;
    final StudyWidgetRequest? request;
    try {
      request = await home.takeRequest();
    } on Object catch (e) {
      debugPrint('home widget: could not read the request: $e');
      return;
    }
    if (!mounted) return;
    if (request == StudyWidgetRequest.quickAdd) {
      ref.read(shellRequestsProvider.notifier).send(ShellRequest.quickAdd);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
