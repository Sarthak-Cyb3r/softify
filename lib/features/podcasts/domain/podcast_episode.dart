class PodcastEpisode {
  final String id; // Spotify episode ID or hash
  final String showId;
  final String showName;
  final String title;
  final String description;
  final Duration duration;
  final String? coverUrl;
  final DateTime? releaseDate;
  final String? audioUrl;
  final Duration resumePosition;

  const PodcastEpisode({
    required this.id,
    required this.showId,
    required this.showName,
    required this.title,
    required this.description,
    required this.duration,
    this.coverUrl,
    this.releaseDate,
    this.audioUrl,
    this.resumePosition = Duration.zero,
  });

  PodcastEpisode copyWith({
    String? id,
    String? showId,
    String? showName,
    String? title,
    String? description,
    Duration? duration,
    String? coverUrl,
    DateTime? releaseDate,
    String? audioUrl,
    Duration? resumePosition,
  }) {
    return PodcastEpisode(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      showName: showName ?? this.showName,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      releaseDate: releaseDate ?? this.releaseDate,
      audioUrl: audioUrl ?? this.audioUrl,
      resumePosition: resumePosition ?? this.resumePosition,
    );
  }
}
