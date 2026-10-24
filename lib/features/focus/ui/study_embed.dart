import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../domain/study_videos.dart';

/// Why the player can't play.
enum EmbedProblem {
  /// YouTube's player didn't load: no internet, most likely.
  offline,

  /// Its owner lets it play only on YouTube itself.
  notEmbeddable,

  /// Private, removed, or not a real video.
  notFound,

  /// YouTube turned the app's player down.
  refused,

  /// Anything else YouTube reported.
  other,
}

/// Where the player's page says it comes from, in the order tried. YouTube
/// asks apps to name themselves with their app id
/// (developers.google.com/youtube/terms/required-minimum-functionality);
/// youtube-nocookie.com is kept for when YouTube still won't play there.
/// (A page on youtube.com itself gets error 152.)
const embedOrigins = [
  (
    page: 'https://com.uttkarsh.study_reminder',
    host: 'https://www.youtube.com',
  ),
  (
    page: 'https://www.youtube-nocookie.com',
    host: 'https://www.youtube-nocookie.com',
  ),
];

/// Runs YouTube's embedded player in a web view, and plays only the study
/// video, or the videos of the study playlist, in it: a video picked from
/// the player's suggestions sends it back. Nothing covers the player, so
/// its own play button can always be tapped.
class StudyEmbedController extends ChangeNotifier {
  StudyEmbedController({
    this.onPlace,
    this.onBlocked,
    this.onEvent,
    @visibleForTesting this.firstOrigin = 0,
  }) {
    web = WebViewController()
      ..addJavaScriptChannel('StudyPlayer', onMessageReceived: _onMessage);
    unawaited(web.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(web.setBackgroundColor(Colors.black));
    unawaited(
      web.setNavigationDelegate(
        NavigationDelegate(
          // YouTube's links out, such as its logo, would open its site in
          // place of the player.
          onNavigationRequest: (request) => request.isMainFrame
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
        ),
      ),
    );
    if (onEvent != null) {
      unawaited(
        web.setOnConsoleMessage(
          (m) => onEvent!('console ${m.level.name}: ${m.message}'),
        ),
      );
    }
    final platform = web.platform;
    if (platform is AndroidWebViewController) {
      unawaited(platform.setMediaPlaybackRequiresUserGesture(false));
    }
  }

  /// Called with the playlist, the video playing and its place in the
  /// playlist as the player moves on.
  final void Function(StudyVideo playlist, String video, int index)? onPlace;

  /// Called when the player was sent back from a video that is not a study
  /// video.
  final VoidCallback? onBlocked;

  /// Called with each message from the page, for checks.
  final void Function(String event)? onEvent;

  /// Which of [embedOrigins] to start with.
  final int firstOrigin;

  /// How long YouTube's player may take to load before the next origin is
  /// tried.
  static const readyTimeout = Duration(seconds: 20);

  late final WebViewController web;

  StudyVideo? _video;
  int _startIndex = 0;
  String? _startAt;
  int _origin = 0;

  /// Counts page loads, so messages from an earlier page are left out.
  int _page = 0;
  Timer? _readyTimer;
  bool _disposed = false;

  bool _ready = false;
  int? _state;
  String _videoId = '';
  String _title = '';
  int _index = 0;
  int _count = 0;
  EmbedProblem? _problem;
  bool _needsTap = false;

  StudyVideo? get video => _video;

  /// Whether YouTube's player has loaded.
  bool get ready => _ready;

  /// YouTube's player state: -1 not started, 0 ended, 1 playing, 2 paused,
  /// 3 buffering, 5 cued. Null until the player says.
  int? get state => _state;

  String get videoId => _videoId;

  /// The title of the video playing. Empty until YouTube says.
  String get title => _title;

  /// The place in the playlist, from 0.
  int get index => _index;

  /// How many videos the playlist has. 0 while unknown.
  int get count => _count;

  EmbedProblem? get problem => _problem;

  /// Whether the phone held back starting the video, so it needs a tap.
  bool get needsTap => _needsTap;

  /// Which of [embedOrigins] the page uses now.
  int get origin => _origin;

  /// Plays [video]. A playlist starts at [index], or at the video [startAt]
  /// once the playlist has loaded.
  Future<void> open(StudyVideo video, {int index = 0, String? startAt}) {
    _video = video;
    _startIndex = index;
    _startAt = startAt;
    _origin = firstOrigin;
    return _load();
  }

  /// Loads the player again, after a problem.
  Future<void> retry() {
    _origin = firstOrigin;
    return _load();
  }

  Future<void> previous() => _run('previousVideo()');

  Future<void> next() => _run('nextVideo()');

  Future<void> pause() => _run('pauseVideo()');

  Future<void> _run(String call) async {
    if (!_ready) return;
    try {
      await web.runJavaScript('if (player) player.$call;');
    } on Object {
      // The page is reloading.
    }
  }

  Future<void> _load() async {
    final video = _video;
    if (video == null || _disposed) return;
    _readyTimer?.cancel();
    _page++;
    _ready = false;
    _state = null;
    _videoId = '';
    _title = '';
    _index = video.isPlaylist ? _startIndex : 0;
    _count = 0;
    _problem = null;
    _needsTap = false;
    notifyListeners();
    final origin = embedOrigins[_origin];
    final page = _page;
    _readyTimer = Timer(readyTimeout, () {
      if (page == _page) _fallBack(EmbedProblem.offline);
    });
    final config = jsonEncode({
      'page': page,
      'kind': video.isPlaylist ? 'playlist' : 'video',
      'id': video.id,
      'index': _index,
      'start': ?_startAt,
      'origin': origin.page,
      'host': origin.host,
    });
    await web.loadHtmlString(
      _html.replaceFirst('__CONFIG__', config),
      baseUrl: origin.page,
    );
  }

  /// Tries the next origin, or gives up with [problem] after the last.
  void _fallBack(EmbedProblem problem) {
    if (_disposed) return;
    if (_origin < embedOrigins.length - 1) {
      _origin++;
      unawaited(_load());
      return;
    }
    _readyTimer?.cancel();
    _problem = problem;
    notifyListeners();
  }

  void _onMessage(JavaScriptMessage message) {
    if (_disposed) return;
    final Object? data;
    try {
      data = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    if (data is! Map || data['page'] != _page) return;
    onEvent?.call(message.message);
    final video = _video;
    switch (data['type']) {
      case 'ready':
        _readyTimer?.cancel();
        _ready = true;
      case 'state':
        final state = data['state'];
        if (state is! int) return;
        _state = state;
        if (state == 1 || state == 3) {
          _needsTap = false;
          // A video that couldn't play has been left for one that can.
          _problem = null;
        }
      case 'video':
        final id = data['id'];
        final title = data['title'];
        final index = data['index'];
        final count = data['count'];
        if (id is! String || index is! int || count is! int) return;
        _videoId = id;
        _title = title is String ? title : '';
        _index = index;
        _count = count;
        if (video != null && video.isPlaylist && count > 0) {
          onPlace?.call(video, id, index);
        }
      case 'error':
        final code = data['code'];
        switch (code) {
          // Turned down for how the app's player names itself.
          case 152 || 153:
            _fallBack(
              code == 153 ? EmbedProblem.refused : EmbedProblem.notEmbeddable,
            );
            return;
          case 101 || 150:
            _problem = EmbedProblem.notEmbeddable;
          case 100 || 105:
            _problem = EmbedProblem.notFound;
          default:
            _problem = EmbedProblem.other;
        }
      case 'autoplayBlocked':
        _needsTap = true;
      case 'blocked':
        onBlocked?.call();
        return;
      case 'apiFailed':
        _readyTimer?.cancel();
        _fallBack(EmbedProblem.offline);
        return;
      default:
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _readyTimer?.cancel();
    unawaited(web.loadHtmlString('<html></html>').catchError((Object _) {}));
    super.dispose();
  }
}

/// Shows the player of [controller].
class StudyEmbed extends StatelessWidget {
  const StudyEmbed({super.key, required this.controller});

  final StudyEmbedController controller;

  @override
  Widget build(BuildContext context) {
    final platform = controller.web.platform;
    return ColoredBox(
      color: Colors.black,
      child: platform is AndroidWebViewController
          // Video shows up reliably when the web view is a real view on
          // screen, not drawn into a texture.
          ? WebViewWidget.fromPlatformCreationParams(
              params: AndroidWebViewWidgetCreationParams(
                controller: platform,
                displayWithHybridComposition: true,
              ),
            )
          : WebViewWidget(controller: controller.web),
    );
  }
}

/// The player's page. It cues the study video or playlist, starts it, and
/// sends the player back whenever it shows a video that isn't one of them.
/// It tells the app what happens through the StudyPlayer channel.
const _html = r'''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }
#player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
</style>
</head>
<body>
<div id="player"></div>
<script>
var config = __CONFIG__;
var player = null;
var known = [];
var index = config.index;
var reported = '';
var started = false;
var bouncedAt = 0;
// Where the study video was, to go back to.
var time = 0;
var timeOf = '';

function send(type, data) {
  data = data || {};
  data.type = type;
  data.page = config.page;
  try { StudyPlayer.postMessage(JSON.stringify(data)); } catch (e) {}
}

window.onerror = function (message, source, line) {
  send('jsError', {message: String(message), line: line || 0});
};

function onYouTubeIframeAPIReady() {
  player = new YT.Player('player', {
    host: config.host,
    width: '100%',
    height: '100%',
    playerVars: {
      playsinline: 1,
      rel: 0,
      fs: 0,
      iv_load_policy: 3,
      origin: config.origin,
      widget_referrer: config.origin
    },
    events: {
      onReady: onReady,
      onStateChange: onStateChange,
      onError: function (e) { send('error', {code: e.data}); },
      onAutoplayBlocked: function () { send('autoplayBlocked'); }
    }
  });
}

function onReady() {
  send('ready');
  if (config.kind === 'video') {
    player.cueVideoById(config.id);
  } else {
    player.cuePlaylist({list: config.id, listType: 'playlist', index: index});
  }
  setInterval(guard, 1000);
}

function onStateChange(e) {
  send('state', {state: e.data});
  if (!guard()) return;
  if (e.data === 5 && !started) {
    started = true;
    var at = config.start ? known.indexOf(config.start) : -1;
    if (at > 0 && at !== index) {
      index = at;
      player.playVideoAt(at);
    } else {
      player.playVideo();
    }
  }
}

// Whether the video in the player is the study video, or one of the study
// playlist's. Sends the player back when it isn't.
function guard() {
  if (!player || typeof player.getVideoData !== 'function') return true;
  var data = player.getVideoData() || {};
  var id = data.video_id || '';
  if (!id) return true;
  var allowed = true;
  if (config.kind === 'video') {
    allowed = id === config.id;
  } else {
    var list = player.getPlaylist();
    if (list && list.length) known = list;
    var at = known.indexOf(id);
    // Long playlists may not list every video.
    var place = typeof player.getPlaylistIndex === 'function' ? player.getPlaylistIndex() : -1;
    if (at < 0 && known.length >= 200 && list && list.length && place >= known.length) at = place;
    if (known.length && at < 0) allowed = false;
    if (at >= 0) index = at;
  }
  if (!allowed) {
    if (Date.now() - bouncedAt < 2500) return false;
    bouncedAt = Date.now();
    send('blocked', {id: id});
    if (config.kind === 'video') {
      player.loadVideoById({videoId: config.id, startSeconds: time});
    } else {
      player.loadPlaylist({list: config.id, listType: 'playlist', index: index, startSeconds: time});
    }
    return false;
  }
  if (id !== timeOf) {
    timeOf = id;
    time = 0;
  }
  if (player.getPlayerState() === 1) time = player.getCurrentTime() || 0;
  var title = data.title || '';
  var key = id + '|' + title + '|' + index + '|' + known.length;
  if (key !== reported) {
    reported = key;
    send('video', {id: id, title: title, index: config.kind === 'video' ? 0 : index, count: known.length});
  }
  return true;
}
</script>
<script src="https://www.youtube.com/iframe_api" onerror="send('apiFailed')"></script>
</body>
</html>
''';
