import 'dart:convert';

import 'focus_session.dart';

/// This device's Focus settings: the defaults for a new session and what to
/// block here. Not synced, because the phone blocks apps by package name and
/// the laptop by program and site.
class FocusPrefs {
  const FocusPrefs({
    this.minutes = 25,
    this.rounds = 1,
    this.breakMinutes = 5,
    this.subjectId,
    this.target = FocusTarget.both,
    this.blockApps = true,
    this.quiet = true,
    this.strict = false,
    this.flipToFocus = false,
    this.phoneApps = defaultPhoneApps,
    this.blockGames = true,
    this.laptopApps = defaultLaptopApps,
    this.sites = defaultSites,
  });

  static const key = 'focus_prefs';

  static const maxRounds = 8;

  /// Instagram, YouTube, Reddit and X.
  static const defaultPhoneApps = {
    'com.instagram.android',
    'com.google.android.youtube',
    'com.reddit.frontpage',
    'com.twitter.android',
  };

  /// Game launchers. Program file names, lower case.
  static const defaultLaptopApps = [
    'steam.exe',
    'steamwebhelper.exe',
    'epicgameslauncher.exe',
    'battle.net.exe',
    'riotclientux.exe',
    'leagueclientux.exe',
  ];

  static const defaultSites = [
    'youtube.com',
    'instagram.com',
    'reddit.com',
    'x.com',
  ];

  /// The length of one round.
  final int minutes;

  /// Rounds per session, with a break of [breakMinutes] between two.
  final int rounds;
  final int breakMinutes;

  /// The subject a new session is for. Null for none.
  final String? subjectId;
  final FocusTarget target;
  final bool blockApps;
  final bool quiet;
  final bool strict;

  /// Start a session by putting the phone down screen first, with the app
  /// open.
  final bool flipToFocus;

  /// Android package names to block.
  final Set<String> phoneApps;

  /// Also block every app Android lists as a game.
  final bool blockGames;

  /// Windows programs to block, as lower-case file names.
  final List<String> laptopApps;

  /// Sites to block in browsers on the laptop.
  final List<String> sites;

  /// Work and break lengths for a new session's rounds; zero for one round.
  Duration get work => rounds > 1 ? Duration(minutes: minutes) : Duration.zero;
  Duration get rest =>
      rounds > 1 ? Duration(minutes: breakMinutes) : Duration.zero;

  /// How long a new session runs, breaks included.
  Duration get length =>
      Duration(minutes: minutes * rounds + breakMinutes * (rounds - 1));

  FocusPrefs copyWith({
    int? minutes,
    int? rounds,
    int? breakMinutes,
    FocusTarget? target,
    bool? blockApps,
    bool? quiet,
    bool? strict,
    bool? flipToFocus,
    Set<String>? phoneApps,
    bool? blockGames,
    List<String>? laptopApps,
    List<String>? sites,
  }) => FocusPrefs(
    minutes: minutes ?? this.minutes,
    rounds: rounds ?? this.rounds,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    subjectId: subjectId,
    target: target ?? this.target,
    blockApps: blockApps ?? this.blockApps,
    quiet: quiet ?? this.quiet,
    strict: strict ?? this.strict,
    flipToFocus: flipToFocus ?? this.flipToFocus,
    phoneApps: phoneApps ?? this.phoneApps,
    blockGames: blockGames ?? this.blockGames,
    laptopApps: laptopApps ?? this.laptopApps,
    sites: sites ?? this.sites,
  );

  FocusPrefs withSubject(String? id) => FocusPrefs(
    minutes: minutes,
    rounds: rounds,
    breakMinutes: breakMinutes,
    subjectId: id,
    target: target,
    blockApps: blockApps,
    quiet: quiet,
    strict: strict,
    flipToFocus: flipToFocus,
    phoneApps: phoneApps,
    blockGames: blockGames,
    laptopApps: laptopApps,
    sites: sites,
  );

  String encode() => jsonEncode({
    'minutes': minutes,
    'rounds': rounds,
    'breakMinutes': breakMinutes,
    'subject': subjectId,
    'target': target.name,
    'blockApps': blockApps,
    'quiet': quiet,
    'strict': strict,
    'flip': flipToFocus,
    'phoneApps': phoneApps.toList()..sort(),
    'blockGames': blockGames,
    'laptopApps': laptopApps,
    'sites': sites,
  });

  /// Reads [raw], falling back to the defaults for anything missing or odd.
  factory FocusPrefs.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const FocusPrefs();
    final Map<String, Object?> m;
    try {
      m = (jsonDecode(raw) as Map).cast<String, Object?>();
    } on Object {
      return const FocusPrefs();
    }
    List<String>? strings(Object? v) => v is List
        ? [
            for (final e in v)
              if (e is String) e,
          ]
        : null;
    const d = FocusPrefs();
    return FocusPrefs(
      minutes: (m['minutes'] as num?)?.toInt().clamp(1, 600) ?? d.minutes,
      rounds: (m['rounds'] as num?)?.toInt().clamp(1, maxRounds) ?? d.rounds,
      breakMinutes:
          (m['breakMinutes'] as num?)?.toInt().clamp(1, 60) ?? d.breakMinutes,
      subjectId: m['subject'] as String?,
      target: FocusTarget.parse(m['target'] as String?),
      blockApps: m['blockApps'] as bool? ?? d.blockApps,
      quiet: m['quiet'] as bool? ?? d.quiet,
      strict: m['strict'] as bool? ?? d.strict,
      flipToFocus: m['flip'] as bool? ?? d.flipToFocus,
      phoneApps: strings(m['phoneApps'])?.toSet() ?? d.phoneApps,
      blockGames: m['blockGames'] as bool? ?? d.blockGames,
      laptopApps: strings(m['laptopApps']) ?? d.laptopApps,
      sites: strings(m['sites']) ?? d.sites,
    );
  }
}
