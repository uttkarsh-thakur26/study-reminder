// Checks on an Android emulator how YouTube treats the user's study
// playlist: in the app's embedded player, and on YouTube's mobile site in a
// web view. Prints what happens; run by player-check.yml.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:study_reminder/features/focus/domain/study_videos.dart';
import 'package:study_reminder/features/focus/ui/study_embed.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const playlistId = 'PLDzeHZWIZsTryvtXdMr6rPh4IDexB5NIA';
const firstVideo = 'WQoB2z67hvY';

/// The video in YouTube's own IFrame API examples, made to be embedded.
const sample = 'M7lc1UVf-VE';

String stamp() => DateTime.now().toUtc().toIso8601String().substring(11, 19);

void say(String name, List<String> log) {
  // ignore: avoid_print
  print('=== $name ===\n${log.join('\n')}\n');
}

Future<int> oembed(http.Client client, String id) async {
  try {
    final r = await client.get(
      Uri.parse(
        'https://www.youtube.com/oembed?format=json&url='
        '${Uri.encodeComponent('https://www.youtube.com/watch?v=$id')}',
      ),
    );
    return r.statusCode;
  } on Object {
    return -1;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(int seconds) =>
      Future<void>.delayed(Duration(seconds: seconds));

  const videoData = '''
(function() {
  if (typeof player === 'undefined' || !player || !player.getVideoData) return 'none';
  var d = player.getVideoData();
  var out = {};
  for (var k in d) { if (typeof d[k] !== 'object') out[k] = d[k]; }
  return JSON.stringify(out);
})()''';

  Future<void> embed(
    WidgetTester tester,
    String name,
    StudyVideo study, {
    bool oembedPlaylist = false,
  }) async {
    final log = <String>['${stamp()} begin $name'];
    final c = StudyEmbedController(
      onEvent: (e) {
        if (!e.startsWith('console')) log.add('${stamp()} $e');
      },
    );
    String now() =>
        'ready=${c.ready} state=${c.state} id=${c.videoId} '
        'index=${c.index}/${c.count} problem=${c.problem?.name} '
        'origin=${c.origin} tap=${c.needsTap}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: StudyEmbed(controller: c),
                ),
                Text(name, style: const TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
    unawaited(c.open(study));
    for (var i = 0; i < 25; i++) {
      await wait(1);
      await tester.pump();
      if (i % 5 == 4) log.add('${stamp()} t$i: ${now()}');
    }
    try {
      log.add(
        'video data: ${await c.web.runJavaScriptReturningResult(videoData)}',
      );
    } on Object catch (e) {
      log.add('video data failed: $e');
    }
    if (oembedPlaylist && c.ready) {
      try {
        final raw = await c.web.runJavaScriptReturningResult(
          'JSON.stringify(player.getPlaylist() || [])',
        );
        var text = raw.toString();
        // Android hands the string back JSON-quoted.
        if (text.startsWith('"')) text = jsonDecode(text) as String;
        final ids = (jsonDecode(text) as List).cast<String>();
        final client = http.Client();
        final codes = <int, int>{};
        final blocked = <String>[];
        for (final id in ids) {
          final code = await oembed(client, id);
          codes[code] = (codes[code] ?? 0) + 1;
          if (code != 200 && blocked.length < 10) blocked.add('$id=$code');
        }
        client.close();
        log.add('oembed over ${ids.length} playlist videos: $codes');
        log.add('first not embeddable: $blocked');
      } on Object catch (e) {
        log.add('oembed check failed: $e');
      }
    }
    log.add('${stamp()} end $name: ${now()}');
    say(name, log);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await wait(2);
  }

  testWidgets('1 oembed of single videos', (tester) async {
    final client = http.Client();
    final log = <String>[];
    for (final id in [firstVideo, sample, 'jNQXAC9IVRw']) {
      log.add('$id: ${await oembed(client, id)}');
    }
    client.close();
    say('oembed', log);
  });

  testWidgets('2 embed: the YouTube API sample video', (tester) async {
    await embed(tester, 'embed-sample', const StudyVideo.video(sample));
  });

  testWidgets('3 embed: the study playlist', (tester) async {
    await embed(
      tester,
      'embed-playlist',
      const StudyVideo.playlist(playlistId),
      oembedPlaylist: true,
    );
  });

  testWidgets('4 YouTube mobile site in a web view', (tester) async {
    final log = <String>['${stamp()} begin mobile-site'];
    final c = WebViewController();
    await c.setJavaScriptMode(JavaScriptMode.unrestricted);
    await c.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (r) {
          log.add('${stamp()} navigation main=${r.isMainFrame} ${r.url}');
          return NavigationDecision.navigate;
        },
        onUrlChange: (change) => log.add('${stamp()} url ${change.url}'),
        onPageFinished: (url) => log.add('${stamp()} finished $url'),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? false) {
            log.add('${stamp()} main frame error ${e.errorCode} ${e.url}');
          }
        },
      ),
    );
    final platform = c.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
    await c.loadRequest(
      Uri.parse('https://m.youtube.com/watch?v=$firstVideo&list=$playlistId'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: platform is AndroidWebViewController
                ? WebViewWidget.fromPlatformCreationParams(
                    params: AndroidWebViewWidgetCreationParams(
                      controller: platform,
                      displayWithHybridComposition: true,
                    ),
                  )
                : WebViewWidget(controller: c),
          ),
        ),
      ),
    );
    const probe = '''
(function() {
  var v = document.querySelector('video');
  var e = document.querySelector('.ytp-error, .player-error-message-container, ytm-player-error-message-renderer');
  return JSON.stringify({
    href: location.href.substring(0, 140),
    title: document.title,
    video: v ? {paused: v.paused, time: Math.round(v.currentTime), ready: v.readyState, duration: Math.round(v.duration || 0)} : null,
    error: e ? e.innerText.substring(0, 200) : null,
    text: (document.body ? document.body.innerText : '').replace(/\\s+/g, ' ').substring(0, 300)
  });
})()''';
    Future<void> look(String when) async {
      try {
        log.add(
          '${stamp()} $when: ${await c.runJavaScriptReturningResult(probe)}',
        );
      } on Object catch (e) {
        log.add('${stamp()} $when failed: $e');
      }
    }

    Future<void> watch(int seconds, String what) async {
      for (var i = 0; i < seconds; i++) {
        await wait(1);
        await tester.pump();
        if (i % 5 == 4) await look('$what t$i');
      }
    }

    await watch(25, 'start');
    log.add('${stamp()} play() from script');
    try {
      await c.runJavaScript("document.querySelector('video').play();");
    } on Object catch (e) {
      log.add('play failed: $e');
    }
    await watch(10, 'after play');
    log.add('${stamp()} clicking a link to another video');
    try {
      final r = await c.runJavaScriptReturningResult('''
(function() {
  var links = document.querySelectorAll('a[href*="/watch?v="]');
  for (var i = 0; i < links.length; i++) {
    if (links[i].href.indexOf('$firstVideo') < 0) { var h = links[i].href; links[i].click(); return h; }
  }
  return 'no link';
})()''');
      log.add('${stamp()} clicked $r');
    } on Object catch (e) {
      log.add('click failed: $e');
    }
    await watch(10, 'after click');
    say('mobile-site', log);
    await tester.pumpWidget(const SizedBox());
    await wait(2);
  });
}
