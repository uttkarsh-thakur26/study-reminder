import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A session for this phone to enforce.
@immutable
class FocusGuardSession {
  const FocusGuardSession({
    required this.startedAt,
    required this.endsAt,
    required this.blockApps,
    required this.quiet,
    required this.strict,
    required this.blockGames,
    required this.packages,
    required this.startedBy,
    this.rounds = 1,
    this.workMinutes = 0,
    this.breakMinutes = 0,
    this.doneMs = 0,
  });

  final DateTime startedAt;
  final DateTime endsAt;

  /// Cover [packages] (and games, with [blockGames]) with a block screen.
  final bool blockApps;

  /// Turn on Do Not Disturb, if it is off.
  final bool quiet;
  final bool strict;
  final bool blockGames;
  final Set<String> packages;

  /// The device the session was started on, for the notification.
  final String startedBy;

  /// [rounds] rounds of [workMinutes] with breaks of [breakMinutes] between
  /// them, the last round running to [endsAt]; zero for one round. Nothing
  /// is blocked during a break.
  final int rounds;
  final int workMinutes;
  final int breakMinutes;

  /// For a session resumed after a pause: how far into its rounds it was.
  final int doneMs;

  Map<String, Object?> toMap() => {
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endsAt': endsAt.millisecondsSinceEpoch,
    'blockApps': blockApps,
    'quiet': quiet,
    'strict': strict,
    'blockGames': blockGames,
    'packages': packages.toList()..sort(),
    'startedBy': startedBy,
    'rounds': rounds,
    'workMinutes': workMinutes,
    'breakMinutes': breakMinutes,
    'doneMs': doneMs,
  };

  @override
  bool operator ==(Object other) =>
      other is FocusGuardSession &&
      mapEquals(
        other.toMap()..remove('packages'),
        toMap()..remove('packages'),
      ) &&
      setEquals(other.packages, packages);

  @override
  int get hashCode => Object.hash(startedAt, endsAt, blockApps, quiet);
}

/// What the user has allowed Focus mode to do on this phone.
@immutable
class FocusGuardAccess {
  const FocusGuardAccess({
    required this.usage,
    required this.overlay,
    required this.media,
    required this.quiet,
    required this.notifications,
    required this.battery,
    this.lock = false,
  });

  /// Usage access: lets the app see which app is open.
  final bool usage;

  /// Display over other apps: lets the block screen appear over them.
  final bool overlay;

  /// Notification access: lets Focus mode pause blocked apps playing in the
  /// background or in a floating window.
  final bool media;

  /// Do Not Disturb access.
  final bool quiet;
  final bool notifications;

  /// Battery use unrestricted: a session started on another device can begin
  /// while the app is closed.
  final bool battery;

  /// Modify system settings: the screen timeout can be shortened after a
  /// flip, so the phone locks soon.
  final bool lock;

  bool get canBlockApps => usage && overlay;

  factory FocusGuardAccess.fromMap(Map<Object?, Object?> m) => FocusGuardAccess(
    usage: m['usage'] == true,
    overlay: m['overlay'] == true,
    media: m['media'] == true,
    quiet: m['quiet'] == true,
    notifications: m['notifications'] == true,
    battery: m['battery'] == true,
    lock: m['lock'] == true,
  );
}

/// System pages where the user grants what Focus mode needs.
enum FocusGuardPage { usage, overlay, media, quiet, battery, lock, appInfo }

/// An app the user can block.
@immutable
class InstalledApp {
  const InstalledApp(this.packageName, this.label, {this.isGame = false});

  final String packageName;
  final String label;
  final bool isGame;
}

/// Focus mode on Android: Do Not Disturb, blocking apps, flip to focus.
class FocusGuard {
  const FocusGuard();

  static const _channel = MethodChannel('focus_guard');
  static const _flips = EventChannel('focus_guard/flip');

  /// Applies the shared session at [version]: enforces [session] here, or
  /// ends what runs here when it is null. The phone ignores a version older
  /// than one it already acted on, including ones pushed while the app was
  /// closed, so callers need no ordering of their own. Safe to repeat.
  Future<void> apply({required String version, FocusGuardSession? session}) =>
      _channel.invokeMethod('apply', {
        'version': version,
        'session': session?.toMap(),
      });

  Future<bool> isRunning() async =>
      await _channel.invokeMethod<bool>('isRunning') ?? false;

  /// What to block when a session arrives from another device while the app
  /// is closed. With [studyVideos], YouTube's block screen offers the app's
  /// own player instead.
  Future<void> setBlocklist(
    Set<String> packages, {
    required bool blockGames,
    bool studyVideos = false,
  }) => _channel.invokeMethod('setBlocklist', {
    'packages': packages.toList()..sort(),
    'blockGames': blockGames,
    'studyVideos': studyVideos,
  });

  /// The page of the app the block screen asked to open, such as
  /// [studyVideosPage]. Null otherwise. Given once.
  Future<String?> takeOpenPage() =>
      _channel.invokeMethod<String>('takeOpenPage');

  static const studyVideosPage = 'study_videos';

  /// When the user tapped "Focus here" on the note that the laptop quit a
  /// strict session: the end of the session they want on this phone. Null
  /// otherwise. Given once.
  Future<DateTime?> takeFocusRequest() async {
    final ms = await _channel.invokeMethod<int>('takeFocusRequest');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// This phone's push token, so other devices can wake it. Null when the app
  /// was built without Firebase or the phone has no Google Play services.
  Future<String?> pushToken() => _channel.invokeMethod<String>('pushToken');

  /// A short buzz, felt with the phone face down.
  Future<void> buzz() => _channel.invokeMethod<void>('buzz');

  /// Locks the phone soon: the screen timeout is shortened until the screen
  /// goes off, then put back, and the phone locks as it always does. No
  /// Accessibility or device admin, which payment apps refuse to run beside.
  /// False without Modify system settings.
  Future<bool> lock() async =>
      await _channel.invokeMethod<bool>('lock') ?? false;

  Future<FocusGuardAccess> access() async => FocusGuardAccess.fromMap(
    await _channel.invokeMethod<Map<Object?, Object?>>('access') ?? const {},
  );

  /// Opens [page] in system settings. False if this phone has no such page.
  Future<bool> open(FocusGuardPage page) async =>
      await _channel.invokeMethod<bool>('open', {'page': page.name}) ?? false;

  Future<List<InstalledApp>> installedApps() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('apps');
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        InstalledApp(
          m['package']! as String,
          m['label']! as String,
          isGame: m['game'] == true,
        ),
    ];
  }

  /// The app's icon as PNG bytes.
  Future<Uint8List?> icon(String packageName) =>
      _channel.invokeMethod<Uint8List>('icon', {'package': packageName});

  /// Fires when the phone has been put down screen first, while listened to.
  Stream<void> faceDown() => _flips.receiveBroadcastStream().map((_) {});
}
