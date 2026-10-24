// Checks on an Android emulator that the study player loads and plays the
// user's study playlist, and sends the player back from other videos.
// Prints what happens; run by player-check.yml.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:study_reminder/features/focus/domain/study_videos.dart';
import 'package:study_reminder/features/focus/ui/study_embed.dart';

const playlist = StudyVideo.playlist('PLDzeHZWIZsTryvtXdMr6rPh4IDexB5NIA');
const video = StudyVideo.video('WQoB2z67hvY');

/// A video outside the playlist.
const outside = 'jNQXAC9IVRw';

String stamp() => DateTime.now().toUtc().toIso8601String().substring(11, 19);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(int seconds) =>
      Future<void>.delayed(Duration(seconds: seconds));

  Future<void> check(
    WidgetTester tester,
    String name,
    StudyVideo study, {
    int origin = 0,
    bool tryOutside = false,
  }) async {
    final log = <String>['${stamp()} begin $name'];
    var blocked = 0;
    final c = StudyEmbedController(
      firstOrigin: origin,
      onEvent: (e) => log.add('${stamp()} $e'),
      onBlocked: () => blocked++,
      onPlaylistIndex: (_, i) => log.add('${stamp()} saved index $i'),
    );
    String now() =>
        'ready=${c.ready} state=${c.state} id=${c.videoId} '
        'index=${c.index}/${c.count} problem=${c.problem?.name} '
        'origin=${c.origin} tap=${c.needsTap} blocked=$blocked';

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

    Future<void> watch(int seconds, String what) async {
      for (var i = 0; i < seconds; i++) {
        await wait(1);
        await tester.pump();
        if (i % 5 == 4) log.add('${stamp()} $what t$i: ${now()}');
      }
    }

    await watch(30, 'start');
    if (c.state != 1 && c.ready) {
      final box = tester.getRect(find.byType(StudyEmbed));
      log.add('${stamp()} tap at ${box.center}');
      await tester.tapAt(box.center);
      await watch(15, 'after tap');
    }
    if (tryOutside && c.ready) {
      log.add('${stamp()} loading an outside video');
      await c.web.runJavaScript("player.loadVideoById('$outside');");
      await watch(10, 'after outside');
    }
    log.add('${stamp()} end $name: ${now()}');
    // ignore: avoid_print
    print('=== $name ===\n${log.join('\n')}\n');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await wait(2);
  }

  testWidgets('1 playlist, app id origin, outside video', (tester) async {
    await check(tester, 'playlist-app-origin', playlist, tryOutside: true);
  });

  testWidgets('2 single video, app id origin, outside video', (tester) async {
    await check(tester, 'video-app-origin', video, tryOutside: true);
  });

  testWidgets('3 playlist, youtube.com origin', (tester) async {
    await check(tester, 'playlist-youtube-origin', playlist, origin: 1);
  });

  testWidgets('4 playlist, youtube-nocookie origin', (tester) async {
    await check(tester, 'playlist-nocookie-origin', playlist, origin: 2);
  });
}
