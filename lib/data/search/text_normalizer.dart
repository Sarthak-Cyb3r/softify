import 'dart:math';

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
}
