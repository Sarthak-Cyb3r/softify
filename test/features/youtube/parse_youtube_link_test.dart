import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/youtube/domain/parse_youtube_link.dart';

void main() {
  group('parseYoutubeLink', () {
    test('parses standard desktop watch url', () {
      final res = parseYoutubeLink('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(res, isA<VideoLink>());
      final video = res as VideoLink;
      expect(video.videoId, 'dQw4w9WgXcQ');
      expect(video.startSeconds, isNull);
    });

    test('parses youtu.be short url', () {
      final res = parseYoutubeLink('https://youtu.be/dQw4w9WgXcQ');
      expect(res, isA<VideoLink>());
      expect((res as VideoLink).videoId, 'dQw4w9WgXcQ');
    });

    test('parses shorts url with extra parameters', () {
      final res = parseYoutubeLink(
        'https://www.youtube.com/shorts/dQw4w9WgXcQ?feature=share&si=abc123xyz',
      );
      expect(res, isA<VideoLink>());
      expect((res as VideoLink).videoId, 'dQw4w9WgXcQ');
    });

    test('parses embed url with start parameter', () {
      final res = parseYoutubeLink('https://www.youtube.com/embed/dQw4w9WgXcQ?start=45');
      expect(res, isA<VideoLink>());
      final video = res as VideoLink;
      expect(video.videoId, 'dQw4w9WgXcQ');
      expect(video.startSeconds, 45);
    });

    test('parses live stream url', () {
      final res = parseYoutubeLink('https://www.youtube.com/live/dQw4w9WgXcQ?t=15s');
      expect(res, isA<VideoLink>());
      final video = res as VideoLink;
      expect(video.videoId, 'dQw4w9WgXcQ');
      expect(video.startSeconds, 15);
    });

    test('parses music.youtube.com url', () {
      final res = parseYoutubeLink('https://music.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(res, isA<VideoLink>());
      expect((res as VideoLink).videoId, 'dQw4w9WgXcQ');
    });

    test('parses m.youtube.com mobile url', () {
      final res = parseYoutubeLink('https://m.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(res, isA<VideoLink>());
      expect((res as VideoLink).videoId, 'dQw4w9WgXcQ');
    });

    test('parses url with missing scheme and leading/trailing whitespace', () {
      final res = parseYoutubeLink('   youtube.com/watch?v=dQw4w9WgXcQ   ');
      expect(res, isA<VideoLink>());
      expect((res as VideoLink).videoId, 'dQw4w9WgXcQ');
    });

    test('parses standalone 11-char video ID', () {
      final res = parseYoutubeLink('dQw4w9WgXcQ');
      expect(res, isA<VideoLink>());
      expect((res as VideoLink).videoId, 'dQw4w9WgXcQ');
    });

    group('timestamp parsing', () {
      test('parses t=90 and t=90s', () {
        final res1 = parseYoutubeLink('https://youtu.be/dQw4w9WgXcQ?t=90');
        expect((res1 as VideoLink).startSeconds, 90);

        final res2 = parseYoutubeLink('https://youtu.be/dQw4w9WgXcQ?t=90s');
        expect((res2 as VideoLink).startSeconds, 90);
      });

      test('parses t=1m30s', () {
        final res = parseYoutubeLink('https://youtu.be/dQw4w9WgXcQ?t=1m30s');
        expect((res as VideoLink).startSeconds, 90);
      });

      test('parses t=1h2m3s', () {
        final res = parseYoutubeLink('https://youtu.be/dQw4w9WgXcQ?t=1h2m3s');
        expect((res as VideoLink).startSeconds, 3723);
      });

      test('parses t=45m', () {
        final res = parseYoutubeLink('https://youtu.be/dQw4w9WgXcQ?t=45m');
        expect((res as VideoLink).startSeconds, 2700);
      });
    });

    group('playlists', () {
      test('parses dedicated playlist url', () {
        final res = parseYoutubeLink(
          'https://www.youtube.com/playlist?list=PLrAl5BIxg9Ue8eXm5u9Q2Q4_2E4uF1q0M',
        );
        expect(res, isA<PlaylistLink>());
        expect(
          (res as PlaylistLink).playlistId,
          'PLrAl5BIxg9Ue8eXm5u9Q2Q4_2E4uF1q0M',
        );
      });

      test('parses video in playlist with timestamp', () {
        final res = parseYoutubeLink(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLrAl5BIxg9Ue8eXm5u9Q2Q4_2E4uF1q0M&t=1m',
        );
        expect(res, isA<VideoInPlaylist>());
        final vp = res as VideoInPlaylist;
        expect(vp.videoId, 'dQw4w9WgXcQ');
        expect(vp.playlistId, 'PLrAl5BIxg9Ue8eXm5u9Q2Q4_2E4uF1q0M');
        expect(vp.startSeconds, 60);
      });
    });

    group('invalid and garbage inputs', () {
      test('returns InvalidLink for empty input', () {
        expect(parseYoutubeLink(''), isA<InvalidLink>());
        expect(parseYoutubeLink('   '), isA<InvalidLink>());
      });

      test('returns InvalidLink for non-youtube urls', () {
        expect(
          parseYoutubeLink('https://open.spotify.com/track/12345'),
          isA<InvalidLink>(),
        );
        expect(parseYoutubeLink('https://google.com'), isA<InvalidLink>());
      });

      test('returns InvalidLink for random garbage text', () {
        expect(parseYoutubeLink('not a link at all'), isA<InvalidLink>());
        expect(parseYoutubeLink('random-invalid-string-123'), isA<InvalidLink>());
      });
    });
  });
}
