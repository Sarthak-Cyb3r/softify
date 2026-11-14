import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/composite_lyrics_provider.dart';
import 'package:softify/data/lyrics/saavn_lyrics_provider.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';

class MockLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? result;
  MockLyricsProvider(this.result);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => result;
}

void main() {
  group('SaavnLyricsProvider & Composite Lyrics Tests', () {
    const track = Track(
      id: 'test_saavn_1',
      sourceId: 'saavn_aRZbUYD7',
      title: 'Tum Hi Ho',
      artist: 'Arijit Singh',
      duration: Duration(minutes: 4, seconds: 22),
    );

    test('SaavnLyricsProvider instantiates with default client', () {
      final provider = SaavnLyricsProvider();
      expect(provider, isNotNull);
    });

    test('CompositeLyricsProvider queries Saavn lyrics when primary and synced sources are null', () async {
      const saavnLyrics = SyncedLyrics(
        trackId: 'test_saavn_1',
        lines: [],
        plainLyrics: 'Hum Tere Bin Ab Reh Nahi Sakte\nTere Bina Kya Wajood Mera\nKyunki Tum Hi Ho',
      );

      final composite = CompositeLyricsProvider(
        spotify: MockLyricsProvider(null),
        primary: MockLyricsProvider(null),
        netease: MockLyricsProvider(null),
        secondary: MockLyricsProvider(null),
        saavn: MockLyricsProvider(saavnLyrics),
        fallback: MockLyricsProvider(null),
      );

      final result = await composite.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.trackId, equals('test_saavn_1'));
      expect(result.plainLyrics, contains('Hum Tere Bin Ab Reh Nahi Sakte'));
      expect(result.plainLyrics, contains('Kyunki Tum Hi Ho'));
    });

    test('CompositeLyricsProvider prefers synced lyrics over plain Saavn lyrics when available', () async {
      const syncedLyrics = SyncedLyrics(
        trackId: 'test_saavn_1',
        lines: [
          LyricLine(timestamp: Duration(seconds: 5), text: 'Hum Tere Bin Ab Reh Nahi Sakte'),
        ],
        plainLyrics: 'Hum Tere Bin...',
      );

      const saavnPlainLyrics = SyncedLyrics(
        trackId: 'test_saavn_1',
        lines: [],
        plainLyrics: 'Plain Saavn Lyrics...',
      );

      final composite = CompositeLyricsProvider(
        spotify: MockLyricsProvider(null),
        primary: MockLyricsProvider(syncedLyrics),
        netease: MockLyricsProvider(null),
        secondary: MockLyricsProvider(null),
        saavn: MockLyricsProvider(saavnPlainLyrics),
        fallback: MockLyricsProvider(null),
      );

      final result = await composite.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.isSynced, isTrue);
      expect(result.lines.first.text, equals('Hum Tere Bin Ab Reh Nahi Sakte'));
    });
  });
}
