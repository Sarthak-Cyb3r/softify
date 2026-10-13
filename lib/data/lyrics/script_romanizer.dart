/// Deterministic on-device phonetic romanizer for Indic and South Asian scripts.
/// Supports Devanagari (Hindi, Marathi, Nepali, Sanskrit) and Gurmukhi (Punjabi).
/// Enables international and non-native listeners to read and sing along phonetically
/// to synchronized lyrics without external API calls or latency.
class ScriptRomanizer {
  ScriptRomanizer._();

  static const Map<String, String> _devanagariVowels = {
    'अ': 'a',
    'आ': 'aa',
    'इ': 'i',
    'ई': 'ee',
    'उ': 'u',
    'ऊ': 'oo',
    'ऋ': 'ri',
    'ए': 'e',
    'ऐ': 'ai',
    'ओ': 'o',
    'औ': 'au',
  };

  static const Map<String, String> _devanagariMatras = {
    'ा': 'aa',
    'ि': 'i',
    'ी': 'ee',
    'ु': 'u',
    'ू': 'oo',
    'ृ': 'ri',
    'े': 'e',
    'ै': 'ai',
    'ो': 'o',
    'ौ': 'au',
  };

  static const Map<String, String> _devanagariConsonants = {
    'क': 'k',
    'ख': 'kh',
    'ग': 'g',
    'घ': 'gh',
    'ङ': 'ng',
    'च': 'ch',
    'छ': 'chh',
    'ज': 'j',
    'झ': 'jh',
    'ञ': 'ny',
    'ट': 't',
    'ठ': 'th',
    'ड': 'd',
    'ढ': 'dh',
    'ण': 'n',
    'त': 't',
    'थ': 'th',
    'द': 'd',
    'ध': 'dh',
    'न': 'n',
    'प': 'p',
    'फ': 'ph',
    'ब': 'b',
    'भ': 'bh',
    'म': 'm',
    'य': 'y',
    'र': 'r',
    'ल': 'l',
    'व': 'v',
    'श': 'sh',
    'ष': 'sh',
    'स': 's',
    'ह': 'h',
    'क़': 'q',
    'ख़': 'kh',
    'ग़': 'gh',
    'ज़': 'z',
    'ड़': 'r',
    'ढ़': 'rh',
    'फ़': 'f',
  };

  static const Map<String, String> _gurmukhiVowels = {
    'ਅ': 'a',
    'ਆ': 'aa',
    'ਇ': 'i',
    'ਈ': 'ee',
    'ਉ': 'u',
    'ਊ': 'oo',
    'ਏ': 'e',
    'ਐ': 'ai',
    'ਓ': 'o',
    'ਔ': 'au',
  };

  static const Map<String, String> _gurmukhiMatras = {
    'ਾ': 'aa',
    'ਿ': 'i',
    'ੀ': 'ee',
    'ੁ': 'u',
    'ੂ': 'oo',
    'ੇ': 'e',
    'ੈ': 'ai',
    'ੋ': 'o',
    'ੌ': 'au',
  };

  static const Map<String, String> _gurmukhiConsonants = {
    'ਕ': 'k',
    'ਖ': 'kh',
    'ਗ': 'g',
    'ਘ': 'gh',
    'ਙ': 'ng',
    'ਚ': 'ch',
    'ਛ': 'chh',
    'ਜ': 'j',
    'ਝ': 'jh',
    'ਞ': 'ny',
    'ਟ': 't',
    'ਠ': 'th',
    'ਡ': 'd',
    'ਢ': 'dh',
    'ਣ': 'n',
    'ਤ': 't',
    'ਥ': 'th',
    'ਦ': 'd',
    'ਧ': 'dh',
    'ਨ': 'n',
    'ਪ': 'p',
    'ਫ': 'ph',
    'ਬ': 'b',
    'ਭ': 'bh',
    'ਮ': 'm',
    'ਯ': 'y',
    'ਰ': 'r',
    'ਲ': 'l',
    'ਵ': 'v',
    'ੜ': 'r',
    'ਸ਼': 'sh',
    'ਸ': 's',
    'ਹ': 'h',
    'ਖ਼': 'kh',
    'ਗ਼': 'gh',
    'ਜ਼': 'z',
    'ਫ਼': 'f',
  };

