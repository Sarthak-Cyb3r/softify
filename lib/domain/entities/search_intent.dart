sealed class SearchIntent {
  const SearchIntent();
}

class ExactTrackIntent extends SearchIntent {
  final String trackId;
  const ExactTrackIntent(this.trackId);

  @override
  String toString() => 'ExactTrackIntent($trackId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExactTrackIntent &&
          runtimeType == other.runtimeType &&
          trackId == other.trackId;

  @override
  int get hashCode => trackId.hashCode;
}

class ArtistIntent extends SearchIntent {
  final String artistName;
  const ArtistIntent(this.artistName);

  @override
  String toString() => 'ArtistIntent($artistName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistIntent &&
          runtimeType == other.runtimeType &&
          artistName == other.artistName;

  @override
  int get hashCode => artistName.hashCode;
}

class SimilarToIntent extends SearchIntent {
  final String seedTrackTitle;
  const SimilarToIntent(this.seedTrackTitle);

  @override
  String toString() => 'SimilarToIntent($seedTrackTitle)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimilarToIntent &&
          runtimeType == other.runtimeType &&
          seedTrackTitle == other.seedTrackTitle;

  @override
  int get hashCode => seedTrackTitle.hashCode;
}

class MoodOrGenreIntent extends SearchIntent {
  final List<String> tags;
  const MoodOrGenreIntent(this.tags);

  @override
  String toString() => 'MoodOrGenreIntent($tags)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodOrGenreIntent &&
          runtimeType == other.runtimeType &&
          tags.join(',') == other.tags.join(',');

  @override
  int get hashCode => Object.hashAll(tags);
}

class GenericSearchIntent extends SearchIntent {
  final String rawQuery;
  const GenericSearchIntent(this.rawQuery);

  @override
  String toString() => 'GenericSearchIntent($rawQuery)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenericSearchIntent &&
          runtimeType == other.runtimeType &&
          rawQuery == other.rawQuery;

  @override
  int get hashCode => rawQuery.hashCode;
}
