import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/podcasts/data/podcast_rss_resolver.dart';
import 'package:softify/features/podcasts/domain/podcast_episode.dart';

void main() {
  group('Spotify Exclusive Shows & Episodes Support', () {
    test('PodcastEpisode correctly preserves direct scdn audio URLs', () {
      const ep = PodcastEpisode(
        id: '5dEdBTgfq9cR7Il2sLflJu',
        showId: '3pUWoZ6fC2qA02D3X0CeMb',
        showName: 'Batman Unburied: Fallen City',
        title: '01. Kind of a Night Person',
        description: 'First episode of Batman Unburied',
        duration: Duration(minutes: 33, seconds: 25),
        audioUrl: 'https://audio4-fa.scdn.co/audio/7aa0bcee427e29c29a54c69369e18d4704393277?token=abc',
      );

      expect(ep.audioUrl, contains('scdn.co'));
      expect(ep.duration.inMinutes, 33);
    });

    test('PodcastRssResolver rejects mismatched Apple show results instead of taking random items', () async {
      final resolver = PodcastRssResolver();

      // Akshay Horror Podcast is NOT on Apple Podcasts (itunes search returns unrelated shows like Chasing Shadows)
      // Must return null, not an unrelated 84-minute episode!
      final result = await resolver.resolveEpisodeStream(
        showName: 'Akshay Horror Podcast',
        episodeTitle: 'Episode 451 ( काले जादू से बनाया था कटपुतली )',
        targetDuration: const Duration(minutes: 61, seconds: 49),
      );

      expect(result, isNull);
    });
  });
}
