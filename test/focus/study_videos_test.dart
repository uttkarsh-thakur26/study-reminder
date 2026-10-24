import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';
import 'package:study_reminder/features/focus/domain/study_videos.dart';

void main() {
  group('StudyVideo.parse', () {
    test('reads video links in their usual shapes', () {
      for (final link in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'youtube.com/watch?v=dQw4w9WgXcQ&t=42s',
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ?si=abc',
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        'https://www.youtube.com/live/dQw4w9WgXcQ',
        '  https://www.youtube.com/embed/dQw4w9WgXcQ  ',
      ]) {
        final v = StudyVideo.parse(link);
        expect(v?.isPlaylist, isFalse, reason: link);
        expect(v?.id, 'dQw4w9WgXcQ', reason: link);
      }
    });

    test('a link with a playlist in it gives the playlist', () {
      final page = StudyVideo.parse(
        'https://www.youtube.com/playlist?list=PLabc_DEF-123',
      )!;
      expect(page.isPlaylist, isTrue);
      expect(page.id, 'PLabc_DEF-123');
      expect(page.startId, isNull);

      final fromVideo = StudyVideo.parse(
        'https://youtu.be/dQw4w9WgXcQ?list=PLabc_DEF-123&index=4',
      )!;
      expect(fromVideo.isPlaylist, isTrue);
      expect(fromVideo.startId, 'dQw4w9WgXcQ');
      expect(
        fromVideo.url,
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLabc_DEF-123',
      );
    });

    test('anything else is not a study video', () {
      for (final text in [
        '',
        'lecture notes',
        'https://www.youtube.com/',
        'https://www.youtube.com/@channel',
        'https://notyoutube.com/watch?v=dQw4w9WgXcQ',
        'https://vimeo.com/123456',
        'https://www.youtube.com/watch?v=bad id',
        'ftp://youtube.com/watch?v=dQw4w9WgXcQ',
      ]) {
        expect(StudyVideo.parse(text), isNull, reason: text);
      }
    });

    test('survives a trip through the settings', () {
      const prefs = FocusPrefs(
        studyVideos: [
          StudyVideo.video('dQw4w9WgXcQ', title: 'Lecture 1'),
          StudyVideo.playlist('PLabc_DEF-123', startId: 'dQw4w9WgXcQ'),
        ],
      );
      final back = FocusPrefs.decode(prefs.encode()).studyVideos;
      expect(back, hasLength(2));
      expect(back[0].title, 'Lecture 1');
      expect(back[0].isPlaylist, isFalse);
      expect(back[1].isPlaylist, isTrue);
      expect(back[1].startId, 'dQw4w9WgXcQ');
      expect(back[1].label, 'Playlist');
      expect(FocusPrefs.decode('{}').studyVideos, isEmpty);
      expect(
        FocusPrefs.decode('{"studyVideos":[{"kind":"x","id":"abcdefg"},3]}')
            .studyVideos,
        isEmpty,
      );
    });
  });

  group('StudyVideoRules', () {
    final rules = StudyVideoRules(const [
      StudyVideo.video('dQw4w9WgXcQ', title: 'Lecture 1'),
      StudyVideo.playlist('PLabc_DEF-123'),
    ]);

    test('allows the study video and anything in the study playlist', () {
      expect(rules.allowsAddress('youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(
        rules.allowsAddress(
          'https://www.youtube.com/watch?v=zzzzzzzzzzz&list=PLabc_DEF-123',
        ),
        isTrue,
      );
      expect(
        rules.allowsAddress('www.youtube.com/playlist?list=PLabc_DEF-123'),
        isTrue,
      );
    });

    test('blocks the rest of YouTube', () {
      for (final address in [
        'youtube.com',
        'youtube.com/results?search_query=cats',
        'youtube.com/watch?v=zzzzzzzzzzz',
        'youtube.com/watch?v=zzzzzzzzzzz&list=PLother1234',
        'youtube.com/shorts/zzzzzzzzzzz',
        'example.com/watch?v=dQw4w9WgXcQ',
      ]) {
        expect(rules.allowsAddress(address), isFalse, reason: address);
      }
    });

    test('knows study videos by title, as browsers show it', () {
      expect(rules.allowsTitle('Lecture 1 - YouTube - Google Chrome'), isTrue);
      expect(rules.allowsTitle('(3) Lecture 1 - YouTube'), isTrue);
      expect(rules.allowsTitle('Lecture 2 - YouTube'), isFalse);
      expect(rules.allowsTitle('YouTube'), isFalse);
      rules.learn('Lecture 2 - YouTube - Microsoft\u200b Edge');
      expect(rules.allowsTitle('Lecture 2 - YouTube'), isTrue);
    });
  });

  group('site view pages', () {
    const playlist = StudyVideo.playlist('PLabc_DEF-123');
    const video = StudyVideo.video('dQw4w9WgXcQ');

    test('opens a playlist at the saved video, its start, or its page', () {
      expect(
        playlist.siteUrl(),
        'https://m.youtube.com/playlist?list=PLabc_DEF-123',
      );
      expect(
        playlist.siteUrl(at: 'zzzzzzzzzzz'),
        'https://m.youtube.com/watch?v=zzzzzzzzzzz&list=PLabc_DEF-123',
      );
      expect(
        const StudyVideo.playlist(
          'PLabc_DEF-123',
          startId: 'yyyyyyyyyyy',
        ).siteUrl(),
        'https://m.youtube.com/watch?v=yyyyyyyyyyy&list=PLabc_DEF-123',
      );
      expect(video.siteUrl(), 'https://m.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('allows only the study pages', () {
      for (final url in [
        'https://m.youtube.com/watch?v=zzzzzzzzzzz&list=PLabc_DEF-123',
        'https://m.youtube.com/watch?v=zzzzzzzzzzz&list=PLabc_DEF-123&index=4&pp=x',
        'https://m.youtube.com/playlist?list=PLabc_DEF-123',
        'https://www.youtube.com/watch?list=PLabc_DEF-123&v=zzzzzzzzzzz',
      ]) {
        expect(playlist.allowsPage(url), isTrue, reason: url);
      }
      for (final url in [
        'https://m.youtube.com/',
        'https://m.youtube.com/watch?v=zzzzzzzzzzz',
        'https://m.youtube.com/watch?v=zzzzzzzzzzz&list=PLother1234',
        'https://m.youtube.com/results?search_query=cats',
        'https://m.youtube.com/shorts/zzzzzzzzzzz',
        'https://m.youtube.com/@channel',
        'https://example.com/watch?v=zzzzzzzzzzz&list=PLabc_DEF-123',
        'intent://watch?v=zzzzzzzzzzz&list=PLabc_DEF-123',
      ]) {
        expect(playlist.allowsPage(url), isFalse, reason: url);
      }
      expect(
        video.allowsPage('https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=30s'),
        isTrue,
      );
      expect(
        video.allowsPage('https://m.youtube.com/watch?v=zzzzzzzzzzz'),
        isFalse,
      );
      expect(
        video.allowsPage('https://m.youtube.com/playlist?list=dQw4w9WgXcQ'),
        isFalse,
      );
    });
  });
}
