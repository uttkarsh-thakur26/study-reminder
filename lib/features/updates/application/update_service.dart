import '../domain/app_version.dart';
import '../domain/update_info.dart';

abstract final class UpdateKeys {
  /// When GitHub was last asked, in ms since epoch.
  static const checkedAt = 'update_checked_at';

  /// The newest release found, as [UpdateInfo.encode].
  static const latest = 'update_latest';

  /// When the user was last asked to update, in ms since epoch.
  static const promptedAt = 'update_prompted_at';

  /// The version a background check last posted a notification for.
  static const notified = 'update_notified';
}

/// Asks GitHub for a newer release at most once a day, and decides when to
/// ask the user about it: at most once a day too.
class UpdateService {
  UpdateService({
    required this.current,
    required this.platform,
    required this.fetch,
    required this.read,
    required this.write,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// This build's version; null for a local build, which never updates.
  final AppVersion? current;
  final UpdatePlatform platform;
  final Future<UpdateInfo?> Function(UpdatePlatform) fetch;
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final DateTime Function() _now;

  static const interval = Duration(days: 1);

  bool get enabled => current != null;

  Future<DateTime?> _readTime(String key) async {
    final ms = int.tryParse(await read(key) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> _due(String key) async {
    final last = await _readTime(key);
    final now = _now();
    // A clock set back past the last time counts as due too.
    return last == null ||
        now.difference(last) >= interval ||
        now.isBefore(last);
  }

  /// The newest release known, when it is newer than this build.
  Future<UpdateInfo?> available() async {
    final latest = UpdateInfo.decode(await read(UpdateKeys.latest));
    final current = this.current;
    if (latest == null || current == null || !(latest.version > current)) {
      return null;
    }
    return latest;
  }

  /// Asks GitHub now and remembers the answer. Returns the update, if any.
  Future<UpdateInfo?> checkNow() async {
    if (!enabled) return null;
    final latest = await fetch(platform);
    await write(UpdateKeys.checkedAt, '${_now().millisecondsSinceEpoch}');
    await write(UpdateKeys.latest, latest?.encode() ?? '');
    return available();
  }

  /// Asks GitHub when the last check is a day old. Network errors are
  /// swallowed: the next call tries again.
  Future<UpdateInfo?> checkIfDue() async {
    if (!enabled) return null;
    if (await _due(UpdateKeys.checkedAt)) {
      try {
        return await checkNow();
      } on Object {
        return available();
      }
    }
    return available();
  }

  /// The update to ask the user about now: found, and not asked about in the
  /// last day. Call [markPrompted] once the prompt is actually shown.
  Future<UpdateInfo?> toPrompt() async {
    final update = await checkIfDue();
    if (update == null || !await _due(UpdateKeys.promptedAt)) return null;
    return update;
  }

  Future<void> markPrompted() =>
      write(UpdateKeys.promptedAt, '${_now().millisecondsSinceEpoch}');

  /// The update a background check should post a notification for: once
  /// per version. Call [markNotified] once the notification is posted, so a
  /// failed one is tried again.
  Future<UpdateInfo?> toNotify() async {
    final update = await checkIfDue();
    if (update == null ||
        await read(UpdateKeys.notified) == '${update.version}') {
      return null;
    }
    return update;
  }

  Future<void> markNotified(UpdateInfo update) =>
      write(UpdateKeys.notified, '${update.version}');
}
