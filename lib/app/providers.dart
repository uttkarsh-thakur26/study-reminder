import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../core/sync/hlc.dart';
import '../features/reminders/domain/reminder.dart';

/// Opened in `bootstrap` and overridden in the root `ProviderScope`.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Stable id of this install, used as the clock node and later for pairing.
final deviceIdProvider = Provider<String>(
  (ref) => throw UnimplementedError('deviceIdProvider must be overridden'),
);

final hlcClockProvider = Provider<HlcClock>(
  (ref) => throw UnimplementedError('hlcClockProvider must be overridden'),
);

/// IANA name of the device time zone, e.g. `Asia/Kolkata`.
final deviceTimeZoneProvider = Provider<String>((ref) => 'UTC');

final deviceKindProvider = Provider<DeviceKind>((ref) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => DeviceKind.phone,
    _ => DeviceKind.laptop,
  };
});

/// The current time, refreshed on every minute boundary so lists showing
/// "missed" or "in 5 min" stay correct without rebuilding every second.
final minuteTickProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void schedule() {
    final now = DateTime.now();
    controller.add(now);
    final untilNextMinute = 60000 - (now.second * 1000 + now.millisecond) + 50;
    timer = Timer(Duration(milliseconds: untilNextMinute), schedule);
  }

  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Combines several async values into one that is loading until all have
/// data and fails with the first error.
AsyncValue<T> combineAsync<T>(
  List<AsyncValue<Object?>> values,
  T Function() build,
) {
  for (final v in values) {
    if (v.hasError) {
      return AsyncError<T>(v.error!, v.stackTrace ?? StackTrace.current);
    }
  }
  for (final v in values) {
    if (!v.hasValue) return AsyncLoading<T>();
  }
  return AsyncData<T>(build());
}
