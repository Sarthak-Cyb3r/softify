sealed class ParsedPodcastLink {
  const ParsedPodcastLink();
}

final class SpotifyEpisodeLink extends ParsedPodcastLink {
  final String episodeId;
  const SpotifyEpisodeLink(this.episodeId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotifyEpisodeLink &&
          runtimeType == other.runtimeType &&
          episodeId == other.episodeId;

  @override
  int get hashCode => episodeId.hashCode;
}

final class SpotifyShowLink extends ParsedPodcastLink {
  final String showId;
  const SpotifyShowLink(this.showId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotifyShowLink &&
          runtimeType == other.runtimeType &&
          showId == other.showId;

  @override
  int get hashCode => showId.hashCode;
}

final class DirectRssLink extends ParsedPodcastLink {
  final Uri feedUri;
  const DirectRssLink(this.feedUri);
}

final class PodcastSearchQuery extends ParsedPodcastLink {
  final String query;
  const PodcastSearchQuery(this.query);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodcastSearchQuery &&
          runtimeType == other.runtimeType &&
          query == other.query;

  @override
  int get hashCode => query.hashCode;
}

final class InvalidPodcastLink extends ParsedPodcastLink {
  final String rawInput;
  const InvalidPodcastLink(this.rawInput);
}

ParsedPodcastLink parsePodcastLink(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const InvalidPodcastLink('');

  // 1. Spotify URI: spotify:episode:ID or spotify:show:ID
  final uriMatch =
      RegExp(r'^spotify:(episode|show):([a-zA-Z0-9]+)$').firstMatch(trimmed);
  if (uriMatch != null) {
    final type = uriMatch.group(1);
    final id = uriMatch.group(2)!;
    return type == 'episode'
        ? SpotifyEpisodeLink(id)
        : SpotifyShowLink(id);
  }

  // 2. Spotify Web URL: open.spotify.com/(locale/)?(embed/)?(episode|show)/ID
  final webMatch = RegExp(
    r'open\.spotify\.com/(?:[\w-]+/)?(?:embed/)?(episode|show)/([a-zA-Z0-9]+)',
  ).firstMatch(trimmed);
  if (webMatch != null) {
    final type = webMatch.group(1);
    final id = webMatch.group(2)!;
    return type == 'episode'
        ? SpotifyEpisodeLink(id)
        : SpotifyShowLink(id);
  }

  // 3. Direct RSS / Atom feed URL
  final uri = Uri.tryParse(trimmed);
  if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
    final path = uri.path.toLowerCase();
    final host = uri.host.toLowerCase();
    if (path.endsWith('.rss') ||
        path.endsWith('.xml') ||
        path.endsWith('/feed') ||
        host.contains('feeds.') ||
        host.contains('feed.')) {
      return DirectRssLink(uri);
    }
  }

  // 4. Standalone 22-char base62 Spotify ID (heuristic default: episode)
  if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(trimmed)) {
    return SpotifyEpisodeLink(trimmed);
  }

  // 5. Plain text show / podcast search query
  if (!trimmed.startsWith('http') &&
      !trimmed.startsWith('spotify:') &&
      trimmed.length >= 2 &&
      RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) {
    return PodcastSearchQuery(trimmed);
  }

  return InvalidPodcastLink(trimmed);
}
