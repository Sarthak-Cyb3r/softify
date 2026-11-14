import 'dart:math';

import '../../domain/entities/track.dart';

/// Enum representing structured voice search intents
enum VoiceIntentType {
  playTrack,
  playArtist,
  shuffleArtist,
  playAlbum,
  generic,
}

/// Structured voice query representation
class VoiceSearchIntent {
  final VoiceIntentType type;
  final String rawQuery;
  final String? trackTitle;
  final String? artistName;
  final String? albumName;
  final bool isShuffle;

  const VoiceSearchIntent({
    required this.type,
    required this.rawQuery,
    this.trackTitle,
    this.artistName,
    this.albumName,
    this.isShuffle = false,
  });

  @override
  String toString() =>
      'VoiceSearchIntent(type: $type, rawQuery: "$rawQuery", trackTitle: "$trackTitle", artistName: "$artistName", albumName: "$albumName", isShuffle: $isShuffle)';
}

/// Container for a candidate item and its voice search score.
class ScoredCandidate<T> {
  final T candidate;
  final double score;

  const ScoredCandidate(this.candidate, this.score);

  T get item => candidate;
  T get track => candidate;
  T get song => candidate;

  @override
  String toString() => 'ScoredCandidate($candidate, score: $score)';
}

/// Reverse-engineered VoiceSearchMatcher from Metrolist.
/// Provides high-precision voice search matching, Jaro-Winkler distance,
/// punctuation-normalized tokenization, artist stripping, and harmonic mean fuzzy scoring.
class VoiceSearchMatcher {
  static const double strongMatchThreshold = 0.60;
  // ignore: constant_identifier_names
  static const double STRONG_MATCH_THRESHOLD = strongMatchThreshold;

  static const double fuzzyThreshold = 0.85;
  // ignore: constant_identifier_names
  static const double FUZZY_THRESHOLD = fuzzyThreshold;

  static final RegExp punctuationRegex = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  // ignore: non_constant_identifier_names
  static final RegExp PUNCTUATION_REGEX = punctuationRegex;

  static const Set<String> _artistPrepositions = {
    'by',
    'from',
    'feat',
    'featuring',
    'ft',
  };

  static const Set<String> _voiceCommandTokens = {
    'play',
    'listen',
    'stream',
    'shuffle',
    'start',
    'put',
    'on',
    'song',
    'track',
    'music',
  };

  /// Token Similarity based on Jaro-Winkler Distance Algorithm.
  /// Boost threshold = 0.7, p = 0.1, max prefix length = 4.
  static double jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxDist = (max(s1.length, s2.length) ~/ 2) - 1;
    if (maxDist < 0) return 0.0;

    int matches = 0;
    final s1Matches = List<bool>.filled(s1.length, false);
    final s2Matches = List<bool>.filled(s2.length, false);

    for (int i = 0; i < s1.length; i++) {
      final start = max(0, i - maxDist);
      final end = min(s2.length - 1, i + maxDist);
      for (int j = start; j <= end; j++) {
        if (!s2Matches[j] && s1[i] == s2[j]) {
          s1Matches[i] = true;
          s2Matches[j] = true;
          matches++;
          break;
        }
      }
    }
    if (matches == 0) return 0.0;

    int transpositions = 0;
    int k = 0;
    for (int i = 0; i < s1.length; i++) {
      if (s1Matches[i]) {
        while (!s2Matches[k]) {
          k++;
        }
        if (s1[i] != s2[k]) transpositions++;
        k++;
      }
    }

    final jaro = (
      matches / s1.length +
      matches / s2.length +
      (matches - transpositions / 2.0) / matches
    ) / 3.0;

    int prefix = 0;
    final maxPrefix = min(4, min(s1.length, s2.length));
    while (prefix < maxPrefix && s1[prefix] == s2[prefix]) {
      prefix++;
    }

