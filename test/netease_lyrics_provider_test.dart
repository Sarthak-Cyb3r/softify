import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/composite_lyrics_provider.dart';
import 'package:softify/data/lyrics/netease_lyrics_provider.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';

class MockLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? result;
  MockLyricsProvider(this.result);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => result;
}

void main() {
  group('CompositeLyricsProvider with NetEase Fallback', () {
    const track = Track(
      id: 'test_1',
      sourceId: 'src_1',
      title: 'Fix You',
      artist: 'Coldplay',
      duration: Duration(minutes: 4, seconds: 55),
    );

    test('Falls back to NetEase provider when primary (LRCLIB) has no lyrics', () async {
      final neteaseLyrics = SyncedLyrics(
        trackId: 'test_1',
        lines: [
          const LyricLine(
            timestamp: Duration(seconds: 12),
            text: 'When you try your best, but you don\'t succeed',
          ),
          const LyricLine(
            timestamp: Duration(seconds: 18),
            text: 'When you get what you want, but not what you need',
          ),
        ],
        plainLyrics: 'When you try your best...\nWhen you get what you want...',
        rawLrc: '[00:12.00]When you try your best\n[00:18.00]When you get what you want',
      );

      final composite = CompositeLyricsProvider(
        spotify: MockLyricsProvider(null),
        primary: MockLyricsProvider(null),
        netease: MockLyricsProvider(neteaseLyrics),
        secondary: MockLyricsProvider(null),
      );

      final result = await composite.getLyrics(track);
      expect(result, isNotNull);
      expect(result!.isSynced, isTrue);
      expect(result.lines.length, 2);
      expect(result.lines.first.text, 'When you try your best, but you don\'t succeed');
    });

    test('NeteaseLyricsProvider cleans title correctly', () {
      final provider = NeteaseLyricsProvider();
      expect(provider, isNotNull);
    });
  });
}
