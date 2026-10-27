import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/kugou_lyrics_provider.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';
import 'package:softify/services/lyrics/better_lyrics_provider.dart';
import 'package:softify/services/lyrics/lyrics_provider_registry.dart';
import 'package:softify/services/lyrics/romanization_service.dart';
import 'package:softify/services/lyrics/ttml_parser.dart';

void main() {
  group('TTMLParser Tests', () {
    test('testV1000AgentMapping: v1000 group is mapped to agent:v2 alongside v1', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <head>
    <metadata>
      <ttm:agent xml:id="v1000" type="group"/>
      <ttm:agent xml:id="v1" type="person"/>
    </metadata>
  </head>
  <body>
    <div>
      <p begin="00:01.500" ttm:agent="v1000">
        <span>(Group vocal)</span>
      </p>
      <p begin="00:02.000" ttm:agent="v1">
        <span>Main vocal</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.length, 2);
      expect(lines[0].agent, 'v1000');
      expect(lines[1].agent, 'v1');

      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.contains('{agent:v2}(Group vocal)'), isTrue);
      expect(lrc.contains('{agent:v1}Main vocal'), isTrue);
    });

    test('testTimeFormats: parses seconds, milliseconds, and standard MM:SS.xx', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="1.5s">
        <span>1.5 seconds</span>
      </p>
      <p begin="2000ms">
        <span>2000 milliseconds</span>
      </p>
      <p begin="00:03.50">
        <span>Standard format</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.length, 3);
      expect(lines[0].startTime, 1.5);
      expect(lines[1].startTime, 2.0);
      expect(lines[2].startTime, 3.5);

      final lrc = TTMLParser.toLRC(lines);
      final lrcLines = lrc.trim().split('\n');
      expect(lrcLines[0].startsWith('[00:01.50]'), isTrue);
      expect(lrcLines[1].startsWith('[00:02.00]'), isTrue);
      expect(lrcLines[2].startsWith('[00:03.50]'), isTrue);
    });

    test('testRoleXBgMapping: role x-bg marks background line with {bg}', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body>
    <div>
      <p begin="00:05.000">
        <span ttm:role="x-bg">Background role</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.length, 1);
      expect(lines[0].isBackground, isTrue);

      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.contains('{bg}Background role'), isTrue);
    });

    test('testWordLevelSync: parses syllable words with begin and end timestamps', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:10.000">
        <span begin="00:10.000" end="00:10.500">Hello </span>
        <span begin="00:10.600" end="00:11.000">world</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.length, 1);
      final words = lines[0].words;
      expect(words.length, 2);
      expect(words[0].text, 'Hello');
      expect(words[0].startTime, 10.0);
      expect(words[0].endTime, 10.5);
      expect(words[1].text, 'world');
      expect(words[1].startTime, 10.6);
      expect(words[1].endTime, 11.0);

      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.contains('<Hello:10.0:10.5|world:10.6:11.0>'), isTrue);
    });

    test('testSingleVocalistWithBackground: includes agent:v1 to distinguish from bg', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body>
    <div>
      <p begin="00:01.000" ttm:agent="v1">
        <span>Main line</span>
      </p>
      <p begin="00:01.200" ttm:agent="v1">
        <span ttm:role="x-bg">bg</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.contains('{agent:v1}'), isTrue);
      expect(lrc.contains('{bg}bg'), isTrue);
    });

    test('testSingleVocalistNotV1: preserves explicit vocalist agent v2', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body>
    <div>
      <p begin="00:01.000" ttm:agent="v2">
        <span>Only singer is v2</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.contains('{agent:v2}Only singer is v2'), isTrue);
    });

    test('testLyricOffset: head metadata audio lyricOffset shifts timestamps', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <head>
    <metadata>
      <audio lyricOffset="10.5"/>
    </metadata>
  </head>
  <body>
    <div>
      <p begin="00:01.000">
        <span begin="00:01.000" end="00:02.000">Hello</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.length, 1);
      expect(lines[0].startTime, 11.5);
      expect(lines[0].words[0].startTime, 11.5);
      expect(lines[0].words[0].endTime, 12.5);

      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.contains('[00:11.50]'), isTrue);
      expect(lrc.contains('Hello:11.5:12.5'), isTrue);
    });

    test('testTranslationAndRomanSpansAreSkipped', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body>
    <div>
      <p begin="00:01.000">
        <span begin="00:01.000" end="00:02.000">Main lyric</span>
        <span ttm:role="x-roman">Romanization</span>
        <span ttm:role="x-translation">Translation</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.length, 1);
      expect(lines[0].text, 'Main lyric');
      expect(lines[0].words.length, 1);
      expect(lines[0].words[0].text, 'Main lyric');
    });

    test('testSplitSyllableSpansAreMerged into single word', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:01.000">
        <span begin="00:01.000" end="00:01.500">hel</span><span begin="00:01.500" end="00:02.000">lo</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.length, 1);
      final line = lines[0];
      expect(line.text, 'hello');
      expect(line.words.length, 1);
      expect(line.words[0].text, 'hello');
      expect(line.words[0].startTime, 1.0);
      expect(line.words[0].endTime, 2.0);
    });

    test('testMultipleBackgroundSpansInOneP are merged into a bg line', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body>
    <div>
      <p begin="00:01.000">
        <span begin="00:01.000" end="00:02.000">Main lyric </span>
        <span ttm:role="x-bg" begin="00:01.200">
          <span begin="00:01.200" end="00:01.500">Bg1 </span>
        </span>
        <span ttm:role="x-bg" begin="00:01.600">
          <span begin="00:01.600" end="00:01.900">Bg2</span>
        </span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.contains('{bg}Bg1 Bg2'), isTrue);
      expect(lrc.contains('<Bg1:1.2:1.5|Bg2:1.6:1.9>'), isTrue);
    });

    test('testSequentialBackgroundDeDuplication: only first bg has {bg}', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <head>
    <metadata>
      <ttm:agent xml:id="v1" type="person"/>
      <ttm:agent xml:id="v2" type="person"/>
    </metadata>
  </head>
  <body>
    <div>
      <p begin="00:01.000" ttm:role="x-bg" ttm:agent="v1">
        <span>Line 1</span>
      </p>
      <p begin="00:02.000" ttm:role="x-bg" ttm:agent="v1">
        <span>Line 2</span>
      </p>
      <p begin="00:03.000" ttm:agent="v1">
        <span>Main Line </span>
        <span ttm:role="x-bg" begin="00:03.500">
          <span>Nested Bg</span>
        </span>
      </p>
      <p begin="00:04.000" ttm:role="x-bg" ttm:agent="v1">
        <span>Line 4</span>
      </p>
      <p begin="00:05.000" ttm:agent="v2">
        <span>Line 5</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      final lrc = TTMLParser.toLRC(lines);
      final linesList =
          lrc.trim().split('\n').where((l) => l.startsWith('[')).toList();

      expect(linesList[0].contains('{bg}Line 1'), isTrue);
      expect(linesList[1].contains('{bg}'), isFalse);
      expect(linesList[2].contains('{agent:v1}Main Line'), isTrue);
      expect(linesList[3].contains('{bg}Nested Bg'), isTrue);
      expect(linesList[4].contains('{bg}'), isFalse);
      expect(linesList[5].contains('{agent:v2}Line 5'), isTrue);
    });

    test('testTtpTimingOnParagraph', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttp="http://www.w3.org/ns/ttml#parameter">
  <body>
    <div>
      <p ttp:begin="2.5" ttp:end="4.0">
        <span>Only timing on ttp</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.isNotEmpty, isTrue);
      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.contains('[00:02.50]'), isTrue);
      expect(lrc.contains('Only timing on ttp'), isTrue);
    });

    test('testParagraphInheritsBeginFromFirstSpan', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p>
        <span begin="00:05.000" end="00:05.500">No </span>
        <span begin="00:05.500" end="00:06.000">begin </span>
        <span begin="00:06.000" end="00:06.500">on p</span>
      </p>
    </div>
  </body>
</tt>
''';

      final lines = TTMLParser.parseTTML(ttml);
      expect(lines.isNotEmpty, isTrue);
      final lrc = TTMLParser.toLRC(lines);
      expect(lrc.trim().split('\n').first.startsWith('[00:05.00]'), isTrue);
    });

    test('toSyncedLyrics converts into domain SyncedLyrics with LyricLine and LyricWord', () {
      const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:01.000">
        <span begin="00:01.000" end="00:01.400">Softify </span>
        <span begin="00:01.400" end="00:02.000">Karaoke</span>
      </p>
    </div>
  </body>
</tt>
''';

      final parsedLines = TTMLParser.parseTTML(ttml);
      final synced = TTMLParser.toSyncedLyrics('track_123', parsedLines);

      expect(synced.trackId, 'track_123');
      expect(synced.syncType, 'SYLLABLE_SYNCED');
      expect(synced.isSyllableSynced, isTrue);
      expect(synced.lines.length, 1);
      expect(synced.lines[0].text, 'Softify Karaoke');
      expect(synced.lines[0].words?.length, 2);
      expect(synced.lines[0].words?[0].text, 'Softify');
      expect(synced.lines[0].words?[0].duration?.inMilliseconds, 400);
      expect(synced.lines[0].words?[1].text, 'Karaoke');
      expect(synced.lines[0].words?[1].duration?.inMilliseconds, 600);
    });
  });

  group('RomanizationService Multilingual Engine Tests', () {
    test('Japanese Kana & Digraphs transliteration into Romaji', () {
      expect(RomanizationService.romanizeJapanese('キョウト'), 'kyouto');
      expect(RomanizationService.romanizeJapanese('トーキョー'), 'tokyo');
      expect(RomanizationService.romanizeJapanese('とうきょう'), 'toukyou');
      expect(RomanizationService.romanizeJapanese('ありがとう'), 'arigatou');
      expect(RomanizationService.romanizeJapanese('さようなら'), 'sayounara');
      expect(RomanizationService.romanizeJapanese('きっと'), 'kitto'); // Sokuon consonant doubling
      expect(RomanizationService.romanizeJapanese('ジャズ'), 'jazu');
    });

    test('Japanese Common Lyrics Kanji transliteration', () {
      expect(RomanizationService.romanizeJapanese('愛してる'), contains('ai'));
      expect(RomanizationService.romanizeJapanese('君の夢'), contains('kimi'));
      expect(RomanizationService.romanizeJapanese('心から'), contains('kokoro'));
    });

    test('Korean Revised Romanization with phonetic assimilation', () {
      expect(RomanizationService.romanizeKorean('안녕하세요'), 'annyeonghaseyo');
      expect(RomanizationService.romanizeKorean('사랑해'), 'saranghae');
      expect(RomanizationService.romanizeKorean('감사합니다'), 'gamsahamnida');
      expect(RomanizationService.romanizeKorean('강남'), 'gangnam');
    });

    test('Chinese Hanzi transliteration to Pinyin', () {
      expect(RomanizationService.romanizeChinese('我爱你'), 'wo ai ni');
      expect(RomanizationService.romanizeChinese('你好'), 'ni hao');
      expect(RomanizationService.romanizeChinese('我的歌声里'), 'wo de ge sheng li');
    });

    test('Russian Cyrillic transliteration with word-initial ye and genitive ovo', () {
      expect(RomanizationService.romanizeRussian('Привет'), 'Privet');
      expect(RomanizationService.romanizeRussian('Если'), 'Yesli');
      expect(RomanizationService.romanizeRussian('Хорошего'), 'Khoroshevo');
      expect(RomanizationService.romanizeRussian('Спасибо'), 'Spasibo');
    });

    test('Ukrainian Cyrillic transliteration with h, yi, ye and iotation', () {
      expect(RomanizationService.romanizeUkrainian('Україна'), 'Ukrayina');
      expect(RomanizationService.romanizeUkrainian('Київ'), 'Kyyiv');
      expect(RomanizationService.romanizeUkrainian('Добрий день'), 'Dobryy den');
    });

    test('Automatic script detection', () {
      expect(RomanizationService.detectLanguage('こんにちは'), 'Japanese');
      expect(RomanizationService.detectLanguage('안녕하세요'), 'Korean');
      expect(RomanizationService.detectLanguage('我爱你中国'), 'Chinese');
      expect(RomanizationService.detectLanguage('Привет мир'), 'Russian');
      expect(RomanizationService.detectLanguage('Доброго вечора, ми з України'), 'Ukrainian');
      expect(RomanizationService.detectLanguage('नमस्ते'), 'Indic');
      expect(RomanizationService.detectLanguage('Hello World'), isNull);
    });

    test('romanizeSyncedLyrics transliterates entire container preserving timestamps', () {
      const orig = SyncedLyrics(
        trackId: 'jp_1',
        lines: [
          LyricLine(
            timestamp: Duration(seconds: 5),
            text: 'ありがとう',
            words: [
              LyricWord(
                timestamp: Duration(seconds: 5),
                text: 'ありがとう',
                duration: Duration(milliseconds: 800),
              ),
            ],
          ),
        ],
        syncType: 'SYLLABLE_SYNCED',
        plainLyrics: 'ありがとう',
      );

      final romanized = RomanizationService.romanizeSyncedLyrics(orig);
      expect(romanized.lines[0].text, 'arigatou');
      expect(romanized.lines[0].words?[0].text, 'arigatou');
      expect(romanized.lines[0].timestamp, const Duration(seconds: 5));
      expect(romanized.plainLyrics, 'arigatou');
    });
  });

  group('LyricsProviderRegistry Tests', () {
    test('Default priority order includes BetterLyrics, LrcLib, KuGou, Paxsenix, Zemer, Spotify', () {
      final registry = LyricsProviderRegistry();
      expect(registry.priorityOrder, [
        'BetterLyrics',
        'LrcLib',
        'KuGou',
        'Paxsenix',
        'Zemer',
        'Spotify',
      ]);
    });

    test('Configures and serializes custom priority order', () {
      final registry = LyricsProviderRegistry();
      registry.setPriorityOrder(['KuGou', 'BetterLyrics', 'Spotify', 'LrcLib']);
      expect(registry.priorityOrder, [
        'KuGou',
        'BetterLyrics',
        'Spotify',
        'LrcLib',
        'Paxsenix',
        'Zemer',
      ]);
      expect(
        registry.serializeProviderOrder(['KuGou', 'BetterLyrics', 'Spotify', 'LrcLib']),
        'KuGou,BetterLyrics,Spotify,LrcLib',
      );
    });

    test('Deserializes priority order string with fallback for missing providers', () {
      final registry = LyricsProviderRegistry();
      final order = registry.deserializeProviderOrder('Spotify,BetterLyrics');
      expect(order, ['Spotify', 'BetterLyrics', 'LrcLib', 'KuGou', 'Paxsenix', 'Zemer']);
    });

    test('Enables and disables providers dynamically', () {
      final registry = LyricsProviderRegistry();
      expect(registry.isProviderEnabled('KuGou'), isTrue);
      registry.setProviderEnabled('KuGou', false);
      expect(registry.isProviderEnabled('KuGou'), isFalse);
      expect(
        registry.getOrderedProviders().map((p) => p.runtimeType).toList(),
        isNot(contains(KugouLyricsProvider)),
      );
    });

    test('Executes priority fallback lookup', () async {
      const track = Track(
        id: 'fallback_1',
        sourceId: 'src_1',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        duration: Duration(minutes: 3, seconds: 53),
      );

      final mockBetter = _MockLyricsProvider(null);
      final mockLrcLib = _MockLyricsProvider(
        const SyncedLyrics(
          trackId: 'fallback_1',
          lines: [LyricLine(timestamp: Duration.zero, text: 'Club isn\'t the best place')],
          syncType: 'LINE_SYNCED',
        ),
      );

      final registry = LyricsProviderRegistry(
        betterLyrics: mockBetter,
        lrclib: mockLrcLib,
        kugou: _MockLyricsProvider(null),
        paxsenix: _MockLyricsProvider(null),
        zemer: _MockLyricsProvider(null),
        spotify: _MockLyricsProvider(null),
      );

      final result = await registry.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.lines[0].text, 'Club isn\'t the best place');
    });

    test('Prefers syllable-synced provider over earlier line-synced provider', () async {
      const track = Track(
        id: 'syllable_pref_1',
        sourceId: 'src_1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(minutes: 3, seconds: 20),
      );

      final mockBetter = _MockLyricsProvider(
        const SyncedLyrics(
          trackId: 'syllable_pref_1',
          lines: [
            LyricLine(
              timestamp: Duration(seconds: 1),
              text: 'I\'ve been on my own',
              words: [
                LyricWord(timestamp: Duration(seconds: 1), text: 'I\'ve'),
                LyricWord(timestamp: Duration(milliseconds: 1400), text: 'been'),
              ],
            ),
          ],
          syncType: 'SYLLABLE_SYNCED',
        ),
      );

      final registry = LyricsProviderRegistry(
        betterLyrics: mockBetter,
      );

      final result = await registry.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.isSyllableSynced, isTrue);
    });
  });

  group('BetterLyricsProvider Unit Tests', () {
    test('Parses TTML response from mock HttpClient', () async {
      const sampleTtml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:01.000">
        <span begin="00:01.000" end="00:01.500">Live </span>
        <span begin="00:01.500" end="00:02.000">forever</span>
      </p>
    </div>
  </body>
</tt>
''';

      final mockHttp = _MockHttpClient(sampleTtml);
      final provider = BetterLyricsProvider(httpClient: mockHttp);

      const track = Track(
        id: 'oasis_1',
        sourceId: 'src_1',
        title: 'Live Forever',
        artist: 'Oasis',
        duration: Duration(minutes: 4, seconds: 36),
      );

      final result = await provider.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.syncType, 'SYLLABLE_SYNCED');
      expect(result.lines.length, 1);
      expect(result.lines[0].text, 'Live forever');
      expect(result.lines[0].words?.length, 2);
    });
  });
}

class _MockLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? result;
  _MockLyricsProvider(this.result);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => result;
}

class _MockHttpClient implements HttpClient {
  final String ttmlResponse;
  _MockHttpClient(this.ttmlResponse);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpRequest(ttmlResponse);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpRequest implements HttpClientRequest {
  final String ttmlResponse;
  final HttpHeaders _headers = _MockHttpHeaders();

  _MockHttpRequest(this.ttmlResponse);

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpResponse(ttmlResponse);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  final String ttml;
  _MockHttpResponse(this.ttml);

  @override
  int get statusCode => 200;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final jsonStr = jsonEncode({'ttml': ttml});
    return Stream.value(utf8.encode(jsonStr)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, Object> _map = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
