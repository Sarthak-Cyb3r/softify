import 'dart:math';

import '../../domain/entities/track.dart';

class TextNormalizer {
  static const Map<String, String> _diacriticsMap = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a', 'æ': 'ae',
    'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
    'ď': 'd', 'đ': 'd',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
    'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ņ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o', 'œ': 'oe',
    'ř': 'r', 'ŕ': 'r', 'ŗ': 'r',
    'š': 's', 'ś': 's', 'ŝ': 's', 'ş': 's', 'ș': 's', 'ß': 'ss',
    'ť': 't', 'ţ': 't', 'ț': 't',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
  };

  /// Normalizes text: lowercases, strips diacritics, collapses punctuation to space,
  /// and trims redundant whitespace.
  static String normalize(String text) {
    if (text.isEmpty) return '';

    final lower = text.toLowerCase();
    final buffer = StringBuffer();

    for (int i = 0; i < lower.length; i++) {
      final char = lower[i];
      buffer.write(_diacriticsMap[char] ?? char);
    }

    final stripped = buffer.toString();
    // Replace non-alphanumeric (excluding space) with space
    final collapsedPunctuation =
        stripped.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // Collapse multiple whitespace
    return collapsedPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Expands query tokens using alias dictionary (e.g. "kk" -> "krishnakumar kunnath")
  static List<String> expandAliases(
    String query,
    Map<String, List<String>> aliases,
  ) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return [];

    final results = <String>{normalizedQuery};
    final tokens = normalizedQuery.split(' ');

    // 1. Full query match in aliases
    if (aliases.containsKey(normalizedQuery)) {
      for (final target in aliases[normalizedQuery]!) {
        results.add(normalize(target));
      }
    }

    // 2. Token-level alias replacement
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (aliases.containsKey(token)) {
        for (final target in aliases[token]!) {
          final expandedTokens = List<String>.from(tokens);
          expandedTokens[i] = normalize(target);
          results.add(expandedTokens.join(' '));
        }
      }
    }

    return results.toList();
  }

  /// Computes standard Levenshtein edit distance between two strings
  static int levenshteinDistance(String s1, String s2) {
    final a = normalize(s1);
    final b = normalize(s2);

    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        v1[j + 1] = min(
          v1[j] + 1, // insertion
          min(v0[j + 1] + 1, v0[j] + cost), // deletion, substitution
        );
      }

      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[b.length];
  }

  /// Calculates normalized string similarity ratio between 0.0 and 1.0
  static double similarity(String s1, String s2) {
    final a = normalize(s1);
    final b = normalize(s2);
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

    final distance = levenshteinDistance(a, b);
    final maxLen = max(a.length, b.length);
    return (1.0 - (distance / maxLen)).clamp(0.0, 1.0);
  }

  /// Checks if normalized query exactly matches target or target tokens
  static bool isExactMatch(String query, String target) {
    final q = normalize(query);
    final t = normalize(target);
    return q.isNotEmpty && q == t;
  }

  /// Checks if normalized target begins with query or contains exact prefix token
  static bool isPrefixMatch(String query, String target) {
    final q = normalize(query);
    final t = normalize(target);
    if (q.isEmpty || t.isEmpty) return false;
    if (t.startsWith(q)) return true;

    // Check individual tokens
    final tokens = t.split(' ');
    return tokens.any((tok) => tok.startsWith(q));
  }

  /// Extracts the canonical song root from a track title by stripping:
  /// - Movie/soundtrack tags e.g. `(From "Movie")`, `[Soundtrack]`
  /// - Video/audio tags e.g. `(Official Video)`, `[Lyric Video]`, `(Visualizer)`
  /// - Derivative/cover tags e.g. `(Cover)`, `[Lofi Remake]`, `(Slowed + Reverb)`
  /// - Feature tags e.g. `(feat. XYZ)`, `[ft. ABC]`
  /// - Delimiter suffixes e.g. ` - Cover`, ` | Acoustic`, ` - Sanam`
  static String extractCanonicalSongRoot(String title) {
    if (title.isEmpty) return '';

    String cleaned = title;

    // 1. Remove bracketed content that matches movie, video, or derivative metadata
    final bracketPatterns = [
      RegExp(r'\s*\((?:from|soundtrack|ost|original\s+motion\s+picture)[^)]*\)', caseSensitive: false),
      RegExp(r'\s*\[(?:from|soundtrack|ost|original\s+motion\s+picture)[^\]]*\]', caseSensitive: false),
      RegExp(r'\s*\((?:official|music|lyric|video|audio|visualizer|hd|4k)[^)]*\)', caseSensitive: false),
      RegExp(r'\s*\[(?:official|music|lyric|video|audio|visualizer|hd|4k)[^\]]*\]', caseSensitive: false),
      RegExp(r'\s*\((?:feat\.|ft\.|with)[^)]*\)', caseSensitive: false),
      RegExp(r'\s*\[(?:feat\.|ft\.|with)[^\]]*\]', caseSensitive: false),
      RegExp(r'\s*\((?:cover|acoustic|live|unplugged|karaoke|instrumental|lofi|lo-fi|slowed|reverb|sped\s+up|speed\s+up|nightcore|tribute|remix|version|edit)[^)]*\)', caseSensitive: false),
      RegExp(r'\s*\[(?:cover|acoustic|live|unplugged|karaoke|instrumental|lofi|lo-fi|slowed|reverb|sped\s+up|speed\s+up|nightcore|tribute|remix|version|edit)[^\]]*\]', caseSensitive: false),
    ];

    for (final pattern in bracketPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    // 2. Remove delimiter suffixes after " - ", " | ", " // ", " : "
    final delimiterMatch = RegExp(r'\s*[-|/:]\s*(.+)$').firstMatch(cleaned);
    if (delimiterMatch != null) {
      final suffix = delimiterMatch.group(1)?.toLowerCase().trim() ?? '';
      const metaKeywords = [
        'cover', 'lofi', 'lo-fi', 'slowed', 'reverb', 'remix', 'acoustic',
        'unplugged', 'live', 'karaoke', 'instrumental', 'official', 'lyrics',
        'video', 'audio', 'version', 'tribute', 'parody', 'sped up', 'speed up',
        'from', 'soundtrack', 'ost', 'mix'
      ];
      if (metaKeywords.any((kw) => suffix.contains(kw))) {
        cleaned = cleaned.substring(0, delimiterMatch.start);
      }
    }

    final norm = normalize(cleaned);
    return norm.isNotEmpty ? norm : normalize(title);
  }

  static const List<String> derivativeKeywords = [
    'cover',
    'tribute',
    'karaoke',
    'instrumental',
    'backing track',
    'acoustic cover',
    'remake',
    're-recorded',
    'fan made',
    'lofi',
    'lo-fi',
    'chillhop',
    'slowed',
    'reverb',
    'sped up',
    'speed up',
    'nightcore',
    '8d audio',
    'bass boosted',
    'bootleg',
    'parody',
    'mashup',
    'remix',
    'club mix',
    'dj mix',
    'dance mix',
    'trap mix',
  ];

  /// Checks if a track title or artist signifies a derivative rendition (cover, lofi, remix, etc.)
  static bool isDerivativeTrack(String title, {String? artist}) {
    final lowerTitle = title.toLowerCase();
    final lowerArtist = artist?.toLowerCase() ?? '';
    for (final kw in derivativeKeywords) {
      if (lowerTitle.contains(kw) || lowerArtist.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// Determines whether two tracks represent the same underlying song from different creators/uploaders
  static bool isSameSongCluster({
    required Track a,
    required Track b,
  }) {
    if (a.id == b.id) return true;

    final rootA = extractCanonicalSongRoot(a.title);
    final rootB = extractCanonicalSongRoot(b.title);

    if (rootA.isEmpty || rootB.isEmpty) return false;

    final isRootMatch = rootA == rootB || similarity(rootA, rootB) >= 0.88;
    if (!isRootMatch) return false;

    // If either track is a derivative (cover, lofi, remix, etc.), they belong to the same cluster
    if (isDerivativeTrack(a.title, artist: a.artist) ||
        isDerivativeTrack(b.title, artist: b.artist)) {
      return true;
    }

    // Artist tokens overlap -> same song / same artists
    final tokensA = a.artist
        .toLowerCase()
        .split(RegExp(r'[,&\s/]+'))
        .where((w) => w.length > 2)
        .toSet();
    final tokensB = b.artist
        .toLowerCase()
        .split(RegExp(r'[,&\s/]+'))
        .where((w) => w.length > 2)
        .toSet();
    if (tokensA.intersection(tokensB).isNotEmpty) {
      return true;
    }

    // Durations within 18 seconds -> same underlying recording/track
    if (a.duration > Duration.zero && b.duration > Duration.zero) {
      final diff = (a.duration.inSeconds - b.duration.inSeconds).abs();
      if (diff <= 18) return true;
    }

    return false;
  }

  /// Evaluates track canonical quality and originality (studio master vs derivative/cover)
  static double scoreTrackOriginality(Track track, {String? query}) {
    double score = (track.matchConfidence ?? 0.5) * 5.0;

    final lowerTitle = track.title.toLowerCase();
    final lowerArtist = track.artist.toLowerCase();
    final root = extractCanonicalSongRoot(track.title);

    final isDerivative = isDerivativeTrack(track.title, artist: track.artist);

    // 1. Exact query match bonus (Title matches user query for non-derivative tracks)
    if (query != null && query.isNotEmpty) {
      final normQuery = normalize(query);
      if (!isDerivative) {
        if (root == normQuery || normalize(track.title) == normQuery) {
          score += 20.0; // Overwhelming priority for canonical exact query match
        } else if (isPrefixMatch(normQuery, root)) {
          score += 8.0;
        }
      }
    }

    // 2. Official Catalog source bonus
    if (track.id.startsWith('spotify_')) {
      score += 4.0;
    } else if (track.id.startsWith('saavn_')) {
      score += 3.5;
    } else if (track.id.startsWith('itunes_')) {
      score += 3.0;
    }

    // 3. Clean title bonus (title matches canonical root without extra metadata noise)
    if (normalize(track.title) == root) {
      score += 2.5;
    }

    // 4. Official Album bonus vs Compilation re-release penalty
    if (track.album != null && track.album!.isNotEmpty) {
      final lAlbum = track.album!.toLowerCase();
      const compWords = [
        'compilation',
        'greatest hits',
        'best of',
        'collection',
        'hits',
        'love songs',
        'special',
        'romantic',
        'monsoon',
        'party',
        'valentine',
        'world music',
        'top 10',
        'top 20',
        'top 50',
        'top 100',
        'now that',
        'playlist',
        'mashup',
        'remix',
        'vol.',
        'volume',
        'cafe',
        'lounge',
        'sessions',
        'selection',
        'various artists',
        'karaoke',
      ];
      final artistWords = lowerArtist
          .split(RegExp(r'[,&\s/]+'))
          .where((w) => w.length > 3);
      final isArtistNameInAlbum =
          artistWords.any((w) => lAlbum.contains(w));

      if (compWords.any((w) => lAlbum.contains(w)) || isArtistNameInAlbum) {
        score -= 25.0; // Strong penalty for compilation re-releases
      } else {
        score += 25.0; // Strong bonus for original studio albums
      }
    }

    // 5. Popular recognized studio vocalists bonus
    const recognizedArtists = [
      'arijit',
      'pritam',
      'atif',
      'shreya',
      'sonu',
      'ed sheeran',
      'weeknd',
      'taylor swift'
    ];
    if (recognizedArtists.any((a) => lowerArtist.contains(a))) {
      score += 5.0;
    }

    // 6. Query artist match bonus
    if (query != null && query.isNotEmpty) {
      final normQuery = normalize(query);
      final artistTokens = lowerArtist
          .split(RegExp(r'[,&\s/]+'))
          .where((w) => w.length > 2);
      if (artistTokens.any((token) => normQuery.contains(token))) {
        score += 6.0;
      }
    }

    // 7. Derivative / Clone / Low-quality penalties
    if (isDerivativeTrack(track.title, artist: track.artist)) {
      if (lowerTitle.contains('cover') || lowerArtist.contains('cover')) {
        score -= 10.0;
      } else if (lowerTitle.contains('karaoke') ||
          lowerArtist.contains('karaoke') ||
          lowerTitle.contains('tribute')) {
        score -= 12.0;
      } else if (lowerTitle.contains('lofi') ||
          lowerTitle.contains('lo-fi') ||
          lowerTitle.contains('slowed')) {
        score -= 8.0;
      } else if (lowerTitle.contains('remix') || lowerTitle.contains('mashup')) {
        score -= 6.0;
      } else {
        score -= 5.0;
      }
    }

    return score;
  }
}

