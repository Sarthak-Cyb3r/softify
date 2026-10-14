import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/data/resolvers/youtube_innertube_service.dart';
import 'package:softify/presentation/widgets/artist_chooser_bottom_sheet.dart';

void main() {
  group('Artist Parser Tests', () {
    test('parses single artist without splitting', () {
      expect(parseArtistNames('The Weeknd'), ['The Weeknd']);
      expect(parseArtistNames('Taylor Swift'), ['Taylor Swift']);
      expect(parseArtistNames('AC/DC'), ['AC/DC']);
    });

    test('parses comma-separated multiple artists', () {
      expect(
        parseArtistNames('A.R. Rahman, Javed Ali, Prasoon Joshi'),
        ['A.R. Rahman', 'Javed Ali', 'Prasoon Joshi'],
      );
    });

    test('parses artists with feat / ft / with / &', () {
      expect(
        parseArtistNames('Drake feat. 21 Savage'),
        ['Drake', '21 Savage'],
      );
      expect(
        parseArtistNames('Kendrick Lamar ft. SZA'),
        ['Kendrick Lamar', 'SZA'],
      );
      expect(
        parseArtistNames('Taylor Swift & Post Malone'),
        ['Taylor Swift', 'Post Malone'],
      );
      expect(
        parseArtistNames('Calvin Harris with Dua Lipa'),
        ['Calvin Harris', 'Dua Lipa'],
      );
      expect(
        parseArtistNames('Daft Punk / Pharrell Williams'),
        ['Daft Punk', 'Pharrell Williams'],
      );
    });

    test('deduplicates and handles empty/whitespace inputs', () {
      expect(parseArtistNames(''), isEmpty);
      expect(parseArtistNames('   '), isEmpty);
      expect(
        parseArtistNames('Artist A, Artist A, Artist B'),
        ['Artist A', 'Artist B'],
      );
    });
  });

  group('YouTube Original Audio vs Auto-Dubbed Filtering Tests', () {
    test('extractStream prioritizes original audio over auto-dubbed foreign language tracks', () {
      final service = YoutubeInnertubeService();

      final mockData = {
        'streamingData': {
          'adaptiveFormats': [
            {
              'itag': 140,
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 131233,
              'url': 'https://googlevideo.com/videoplayback?itag=140&xtags=acont%3Ddubbed-auto%3Alang%3Dko',
              'audioTrack': {
                'displayName': 'Korean',
                'id': 'ko.10',
                'audioIsDefault': false,
                'isAutoDubbed': true,
              },
            },
            {
              'itag': 140,
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 131381,
              'url': 'https://googlevideo.com/videoplayback?itag=140&xtags=acont%3Doriginal%3Alang%3Den-US',
              'audioTrack': {
                'displayName': 'English (US) original',
                'id': 'en-US.4',
                'audioIsDefault': true,
              },
            },
            {
              'itag': 140,
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 131425,
              'url': 'https://googlevideo.com/videoplayback?itag=140&xtags=acont%3Ddubbed-auto%3Alang%3Dhi',
              'audioTrack': {
                'displayName': 'Hindi',
                'id': 'hi.10',
                'audioIsDefault': false,
                'isAutoDubbed': true,
              },
            },
          ],
        },
      };

      final stream = service.extractStream('test_video', mockData, quality: AudioQualityPreset.standard);
      expect(stream, isNotNull);
      expect(stream!.url.toString(), contains('acont%3Doriginal%3Alang%3Den-US'));
      expect(stream.url.toString(), isNot(contains('dubbed-auto')));
    });
  });
}
