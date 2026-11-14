sealed class PodcastFailure {
  final String userMessage;
  const PodcastFailure(this.userMessage);

  @override
  String toString() => userMessage;
}

final class InvalidPodcastLinkFailure extends PodcastFailure {
  const InvalidPodcastLinkFailure([
    super.message = 'Please enter a valid Spotify podcast episode or show link.',
  ]);
}

final class EpisodeUnavailableFailure extends PodcastFailure {
  const EpisodeUnavailableFailure([
    super.message = 'This podcast episode could not be loaded or is unavailable.',
  ]);
}

final class PodcastRssNotFoundFailure extends PodcastFailure {
  const PodcastRssNotFoundFailure([
    super.message = 'Audio stream could not be found for this podcast.',
  ]);
}

final class NetworkPodcastFailure extends PodcastFailure {
  const NetworkPodcastFailure([
    super.message = 'Network error while retrieving podcast. Check your connection.',
  ]);
}

final class GenericPodcastFailure extends PodcastFailure {
  const GenericPodcastFailure([
    super.message = 'An unexpected error occurred while loading this podcast.',
  ]);
}
