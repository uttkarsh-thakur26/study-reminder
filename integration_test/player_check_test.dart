// Checks on a real Android device how the YouTube player behaves with the
// user's study playlist. Prints what happens; run by player-check.yml.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

const playlist = 'PLDzeHZWIZsTryvtXdMr6rPh4IDexB5NIA';
const video = 'WQoB2z67hvY';
const appOrigin = 'https://com.uttkarsh.study_reminder';

const probe = '''
(function() {
  var p = (typeof player !== 'undefined') ? player : null;
  if (p && p.addEventListener && !window.__hooked && typeof p.getPlayerState === 'function') {
    window.__hooked = true;
    window.__states = [];
    window.__onBlocked = function() { window.__blocked = (window.__blocked || 0) + 1; };
    window.__onErr = function(e) { window.__err = e.data; };
    window.__onState = function(e) { window.__states.push(e.data); };
    p.addEventListener('onAutoplayBlocked', '__onBlocked');
    p.addEventListener('onError', '__onErr');
    p.addEventListener('onStateChange', '__onState');
  }
  var ready = !!(p && typeof p.getPlayerState === 'function');
  var f = document.querySelector('iframe');
  return JSON.stringify({
    ready: ready,
    state: ready ? p.getPlayerState() : null,
    playlist: ready && p.getPlaylist() ? p.getPlaylist().length : null,
    index: ready ? p.getPlaylistIndex() : null,
    url: ready ? p.getVideoUrl() : null,
    blocked: window.__blocked || 0,
    err: window.__err,
    states: window.__states,
    iframe: f ? f.src.substring(0, 160) : null,
    referrer: document.referrer,
    origin: location.origin
  });
})()
''';

const rawProbe = '''
(function() {
  var m = document.getElementById('movie_player');
  var e = document.querySelector('.ytp-error-content-wrap-reason, .ytp-error');
  return JSON.stringify({
    title: document.title,
    href: location.href.substring(0, 120),
    state: m && m.getPlayerState ? m.getPlayerState() : null,
    error: e ? e.innerText.substring(0, 200) : null,
    video: m && m.getVideoData ? m.getVideoData().video_id : null
  });
})()
''';

String stamp() => DateTime.now().toUtc().toIso8601String().substring(11, 19);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(int seconds) =>
      Future<void>.delayed(Duration(seconds: seconds));

  Future<void> check(
    WidgetTester tester,
    String name, {
    required YoutubePlayerParams params,
    required Future<void> Function(YoutubePlayerController c) start,
    bool tap = false,
  }) async {
    final c = YoutubePlayerController(params: params);
    final t0 = DateTime.now();
    String at() => '${DateTime.now().difference(t0).inMilliseconds}ms';
    final log = <String>['${stamp()} begin $name'];
    final sub = c.listen(
      (v) => log.add(
        '${at()} value state=${v.playerState.name} error=${v.error.name} '
        'id=${v.metaData.videoId} title=${v.metaData.title}',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                YoutubePlayer(
                  controller: c,
                  backgroundColor: Colors.transparent,
                ),
                Text(name, style: const TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
    unawaited(
      start(c).then(
        (_) => log.add('${at()} start returned'),
        onError: (Object e) => log.add('${at()} start failed: $e'),
      ),
    );
    Future<void> look(String when) async {
      try {
        final r = await c.webViewController.runJavaScriptReturningResult(probe);
        log.add('${at()} probe $when ${stamp()}: $r');
      } on Object catch (e) {
        log.add('${at()} probe $when failed: $e');
      }
    }

    for (var i = 0; i < 25; i++) {
      await wait(1);
      await tester.pump();
      if (i % 5 == 4) await look('t$i');
    }
    if (tap) {
      final box = tester.getRect(find.byType(YoutubePlayer));
      log.add('${at()} tap at ${box.center} ${stamp()}');
      await tester.tapAt(box.center);
      for (var i = 0; i < 15; i++) {
        await wait(1);
        await tester.pump();
        if (i % 5 == 4) await look('after tap t$i');
      }
    }
    log.add('${stamp()} end $name');
    // ignore: avoid_print
    print('=== $name ===\n${log.join('\n')}\n');
    await sub.cancel();
    await tester.pumpWidget(const SizedBox());
    // Waits up to 30 s for a player that never got ready.
    unawaited(c.close().catchError((Object _) {}));
    await wait(2);
  }

  testWidgets('1 app today: loadPlaylist, default params', (tester) async {
    await check(
      tester,
      'load-playlist-default',
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
      start: (c) => c.loadPlaylist(
        list: [playlist],
        listType: ListType.playlist,
        index: 0,
      ),
    );
  });

  testWidgets('2 cuePlaylist, default params, then tap', (tester) async {
    await check(
      tester,
      'cue-playlist-default',
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
      start: (c) => c.cuePlaylist(
        list: [playlist],
        listType: ListType.playlist,
        index: 0,
      ),
      tap: true,
    );
  });

  testWidgets('3 loadVideoById, default params', (tester) async {
    await check(
      tester,
      'load-video-default',
      params: const YoutubePlayerParams(strictRelatedVideos: true),
      start: (c) => c.loadVideoById(videoId: video),
    );
  });

  testWidgets('4 cuePlaylist with the app as origin, then tap', (tester) async {
    await check(
      tester,
      'cue-playlist-app-origin',
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        origin: appOrigin,
      ),
      start: (c) => c.cuePlaylist(
        list: [playlist],
        listType: ListType.playlist,
        index: 0,
      ),
      tap: true,
    );
  });

  testWidgets('5 cueVideoById, youtube.com host, then tap', (tester) async {
    await check(
      tester,
      'cue-video-youtube-host',
      params: const YoutubePlayerParams(
        strictRelatedVideos: true,
        privacyEnhancedMode: false,
      ),
      start: (c) => c.cueVideoById(videoId: video),
      tap: true,
    );
  });

  testWidgets('6 raw embed page with a Referer header', (tester) async {
    final log = <String>['${stamp()} begin raw-embed'];
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) => log.add('${stamp()} finished $url'),
          onWebResourceError: (e) =>
              log.add('${stamp()} resource error ${e.errorCode} ${e.url}'),
          onNavigationRequest: (r) {
            log.add('${stamp()} navigation ${r.url}');
            return NavigationDecision.navigate;
          },
        ),
      );
    final platform = c.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
    await c.loadRequest(
      Uri.parse(
        'https://www.youtube.com/embed/videoseries?list=$playlist'
        '&playsinline=1&rel=0&enablejsapi=1',
      ),
      headers: {'Referer': '$appOrigin/'},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: WebViewWidget(controller: c),
                ),
                const Text('raw-embed', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
    Future<void> look(String when) async {
      try {
        final r = await c.runJavaScriptReturningResult(rawProbe);
        log.add('${stamp()} probe $when: $r');
      } on Object catch (e) {
        log.add('${stamp()} probe $when failed: $e');
      }
    }

    for (var i = 0; i < 15; i++) {
      await wait(1);
      await tester.pump();
      if (i % 5 == 4) await look('t$i');
    }
    final box = tester.getRect(find.byType(WebViewWidget));
    log.add('${stamp()} tap at ${box.center}');
    await tester.tapAt(box.center);
    for (var i = 0; i < 15; i++) {
      await wait(1);
      await tester.pump();
      if (i % 5 == 4) await look('after tap t$i');
    }
    // ignore: avoid_print
    print('=== raw-embed ===\n${log.join('\n')}\n');
  });
}
