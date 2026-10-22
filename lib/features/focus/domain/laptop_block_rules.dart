/// What a blocked window on the laptop matched.
class BlockHit {
  const BlockHit(this.label, {required this.isSite});

  /// What to call it in the notice, for example "YouTube" or "steam".
  final String label;

  /// A site open in a browser, as opposed to a program.
  final bool isSite;
}

/// Decides whether a window on the laptop is a distraction during focus:
/// a blocked program, or a browser showing a blocked site.
///
/// Browsers do not tell other programs which address a tab shows, so sites
/// are matched by the window title, which is the page title. Most sites put
/// their name in it ("Lo-fi beats - YouTube", "Home / X").
class LaptopBlockRules {
  LaptopBlockRules({
    required Iterable<String> programs,
    required Iterable<String> sites,
  }) : _programs = {for (final p in programs) programName(p)},
       _sites = [
         for (final s in sites)
           if (siteKeyword(s) case final String k) (site: s, keyword: k),
       ];

  final Set<String> _programs;
  final List<({String site, String keyword})> _sites;

  static const browsers = {
    'chrome.exe',
    'msedge.exe',
    'firefox.exe',
    'brave.exe',
    'opera.exe',
    'vivaldi.exe',
    'arc.exe',
    'chromium.exe',
    'librewolf.exe',
    'waterfox.exe',
    'floorp.exe',
    'zen.exe',
  };

  /// The browsers whose tabs Focus can read and close when they are not in
  /// front: those built on Chromium with its own tab strip. Vivaldi draws its
  /// tabs as a web page, and turning on Firefox's accessibility costs it too
  /// much to do every few seconds.
  static const tabBrowsers = {
    'chrome.exe',
    'msedge.exe',
    'brave.exe',
    'opera.exe',
    'chromium.exe',
  };

  /// Whether any site is blocked.
  bool get blocksSites => _sites.isNotEmpty;

  /// What [exePath] showing [title] matches, or null when it is fine.
  BlockHit? match(String exePath, String title) {
    final program = programName(exePath);
    if (_programs.contains(program)) {
      return BlockHit(
        program.replaceFirst(RegExp(r'\.exe$'), ''),
        isSite: false,
      );
    }
    if (!browsers.contains(program)) return null;
    return matchTab(title);
  }

  /// The blocked site a browser tab titled [title] shows, or null. Programs
  /// are not looked at.
  BlockHit? matchTab(String title) {
    // Edge puts a zero-width space in its own name.
    final t = title.toLowerCase().replaceAll('\u200b', '');
    for (final s in _sites) {
      if (_titleShows(t, s.site.toLowerCase(), s.keyword)) {
        return BlockHit(_display(s.keyword), isSite: true);
      }
    }
    return null;
  }

  static bool _titleShows(String title, String site, String keyword) {
    // The address itself, but not inside a longer one: x.com is not netflix.com.
    final address = RegExp(
      '(^|[^a-z0-9.-])${RegExp.escape(site)}(\$|[^a-z0-9-])',
    );
    if (address.hasMatch(title)) return true;
    if (keyword.length <= 2) {
      // Too short to look for on its own: X titles end in " / X".
      return RegExp('[/|]\\s${RegExp.escape(keyword)}(\\s|\$)').hasMatch(title);
    }
    return RegExp('(^|[^a-z0-9])${RegExp.escape(keyword)}(\$|[^a-z0-9])')
        .hasMatch(title);
  }

  static String _display(String keyword) => switch (keyword) {
    'youtube' => 'YouTube',
    'x' => 'X',
    _ => '${keyword[0].toUpperCase()}${keyword.substring(1)}',
  };
}

/// The lower-case file name of a program, from its path or its name.
String programName(String path) =>
    path.trim().split(RegExp(r'[\\/]')).last.toLowerCase();

/// The part of a site's address its pages put in their titles: "youtube"
/// for "https://www.youtube.com/watch". Null for something that is not an
/// address.
String? siteKeyword(String site) {
  var s = site.trim().toLowerCase();
  s = s.replaceFirst(RegExp(r'^[a-z]+://'), '');
  s = s.split(RegExp(r'[/?#:]')).first;
  final parts = s.split('.').where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) return null;
  // bbc.co.uk and the like.
  final countryPair =
      parts.length >= 3 &&
      parts.last.length == 2 &&
      _secondLevel.contains(parts[parts.length - 2]);
  final name = parts[parts.length - (countryPair ? 3 : 2)];
  return RegExp(r'^[a-z0-9-]+$').hasMatch(name) ? name : null;
}

const _secondLevel = {'co', 'com', 'org', 'net', 'ac', 'gov'};

/// Tidies what the user typed into a site address to store, or null.
String? normalizeSite(String input) {
  var s = input.trim().toLowerCase();
  s = s.replaceFirst(RegExp(r'^[a-z]+://'), '');
  s = s.split(RegExp(r'[/?#:]')).first.replaceFirst(RegExp(r'^www\.'), '');
  return siteKeyword(s) == null ? null : s;
}

/// Tidies what the user typed into a program file name to store, or null.
String? normalizeProgram(String input) {
  var s = programName(input.replaceAll('"', ''));
  if (s.isEmpty || s.contains(RegExp(r'\s{2,}'))) return null;
  if (!s.endsWith('.exe')) s = '$s.exe';
  return s;
}
