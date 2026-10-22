import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/domain/laptop_block_rules.dart';

void main() {
  final rules = LaptopBlockRules(
    programs: ['steam.exe', 'Discord.exe'],
    sites: ['youtube.com', 'x.com', 'reddit.com', 'bbc.co.uk'],
  );

  const chrome = r'C:\Program Files\Google\Chrome\Application\chrome.exe';
  const edge = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe';

  test('blocked programs match by file name, any case and path', () {
    final hit = rules.match(r'C:\Games\Steam\STEAM.EXE', 'Steam');
    expect(hit?.label, 'steam');
    expect(hit?.isSite, isFalse);
    expect(rules.match(r'D:\apps\discord.exe', 'Friends'), isNotNull);
    expect(rules.match(r'C:\Windows\notepad.exe', 'YouTube notes'), isNull);
  });

  test('sites match by the page title in a browser', () {
    expect(
      rules.match(chrome, 'Lo-fi beats - YouTube - Google Chrome')?.label,
      'YouTube',
    );
    expect(
      rules
          .match(
            edge,
            'Home / X and 3 more pages - Personal - Microsoft\u200b Edge',
          )
          ?.label,
      'X',
    );
    expect(rules.match(chrome, 'r/learnmath - Reddit'), isNotNull);
    expect(rules.match(chrome, 'BBC News - Home')?.label, 'Bbc');
    expect(rules.match(chrome, 'youtube.com/watch?v=1')?.isSite, isTrue);
  });

  test('similar words and other pages are left alone', () {
    expect(rules.match(chrome, 'Calculus notes - Google Docs'), isNull);
    expect(rules.match(chrome, 'Matrix X Y plots - Wikipedia'), isNull);
    expect(rules.match(chrome, 'myyoutubehelper docs'), isNull);
    // x.com inside other addresses.
    expect(rules.match(chrome, 'netflix.com - Watch TV'), isNull);
    expect(rules.match(chrome, 'dropbox.com login - Google Search'), isNull);
    expect(rules.match(chrome, 'Box.com | Sign in'), isNull);
    expect(rules.match(chrome, 'x.com/home - Google Chrome')?.label, 'X');
  });

  test('site keywords and tidying what the user types', () {
    expect(siteKeyword('https://www.youtube.com/watch'), 'youtube');
    expect(siteKeyword('news.bbc.co.uk'), 'bbc');
    expect(siteKeyword('localhost'), isNull);
    expect(normalizeSite(' HTTPS://www.Netflix.com/browse '), 'netflix.com');
    expect(normalizeSite('netflix'), isNull);
    expect(normalizeProgram('"C:\\Apps\\Spotify.exe"'), 'spotify.exe');
    expect(normalizeProgram('discord'), 'discord.exe');
    expect(normalizeProgram('  '), isNull);
  });
}
