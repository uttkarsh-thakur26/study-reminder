/// A YouTube video or playlist the user studies with, allowed during focus
/// while the rest of YouTube stays blocked.
class StudyVideo {
  const StudyVideo.video(this.id, {this.title = ''})
    : isPlaylist = false,
      startId = null;

  const StudyVideo.playlist(this.id, {this.startId, this.title = ''})
    : isPlaylist = true;

  final bool isPlaylist;

  /// The video id, or the playlist id.
  final String id;

  /// For a playlist, the video its link opened at. Null for the first.
  final String? startId;

  /// What YouTube calls it. Empty until it has been looked up.
  final String title;

  StudyVideo withTitle(String title) => isPlaylist
      ? StudyVideo.playlist(id, startId: startId, title: title)
      : StudyVideo.video(id, title: title);

  /// The page on YouTube.
  String get url => isPlaylist
      ? startId == null
            ? 'https://www.youtube.com/playlist?list=$id'
            : 'https://www.youtube.com/watch?v=$startId&list=$id'
      : 'https://www.youtube.com/watch?v=$id';

  /// The name to show: its title, or what it is while that is unknown.
  String get label => title.isNotEmpty
      ? title
      : isPlaylist
      ? 'Playlist'
      : 'Video';

  bool sameAs(StudyVideo other) =>
      isPlaylist == other.isPlaylist && id == other.id;

  Map<String, Object?> toJson() => {
    'kind': isPlaylist ? 'playlist' : 'video',
    'id': id,
    if (startId != null) 'start': startId,
    if (title.isNotEmpty) 'title': title,
  };

  static StudyVideo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || !_validId.hasMatch(id)) return null;
    final title = json['title'] is String ? json['title'] as String : '';
    final start = json['start'];
    return switch (json['kind']) {
      'video' => StudyVideo.video(id, title: title),
      'playlist' => StudyVideo.playlist(
        id,
        startId: start is String && _validId.hasMatch(start) ? start : null,
        title: title,
      ),
      _ => null,
    };
  }

  /// Reads a YouTube link the user pasted or shared. A link with a playlist
  /// in it, such as a video opened from the playlist, gives the playlist.
  /// Null for anything else.
  static StudyVideo? parse(String input) {
    final link = _youTubeLink(input.trim());
    if (link == null) return null;
    if (link.list != null) {
      return StudyVideo.playlist(link.list!, startId: link.video);
    }
    if (link.video != null) return StudyVideo.video(link.video!);
    return null;
  }
}

/// Ids of videos and playlists: letters, digits, - and _.
final _validId = RegExp(r'^[A-Za-z0-9_-]{6,64}$');

/// The video and playlist a YouTube address names. Null when [address] is
/// not on YouTube. Takes addresses without the https:// in front, as
/// browsers show them.
({String? video, String? list})? _youTubeLink(String address) {
  if (address.isEmpty || address.contains(RegExp(r'\s'))) return null;
  final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(address)
      ? address
      : 'https://$address';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  String? valid(String? id) => id != null && _validId.hasMatch(id) ? id : null;
  final String? list;
  try {
    list = valid(uri.queryParameters['list']);
  } on FormatException {
    return null;
  }
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    return (video: valid(segments.firstOrNull), list: list);
  }
  if (host != 'youtube.com' &&
      !host.endsWith('.youtube.com') &&
      host != 'youtube-nocookie.com' &&
      !host.endsWith('.youtube-nocookie.com')) {
    return null;
  }
  var video = valid(uri.queryParameters['v']);
  if (video == null &&
      segments.length >= 2 &&
      const {'shorts', 'live', 'embed', 'v'}.contains(segments.first)) {
    video = valid(segments[1]);
  }
  return (video: video, list: list);
}

/// Decides which YouTube pages and tabs are the user's study videos.
class StudyVideoRules {
  StudyVideoRules(
    Iterable<StudyVideo> videos, {
    Iterable<String> titles = const [],
  }) : _videos = {
         for (final v in videos)
           if (!v.isPlaylist) v.id,
       },
       _lists = {
         for (final v in videos)
           if (v.isPlaylist) v.id,
       },
       _titles = {
         for (final v in videos)
           if (!v.isPlaylist && v.title.isNotEmpty) cleanTitle(v.title),
         for (final t in titles) cleanTitle(t),
       }..remove('');

  final Set<String> _videos;
  final Set<String> _lists;
  final Set<String> _titles;

  bool get isEmpty => _videos.isEmpty && _lists.isEmpty;

  /// The titles of study videos seen so far.
  Set<String> get titles => Set.unmodifiable(_titles);

  /// Whether the YouTube page at [address] is a study video, or the page
  /// of a study playlist. Addresses may come without https:// in front.
  bool allowsAddress(String address) {
    final link = _youTubeLink(address.trim());
    if (link == null) return false;
    if (link.list != null && _lists.contains(link.list)) return true;
    return link.video != null && _videos.contains(link.video);
  }

  /// Whether a tab titled [title] shows a study video seen before.
  bool allowsTitle(String title) {
    final t = cleanTitle(title);
    return t.isNotEmpty && _titles.contains(t);
  }

  /// Remembers [title] as the title of a study video, so its tab is known
  /// when its address can't be read.
  void learn(String title) {
    final t = cleanTitle(title);
    if (t.isNotEmpty) _titles.add(t);
  }

  /// A browser tab or window title with YouTube's parts taken off: the
  /// count of new notifications in front and " - YouTube" (and the
  /// browser's name) at the end. Lower case.
  static String cleanTitle(String title) {
    var t = title.replaceAll('​', '').trim();
    t = t.replaceFirst(RegExp(r'^\(\d+\+?\)\s*'), '');
    final at = t.toLowerCase().lastIndexOf(' - youtube');
    if (at >= 0) t = t.substring(0, at);
    return t.trim().toLowerCase();
  }
}
