// ============================================================================
// Softify Quality of Life (QoL) Feature 43: Instant Lyric Translation Toggle
// ============================================================================
// Provides bilingual lyric display (original line with translated line underneath),
// instant language target selection, offline heuristic and dictionary translation,
// and durable SharedPreferences persistence for Linux desktop and mobile.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/ports/i_lyrics_provider.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';

// ============================================================================
// SharedPreferences Persistence Layer (Zero-Dependency & Self-Contained)
// ============================================================================

/// Storage keys for lyric translation persistence.
const String kLyricTranslationEnabledKey = 'softify_lyric_translation_enabled';
const String kLyricTranslationTargetLangKey = 'softify_lyric_translation_target_lang';
const String kLyricTranslationShowOriginalKey = 'softify_lyric_translation_show_original';
const String kLyricTranslationSubtitleRatioKey = 'softify_lyric_translation_subtitle_ratio';

/// Self-contained SharedPreferences storage engine matching standard APIs
/// without requiring external native plugin builds.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronous singleton accessor if already resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock values for testing environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets mock and cached singleton instances.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Resolves or initializes the SharedPreferences singleton instance.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;

    try {
      file = await _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // In-memory fallback
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static Future<File?> _resolveStorageFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final targetDir = Directory(dir.path);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return File(p.join(dir.path, 'shared_preferences.json'));
    } catch (_) {
      try {
        final home = Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            Platform.environment['LOCALAPPDATA'];
        if (home != null && home.isNotEmpty) {
          final dir = Directory(p.join(home, '.softify'));
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          return File(p.join(dir.path, 'shared_preferences.json'));
        }
      } catch (_) {}
      return File('.softify_shared_preferences.json');
    }
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_store);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  bool? getBool(String key) {
    final val = _store[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) {
    final val = _store[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  double? getDouble(String key) {
    final val = _store[key];
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Future<bool> setDouble(String key, double value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  int? getInt(String key) {
    final val = _store[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  bool containsKey(String key) => _store.containsKey(key);

  Future<bool> remove(String key) async {
    _store.remove(key);
    await _persist();
    return true;
  }

  Future<bool> clear() async {
    _store.clear();
    await _persist();
    return true;
  }
}

// ============================================================================
// Domain Models
// ============================================================================

/// Metadata describing a translation target language.
@immutable
class LyricLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flagEmoji;

  const LyricLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flagEmoji,
  });

  static const LyricLanguage english = LyricLanguage(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    flagEmoji: '🇬🇧',
  );

  static const List<LyricLanguage> supportedLanguages = [
    english,
    LyricLanguage(code: 'es', name: 'Spanish', nativeName: 'Español', flagEmoji: '🇪🇸'),
    LyricLanguage(code: 'fr', name: 'French', nativeName: 'Français', flagEmoji: '🇫🇷'),
    LyricLanguage(code: 'de', name: 'German', nativeName: 'Deutsch', flagEmoji: '🇩🇪'),
    LyricLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語', flagEmoji: '🇯🇵'),
    LyricLanguage(code: 'ko', name: 'Korean', nativeName: '한국어', flagEmoji: '🇰🇷'),
    LyricLanguage(code: 'zh', name: 'Chinese', nativeName: '中文', flagEmoji: '🇨🇳'),
    LyricLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flagEmoji: '🇮🇳'),
    LyricLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português', flagEmoji: '🇧🇷'),
    LyricLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano', flagEmoji: '🇮🇹'),
    LyricLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский', flagEmoji: '🇷🇺'),
    LyricLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', flagEmoji: '🇮🇩'),
    LyricLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', flagEmoji: '🇻🇳'),
    LyricLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', flagEmoji: '🇹🇷'),
    LyricLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية', flagEmoji: '🇸🇦'),
    LyricLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands', flagEmoji: '🇳🇱'),
    LyricLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski', flagEmoji: '🇵🇱'),
    LyricLanguage(code: 'sv', name: 'Swedish', nativeName: 'Svenska', flagEmoji: '🇸🇪'),
  ];

  /// Resolves language by ISO-639-1 code with safe fallback.
  static LyricLanguage fromCode(String code) {
    final lower = code.trim().toLowerCase();
    return supportedLanguages.firstWhere(
      (lang) => lang.code.toLowerCase() == lower,
      orElse: () => LyricLanguage(
        code: lower,
        name: lower.toUpperCase(),
        nativeName: lower.toUpperCase(),
        flagEmoji: '🌐',
      ),
    );
  }

  /// Filters supported languages by query string.
  static List<LyricLanguage> filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return supportedLanguages;
    return supportedLanguages.where((lang) {
      return lang.name.toLowerCase().contains(q) ||
          lang.nativeName.toLowerCase().contains(q) ||
          lang.code.toLowerCase().contains(q);
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLanguage &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'LyricLanguage($code, $name)';
}

/// Represents a bilingual synchronized or plain lyric line.
///
/// Holds the [originalText] alongside the translated [translatedText]
/// rendered directly underneath in the UI.
@immutable
class BilingualLyricLine {
  final Duration timestamp;
  final String originalText;
  final String? translatedText;
  final Duration? duration;
  final List<LyricWord>? words;
  final String? agent;
  final bool isTranslating;

  const BilingualLyricLine({
    required this.timestamp,
    required this.originalText,
    this.translatedText,
    this.duration,
    this.words,
    this.agent,
    this.isTranslating = false,
  });

  /// Factory constructing from domain [LyricLine].
  factory BilingualLyricLine.fromLyricLine(
    LyricLine line, {
    String? translatedText,
    bool isTranslating = false,
  }) {
    return BilingualLyricLine(
      timestamp: line.timestamp,
      originalText: line.text,
      translatedText: translatedText,
      words: line.words,
      agent: line.agent,
      isTranslating: isTranslating,
    );
  }

  /// True if a translated line is available and non-empty.
  bool get hasTranslation =>
      translatedText != null && translatedText!.trim().isNotEmpty;

  /// Primary line display text.
  String get displayText => originalText;

  /// Translated subtitle display text.
  String get subtitleText => translatedText ?? '';

  BilingualLyricLine copyWith({
    Duration? timestamp,
    String? originalText,
    String? translatedText,
    Duration? duration,
    List<LyricWord>? words,
    String? agent,
    bool? isTranslating,
  }) {
    return BilingualLyricLine(
      timestamp: timestamp ?? this.timestamp,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      duration: duration ?? this.duration,
      words: words ?? this.words,
      agent: agent ?? this.agent,
      isTranslating: isTranslating ?? this.isTranslating,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BilingualLyricLine &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          originalText == other.originalText &&
          translatedText == other.translatedText &&
          isTranslating == other.isTranslating;

  @override
  int get hashCode => Object.hash(
        timestamp,
        originalText,
        translatedText,
        isTranslating,
      );

  @override
  String toString() =>
      'BilingualLyricLine(timestamp: $timestamp, original: "$originalText", translated: "$translatedText")';
}

/// Container for a song's complete set of bilingual lines.
@immutable
class BilingualLyrics {
  final String trackId;
  final List<BilingualLyricLine> lines;
  final String? sourceLanguage;
  final String targetLanguage;
  final bool isSynced;
  final String? providerName;
  final DateTime translatedAt;

  BilingualLyrics({
    required this.trackId,
    required this.lines,
    this.sourceLanguage,
    required this.targetLanguage,
    this.isSynced = true,
    this.providerName,
    DateTime? translatedAt,
  }) : translatedAt = translatedAt ?? DateTime.now();

  /// Locates the active line at playback [position].
  BilingualLyricLine? lineAt(Duration position) {
    final idx = lineIndexAt(position);
    if (idx >= 0 && idx < lines.length) {
      return lines[idx];
    }
    return null;
  }

  /// Calculates the active line index using binary search on timestamps.
  int lineIndexAt(Duration position) {
    if (lines.isEmpty) return -1;
    if (position < lines.first.timestamp) return -1;

    int low = 0;
    int high = lines.length - 1;
    int result = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].timestamp <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  /// Formatted plain original lyrics.
  String toOriginalText() => lines.map((l) => l.originalText).join('\n');

  /// Formatted plain translated lyrics.
  String toTranslatedText() =>
      lines.map((l) => l.translatedText ?? l.originalText).join('\n');

  /// Interleaved bilingual lyrics text.
  String toBilingualText({String separator = '\n'}) {
    return lines.map((l) {
      if (l.hasTranslation) {
        return '${l.originalText}\n(${l.translatedText})';
      }
      return l.originalText;
    }).join(separator);
  }

  BilingualLyrics copyWith({
    String? trackId,
    List<BilingualLyricLine>? lines,
    String? sourceLanguage,
    String? targetLanguage,
    bool? isSynced,
    String? providerName,
    DateTime? translatedAt,
  }) {
    return BilingualLyrics(
      trackId: trackId ?? this.trackId,
      lines: lines ?? this.lines,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      isSynced: isSynced ?? this.isSynced,
      providerName: providerName ?? this.providerName,
      translatedAt: translatedAt ?? this.translatedAt,
    );
  }
}

// ============================================================================
// Pure Translation Engine & Offline Dictionary
// ============================================================================

/// Extensible pure-Dart translation engine.
///
/// Includes script detection, built-in multi-lingual phrase dictionaries,
/// word substitution heuristics, and support for pluggable remote API hooks.
class LyricTranslationEngine {
  LyricTranslationEngine._();

  /// Optional external translator hook (for remote AI or cloud API integration).
  static Future<String> Function(
    String text,
    String sourceLang,
    String targetLang,
  )? customTranslator;

  // ---------------------------------------------------------------------------
  // Language & Script Detection
  // ---------------------------------------------------------------------------

  /// Identifies the likely source language of [text] using character script heuristics.
  static String detectLanguage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'en';

    // Japanese: Hiragana / Katakana
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(trimmed)) {
      return 'ja';
    }

    // Korean: Hangul syllables or Jamo
    if (RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]').hasMatch(trimmed)) {
      return 'ko';
    }

    // Chinese: Hanzi ideographs without Japanese Kana
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(trimmed)) {
      return 'zh';
    }

    // Hindi: Devanagari
    if (RegExp(r'[\u0900-\u097F]').hasMatch(trimmed)) {
      return 'hi';
    }

    // Russian / Ukrainian: Cyrillic
    if (RegExp(r'[\u0400-\u04FF]').hasMatch(trimmed)) {
      return 'ru';
    }

    // Arabic
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed)) {
      return 'ar';
    }

    // Spanish distinctive diacritics
    if (RegExp(r'[áéíóúñ¿¡]', caseSensitive: false).hasMatch(trimmed)) {
      return 'es';
    }

    // French distinctive diacritics
    if (RegExp(r'[àâçéèêëîïôûùüÿœæ]', caseSensitive: false).hasMatch(trimmed)) {
      return 'fr';
    }

    // German distinctive diacritics
    if (RegExp(r'[äöüß]', caseSensitive: false).hasMatch(trimmed)) {
      return 'de';
    }

    // Default to English
    return 'en';
  }

  // ---------------------------------------------------------------------------
  // Offline Multilingual Phrase Dictionary
  // ---------------------------------------------------------------------------

  static const Map<String, Map<String, String>> _phraseDictionary = {
    // English -> Target
    'i love you': {
      'es': 'Te amo',
      'fr': 'Je t\'aime',
      'de': 'Ich liebe dich',
      'ja': '愛してる',
      'ko': '사랑해',
      'zh': '我爱你',
      'hi': 'मैं तुमसे प्यार करता हूँ',
      'pt': 'Eu te amo',
      'it': 'Ti amo',
      'ru': 'Я тебя люблю',
      'id': 'Aku mencintaimu',
      'tr': 'Seni seviyorum',
      'ar': 'أحبك',
    },
    'stay with me': {
      'es': 'Quédate conmigo',
      'fr': 'Reste avec moi',
      'de': 'Bleib bei mir',
      'ja': 'そばにいて',
      'ko': '내 곁에 있어줘',
      'zh': '和我在一起',
      'hi': 'मेरे साथ रहो',
      'pt': 'Fique comigo',
      'it': 'Resta con me',
      'ru': 'Останься со мной',
    },
    'take my hand': {
      'es': 'Toma mi mano',
      'fr': 'Prends ma main',
      'de': 'Nimm meine Hand',
      'ja': '手を取って',
      'ko': '내 손을 잡아',
      'zh': '牵着我的手',
      'hi': 'मेरा हाथ पकड़ो',
      'pt': 'Pegue minha mão',
      'it': 'Prendi la mia mano',
      'ru': 'Возьми меня за руку',
    },
    'dancing in the dark': {
      'es': 'Bailando en la oscuridad',
      'fr': 'Danser dans le noir',
      'de': 'Tanzen im Dunkeln',
      'ja': '暗闇の中で踊る',
      'ko': '어둠 속에서 춤추며',
      'zh': '在黑暗中起舞',
      'hi': 'अंधेरे में नाचते हुए',
      'pt': 'Dançando no escuro',
      'it': 'Ballando al buio',
      'ru': 'Танцуя в темноте',
    },
    'can\'t let you go': {
      'es': 'No puedo dejarte ir',
      'fr': 'Je ne peux pas te laisser partir',
      'de': 'Kann dich nicht gehen lassen',
      'ja': '君を手放せない',
      'ko': '널 보낼 수 없어',
      'zh': '不能放你走',
      'hi': 'तुम्हें जाने नहीं दे सकता',
      'pt': 'Não posso te deixar ir',
      'it': 'Non posso lasciarti andare',
      'ru': 'Не могу отпустить тебя',
    },
    'never say goodbye': {
      'es': 'Nunca digas adiós',
      'fr': 'Ne dis jamais au revoir',
      'de': 'Sag niemals Lebewohl',
      'ja': 'さよならは言わないで',
      'ko': '안녕이라고 말하지 마',
      'zh': '永不说再见',
      'hi': 'कभी अलविदा न कहना',
      'pt': 'Nunca diga adeus',
      'it': 'Non dire mai addio',
      'ru': 'Никогда не говори прощай',
    },
    'lost in your eyes': {
      'es': 'Perdido en tus ojos',
      'fr': 'Perdu dans tes yeux',
      'de': 'Verloren in deinen Augen',
      'ja': '君の瞳に迷い込んで',
      'ko': '네 눈 속에서 길을 잃고',
      'zh': '迷失在你的眼眸',
      'hi': 'तेरी आँखों में खोया हुआ',
      'pt': 'Perdido em seus olhos',
      'it': 'Perso nei tuoi occhi',
      'ru': 'Потерян в твоих глазах',
    },
    'under the stars': {
      'es': 'Bajo las estrellas',
      'fr': 'Sous les étoiles',
      'de': 'Unter den Sternen',
      'ja': '星空の下で',
      'ko': '별빛 아래서',
      'zh': '繁星之下',
      'hi': 'तारों के नीचे',
      'pt': 'Sob as estrelas',
      'it': 'Sotto le stelle',
      'ru': 'Под звездами',
    },
    'heart and soul': {
      'es': 'Corazón y alma',
      'fr': 'Cœur et âme',
      'de': 'Herz und Seele',
      'ja': '心と魂',
      'ko': '가슴과 영혼',
      'zh': '全心全意',
      'hi': 'दिल और जान से',
      'pt': 'Coração e alma',
      'it': 'Cuore e anima',
      'ru': 'Сердцем и душой',
    },
    'forever and always': {
      'es': 'Por siempre y para siempre',
      'fr': 'Pour toujours et à jamais',
      'de': 'Für immer und ewig',
      'ja': 'いつまでも永遠に',
      'ko': '영원히 영원토록',
      'zh': '生生世世',
      'hi': 'हमेशा और हमेशा के लिए',
      'pt': 'Para sempre e sempre',
      'it': 'Per sempre e sempre',
      'ru': 'Всегда и навечно',
    },

    // Spanish -> Target
    'te amo': {
      'en': 'I love you',
      'fr': 'Je t\'aime',
      'de': 'Ich liebe dich',
      'ja': '愛してる',
      'ko': '사랑해',
      'zh': '我爱你',
    },
    'despacito': {
      'en': 'Slowly',
      'fr': 'Tout doucement',
      'de': 'Ganz langsam',
      'ja': 'ゆっくりと',
      'ko': '천천히',
      'zh': '慢慢地',
    },
    'corazón': {
      'en': 'Heart',
      'fr': 'Cœur',
      'de': 'Herz',
      'ja': '心',
      'ko': '마음',
      'zh': '心灵',
    },
    'la vida es un sueño': {
      'en': 'Life is a dream',
      'fr': 'La vie est un songe',
      'de': 'Das Leben ist ein Traum',
      'ja': '人生は夢のよう',
      'ko': '인생은 꿈과 같아',
      'zh': '人生如梦',
    },

    // Japanese -> Target
    '愛してる': {
      'en': 'I love you',
      'es': 'Te amo',
      'fr': 'Je t\'aime',
      'de': 'Ich liebe dich',
      'ko': '사랑해',
      'zh': '我爱你',
    },
    'さようなら': {
      'en': 'Goodbye',
      'es': 'Adiós',
      'fr': 'Au revoir',
      'de': 'Auf Wiedersehen',
      'ko': '안녕',
      'zh': '再见',
    },
    'ありがとう': {
      'en': 'Thank you',
      'es': 'Gracias',
      'fr': 'Merci',
      'de': 'Danke',
      'ko': '고마워',
      'zh': '谢谢',
    },
    '君が好き': {
      'en': 'I like you',
      'es': 'Me gustas',
      'fr': 'Je te plais',
      'de': 'Ich mag dich',
      'ko': '네가 좋아',
      'zh': '喜欢你',
    },
    'そばにいて': {
      'en': 'Stay by my side',
      'es': 'Quédate a mi lado',
      'fr': 'Reste à mes côtés',
      'de': 'Bleib an meiner Seite',
      'ko': '내 곁에 있어줘',
      'zh': '陪在我身旁',
    },

    // Korean -> Target
    '사랑해': {
      'en': 'I love you',
      'es': 'Te amo',
      'fr': 'Je t\'aime',
      'de': 'Ich liebe dich',
      'ja': '愛してる',
      'zh': '我爱你',
    },
    '보고 싶다': {
      'en': 'I miss you',
      'es': 'Te extraño',
      'fr': 'Tu me manques',
      'de': 'Ich vermisse dich',
      'ja': '会いたい',
      'zh': '好想你',
    },
    '영원히': {
      'en': 'Forever',
      'es': 'Para siempre',
      'fr': 'Pour toujours',
      'de': 'Für immer',
      'ja': '永遠に',
      'zh': '永远',
    },

    // Chinese -> Target
    '我爱你': {
      'en': 'I love you',
      'es': 'Te amo',
      'fr': 'Je t\'aime',
      'de': 'Ich liebe dich',
      'ja': '愛してる',
      'ko': '사랑해',
    },
    '想你': {
      'en': 'Missing you',
      'es': 'Pensando en ti',
      'fr': 'Penser à toi',
      'de': 'Vermisse dich',
      'ja': '君を想う',
      'ko': '보고 싶어',
    },

    // Hindi -> Target
    'तुम ही हो': {
      'en': 'You are the only one',
      'es': 'Tú eres el único',
      'fr': 'Tu es le seul',
      'de': 'Du bist die Einzige',
      'ja': '君だけがすべて',
      'ko': '오직 너뿐이야',
    },
    'तेरे बिना': {
      'en': 'Without you',
      'es': 'Sin ti',
      'fr': 'Sans toi',
      'de': 'Ohne dich',
      'ja': '君がいなければ',
      'ko': '너 없이는',
    },

    // French -> Target
    'la vie en rose': {
      'en': 'Life in pink / Rosy life',
      'es': 'La vida en rosa',
      'de': 'Das Leben durch die rosarote Brille',
      'ja': 'ばら色の人生',
    },
    'je t\'aime': {
      'en': 'I love you',
      'es': 'Te amo',
      'de': 'Ich liebe dich',
      'ja': '愛してる',
      'ko': '사랑해',
      'zh': '我爱你',
    },
  };

  // Word token dictionary for heuristic substitutions
  static const Map<String, Map<String, String>> _wordDictionary = {
    'love': {'es': 'amor', 'fr': 'amour', 'de': 'Liebe', 'ja': '愛', 'ko': '사랑'},
    'heart': {'es': 'corazón', 'fr': 'cœur', 'de': 'Herz', 'ja': '心', 'ko': '마음'},
    'night': {'es': 'noche', 'fr': 'nuit', 'de': 'Nacht', 'ja': '夜', 'ko': '밤'},
    'dream': {'es': 'sueño', 'fr': 'rêve', 'de': 'Traum', 'ja': '夢', 'ko': '꿈'},
    'light': {'es': 'luz', 'fr': 'lumière', 'de': 'Licht', 'ja': '光', 'ko': '빛'},
    'eyes': {'es': 'ojos', 'fr': 'yeux', 'de': 'Augen', 'ja': '瞳', 'ko': '눈'},
    'sky': {'es': 'cielo', 'fr': 'ciel', 'de': 'Himmel', 'ja': '空', 'ko': '하늘'},
    'star': {'es': 'estrella', 'fr': 'étoile', 'de': 'Stern', 'ja': '星', 'ko': '별'},
    'time': {'es': 'tiempo', 'fr': 'temps', 'de': 'Zeit', 'ja': '時間', 'ko': '시간'},
    'world': {'es': 'mundo', 'fr': 'monde', 'de': 'Welt', 'ja': '世界', 'ko': '세상'},
    'baby': {'es': 'cariño', 'fr': 'bébé', 'de': 'Baby', 'ja': 'ベイビー', 'ko': '그대'},
    'together': {'es': 'juntos', 'fr': 'ensemble', 'de': 'zusammen', 'ja': '一緒に', 'ko': '함께'},
    'forever': {'es': 'por siempre', 'fr': 'pour toujours', 'de': 'für immer', 'ja': '永遠に', 'ko': '영원히'},
  };

  // ---------------------------------------------------------------------------
  // Translation Methods
  // ---------------------------------------------------------------------------

  /// Translates a single line of text from [sourceLang] to [targetLang].
  static Future<String> translateLine(
    String text, {
    String? sourceLang,
    required String targetLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final src = (sourceLang != null && sourceLang.isNotEmpty)
        ? sourceLang.toLowerCase()
        : detectLanguage(trimmed);
    final tgt = targetLang.toLowerCase();

    // Same language: return original
    if (src == tgt) return trimmed;

    // Delegate to custom hook if configured
    if (customTranslator != null) {
      try {
        final result = await customTranslator!(trimmed, src, tgt);
        if (result.trim().isNotEmpty) return result.trim();
      } catch (_) {}
    }

    // 1. Direct dictionary match (case-insensitive)
    final lowerKey = trimmed.toLowerCase();
    final dictMatch = _phraseDictionary[lowerKey]?[tgt];
    if (dictMatch != null && dictMatch.isNotEmpty) {
      return dictMatch;
    }

    // 2. Stripped punctuation lookup
    final cleanPunct = lowerKey.replaceAll(RegExp(r'[^\w\s\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF]'), '').trim();
    final cleanMatch = _phraseDictionary[cleanPunct]?[tgt];
    if (cleanMatch != null && cleanMatch.isNotEmpty) {
      return cleanMatch;
    }

    // 3. Heuristic Token Substitution (English -> Other)
    if (src == 'en' && (_wordDictionary.isNotEmpty)) {
      final words = trimmed.split(RegExp(r'(\s+)'));
      bool modified = false;
      final translatedTokens = words.map((token) {
        final cleanToken = token.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');
        final translatedWord = _wordDictionary[cleanToken]?[tgt];
        if (translatedWord != null) {
          modified = true;
          // Retain surrounding punctuation if any
          return token.replaceAll(RegExp(cleanToken, caseSensitive: false), translatedWord);
        }
        return token;
      }).toList();

      if (modified) {
        return translatedTokens.join();
      }
    }

    // 4. Fallback: Return original text gracefully
    return trimmed;
  }

  /// Translates a collection of [LyricLine] instances into [BilingualLyricLine]s.
  static Future<List<BilingualLyricLine>> translateLines(
    List<LyricLine> originalLines, {
    String? sourceLang,
    required String targetLang,
  }) async {
    final results = <BilingualLyricLine>[];

    for (final line in originalLines) {
      final translated = await translateLine(
        line.text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );

      results.add(BilingualLyricLine(
        timestamp: line.timestamp,
        originalText: line.text,
        translatedText: translated.isNotEmpty && translated != line.text ? translated : null,
        words: line.words,
        agent: line.agent,
      ));
    }

    return results;
  }

  /// Translates a complete [SyncedLyrics] container into [BilingualLyrics].
  static Future<BilingualLyrics> translateSyncedLyrics(
    SyncedLyrics original, {
    required String targetLang,
    String? sourceLang,
  }) async {
    final detectedSource = sourceLang ??
        (original.lines.isNotEmpty
            ? detectLanguage(original.lines.first.text)
            : 'en');

    final bilingualLines = await translateLines(
      original.lines,
      sourceLang: detectedSource,
      targetLang: targetLang,
    );

    return BilingualLyrics(
      trackId: original.trackId,
      lines: bilingualLines,
      sourceLanguage: detectedSource,
      targetLanguage: targetLang,
      isSynced: original.isSynced,
      providerName: original.providerName,
      translatedAt: DateTime.now(),
    );
  }
}

// ============================================================================
// State Management & Riverpod Notifier
// ============================================================================

enum LyricTranslationStatus {
  idle,
  translating,
  success,
  error,
}

/// State representation for the lyric translation feature.
@immutable
class LyricTranslationState {
  final bool isEnabled;
  final String targetLanguage;
  final LyricTranslationStatus status;
  final String? currentTrackId;
  final BilingualLyrics? currentLyrics;
  final String? errorMessage;
  final Map<String, BilingualLyrics> cache;
  final bool showOriginal;
  final double subtitleScale;

  const LyricTranslationState({
    this.isEnabled = false,
    this.targetLanguage = 'en',
    this.status = LyricTranslationStatus.idle,
    this.currentTrackId,
    this.currentLyrics,
    this.errorMessage,
    this.cache = const {},
    this.showOriginal = true,
    this.subtitleScale = 0.82,
  });

  bool get isTranslating => status == LyricTranslationStatus.translating;

  LyricTranslationState copyWith({
    bool? isEnabled,
    String? targetLanguage,
    LyricTranslationStatus? status,
    String? currentTrackId,
    BilingualLyrics? currentLyrics,
    String? errorMessage,
    Map<String, BilingualLyrics>? cache,
    bool? showOriginal,
    double? subtitleScale,
  }) {
    return LyricTranslationState(
      isEnabled: isEnabled ?? this.isEnabled,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      status: status ?? this.status,
      currentTrackId: currentTrackId ?? this.currentTrackId,
      currentLyrics: currentLyrics ?? this.currentLyrics,
      errorMessage: errorMessage ?? this.errorMessage,
      cache: cache ?? this.cache,
      showOriginal: showOriginal ?? this.showOriginal,
      subtitleScale: subtitleScale ?? this.subtitleScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricTranslationState &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          targetLanguage == other.targetLanguage &&
          status == other.status &&
          currentTrackId == other.currentTrackId &&
          currentLyrics == other.currentLyrics &&
          errorMessage == other.errorMessage &&
          showOriginal == other.showOriginal &&
          subtitleScale == other.subtitleScale;

  @override
  int get hashCode => Object.hash(
        isEnabled,
        targetLanguage,
        status,
        currentTrackId,
        currentLyrics,
        errorMessage,
        showOriginal,
        subtitleScale,
      );
}

/// Riverpod StateNotifier controlling translation toggle, language selection,
/// and bilingual lyrics caching and retrieval.
class LyricTranslationNotifier extends StateNotifier<LyricTranslationState> {
  LyricTranslationNotifier({
    bool? initialEnabled,
    String? initialTargetLanguage,
  }) : super(LyricTranslationState(
          isEnabled: initialEnabled ?? false,
          targetLanguage: initialTargetLanguage ?? 'en',
        )) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(kLyricTranslationEnabledKey);
      final lang = prefs.getString(kLyricTranslationTargetLangKey);
      final showOrig = prefs.getBool(kLyricTranslationShowOriginalKey);
      final subRatio = prefs.getDouble(kLyricTranslationSubtitleRatioKey);

      state = state.copyWith(
        isEnabled: enabled ?? state.isEnabled,
        targetLanguage: lang ?? state.targetLanguage,
        showOriginal: showOrig ?? state.showOriginal,
        subtitleScale: subRatio ?? state.subtitleScale,
      );
    } catch (_) {}
  }

  /// Toggles translation mode on or off with immediate persistence.
  Future<void> toggle() async {
    final next = !state.isEnabled;
    state = state.copyWith(isEnabled: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kLyricTranslationEnabledKey, next);
    } catch (_) {}
  }

  /// Explicitly sets the translation enabled state.
  Future<void> setEnabled(bool enabled) async {
    if (state.isEnabled == enabled) return;
    state = state.copyWith(isEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kLyricTranslationEnabledKey, enabled);
    } catch (_) {}
  }

  /// Changes the target translation language and updates active lyrics.
  Future<void> setTargetLanguage(String languageCode) async {
    final lang = LyricLanguage.fromCode(languageCode).code;
    if (state.targetLanguage == lang) return;

    state = state.copyWith(targetLanguage: lang);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLyricTranslationTargetLangKey, lang);
    } catch (_) {}

    // Check if we already have translated cached version for current track
    final trackId = state.currentTrackId;
    if (trackId != null && state.isEnabled) {
      final cacheKey = '${trackId}_$lang';
      if (state.cache.containsKey(cacheKey)) {
        state = state.copyWith(
          currentLyrics: state.cache[cacheKey],
          status: LyricTranslationStatus.success,
        );
      }
    }
  }

  /// Sets whether the original line is visible alongside the translation.
  Future<void> setShowOriginal(bool show) async {
    state = state.copyWith(showOriginal: show);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kLyricTranslationShowOriginalKey, show);
    } catch (_) {}
  }

  /// Sets the subtitle scaling factor for the translated line.
  Future<void> setSubtitleScale(double scale) async {
    final clamped = scale.clamp(0.6, 1.2);
    state = state.copyWith(subtitleScale: clamped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(kLyricTranslationSubtitleRatioKey, clamped);
    } catch (_) {}
  }

  /// Translates given [SyncedLyrics] into bilingual format, caching results.
  Future<BilingualLyrics?> translateLyrics(
    SyncedLyrics lyrics, {
    String? targetLang,
    bool force = false,
  }) async {
    final tgt = targetLang ?? state.targetLanguage;
    final cacheKey = '${lyrics.trackId}_$tgt';

    // 1. Check in-memory cache
    if (!force && state.cache.containsKey(cacheKey)) {
      final cached = state.cache[cacheKey]!;
      state = state.copyWith(
        currentTrackId: lyrics.trackId,
        currentLyrics: cached,
        status: LyricTranslationStatus.success,
        errorMessage: null,
      );
      return cached;
    }

    // 2. Perform translation
    state = state.copyWith(
      currentTrackId: lyrics.trackId,
      status: LyricTranslationStatus.translating,
      errorMessage: null,
    );

    try {
      final bilingual = await LyricTranslationEngine.translateSyncedLyrics(
        lyrics,
        targetLang: tgt,
      );

      final updatedCache = Map<String, BilingualLyrics>.from(state.cache);
      updatedCache[cacheKey] = bilingual;

      state = state.copyWith(
        currentLyrics: bilingual,
        status: LyricTranslationStatus.success,
        cache: updatedCache,
      );

      return bilingual;
    } catch (e) {
      state = state.copyWith(
        status: LyricTranslationStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Translates plain text lyrics.
  Future<BilingualLyrics?> translatePlainText(
    String trackId,
    String plainText, {
    String? targetLang,
  }) async {
    final tgt = targetLang ?? state.targetLanguage;
    final lines = plainText
        .split('\n')
        .asMap()
        .entries
        .map((e) => LyricLine(
              timestamp: Duration(seconds: e.key * 3),
              text: e.value,
            ))
        .toList();

    final synced = SyncedLyrics(
      trackId: trackId,
      lines: lines,
      plainLyrics: plainText,
      syncType: 'UNSYNCED',
    );

    return translateLyrics(synced, targetLang: tgt);
  }

  /// Clears in-memory translation cache.
  void clearCache() {
    state = state.copyWith(cache: const {});
  }

  /// Manually sets current lyrics object.
  void setCurrentLyrics(BilingualLyrics? lyrics) {
    state = state.copyWith(
      currentLyrics: lyrics,
      currentTrackId: lyrics?.trackId,
    );
  }

  /// Retrieves the active bilingual line at playback [position].
  BilingualLyricLine? getLineAt(Duration position) {
    return state.currentLyrics?.lineAt(position);
  }

  /// Retrieves the active line index at playback [position].
  int getLineIndexAt(Duration position) {
    return state.currentLyrics?.lineIndexAt(position) ?? -1;
  }
}

// ============================================================================
// Providers
// ============================================================================

/// Global StateNotifierProvider for LyricTranslation state and actions.
final lyricTranslationNotifierProvider =
    StateNotifierProvider<LyricTranslationNotifier, LyricTranslationState>((ref) {
  return LyricTranslationNotifier();
});

/// Convenience provider for translation enabled flag.
final lyricTranslationEnabledProvider = Provider<bool>((ref) {
  return ref.watch(lyricTranslationNotifierProvider).isEnabled;
});

/// Convenience provider for current target language.
final lyricTranslationTargetLangProvider = Provider<String>((ref) {
  return ref.watch(lyricTranslationNotifierProvider).targetLanguage;
});

/// Convenience provider for active bilingual lyrics.
final currentBilingualLyricsProvider = Provider<BilingualLyrics?>((ref) {
  return ref.watch(lyricTranslationNotifierProvider).currentLyrics;
});

// ============================================================================
// UI Widgets
// ============================================================================

/// Material 3 interactive toggle button for instant lyric translation.
///
/// Tapping toggles translation on/off with haptic feedback.
/// Long-pressing opens the [LyricLanguageTargetSelector] modal bottom sheet.
class LyricTranslationToggle extends ConsumerWidget {
  final EdgeInsetsGeometry padding;
  final bool compact;
  final VoidCallback? onLongPress;
  final Color? activeColor;
  final Color? inactiveColor;

  const LyricTranslationToggle({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.compact = false,
    this.onLongPress,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationState = ref.watch(lyricTranslationNotifierProvider);
    final notifier = ref.read(lyricTranslationNotifierProvider.notifier);
    final isEnabled = translationState.isEnabled;
    final isTranslating = translationState.isTranslating;
    final targetLang = LyricLanguage.fromCode(translationState.targetLanguage);

    final theme = Theme.of(context);
    final primaryAccent = activeColor ?? AppTheme.accent;
    final mutedColor = inactiveColor ?? AppTheme.textSecondary;

    return Semantics(
      label: 'Lyric Translation Toggle. Status: ${isEnabled ? "Enabled" : "Disabled"}. Target language: ${targetLang.name}',
      button: true,
      toggled: isEnabled,
      child: Tooltip(
        message: 'Translate Lyrics (${targetLang.name}) - ${isEnabled ? "ON" : "OFF"}\nLong press to change language',
        waitDuration: const Duration(milliseconds: 600),
        child: BouncingScaleButton(
          onTap: () {
            HapticFeedback.lightImpact();
            notifier.toggle();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            if (onLongPress != null) {
              onLongPress!();
            } else {
              LyricLanguageTargetSelector.showModal(context, ref);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: padding,
            decoration: BoxDecoration(
              color: isEnabled
                  ? primaryAccent.withOpacity(0.18)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEnabled
                    ? primaryAccent.withOpacity(0.65)
                    : Colors.white.withOpacity(0.12),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTranslating)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isEnabled ? primaryAccent : mutedColor,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.translate_rounded,
                    size: 17,
                    color: isEnabled ? primaryAccent : mutedColor,
                  ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    targetLang.code.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 12,
                      fontWeight: isEnabled ? FontWeight.w700 : FontWeight.w500,
                      color: isEnabled ? primaryAccent : mutedColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet and dialog for selecting translation target language.
class LyricLanguageTargetSelector extends StatefulWidget {
  final WidgetRef ref;

  const LyricLanguageTargetSelector({super.key, required this.ref});

  /// Presents the language selector inside a modal bottom sheet.
  static Future<String?> showModal(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => LyricLanguageTargetSelector(ref: ref),
    );
  }

  /// Presents the language selector inside a desktop dialog.
  static Future<String?> showAsDialog(BuildContext context, WidgetRef ref) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LyricLanguageTargetSelector(ref: ref),
          ),
        ),
      ),
    );
  }

  @override
  State<LyricLanguageTargetSelector> createState() =>
      _LyricLanguageTargetSelectorState();
}

class _LyricLanguageTargetSelectorState
    extends State<LyricLanguageTargetSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<LyricLanguage> _filtered = LyricLanguage.supportedLanguages;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _filtered = LyricLanguage.filter(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translationState = widget.ref.watch(lyricTranslationNotifierProvider);
    final notifier = widget.ref.read(lyricTranslationNotifierProvider.notifier);
    final activeCode = translationState.targetLanguage;
    final isEnabled = translationState.isEnabled;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with switch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    color: AppTheme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lyric Translation',
                        style: TextStyle(
                          fontFamily: AppTheme.fontPageTitle,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Bilingual lyrics in real time',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle Switch
                Switch.adaptive(
                  value: isEnabled,
                  activeColor: AppTheme.accent,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    notifier.setEnabled(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const Key('lyric_language_search_field'),
              controller: _searchController,
              style: const TextStyle(
                fontFamily: AppTheme.fontUi,
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search language or code...',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  color: AppTheme.textMuted,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Languages List
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.05),
                ),
                itemBuilder: (context, index) {
                  final lang = _filtered[index];
                  final isSelected = lang.code.toLowerCase() == activeCode.toLowerCase();

                  return ListTile(
                    key: Key('lyric_lang_item_${lang.code}'),
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: isSelected
                        ? AppTheme.accent.withOpacity(0.12)
                        : Colors.transparent,
                    leading: Text(
                      lang.flagEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Row(
                      children: [
                        Text(
                          lang.name,
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${lang.nativeName})',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.accent,
                            size: 20,
                          )
                        : Text(
                            lang.code.toUpperCase(),
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      notifier.setTargetLanguage(lang.code);
                      if (!isEnabled) {
                        notifier.setEnabled(true);
                      }
                      Navigator.of(context).pop(lang.code);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a single bilingual lyric line with the original line on top
/// and translated text directly underneath in secondary styling.
class BilingualLyricLineView extends StatelessWidget {
  final BilingualLyricLine line;
  final bool isTranslationEnabled;
  final bool isActive;
  final bool showOriginal;
  final double fontSize;
  final double subtitleRatio;
  final Color? activeColor;
  final Color? inactiveColor;
  final VoidCallback? onTap;

  const BilingualLyricLineView({
    super.key,
    required this.line,
    this.isTranslationEnabled = true,
    this.isActive = false,
    this.showOriginal = true,
    this.fontSize = 20.0,
    this.subtitleRatio = 0.82,
    this.activeColor,
    this.inactiveColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppTheme.textPrimary;
    final effectiveInactiveColor = inactiveColor ?? AppTheme.textSecondary.withOpacity(0.5);
    final primaryColor = isActive ? effectiveActiveColor : effectiveInactiveColor;

    final hasTrans = line.hasTranslation && isTranslationEnabled;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Original Line
            if (showOriginal || !hasTrans)
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: fontSize,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: primaryColor,
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
                child: Text(line.originalText),
              ),

            // Translated Line Underneath
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: hasTrans
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 3.0),
                child: Text(
                  line.subtitleText,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: fontSize * subtitleRatio,
                    fontStyle: FontStyle.italic,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                    color: isActive
                        ? AppTheme.accentLight.withOpacity(0.9)
                        : effectiveInactiveColor.withOpacity(0.75),
                    height: 1.25,
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