  /// Returns true if the string contains non-Latin South Asian Indic scripts
  /// (Devanagari, Gurmukhi) that can be transliterated.
  static bool hasRomanizableScript(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Devanagari: 0x0900 - 0x097F
      // Gurmukhi: 0x0A00 - 0x0A7F
      if ((code >= 0x0900 && code <= 0x097F) ||
          (code >= 0x0A00 && code <= 0x0A7F)) {
        return true;
      }
    }
    return false;
  }

  /// Converts Devanagari and Gurmukhi script words into phonetic Roman alphabet.
  /// Preserves all Latin, numbers, punctuation, and whitespace identically.
  static String romanize(String text) {
    if (!hasRomanizableScript(text)) return text;

    final buffer = StringBuffer();
    final runes = text.runes.toList();
    final n = runes.length;
    int i = 0;

    while (i < n) {
      final c = String.fromCharCode(runes[i]);
      final code = runes[i];

      if (code >= 0x0900 && code <= 0x097F) {
        // Devanagari
        // Check 2-char nukta combination
        String current = c;
        if (i + 1 < n) {
          final nextC = String.fromCharCode(runes[i + 1]);
          final combined = current + nextC;
          if (_devanagariConsonants.containsKey(combined)) {
            current = combined;
            i++;
          }
        }

        if (_devanagariVowels.containsKey(current)) {
          buffer.write(_devanagariVowels[current]);
        } else if (_devanagariConsonants.containsKey(current)) {
          final base = _devanagariConsonants[current]!;
          if (i + 1 < n) {
            final nextCode = runes[i + 1];
            final nextC = String.fromCharCode(nextCode);

            if (nextC == '्') {
              // Virama / Halant cancels vowel
              buffer.write(base);
              i++;
            } else if (_devanagariMatras.containsKey(nextC)) {
              buffer.write(base + _devanagariMatras[nextC]!);
              i++;
            } else if (nextC == 'ं' || nextC == 'ँ') {
              buffer.write('${base}an');
              i++;
            } else if (_devanagariConsonants.containsKey(nextC) ||
                _devanagariVowels.containsKey(nextC)) {
              buffer.write('${base}a');
            } else if (nextCode <= 0x0020 || nextCode < 0x0900 || nextCode > 0x097F) {
              // End-of-word schwa deletion in modern Hindi
              buffer.write(base);
            } else {
              buffer.write('${base}a');
            }
          } else {
            // End of line/string schwa deletion
            buffer.write(base);
          }
        } else if (_devanagariMatras.containsKey(current)) {
          buffer.write(_devanagariMatras[current]);
        } else if (current == 'ं' || current == 'ँ') {
          buffer.write('n');
        } else if (current == 'ः') {
          buffer.write('h');
        } else if (current == '्') {
          // Virama standalone
        } else {
          buffer.write(current);
        }
      } else if (code >= 0x0A00 && code <= 0x0A7F) {
        // Gurmukhi
        String current = c;
        if (i + 1 < n) {
          final nextC = String.fromCharCode(runes[i + 1]);
          final combined = current + nextC;
          if (_gurmukhiConsonants.containsKey(combined)) {
            current = combined;
            i++;
          }
        }

        if (_gurmukhiVowels.containsKey(current)) {
          buffer.write(_gurmukhiVowels[current]);
        } else if (_gurmukhiConsonants.containsKey(current)) {
          final base = _gurmukhiConsonants[current]!;
          if (i + 1 < n) {
            final nextCode = runes[i + 1];
            final nextC = String.fromCharCode(nextCode);

            if (nextC == '੍') {
              buffer.write(base);
              i++;
            } else if (_gurmukhiMatras.containsKey(nextC)) {
              buffer.write(base + _gurmukhiMatras[nextC]!);
              i++;
            } else if (nextC == 'ਂ' || nextC == 'ੰ') {
              buffer.write('${base}an');
              i++;
            } else if (nextC == 'ੱ') {
              // Adhak (gemination)
              buffer.write(base);
              i++;
            } else if (_gurmukhiConsonants.containsKey(nextC) ||
                _gurmukhiVowels.containsKey(nextC)) {
              buffer.write('${base}a');
            } else if (nextCode <= 0x0020 || nextCode < 0x0A00 || nextCode > 0x0A7F) {
              buffer.write(base);
            } else {
              buffer.write('${base}a');
            }
          } else {
            buffer.write(base);
          }
        } else if (_gurmukhiMatras.containsKey(current)) {
          buffer.write(_gurmukhiMatras[current]);
        } else if (current == 'ਂ' || current == 'ੰ') {
          buffer.write('n');
        } else if (current == 'ੱ') {
          // Adhak
        } else {
          buffer.write(current);
        }
      } else {
        buffer.write(c);
      }

      i++;
    }

    return buffer.toString();
  }
}
