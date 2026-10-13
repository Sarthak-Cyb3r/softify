import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/composite_lyrics_provider.dart';
import 'package:softify/data/lyrics/genius_lyrics_provider.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';

class MockLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? result;
  MockLyricsProvider(this.result);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => result;
}

void main() {
  group('CompositeLyricsProvider with Genius Fallback', () {
    const track = Track(
      id: 'test_genius_1',
      sourceId: 'src_genius_1',
      title: 'HUMBLE.',
      artist: 'Kendrick Lamar',
      duration: Duration(minutes: 2, seconds: 57),
    );

    test('Falls back to Genius when LRCLIB, NetEase, and Kugou have no lyrics', () async {
      const geniusLyrics = SyncedLyrics(
        trackId: 'test_genius_1',
        lines: [],
        plainLyrics: 'Nobody pray for me\nIt been that day for me\nAy, remember syrup sandwiches',
      );

      final composite = CompositeLyricsProvider(
        spotify: MockLyricsProvider(null),
        primary: MockLyricsProvider(null),
        netease: MockLyricsProvider(null),
        secondary: MockLyricsProvider(null),
        fallback: MockLyricsProvider(geniusLyrics),
      );

      final result = await composite.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.isSynced, isFalse);
      expect(result.plainLyrics, contains('Nobody pray for me'));
    });

    test('GeniusLyricsProvider instantiates correctly', () {
      final provider = GeniusLyricsProvider();
      expect(provider, isNotNull);
    });
  });
}
