import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../domain/study_videos.dart';

/// Plays the study video or playlist on YouTube's mobile site, for when
/// YouTube won't play it in the app's own player. The web view stays on the
/// study pages: links anywhere else do nothing, and when YouTube moves on by
/// itself (to a suggested video, at the end) it goes back to the last study
/// page.
class StudySiteController extends ChangeNotifier {
  StudySiteController({this.onPlace, this.onBlocked, this.onEvent}) {
    web = WebViewController()
      ..addJavaScriptChannel('StudySite', onMessageReceived: _onMessage);
    unawaited(web.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(web.setBackgroundColor(Colors.black));
    unawaited(
      web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          onUrlChange: (change) {
            if (change.url case final String url) _seen(url);
          },
          onPageFinished: (url) {
            _seen(url);
            unawaited(_prepare());
          },
        ),
      ),
    );
    final platform = web.platform;
    if (platform is AndroidWebViewController) {
      unawaited(platform.setMediaPlaybackRequiresUserGesture(false));
    }
  }

  /// Called with the playlist, the video in it, and its place from 0 when
  /// the page says, as the user moves through the playlist.
  final void Function(StudyVideo playlist, String video, int? index)? onPlace;

  /// Called when a page or link that isn't a study page was kept shut.
  final VoidCallback? onBlocked;

  /// Called with what happens, for checks.
  final void Function(String event)? onEvent;

  late final WebViewController web;

  StudyVideo? _video;

  /// The last study page shown, to go back to.
  String? _last;
  String? _current;
  Timer? _poll;
  bool _looking = false;
  bool _disposed = false;
  String _title = '';

  /// Where the video on the last study page was, in seconds, and how long
  /// it is.
  double _time = 0;
  double _duration = 0;

  /// When it last went back, to notice YouTube going on again and again.
  final _backs = <DateTime>[];

  StudyVideo? get video => _video;

  /// The title of the page, without " - YouTube".
  String get title => _title;

  /// Opens [video]'s page: for a playlist, at the video [at] when known.
  Future<void> open(StudyVideo video, {String? at}) async {
    _video = video;
    final url = video.siteUrl(at: at);
    _last = url;
    _current = null;
    _time = 0;
    _duration = 0;
    _title = '';
    notifyListeners();
    _poll ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_look()),
    );
    await web.loadRequest(Uri.parse(url));
  }

  Future<void> pause() =>
      _run("var v = document.querySelector('video'); if (v) v.pause();");

  Future<void> _run(String script) async {
    try {
      await web.runJavaScript(script);
    } on Object {
      // The page is loading.
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    if (!request.isMainFrame) return NavigationDecision.navigate;
    final video = _video;
    if (video != null &&
        (video.allowsPage(request.url) || _neutral(request.url))) {
      return NavigationDecision.navigate;
    }
    onEvent?.call('kept shut: ${request.url}');
    onBlocked?.call();
    return NavigationDecision.prevent;
  }

  /// Pages YouTube may show on the way, such as asking for cookie consent.
  static bool _neutral(String url) {
    if (url == 'about:blank') return true;
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'consent.youtube.com' || host == 'consent.google.com';
  }

  void _seen(String url) {
    final video = _video;
    if (video == null || _disposed || url == _current) return;
    _current = url;
    onEvent?.call('page $url');
    if (video.allowsPage(url)) {
      if (url != _last) {
        _time = 0;
        _duration = 0;
      }
      _last = url;
      final query = Uri.parse(url).queryParameters;
      final v = query['v'];
      if (video.isPlaylist && v != null) {
        final index = int.tryParse(query['index'] ?? '');
        onPlace?.call(video, v, index != null && index > 0 ? index - 1 : null);
      }
      return;
    }
    if (_neutral(url)) return;
    // YouTube went on by itself, to a suggested video or another page.
    onBlocked?.call();
    unawaited(_back());
  }

  Future<void> _back() async {
    await pause();
    final last = _last;
    if (last == null || _disposed) return;
    final now = DateTime.now();
    _backs
      ..removeWhere((t) => now.difference(t) > const Duration(seconds: 20))
      ..add(now);
    var url = last;
    if (_backs.length >= 3) {
      // Going on by itself each time: the playlist's page doesn't play.
      url = _video?.siteUrl() ?? last;
    } else if (Uri.parse(last).path == '/watch' &&
        _time > 5 &&
        (_duration <= 0 || _time < _duration - 5)) {
      // Back where the video was, unless it had all but ended.
      final uri = Uri.parse(last);
      url = uri
          .replace(
            queryParameters: {...uri.queryParameters, 't': '${_time.floor()}s'},
          )
          .toString();
    }
    onEvent?.call('back to $url');
    _current = null;
    await web.loadRequest(Uri.parse(url));
  }

  /// Checks the page every second: YouTube changes pages without loading
  /// them, and the page may have been changed since it was set up.
  Future<void> _look() async {
    if (_looking || _disposed || _video == null) return;
    _looking = true;
    try {
      final raw = await web.runJavaScriptReturningResult(_lookScript);
      var text = raw.toString();
      // Android hands a string back JSON-quoted.
      if (text.startsWith('"')) text = jsonDecode(text) as String;
      final data = jsonDecode(text);
      if (data is! Map || _disposed) return;
      final href = data['href'];
      if (href is String) _seen(href);
      final video = _video;
      if (video != null && href is String && video.allowsPage(href)) {
        if (data['time'] case final num time when time >= 0) {
          _time = time.toDouble();
        }
        if (data['duration'] case final num duration when duration > 0) {
          _duration = duration.toDouble();
        }
      }
      final title = (data['title'] as String? ?? '').replaceFirst(
        RegExp(r'\s*-\s*YouTube$'),
        '',
      );
      if (title != _title) {
        _title = title;
        notifyListeners();
      }
      if (data['ready'] != true) await _prepare();
    } on Object {
      // The page is loading.
    } finally {
      _looking = false;
    }
  }

  /// Hides YouTube's ways to other videos and keeps its links to them shut.
  Future<void> _prepare() async {
    final video = _video;
    if (video == null || _disposed) return;
    final config = jsonEncode({
      'kind': video.isPlaylist ? 'playlist' : 'video',
      'id': video.id,
    });
    await _run(_prepareScript.replaceFirst('__CONFIG__', config));
  }

  void _onMessage(JavaScriptMessage message) {
    if (_disposed) return;
    onEvent?.call('page says ${message.message}');
    if (message.message == 'blocked') onBlocked?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    unawaited(web.loadRequest(Uri.parse('about:blank')).catchError((_) {}));
    super.dispose();
  }
}

