import 'podcast_episode.dart';

class PodcastShow {
  final String id;
  final String title;
  final String publisher;
  final String description;
  final String? coverUrl;
  final List<PodcastEpisode> episodes;

  const PodcastShow({
    required this.id,
    required this.title,
    required this.publisher,
    required this.description,
    this.coverUrl,
    this.episodes = const [],
  });
}
