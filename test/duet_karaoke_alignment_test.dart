import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/lrclib_lyrics_provider.dart';
import 'package:softify/services/lyrics/ttml_parser.dart';

void main() {
  group('Duet Vocalist Positioning & Agent Parsing Tests', () {
    test('LrclibLyricsProvider extracts agent tags from enhanced LRC', () {
      const lrc = '''
[00:05.00] {agent:v1} When I was young
[00:10.00] [agent:v2] I listened to the radio
[00:15.00] {agent:v1000} Waiting for my favorite songs
''';
      final lines = LrclibLyricsProvider.parseLrc(lrc);
      expect(lines.length, 3);

      expect(lines[0].text, 'When I was young');
      expect(lines[0].agent, 'v1');

      expect(lines[1].text, 'I listened to the radio');
      expect(lines[1].agent, 'v2');

      expect(lines[2].text, 'Waiting for my favorite songs');
      expect(lines[2].agent, 'v1000');
    });

    test('TTMLParser preserves vocalist agent on ParsedLine and LyricLine conversion', () {
      const ttml = '''<?xml version="1.0" encoding="utf-8"?>
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body>
    <div>
      <p begin="00:02.000" end="00:05.000" ttm:agent="v1">
        <span begin="00:02.000" end="00:05.000">Singer one line</span>
      </p>
      <p begin="00:12.000" end="00:16.000" ttm:agent="v2">
        <span begin="00:12.000" end="00:16.000">Singer two duet response</span>
      </p>
      <p begin="00:25.000" end="00:30.000" ttm:agent="v1000">
        <span begin="00:25.000" end="00:30.000">Chorus together in harmony</span>
      </p>
    </div>
  </body>
</tt>''';

      final parsed = TTMLParser.parseTTML(ttml);
      expect(parsed.length, 3);
      expect(parsed[0].agent, 'v1');
      expect(parsed[1].agent, 'v2');
      expect(parsed[2].agent, 'v1000');

      final lyricLines = TTMLParser.toLyricLines(parsed);
      expect(lyricLines.length, 3);
      expect(lyricLines[0].agent, 'v1');
      expect(lyricLines[1].agent, 'v2');
      expect(lyricLines[2].agent, 'v1000');

      // Verify interlude gap calculation for solo countdown
      final gap = lyricLines[1].timestamp - lyricLines[0].timestamp;
      expect(gap.inMilliseconds, greaterThanOrEqualTo(5000));
    });
  });
}
