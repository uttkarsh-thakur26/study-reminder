import 'dart:convert';

import 'app_version.dart';

/// Which file of a release this device installs.
enum UpdatePlatform {
  android,
  windows;

  /// The release file for [version], as `release.yml` names it.
  String assetName(AppVersion version) => switch (this) {
    android => 'StudyReminder-$version.apk',
    windows => 'StudyReminder-Setup-$version.exe',
  };
}

/// The newest release, and the file this device would install from it.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.downloadUrl,
    required this.size,
  });

  final AppVersion version;

  /// The release notes, as plain lines.
  final String notes;

  /// The release on GitHub, for opening in a browser.
  final String pageUrl;

  /// The APK or installer. Null when the release has no file for this
  /// device yet.
  final String? downloadUrl;

  /// Bytes of [downloadUrl], 0 when unknown.
  final int size;

  /// Reads GitHub's `releases/latest` answer. Null when it is not a release
  /// numbered `X.Y.Z`.
  static UpdateInfo? fromGitHub(
    Map<String, Object?> json,
    UpdatePlatform platform,
  ) {
    final version = AppVersion.tryParse('${json['tag_name'] ?? ''}');
    if (version == null ||
        json['draft'] == true ||
        json['prerelease'] == true) {
      return null;
    }
    final wanted = platform.assetName(version);
    String? url;
    var size = 0;
    for (final asset in (json['assets'] as List?) ?? const []) {
      if (asset is Map && asset['name'] == wanted) {
        url = asset['browser_download_url'] as String?;
        size = (asset['size'] as num?)?.toInt() ?? 0;
      }
    }
    return UpdateInfo(
      version: version,
      notes: plainNotes('${json['body'] ?? ''}'),
      pageUrl: '${json['html_url'] ?? ''}',
      downloadUrl: url,
      size: size,
    );
  }

  Map<String, Object?> toJson() => {
    'version': '$version',
    'notes': notes,
    'page': pageUrl,
    'url': downloadUrl,
    'size': size,
  };

  static UpdateInfo? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final json = jsonDecode(text) as Map<String, Object?>;
      final version = AppVersion.tryParse('${json['version']}');
      if (version == null) return null;
      return UpdateInfo(
        version: version,
        notes: '${json['notes'] ?? ''}',
        pageUrl: '${json['page'] ?? ''}',
        downloadUrl: json['url'] as String?,
        size: (json['size'] as num?)?.toInt() ?? 0,
      );
    } on Object {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

/// Release notes without Markdown headings, links or the changelog line:
/// one change per line, starting with "• ".
String plainNotes(String markdown) {
  final lines = <String>[];
  for (var line in const LineSplitter().convert(markdown)) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('**Full Changelog**')) continue;
    // [text](url) -> text, and drop bold markers.
    line = line
        .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAll('**', '')
        // GitHub's generated notes name who opened each pull request.
        .replaceFirst(RegExp(r' by @\S+ in \S+$'), '');
    if (line.startsWith('New Contributors') ||
        line.contains('first contribution')) {
      continue;
    }
    if (line.startsWith('* ') || line.startsWith('- ')) {
      line = '• ${line.substring(2).trim()}';
    }
    lines.add(line);
  }
  return lines.join('\n');
}