    const p = 0.1;
    const boostThreshold = 0.7;
    return (jaro > boostThreshold) ? jaro + (prefix * p * (1.0 - jaro)) : jaro;
  }

  /// Tokenizes [text] by removing punctuation and splitting by whitespace into a unique set of lowercase tokens.
  static Set<String> tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(punctuationRegex, ' ')
        .split(' ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  /// Strips artist tokens from [queryOrTokens].
  /// Supports query tokens as [Set<String>] or raw [String], and candidate as [Track],
  /// [String], [List<String>], or generic object.
  static Set<String> stripArtistTokens(
    dynamic queryOrTokens,
    dynamic candidateOrArtists, {
    bool stripPrepositions = true,
  }) {
    final Set<String> remaining;
    if (queryOrTokens is Set<String>) {
      remaining = Set<String>.from(queryOrTokens);
    } else if (queryOrTokens is Iterable) {
      remaining = queryOrTokens.map((e) => e.toString()).toSet();
    } else {
      remaining = tokenize(queryOrTokens.toString());
    }

    final List<String> artistNames;
    if (candidateOrArtists is List<String>) {
      artistNames = candidateOrArtists;
    } else if (candidateOrArtists is String) {
      artistNames = _parseArtistNames(candidateOrArtists);
    } else if (candidateOrArtists is Iterable) {
      artistNames = candidateOrArtists.map((e) => e.toString()).toList();
    } else {
      artistNames = _extractArtists(candidateOrArtists);
    }

    bool anyArtistMatched = false;
    for (final artist in artistNames) {
      final artistTokens = tokenize(artist);
      if (artistTokens.isEmpty) continue;

      final toRemove = <String>{};
      for (final queryToken in remaining) {
        if (queryToken.length < 4) {
          if (artistTokens.contains(queryToken)) {
            toRemove.add(queryToken);
            anyArtistMatched = true;
          }
        } else {
          final matches = artistTokens.any(
            (artistToken) => jaroWinkler(queryToken, artistToken) >= 0.85,
          );
          if (matches) {
            toRemove.add(queryToken);
            anyArtistMatched = true;
          }
        }
      }
      remaining.removeAll(toRemove);
    }

    if (stripPrepositions && anyArtistMatched) {
      remaining.removeWhere((token) => _artistPrepositions.contains(token));
    }

    return remaining;
  }

  /// Computes the harmonic mean score of token coverage between [queryTokens] and [titleTokens].
  static double fuzzyScore(Set<String> queryTokens, Set<String> titleTokens) {
    if (queryTokens.isEmpty || titleTokens.isEmpty) return 0.0;

    int matchedQuery = 0;
    for (final q in queryTokens) {
      if (titleTokens.any((t) => q == t || jaroWinkler(q, t) >= fuzzyThreshold)) {
        matchedQuery++;
      }
    }

    int matchedTitle = 0;
    for (final t in titleTokens) {
      if (queryTokens.any((q) => q == t || jaroWinkler(q, t) >= fuzzyThreshold)) {
        matchedTitle++;
      }
    }

    if (matchedQuery == 0 || matchedTitle == 0) return 0.0;

    final titleCoverage = matchedTitle / titleTokens.length;
    final queryCoverage = matchedQuery / queryTokens.length;

    if (titleCoverage + queryCoverage > 0) {
      return (2.0 * titleCoverage * queryCoverage) / (titleCoverage + queryCoverage);
    }
    return 0.0;
  }

  /// Scores a single candidate against the query tokens.
  static double scoreCandidate<T>(
    T candidate,
    String queryLower,
    Set<String> queryTokens,
    bool isTooGeneric, {
    String Function(T)? getTitle,
    List<String> Function(T)? getArtists,
    String? Function(T)? getAlbum,
  }) {
    final title = _extractTitle(candidate, getTitle).toLowerCase().trim();
    final titleTokens = tokenize(title);

    // Exact match or set equality on full query
    if ((titleTokens.isNotEmpty && _areSetsEqual(titleTokens, queryTokens)) ||
        title == queryLower) {
      return 1.0;
    }

    // Exact album match
    final album = _extractAlbum(candidate, getAlbum)?.toLowerCase().trim();
    if (album != null &&
        album.isNotEmpty &&
        (album == queryLower || _areSetsEqual(tokenize(album), queryTokens))) {
      return 0.95;
    }

    final remaining = stripArtistTokens(
      queryTokens,
      _extractArtists(candidate, getArtists),
    );

    // Pure artist query
    if (remaining.isEmpty) return 0.5;

    // Remaining tokens exactly match title tokens
    if (titleTokens.isNotEmpty && _areSetsEqual(titleTokens, remaining)) {
      return 0.95;
    }

    // Strip leading/embedded voice command tokens from remaining if title doesn't have them
    final remainingWithoutCommands = remaining
        .where((t) => titleTokens.contains(t) || !_voiceCommandTokens.contains(t))
        .toSet();

    if (remainingWithoutCommands.isNotEmpty &&
        titleTokens.isNotEmpty &&
        _areSetsEqual(titleTokens, remainingWithoutCommands)) {
      return 0.95;
    }

    if (isTooGeneric) return 0.0;

    final baseFuzzy = fuzzyScore(remaining, titleTokens);
    if (remainingWithoutCommands.isNotEmpty &&
        remainingWithoutCommands.length != remaining.length) {
      final cmdFuzzy = fuzzyScore(remainingWithoutCommands, titleTokens);
      return max(baseFuzzy, cmdFuzzy);
    }
    return baseFuzzy;
  }

  /// Ranks all [candidates] against [query] in descending order of score.
  static List<ScoredCandidate<T>> rankAll<T>(
    String query,
    List<T> candidates, {
    String Function(T)? getTitle,
    List<String> Function(T)? getArtists,
    String? Function(T)? getAlbum,
  }) {
    final queryLower = query.toLowerCase().trim();
    final queryTokens = tokenize(queryLower);
    if (queryTokens.isEmpty || candidates.isEmpty) return const [];

    final isTooGeneric = (queryTokens.length == 1 && queryTokens.first.length < 4) ||
        queryLower.length < 5;

    final scored = candidates.map((candidate) {
      final score = scoreCandidate<T>(
        candidate,
        queryLower,
        queryTokens,
        isTooGeneric,
        getTitle: getTitle,
        getArtists: getArtists,
        getAlbum: getAlbum,
      );
      return ScoredCandidate<T>(candidate, score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// Finds the best matching candidate meeting the [threshold] (default 0.60).
  static T? findBest<T>(
    String query,
    List<T> candidates, {
    double threshold = strongMatchThreshold,
    String Function(T)? getTitle,
    List<String> Function(T)? getArtists,
    String? Function(T)? getAlbum,
  }) {
    final ranked = rankAll<T>(
      query,
      candidates,
      getTitle: getTitle,
      getArtists: getArtists,
      getAlbum: getAlbum,
    );
    for (final item in ranked) {
      if (item.score >= threshold) {
        return item.candidate;
      }
    }
    return null;
  }

  /// Parses natural language voice queries into structured [VoiceSearchIntent].
  /// Supports:
  /// - "play [song] by [artist]"
  /// - "[artist] [song]"
  /// - "shuffle [artist]" / "shuffle songs by [artist]"
  /// - "play album [album]" / "play album [album] by [artist]"
  static VoiceSearchIntent parseIntent(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return VoiceSearchIntent(
        type: VoiceIntentType.generic,
        rawQuery: query,
      );
    }

    final lower = trimmed.toLowerCase();

    // 1. Shuffle intent
    final shuffleMatch = RegExp(
      r'^(?:play\s+)?shuffle(?:\s+songs|\s+tracks|\s+music)?(?:\s+by)?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (shuffleMatch != null) {
      var target = shuffleMatch.group(1)!.trim();
      target = target.replaceAll(RegExp(r'\s+(?:songs|tracks|music)$', caseSensitive: false), '').trim();
      return VoiceSearchIntent(
        type: VoiceIntentType.shuffleArtist,
        rawQuery: query,
        artistName: target,
        isShuffle: true,
      );
    }

    // 2. Play album intent
    final albumByArtistMatch = RegExp(
      r'^(?:play\s+)?(?:the\s+)?album\s+(.+?)\s+by\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (albumByArtistMatch != null) {
      return VoiceSearchIntent(
        type: VoiceIntentType.playAlbum,
        rawQuery: query,
        albumName: albumByArtistMatch.group(1)!.trim(),
        artistName: albumByArtistMatch.group(2)!.trim(),
      );
    }

    final albumOnlyMatch = RegExp(
      r'^(?:play\s+)?(?:the\s+)?album\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (albumOnlyMatch != null) {
      return VoiceSearchIntent(
        type: VoiceIntentType.playAlbum,
        rawQuery: query,
        albumName: albumOnlyMatch.group(1)!.trim(),
      );
    }

    // 3. Play [song] by [artist]
    final songByArtistMatch = RegExp(
      r'^(?:play\s+)?(?:the\s+song\s+|the\s+track\s+)?(.+?)\s+by\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (songByArtistMatch != null) {
      return VoiceSearchIntent(
        type: VoiceIntentType.playTrack,
        rawQuery: query,
        trackTitle: songByArtistMatch.group(1)!.trim(),
        artistName: songByArtistMatch.group(2)!.trim(),
      );
    }

    // 4. Play artist
    final artistOnlyMatch = RegExp(
      r'^(?:play\s+)?(?:artist|songs\s+by|tracks\s+by|music\s+by)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (artistOnlyMatch != null) {
      return VoiceSearchIntent(
        type: VoiceIntentType.playArtist,
        rawQuery: query,
        artistName: artistOnlyMatch.group(1)!.trim(),
      );
    }

    // 5. Play [target]
    if (lower.startsWith('play ')) {
      final target = trimmed.substring(5).trim();
      return VoiceSearchIntent(
        type: VoiceIntentType.playTrack,
        rawQuery: query,
        trackTitle: target,
      );
    }

    // 6. Generic search query
    return VoiceSearchIntent(
      type: VoiceIntentType.generic,
      rawQuery: query,
    );
  }

  // --- Internal extraction helpers ---

  static bool _areSetsEqual(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  static String _extractTitle<T>(T item, [String Function(T)? getTitle]) {
    if (getTitle != null) return getTitle(item);
    if (item is Track) return item.title;
    if (item is Map) return item['title']?.toString() ?? '';
    try {
      final dynamic dyn = item;
      final t = dyn.title;
      if (t != null) return t.toString();
    } catch (_) {}
    return item.toString();
  }

  static List<String> _extractArtists<T>(T item, [List<String> Function(T)? getArtists]) {
    if (getArtists != null) return getArtists(item);
    if (item is Track) return _parseArtistNames(item.artist);
    if (item is Map) {
      final a = item['artist'] ?? item['artists'] ?? item['artistName'];
      if (a is List) return a.map((e) => e.toString()).toList();
      if (a is String) return _parseArtistNames(a);
    }
    try {
      final dynamic dyn = item;
      final a = dyn.artists ?? dyn.artist ?? dyn.artistName;
      if (a is List) {
        return a.map((e) => (e is String ? e : (e.name ?? e.toString())).toString()).toList();
      }
      if (a is String) return _parseArtistNames(a);
    } catch (_) {}
    return const [];
  }

  static String? _extractAlbum<T>(T item, [String? Function(T)? getAlbum]) {
    if (getAlbum != null) return getAlbum(item);
    if (item is Track) return item.album;
    if (item is Map) return item['album']?.toString();
    try {
      final dynamic dyn = item;
      final al = dyn.album;
      if (al != null) return al.toString();
    } catch (_) {}
    return null;
  }

  static List<String> _parseArtistNames(dynamic artistOrArtists) {
    if (artistOrArtists == null) return const [];
    if (artistOrArtists is List) {
      return artistOrArtists.map((e) => e.toString()).toList();
    }
    final str = artistOrArtists.toString().trim();
    if (str.isEmpty) return const [];

    final result = <String>{};
    result.add(str);

    final parts = str
        .split(RegExp(r',|\bfeat\.?\b|\bft\.?\b|&', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    result.addAll(parts);

    return result.toList();
  }
}
