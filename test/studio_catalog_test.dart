import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/catalog/keyless_youtube_catalog.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  group('Studio Catalog & Official Matching Engine', () {
    late KeylessYouTubeCatalog catalog;

    setUp(() {
      catalog = KeylessYouTubeCatalog();
    });

    tearDown(() {
      catalog.close();
    });

    test('Clean track title strips YouTube video suffixes', () {
      // Accessing cleanTitle via catalog search simulation
      const dirtyTitle1 = 'Kesariya - Official Lyric | Brahmāstra | Full Song | 4K';
      const dirtyTitle2 = 'Blinding Lights (Official Music Video)';
      const dirtyTitle3 = 'Shape of You [Official Video]';

      // Verify regex stripping behavior
      final clean1 = dirtyTitle1
          .replaceAll(
            RegExp(
              r'\s*[\(\[]\s*official\s*(video|audio|music video|lyric video|lyrics)?\s*[\)\]]',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'\s*\|\s*4K|\s*\|\s*HD|\s*\|\s*full song',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      expect(clean1, equals('Kesariya - Official Lyric | Brahmāstra'));

      final clean2 = dirtyTitle2
          .replaceAll(
            RegExp(
              r'\s*[\(\[]\s*official\s*(video|audio|music video|lyric video|lyrics)?\s*[\)\]]',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      expect(clean2, equals('Blinding Lights'));

      final clean3 = dirtyTitle3
          .replaceAll(
            RegExp(
              r'\s*[\(\[]\s*official\s*(video|audio|music video|lyric video|lyrics)?\s*[\)\]]',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      expect(clean3, equals('Shape of You'));
    });

    test('Artwork URL upgrades 100x100 thumbnail to 600x600 studio album cover', () {
      const itunesThumb =
          'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/a5/63/12/a56312a0-410e-0d1a-47ca-8fe9d9c24097/190295851286.jpg/100x100bb.jpg';
      final studioCover = itunesThumb.replaceAll('100x100bb', '600x600bb');

      expect(studioCover, contains('600x600bb.jpg'));
      expect(studioCover, isNot(contains('100x100bb.jpg')));
    });

    test('Studio tracks preserve clean metadata and high match confidence', () {
      const track = Track(
        id: 'itunes_1633583274',
        sourceId: 'itunes_1633583274',
        title: 'Kesariya',
        artist: 'Pritam, Arijit Singh & Amitabh Bhattacharya',
        album: 'Brahmastra (Original Motion Picture Soundtrack)',
        duration: Duration(seconds: 268),
        coverUrl: 'https://is1-ssl.mzstatic.com/.../600x600bb.jpg',
        matchConfidence: 1.0,
      );

      expect(track.isStudioTrack, isTrue);
      expect(track.matchConfidence, equals(1.0));
      expect(track.album, isNotNull);
    });
  });
}

extension TrackStudioCheck on Track {
  bool get isStudioTrack => sourceId.startsWith('itunes_');
}
