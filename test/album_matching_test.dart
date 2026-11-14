import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/composite_lyrics_provider.dart';
import 'package:softify/data/lyrics/spotify_lyrics_synchronizer.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';

class _MockLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? _lyrics;
  _MockLyricsProvider(this._lyrics);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => _lyrics;
}

void main() {
  group('Album Detail Matching & Sequel Number Parity', () {
    test('cleans track titles from YouTube and Indian labels preserving pure song name', () {
      expect(
        SpotifyLyricsSynchronizer.cleanTrackTitle(
          'The Jawaani Song - Student Of The Year 2 | Tiger Shroff, Tara & Ananya| Vishal & Shekhar | RD Burman',
        ),
        equals('The Jawaani Song'),
      );

      expect(
        SpotifyLyricsSynchronizer.cleanTrackTitle(
          'Kesariya - Brahmāstra | Ranbir Kapoor | Alia Bhatt | Pritam | Arijit Singh, Amitabh B',
        ),
        equals('Kesariya'),
      );

      expect(
        SpotifyLyricsSynchronizer.cleanTrackTitle(
          'Apna Bana Le - Bhediya | Varun Dhawan, Kriti Sanon| Sachin-Jigar, Arijit Singh, Amitabh Bhattacharya',
        ),
        equals('Apna Bana Le'),
      );

      expect(
        SpotifyLyricsSynchronizer.cleanTrackTitle(
          'Chaleya (Hindi) | Jawan | Shah Rukh Khan | Nayanthara | Atlee | Anirudh',
        ),
        equals('Chaleya'),
      );

      expect(
        SpotifyLyricsSynchronizer.cleanTrackTitle('Tum Hi Ho (From "Aashiqui 2")'),
        equals('Tum Hi Ho'),
      );
    });

    test('movie soundtrack tracks are never falsely marked as instrumental', () async {
      const vocalMovieTrack = Track(
        id: 'soty2_1',
        sourceId: 'soty2_1',
        title: 'The Jawaani Song - Student Of The Year 2 (Original Motion Picture Soundtrack)',
        artist: 'Vishal & Shekhar',
        duration: Duration(seconds: 215),
      );

      final composite = CompositeLyricsProvider(
        spotify: _MockLyricsProvider(null),
        primary: _MockLyricsProvider(null),
        secondary: _MockLyricsProvider(null),
        saavn: _MockLyricsProvider(null),
        fallback: _MockLyricsProvider(null),
      );

      final result = await composite.getLyrics(vocalMovieTrack);
      // Must NOT return Instrumental cue for movie vocal tracks
      expect(result?.providerName, isNot(equals('Instrumental')));
      expect(result, isNull);
    });

    test('explicit instrumental keywords still resolve to instrumental cue', () async {
      const karaokeTrack = Track(
        id: 'karaoke_1',
        sourceId: 'karaoke_1',
        title: 'The Jawaani Song (Karaoke Track)',
        artist: 'Various',
        duration: Duration(seconds: 215),
      );

      final composite = CompositeLyricsProvider(
        spotify: _MockLyricsProvider(null),
        primary: _MockLyricsProvider(null),
        secondary: _MockLyricsProvider(null),
        saavn: _MockLyricsProvider(null),
        fallback: _MockLyricsProvider(null),
      );

      final result = await composite.getLyrics(karaokeTrack);
      expect(result, isNotNull);
      expect(result!.isSynced, isTrue);
      expect(result.providerName, equals('Instrumental'));
      expect(result.lines.first.text, equals('♪ Instrumental ♪'));
    });
  });
}
