import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';
import 'package:softify/services/lyrics/lyrics_provider_registry.dart';
import 'package:softify/services/lyrics/paxsenix_lyrics_provider.dart';
import 'package:softify/services/lyrics/zemer_lyrics_provider.dart';

void main() {
  group('Paxsenix Sanitization & Scoring Tests', () {
    test('cleanTitle removes video, audio, visualizer, remix, and format tags', () {
      expect(
        PaxsenixLyricsProvider.cleanTitle('Shape of You (Official Music Video)'),
        'Shape of You',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('In The End [Official HD Video]'),
        'In The End',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Bad Guy 【MV】'),
        'Bad Guy',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Stay | Official Visualizer'),
        'Stay',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Starboy - Official Audio'),
        'Starboy',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Closer (feat. Halsey)'),
        'Closer',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Havana (ft. Young Thug)'),
        'Havana',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Levitating feat. DaBaby'),
        'Levitating',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Rockstar ft. 21 Savage'),
        'Rockstar',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Creep (1993)'),
        'Creep',
      );
      expect(
        PaxsenixLyricsProvider.cleanTitle('Bohemian Rhapsody [Remastered 2011]'),
        'Bohemian Rhapsody',
      );
    });

    test('cleanArtist extracts primary artist across all separator formats', () {
      expect(
        PaxsenixLyricsProvider.cleanArtist('Queen & David Bowie'),
        'Queen',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Simon and Garfunkel'),
        'Simon',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Ed Sheeran, Justin Bieber'),
        'Ed Sheeran',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Marshmello x Bastille'),
        'Marshmello',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('David Guetta X Sia'),
        'David Guetta',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Major Lazer feat. Justin Bieber'),
        'Major Lazer',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Calvin Harris feat Ellie Goulding'),
        'Calvin Harris',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Mark Ronson ft. Bruno Mars'),
        'Mark Ronson',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Post Malone ft 21 Savage'),
        'Post Malone',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Clean Bandit featuring Zara Larsson'),
        'Clean Bandit',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Silk Sonic with Thundercat'),
        'Silk Sonic',
      );
      expect(
        PaxsenixLyricsProvider.cleanArtist('Adele'),
        'Adele',
      );
    });

    test('scoreAndFilterResults evaluates duration diff, title, artist and penalties', () {
      const targetDurationSec = 200; // 3m 20s
      final candidates = [
        const PaxsenixSearchResult(
          id: 'apple_exact',
          trackName: 'Blinding Lights',
          artistName: 'The Weeknd',
          durationSec: 200,
        ),
        const PaxsenixSearchResult(
          id: 'apple_remix',
          trackName: 'Blinding Lights (Major Lazer Remix)',
          artistName: 'The Weeknd',
          durationSec: 195,
        ),
        const PaxsenixSearchResult(
          id: 'apple_different_artist',
          trackName: 'Blinding Lights',
          artistName: 'Cover Artist',
          durationSec: 201,
        ),
        const PaxsenixSearchResult(
          id: 'apple_duration_far',
          trackName: 'Blinding Lights',
          artistName: 'The Weeknd',
          durationSec: 250,
        ),
      ];

      final scored = PaxsenixLyricsProvider.scoreAndFilterResults(
        candidates,
        'Blinding Lights',
        'The Weeknd',
        targetDurationSec,
      );

      expect(scored.isNotEmpty, isTrue);
      // Top candidate must be the exact match
      expect(scored.first.key.id, 'apple_exact');
      expect(scored.first.value > 200, isTrue); // +100 duration, +80 title, +50 artist

      // Check remix penalty: remix score should be lower than exact match
      final remixMatch = scored.firstWhere((e) => e.key.id == 'apple_remix');
      expect(remixMatch.value < scored.first.value, isTrue);
    });
  });

  group('PaxsenixLyricsProvider HTTP & Lyrics Parsing Tests', () {
    test('fetches and parses TTML lyrics payload with syllable timings', () async {
      const sampleTtml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:02.000">
        <span begin="00:02.000" end="00:02.500">Fast </span>
        <span begin="00:02.500" end="00:03.000">car</span>
      </p>
    </div>
  </body>
</tt>
''';

      final mockHttp = _MockRouteHttpClient({
        'https://lyrics.paxsenix.org/apple-music/lyrics?id=apple_123':
            jsonEncode({'ttmlContent': sampleTtml}),
      });

      final provider = PaxsenixLyricsProvider(
        httpClient: mockHttp,
      );

      const track = Track(
        id: 'track_1',
        sourceId: '123', // Direct numeric match for apple_123
        title: 'Fast Car',
        artist: 'Tracy Chapman',
        duration: Duration(minutes: 4, seconds: 56),
      );

      final result = await provider.fetchLyricsForTrack('apple_123', track.id);
      expect(result, isNotNull);
      expect(result!.isSyllableSynced, isTrue);
      expect(result.lines.length, 1);
      expect(result.lines.first.text, 'Fast car');
      expect(result.lines.first.words?.length, 2);
      expect(result.providerName, 'Paxsenix (TTML)');
    });

    test('fetches and parses ELRC lyrics format', () async {
      const sampleElrc = '''
[00:01.00]First line of the song
[00:05.50]Second line of the song
''';

      final mockHttp = _MockRouteHttpClient({
        'https://lyrics.paxsenix.org/apple-music/lyrics?id=apple_456':
            jsonEncode({'elrc': sampleElrc}),
      });

      final provider = PaxsenixLyricsProvider(httpClient: mockHttp);
      final result = await provider.fetchLyricsForTrack('apple_456', 'track_456');

      expect(result, isNotNull);
      expect(result!.isSynced, isTrue);
      expect(result.lines.length, 2);
      expect(result.lines[0].text, 'First line of the song');
      expect(result.lines[1].text, 'Second line of the song');
      expect(result.providerName, 'Paxsenix (ELRC)');
    });

    test('fetches and parses structured Syllable content JSON', () async {
      final sampleContent = [
        {
          'timestamp': 1000,
          'endtime': 3000,
          'text': [
            {'text': 'Hello', 'timestamp': 1000, 'endtime': 1800},
            {'text': 'world', 'timestamp': 1800, 'endtime': 3000},
          ],
        },
      ];

      final mockHttp = _MockRouteHttpClient({
        'https://lyrics.paxsenix.org/apple-music/lyrics?id=apple_789': jsonEncode({
          'type': 'Syllable',
          'content': sampleContent,
        }),
      });

      final provider = PaxsenixLyricsProvider(httpClient: mockHttp);
      final result = await provider.fetchLyricsForTrack('apple_789', 'track_789');

      expect(result, isNotNull);
      expect(result!.isSyllableSynced, isTrue);
      expect(result.lines.length, 1);
      expect(result.lines.first.text, 'Hello world');
      expect(result.lines.first.words?.length, 2);
      expect(result.lines.first.words?[0].text, 'Hello');
      expect(result.lines.first.words?[1].text, 'world');
    });

    test('fetches and parses unsynced plain lyrics', () async {
      final mockHttp = _MockRouteHttpClient({
        'https://lyrics.paxsenix.org/apple-music/lyrics?id=apple_plain':
            jsonEncode({'plain': 'Line one\nLine two\nLine three\nLine four'}),
      });

      final provider = PaxsenixLyricsProvider(httpClient: mockHttp);
      final result = await provider.fetchLyricsForTrack('apple_plain', 'track_plain');

      expect(result, isNotNull);
      expect(result!.isSynced, isFalse);
      expect(result.syncType, 'UNSYNCED');
      expect(result.plainLyrics, contains('Line one'));
    });

    test('end-to-end getLyrics with Apple search and candidate scoring', () async {
      final appleSearchResponse = jsonEncode({
        'results': {
          'songs': {
            'data': [
              {'id': '1500000001', 'type': 'songs'},
            ],
          },
        },
        'resources': {
          'songs': {
            '1500000001': {
              'attributes': {
                'name': 'As It Was',
                'artistName': 'Harry Styles',
                'durationInMillis': 167000,
              },
            },
          },
        },
      });

      const sampleLrc = '''
[00:05.00]Hold on
[00:08.50]As it was
''';

      final mockHttp = _MockRouteHttpClient({
        'amp-api.music.apple.com': appleSearchResponse,
        'https://lyrics.paxsenix.org/apple-music/lyrics?id=1500000001':
            jsonEncode({'elrc': sampleLrc}),
      });

      final provider = PaxsenixLyricsProvider(
        httpClient: mockHttp,
        appleToken: 'mock_apple_token',
      );

      const track = Track(
        id: 'track_aiw',
        sourceId: 'yt_xyz999',
        title: 'As It Was (Official Video)',
        artist: 'Harry Styles & Friends',
        duration: Duration(seconds: 167),
      );

      final result = await provider.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.isSynced, isTrue);
      expect(result.lines.length, 2);
      expect(result.lines[1].text, 'As it was');
    });
  });

  group('ZemerLyricsProvider Tests', () {
    test('extractVideoId accurately strips yt_ prefix and isolates 11-char ID', () {
      const track1 = Track(
        id: 'softify_1',
        sourceId: 'yt_dQw4w9WgXcQ',
        title: 'Song',
        artist: 'Artist',
        duration: Duration(minutes: 3),
      );
      expect(ZemerLyricsProvider.extractVideoId(track1), 'dQw4w9WgXcQ');

      const track2 = Track(
        id: 'yt_12345678901',
        sourceId: '12345678901',
        title: 'Song',
        artist: 'Artist',
        duration: Duration(minutes: 3),
      );
      expect(ZemerLyricsProvider.extractVideoId(track2), '12345678901');
    });

    test('unescape decodes numeric and named HTML entities', () {
      expect(
        ZemerLyricsProvider.unescape('Shalom &#8217;Olam&#8211; &amp; &quot;Peace&quot; &#039;test&#039;'),
        "Shalom 'Olam– & \"Peace\" 'test'",
      );
      expect(
        ZemerLyricsProvider.unescape('&#x5E9;&#x5DC;&#x5D5;&#x5DD;'),
        'שלום',
      );
    });

    test('lrcTime formats second float into standard mm:ss.xx timestamp', () {
      expect(ZemerLyricsProvider.lrcTime(0.0), '00:00.00');
      expect(ZemerLyricsProvider.lrcTime(5.5), '00:05.50');
      expect(ZemerLyricsProvider.lrcTime(65.25), '01:05.25');
      expect(ZemerLyricsProvider.lrcTime(125.0), '02:05.00');
    });

    test('jkaraokeLrc parses JSON feed with monotonic validation', () {
      final feedJson = jsonEncode({
        'data': [
          {
            'id': 1001,
            'duration': 180,
            'lyrics': [
              {'start': 5.0, 'text': 'Line one of song'},
              {'start': 10.5, 'text': 'Line two of song'},
              {'start': 15.0, 'text': 'Line three of song'},
              {'start': 20.0, 'text': 'Line four of song'},
            ],
          },
        ],
      });

      final lrc = ZemerLyricsProvider.jkaraokeLrc(feedJson, 1001);
      expect(lrc, isNotNull);
      expect(lrc, contains('[00:05.00]Line one of song'));
      expect(lrc, contains('[00:10.50]Line two of song'));
      expect(lrc, contains('[00:15.00]Line three of song'));
      expect(lrc, contains('[00:20.00]Line four of song'));

      // Non-monotonic timestamps should be rejected
      final invalidJson = jsonEncode({
        'data': [
          {
            'id': 1002,
            'lyrics': [
              {'start': 10.0, 'text': 'Line 1'},
              {'start': 5.0, 'text': 'Line 2'},
              {'start': 15.0, 'text': 'Line 3'},
              {'start': 20.0, 'text': 'Line 4'},
            ],
          },
        ],
      });
      expect(ZemerLyricsProvider.jkaraokeLrc(invalidJson, 1002), isNull);
    });

    test('parseJyrics cleans HTML, strips nav and credit lines', () {
      const sampleJyrics = '''
<article>
  <div class="header">LYRIC</div>
  <p class="song-header">Song Title - Artist</p>
  <p>First line of prayer</p>
  <p>Second line of prayer</p>
  <p>(Chorus)</p>
  <p>Third line of prayer</p>
  <p>Fourth line of prayer</p>
  <p>Composed by Famous Rabbi</p>
  <div class="share-buttons">SHARE</div>
</article>
''';

      final parsed = ZemerLyricsProvider.parseJyrics(sampleJyrics);
      expect(parsed, isNotNull);
      expect(parsed, contains('First line of prayer'));
      expect(parsed, contains('Second line of prayer'));
      expect(parsed, contains('Third line of prayer'));
      expect(parsed, contains('Fourth line of prayer'));
      // Label and credit lines removed
      expect(parsed, isNot(contains('(Chorus)')));
      expect(parsed, isNot(contains('Composed by')));
      expect(parsed, isNot(contains('SHARE')));
    });

    test('parseShironet extracts Hebrew artist_lyrics_text span', () {
      const sampleShironet = '''
<html>
  <body>
    <span class="artist_lyrics_text">
      שלום עליכם מלאכי השרת<br>
      מלאכי עליון<br>
      ממלך מלכי המלכים<br>
      הקדוש ברוך הוא
    </span>
  </body>
</html>
''';

      final parsed = ZemerLyricsProvider.parseShironet(sampleShironet);
      expect(parsed, isNotNull);
      expect(parsed, contains('שלום עליכם מלאכי השרת'));
      expect(parsed, contains('הקדוש ברוך הוא'));
    });

    test('parseTab4u filters table cells containing Hebrew characters', () {
      const sampleTab4u = '''
<table>
  <tr><td class="song_name">עוד ישמע בערי יהודה</td></tr>
  <tr><td class="song_name">ובחוצות ירושלים</td></tr>
  <tr><td class="song_name">קול ששון וקול שמחה</td></tr>
  <tr><td class="song_name">קול חתן וקול כלה</td></tr>
  <tr><td class="song_other">Chords: Am G C Dm</td></tr>
</table>
''';

      final parsed = ZemerLyricsProvider.parseTab4u(sampleTab4u);
      expect(parsed, isNotNull);
      expect(parsed, contains('עוד ישמע בערי יהודה'));
      expect(parsed, contains('קול חתן וקול כלה'));
      expect(parsed, isNot(contains('Chords')));
    });

    test('end-to-end Zemer getLyrics prioritizes synced sources and resolves correctly', () async {
      final resolvePayload = jsonEncode({
        'videoId': 'jewish_12345',
        'verified': true,
        'sources': [
          {
            'type': 'community',
            'plain': 'Plain line 1\nPlain line 2\nPlain line 3\nPlain line 4',
            'synced': false,
          },
          {
            'type': 'jkaraoke',
            'feedUrl': 'https://karaoke.example/feed.json',
            'songId': 555,
            'synced': true,
          },
        ],
      });

      final jkaraokePayload = jsonEncode({
        'data': [
          {
            'id': 555,
            'duration': 240,
            'lyrics': [
              {'start': 2.0, 'text': 'Baruch atah Adonai'},
              {'start': 6.0, 'text': 'Eloheinu melech haolam'},
              {'start': 10.0, 'text': 'Asher kidshanu bemitzvotav'},
              {'start': 14.0, 'text': 'Vetzivanu al divrei torah'},
            ],
          },
        ],
      });

      final mockHttp = _MockRouteHttpClient({
        'https://search.zemer.io/lyrics/resolve?videoId=jewish_12345': resolvePayload,
        'https://karaoke.example/feed.json': jkaraokePayload,
      });

      final provider = ZemerLyricsProvider(httpClient: mockHttp);
      const track = Track(
        id: 'track_jewish',
        sourceId: 'yt_jewish_12345',
        title: 'Torah Blessing',
        artist: 'Cantor',
        duration: Duration(minutes: 4),
      );

      final result = await provider.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.isSynced, isTrue);
      expect(result.lines.length, 4);
      expect(result.lines.first.text, 'Baruch atah Adonai');
      expect(result.providerName, 'Zemer (jkaraoke)');
    });
  });

  group('LyricsProviderRegistry Multi-Provider Integration Tests', () {
    test('Registry contains all 6 providers in default priority order', () {
      final registry = LyricsProviderRegistry();
      expect(registry.priorityOrder, [
        'BetterLyrics',
        'LrcLib',
        'KuGou',
        'Paxsenix',
        'Zemer',
        'Spotify',
      ]);
      expect(registry.registeredNames, containsAll(['Paxsenix', 'Zemer']));
    });

    test('Registry falls back to Paxsenix when earlier providers fail', () async {
      const track = Track(
        id: 'fallback_paxsenix',
        sourceId: 'src_pax',
        title: 'Song for Paxsenix',
        artist: 'Artist',
        duration: Duration(minutes: 3),
      );

      final mockBetter = _MockLyricsProvider(null);
      final mockLrcLib = _MockLyricsProvider(null);
      final mockKuGou = _MockLyricsProvider(null);
      final mockPaxsenix = _MockLyricsProvider(
        const SyncedLyrics(
          trackId: 'fallback_paxsenix',
          lines: [
            LyricLine(timestamp: Duration(seconds: 1), text: 'Lyrics from Paxsenix'),
            LyricLine(timestamp: Duration(seconds: 4), text: 'Second line'),
          ],
          syncType: 'LINE_SYNCED',
          providerName: 'Paxsenix',
        ),
      );

      final registry = LyricsProviderRegistry(
        betterLyrics: mockBetter,
        lrclib: mockLrcLib,
        kugou: mockKuGou,
        paxsenix: mockPaxsenix,
        zemer: _MockLyricsProvider(null),
        spotify: _MockLyricsProvider(null),
      );

      final result = await registry.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.providerName, 'Paxsenix');
      expect(result.lines.first.text, 'Lyrics from Paxsenix');
    });

    test('Registry falls back to Zemer when earlier providers fail', () async {
      const track = Track(
        id: 'fallback_zemer',
        sourceId: 'yt_heb12345678',
        title: 'Hebrew Song',
        artist: 'Hebrew Artist',
        duration: Duration(minutes: 3),
      );

      final mockBetter = _MockLyricsProvider(null);
      final mockLrcLib = _MockLyricsProvider(null);
      final mockKuGou = _MockLyricsProvider(null);
      final mockPaxsenix = _MockLyricsProvider(null);
      final mockZemer = _MockLyricsProvider(
        const SyncedLyrics(
          trackId: 'fallback_zemer',
          lines: [
            LyricLine(timestamp: Duration(seconds: 2), text: 'שמע ישראל'),
            LyricLine(timestamp: Duration(seconds: 5), text: 'ה\' אלוקינו'),
          ],
          syncType: 'LINE_SYNCED',
          providerName: 'Zemer (jkaraoke)',
        ),
      );

      final registry = LyricsProviderRegistry(
        betterLyrics: mockBetter,
        lrclib: mockLrcLib,
        kugou: mockKuGou,
        paxsenix: mockPaxsenix,
        zemer: mockZemer,
        spotify: _MockLyricsProvider(null),
      );

      final result = await registry.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.providerName, 'Zemer (jkaraoke)');
      expect(result.lines.first.text, 'שמע ישראל');
    });

    test('Registry prefers syllable-synced candidate over earlier line-synced candidate', () async {
      const track = Track(
        id: 'syllable_override',
        sourceId: 'src_syllable',
        title: 'Word Synced Hit',
        artist: 'Popular Artist',
        duration: Duration(minutes: 3, seconds: 30),
      );

      final mockBetter = _MockLyricsProvider(null);
      // LrcLib returns line-synced
      final mockLrcLib = _MockLyricsProvider(
        const SyncedLyrics(
          trackId: 'syllable_override',
          lines: [LyricLine(timestamp: Duration.zero, text: 'Line synced only')],
          syncType: 'LINE_SYNCED',
          providerName: 'LRCLIB',
        ),
      );
      // Paxsenix returns syllable-synced karaoke
      final mockPaxsenix = _MockLyricsProvider(
        const SyncedLyrics(
          trackId: 'syllable_override',
          lines: [
            LyricLine(
              timestamp: Duration(seconds: 1),
              text: 'Word synced lyrics',
              words: [
                LyricWord(timestamp: Duration(seconds: 1), text: 'Word'),
                LyricWord(timestamp: Duration(milliseconds: 1500), text: 'synced'),
              ],
            ),
          ],
          syncType: 'SYLLABLE_SYNCED',
          providerName: 'Paxsenix',
        ),
      );

      final registry = LyricsProviderRegistry(
        betterLyrics: mockBetter,
        lrclib: mockLrcLib,
        kugou: _MockLyricsProvider(null),
        paxsenix: mockPaxsenix,
        zemer: _MockLyricsProvider(null),
        spotify: _MockLyricsProvider(null),
      );

      final result = await registry.getLyrics(track, preferSyllableSynced: true);
      expect(result, isNotNull);
      expect(result!.isSyllableSynced, isTrue);
      expect(result.providerName, 'Paxsenix');
    });
  });
}

class _MockLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? result;
  _MockLyricsProvider(this.result);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => result;
}

class _MockRouteHttpClient implements HttpClient {
  final Map<String, String> routes;
  _MockRouteHttpClient(this.routes);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final key = url.toString();
    if (routes.containsKey(key)) {
      return _MockRouteRequest(routes[key]!);
    }
    for (final entry in routes.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return _MockRouteRequest(entry.value);
      }
    }
    return _MockRouteRequest(routes[url.path] ?? '{}');
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    final key = url.toString();
    if (routes.containsKey(key)) {
      return _MockRouteRequest(routes[key]!);
    }
    for (final entry in routes.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return _MockRouteRequest(entry.value);
      }
    }
    return _MockRouteRequest(routes[url.path] ?? '{}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockRouteRequest implements HttpClientRequest {
  final String responseBody;
  final HttpHeaders _headers = _MockHeaders();

  _MockRouteRequest(this.responseBody);

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async {
    return _MockRouteResponse(responseBody);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockRouteResponse extends Stream<List<int>> implements HttpClientResponse {
  final String body;
  _MockRouteResponse(this.body);

  @override
  int get statusCode => 200;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHeaders implements HttpHeaders {
  final Map<String, Object> _map = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
