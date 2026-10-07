import '../../domain/entities/search_intent.dart';
import '../../domain/ports/i_intent_router.dart';
import '../../domain/ports/i_remote_config.dart';
import 'text_normalizer.dart';

class RuleIntentRouter implements IIntentRouter {
  final IRemoteConfig? _remoteConfig;

  static const Set<String> defaultKnownArtists = {
    'arijit singh',
    'the weeknd',
    'taylor swift',
    'ed sheeran',
    'drake',
    'coldplay',
    'diljit dosanjh',
    'badshah',
    'shreya ghoshal',
    'atif aslam',
    'pritam',
    'lata mangeshkar',
    'kishore kumar',
    'kk',
    'a r rahman',
    'ar rahman',
    'justin bieber',
    'post malone',
    'dua lipa',
    'billie eilish',
    'eminem',
    'kanye west',
    'bruno mars',
  };

  static const Set<String> moodKeywords = {
    'sad',
    'happy',
    'party',
    'chill',
    'relaxed',
    'workout',
    'gym',
    'running',
    'romantic',
    'love',
    'heartbreak',
    'focus',
    'study',
    'sleep',
    'lofi',
    'lo-fi',
    'peaceful',
    'calm',
    'dance',
    'club',
    'driving',
    'night',
    'morning',
    'retro',
    'energetic',
  };

  static const Set<String> genreKeywords = {
    'hindi',
    'punjabi',
    'bollywood',
    'english',
    'pop',
    'rock',
    'hip hop',
    'hip-hop',
    'rap',
    'jazz',
    'classical',
    'acoustic',
    'metal',
    'edm',
    'electronic',
    'r&b',
    'soul',
    'indie',
    'folk',
    'reggae',
    'blues',
    'sufi',
    'ghazal',
  };

  static const Set<String> noiseWords = {
    'songs',
    'song',
    'music',
    'tracks',
    'track',
    'beats',
    'mix',
    'playlist',
    'vibes',
    'vibe',
    'hits',
    'best',
    'top',
  };

  RuleIntentRouter({IRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig;

  @override
  SearchIntent resolve(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return const GenericSearchIntent('');

    final normalized = TextNormalizer.normalize(query);

    // 1. Exact Track ID match (e.g. softify:track:123 or t_12345)
    if (query.startsWith('softify:track:') || RegExp(r'^t_[a-zA-Z0-9_-]+$').hasMatch(query)) {
      final id = query.replaceFirst('softify:track:', '');
      return ExactTrackIntent(id);
    }

    // 2. Similar To / Like pattern
    // e.g. "songs like tum hi ho", "music like starboy", "similar to blinding lights", "like the weeknd"
    final similarMatch = RegExp(
      r'^(?:songs\s+like|music\s+like|tracks\s+like|similar\s+to|like)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(query);
    if (similarMatch != null) {
      final seed = similarMatch.group(1)!.trim();
      if (seed.isNotEmpty) {
        return SimilarToIntent(seed);
      }
    }

    // 3. Songs by Artist pattern
    // e.g. "songs by taylor swift", "music by arijit", "by the weeknd"
    final artistByMatch = RegExp(
      r'^(?:songs\s+by|music\s+by|tracks\s+by|by)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(query);
    if (artistByMatch != null) {
      final artistName = artistByMatch.group(1)!.trim();
      if (artistName.isNotEmpty) {
        return ArtistIntent(artistName);
      }
    }

    // 4. Known Artist direct match
    final knownArtists = _getKnownArtists();
    if (knownArtists.contains(normalized)) {
      return ArtistIntent(query);
    }
    // Check if query is "[artist] songs" or "[artist] hits" where artist is known
    for (final artist in knownArtists) {
      if (normalized == '$artist songs' ||
          normalized == '$artist hits' ||
          normalized == '$artist music') {
        return ArtistIntent(artist);
      }
    }

    // 5. Mood / Genre match
    final matchedTags = <String>[];

    // Check multi-word genres first (e.g. "hip hop")
    String remainingText = normalized;
    if (remainingText.contains('hip hop')) {
      matchedTags.add('hip hop');
      remainingText = remainingText.replaceAll('hip hop', ' ');
    }
    if (remainingText.contains('lo fi')) {
      matchedTags.add('lo-fi');
      remainingText = remainingText.replaceAll('lo fi', ' ');
    }

    final singleTokens = remainingText.split(' ').where((w) => w.isNotEmpty).toList();
    for (final token in singleTokens) {
      if (moodKeywords.contains(token)) {
        matchedTags.add(token);
      } else if (genreKeywords.contains(token)) {
        matchedTags.add(token);
      }
    }

    // If query only contains mood/genre tags and noise words (e.g. "sad hindi songs", "party music", "chill mix")
    if (matchedTags.isNotEmpty) {
      final nonNoiseNonTag = singleTokens.where((w) =>
          !matchedTags.contains(w) &&
          !noiseWords.contains(w) &&
          w != 'hip' &&
          w != 'hop');

      // If at most 1 unknown word or all words are accounted for, it's a mood/genre intent
      if (nonNoiseNonTag.length <= 1) {
        return MoodOrGenreIntent(matchedTags);
      }
    }

    // 6. Generic search fallback
    return GenericSearchIntent(query);
  }

  Set<String> _getKnownArtists() {
    final artists = Set<String>.from(defaultKnownArtists);
    if (_remoteConfig != null) {
      final aliases = _remoteConfig.getSearchAliases();
      artists.addAll(aliases.keys.map(TextNormalizer.normalize));
      for (final list in aliases.values) {
        artists.addAll(list.map(TextNormalizer.normalize));
      }
    }
    return artists;
  }
}
