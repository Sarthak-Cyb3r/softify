import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/podcasts/domain/parse_podcast_link.dart';

void main() {
  group('parsePodcastLink', () {
    test('parses spotify episode uri', () {
      final res = parsePodcastLink('spotify:episode:512ASxD2i3NOFOB17m5Wzp');
      expect(res, isA<SpotifyEpisodeLink>());
      expect((res as SpotifyEpisodeLink).episodeId, '512ASxD2i3NOFOB17m5Wzp');
    });

    test('parses spotify show uri', () {
      final res = parsePodcastLink('spotify:show:7cpFspd2FfvM45014vXfUq');
      expect(res, isA<SpotifyShowLink>());
      expect((res as SpotifyShowLink).showId, '7cpFspd2FfvM45014vXfUq');
    });

    test('parses web episode url with query params', () {
      final res = parsePodcastLink(
        'https://open.spotify.com/episode/512ASxD2i3NOFOB17m5Wzp?si=abc123xyz',
      );
      expect(res, isA<SpotifyEpisodeLink>());
      expect((res as SpotifyEpisodeLink).episodeId, '512ASxD2i3NOFOB17m5Wzp');
    });

    test('parses embed episode url', () {
      final res = parsePodcastLink(
        'https://open.spotify.com/embed/episode/512ASxD2i3NOFOB17m5Wzp',
      );
      expect(res, isA<SpotifyEpisodeLink>());
      expect((res as SpotifyEpisodeLink).episodeId, '512ASxD2i3NOFOB17m5Wzp');
    });

    test('parses internationalized episode url', () {
      final res = parsePodcastLink(
        'https://open.spotify.com/intl-de/episode/512ASxD2i3NOFOB17m5Wzp',
      );
      expect(res, isA<SpotifyEpisodeLink>());
      expect((res as SpotifyEpisodeLink).episodeId, '512ASxD2i3NOFOB17m5Wzp');
    });

    test('parses web show url', () {
      final res = parsePodcastLink(
        'https://open.spotify.com/show/7cpFspd2FfvM45014vXfUq',
      );
      expect(res, isA<SpotifyShowLink>());
      expect((res as SpotifyShowLink).showId, '7cpFspd2FfvM45014vXfUq');
    });

    test('parses standalone 22-char Spotify ID', () {
      final res = parsePodcastLink('512ASxD2i3NOFOB17m5Wzp');
      expect(res, isA<SpotifyEpisodeLink>());
      expect((res as SpotifyEpisodeLink).episodeId, '512ASxD2i3NOFOB17m5Wzp');
    });

    test('parses direct RSS feed url', () {
      final res = parsePodcastLink('https://feeds.megaphone.fm/hubermanlab');
      expect(res, isA<DirectRssLink>());
      expect((res as DirectRssLink).feedUri.toString(), 'https://feeds.megaphone.fm/hubermanlab');
    });

    test('parses xml feed url', () {
      final res = parsePodcastLink('https://example.com/podcast/feed.xml');
      expect(res, isA<DirectRssLink>());
    });

    test('returns InvalidPodcastLink for empty or blank input', () {
      expect(parsePodcastLink(''), isA<InvalidPodcastLink>());
      expect(parsePodcastLink('   '), isA<InvalidPodcastLink>());
    });

    test('returns InvalidPodcastLink for non-podcast urls or symbols', () {
      expect(parsePodcastLink('https://google.com'), isA<InvalidPodcastLink>());
      expect(parsePodcastLink('???///'), isA<InvalidPodcastLink>());
    });

    test('parses plain text search query', () {
      final res = parsePodcastLink('huberman lab');
      expect(res, isA<PodcastSearchQuery>());
      expect((res as PodcastSearchQuery).query, 'huberman lab');
    });
  });
}