/// Shows the site view of [controller], with YouTube's full screen in a
/// landscape page of its own.
class StudySite extends StatefulWidget {
  const StudySite({super.key, required this.controller});

  final StudySiteController controller;

  @override
  State<StudySite> createState() => _StudySiteState();
}

class _StudySiteState extends State<StudySite> {
  Route<void>? _fullscreen;

  @override
  void initState() {
    super.initState();
    final platform = widget.controller.web.platform;
    if (platform is AndroidWebViewController) {
      unawaited(
        platform.setCustomWidgetCallbacks(
          onShowCustomWidget: _showFullscreen,
          onHideCustomWidget: _hideFullscreen,
        ),
      );
    }
  }

  void _showFullscreen(Widget view, void Function() hidden) {
    if (_fullscreen != null || !mounted) return;
    final route = MaterialPageRoute<void>(
      builder: (_) => _FullscreenVideo(view: view),
    );
    _fullscreen = route;
    unawaited(
      Navigator.of(context).push(route).then((_) {
        // Closed with back: the web view has to be told.
        if (identical(_fullscreen, route)) {
          _fullscreen = null;
          hidden();
        }
      }),
    );
  }

  void _hideFullscreen() {
    final route = _fullscreen;
    _fullscreen = null;
    if (route == null || !mounted || !route.isActive) return;
    Navigator.of(context).removeRoute(route);
  }

  @override
  Widget build(BuildContext context) {
    final platform = widget.controller.web.platform;
    return ColoredBox(
      color: Colors.black,
      child: platform is AndroidWebViewController
          ? WebViewWidget.fromPlatformCreationParams(
              params: AndroidWebViewWidgetCreationParams(
                controller: platform,
                displayWithHybridComposition: true,
              ),
            )
          : WebViewWidget(controller: widget.controller.web),
    );
  }
}

/// The video alone, in landscape, without the system bars.
class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.view});

  final Widget view;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(const []));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Colors.black, child: widget.view);
}

const _lookScript = '''
(function () {
  var v = document.querySelector('video');
  return JSON.stringify({
    href: location.href,
    title: document.title,
    time: v ? v.currentTime : -1,
    duration: v && isFinite(v.duration) ? v.duration : -1,
    ready: !!window.__studyReady && !!document.getElementById('study-style')
  });
})()''';

/// Hides the parts of YouTube's mobile site that lead to other videos, and
/// stops taps on links to pages that aren't study pages. Run on every page;
/// it sets itself up once.
const _prepareScript = r'''
(function () {
  var config = __CONFIG__;
  if (!window.__studyReady) {
    window.__studyReady = true;
    var allowed = function (href) {
      var u;
      try { u = new URL(href, location.href); } catch (e) { return false; }
      var host = u.hostname.toLowerCase();
      if (host !== 'youtube.com' && !/\.youtube\.com$/.test(host)) return false;
      var p = u.searchParams;
      if (u.pathname === '/watch') {
        return config.kind === 'playlist' ? p.get('list') === config.id : p.get('v') === config.id;
      }
      if (u.pathname === '/playlist') return config.kind === 'playlist' && p.get('list') === config.id;
      return false;
    };
    document.addEventListener('click', function (e) {
      var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
      if (!a) return;
      var href = a.getAttribute('href') || '';
      if (href === '' || href.charAt(0) === '#' || href.indexOf('javascript:') === 0) return;
      if (allowed(a.href)) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      try { StudySite.postMessage('blocked'); } catch (x) {}
    }, true);
  }
  if (!document.getElementById('study-style')) {
    var style = document.createElement('style');
    style.id = 'study-style';
    style.textContent = [
      'ytm-pivot-bar-renderer',
      'ytm-mobile-topbar-renderer',
      'ytm-item-section-renderer[section-identifier="related-items"]',
      'ytm-video-with-context-renderer',
      'ytm-reel-shelf-renderer',
      'ytm-comments-entry-point-header-renderer',
      'comments-entry-point-teaser-view-model',
      'ytm-comment-section-renderer',
      'ytm-mealbar-promo-renderer',
      'ytm-companion-slot',
      'ytm-promoted-sparkles-web-renderer',
      'ad-slot-renderer'
    ].join(',') + ' { display: none !important; }';
    (document.head || document.documentElement).appendChild(style);
  }
})();
''';
