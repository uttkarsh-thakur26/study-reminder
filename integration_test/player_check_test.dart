// Checks on an Android emulator that the phone's site view of YouTube stays
// on the study playlist: links elsewhere do nothing, and pages YouTube moves
// on to are left for the last study page. Prints what happens; run by
// player-check.yml.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:study_reminder/features/focus/domain/study_videos.dart';
import 'package:study_reminder/features/focus/ui/study_site.dart';

const playlist = StudyVideo.playlist('PLDzeHZWIZsTryvtXdMr6rPh4IDexB5NIA');

String stamp() => DateTime.now().toUtc().toIso8601String().substring(11, 19);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(int seconds) =>
      Future<void>.delayed(Duration(seconds: seconds));

  testWidgets('site view stays on the playlist', (tester) async {
    final log = <String>['${stamp()} begin'];
    var blocked = 0;
    final places = <String>[];
    final c = StudySiteController(
      onEvent: (e) => log.add('${stamp()} $e'),
      onBlocked: () => blocked++,
      onPlace: (_, v, i) => places.add('$v@$i'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(child: StudySite(controller: c)),
        ),
      ),
    );
    unawaited(c.open(playlist, at: 'WQoB2z67hvY'));

    Future<String> run(String script) async {
      try {
        final raw = await c.web
            .runJavaScriptReturningResult(script)
            .timeout(const Duration(seconds: 10));
        var text = raw.toString();
        if (text.startsWith('"')) text = jsonDecode(text) as String;
        return text;
      } on Object catch (e) {
        return 'failed: $e';
      }
    }

    const probe = '''
(function () {
  var v = document.querySelector('video');
  return JSON.stringify({
    href: location.href.substring(0, 120),
    video: v ? {paused: v.paused, time: Math.round(v.currentTime), ready: v.readyState} : null,
    style: !!document.getElementById('study-style'),
    text: (document.body ? document.body.innerText : '').replace(/\\s+/g, ' ').substring(0, 160)
  });
})()''';

    Future<void> watch(int seconds, String what) async {
      for (var i = 0; i < seconds; i++) {
        await wait(1);
        await tester.pump();
        if (i % 5 == 4) {
          log.add(
            '${stamp()} $what t$i: ${await run(probe)} '
            'title=${c.title} blocked=$blocked',
          );
        }
      }
    }

    await watch(25, 'start');

    // Which of YouTube's parts the page has, to hide the right ones.
    log.add(
      'tags: ${await run('''
(function () {
  var counts = {};
  document.querySelectorAll('*').forEach(function (e) {
    var t = e.tagName.toLowerCase();
    if (t.indexOf('ytm-') === 0 || t.indexOf('-renderer') > 0 || t.indexOf('-view-model') > 0) {
      var shown = e.offsetParent !== null || e.getClientRects().length > 0;
      counts[t] = (counts[t] || 0) + (shown ? 1 : 0);
    }
  });
  return JSON.stringify(counts);
})()''')}',
    );
    log.add(
      'links: ${await run('''
(function () {
  var out = [];
  document.querySelectorAll('a[href]').forEach(function (a) {
    if (out.length < 25) out.push(a.getAttribute('href').substring(0, 80));
  });
  return JSON.stringify(out);
})()''')}',
    );

    log.add('${stamp()} tapping a link that leaves the playlist');
    log.add(
      'clicked: ${await run('''
(function () {
  var links = document.querySelectorAll('a[href]');
  for (var i = 0; i < links.length; i++) {
    var h = links[i].href;
    if (h.indexOf('PLDzeHZWIZsTryvtXdMr6rPh4IDexB5NIA') < 0) { links[i].click(); return h; }
  }
  return 'no link';
})()''')}',
    );
    await watch(5, 'after link');

    log.add('${stamp()} YouTube changing page without loading one');
    await run("history.pushState({}, '', '/results?search_query=cats'); 'ok'");
    await watch(10, 'after pushState');

    log.add('${stamp()} a page load elsewhere');
    await run("location.href = 'https://m.youtube.com/'; 'ok'");
    await watch(10, 'after load');

    log.add('${stamp()} end blocked=$blocked places=$places');
    // ignore: avoid_print
    print('=== site-view ===\n${log.join('\n')}\n');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await wait(2);
  });
}
