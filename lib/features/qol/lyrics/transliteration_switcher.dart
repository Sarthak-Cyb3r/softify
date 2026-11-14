// ============================================================================
// Softify Quality of Life (QoL) - Feature 38: Romanized Transliteration Switcher
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/ports/i_lyrics_provider.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';
import '../../../services/lyrics/romanization_service.dart';

// ============================================================================
// Enums & Model Definitions
// ============================================================================

/// Supported transliteration modes for synchronized and plain lyrics.
enum TransliterationMode {
  /// Original unmodified lyrics as delivered by the lyrics provider.
  original(
    id: 'original',
    badgeLabel: 'ORIG',
    displayName: 'Original',
    description: 'Keep original script without transliteration',
    icon: Icons.subtitles_off_rounded,
  ),

  /// Automatic multilingual romanization (detects Japanese, Chinese, Korean, Cyrillic, Indic).
  romanized(
    id: 'romanized',
    badgeLabel: 'ROM',
    displayName: 'Auto Romanize',
    description: 'Automatically transliterate non-Latin scripts to Latin phonetic text',
    icon: Icons.translate_rounded,
  ),

  /// Japanese Hepburn Romaji transliteration (Hiragana, Katakana, and common Kanji).
  romaji(
    id: 'romaji',
    badgeLabel: 'ROMAJI',
    displayName: 'Romaji (Japanese)',
    description: 'Transliterate Japanese Kana and Kanji into Hepburn Romaji',
    icon: Icons.language_rounded,
  ),

  /// Mandarin Chinese Pinyin transliteration (Hanzi to Latin pinyin phonetics).
  pinyin(
    id: 'pinyin',
    badgeLabel: 'PINYIN',
    displayName: 'Pinyin (Chinese)',
    description: 'Transliterate Chinese Hanzi characters into Pinyin',
    icon: Icons.translate_rounded,
  ),

  /// Korean Revised Romanization (Hangul syllables to Latin phonetic script).
  hangul(
    id: 'hangul',
    badgeLabel: 'HANGUL',
    displayName: 'Hangul RR (Korean)',
    description: 'Transliterate Korean Hangul into Revised Romanization',
    icon: Icons.short_text_rounded,
  ),

  /// Cyrillic to Latin transliteration (Russian, Ukrainian).
  cyrillic(
    id: 'cyrillic',
    badgeLabel: 'LATIN',
    displayName: 'Cyrillic Latin',
    description: 'Transliterate Ukrainian and Russian Cyrillic into Latin alphabet',
    icon: Icons.font_download_rounded,
  ),

  /// Indic scripts (Devanagari, Gurmukhi) to Latin transliteration.
  indic(
    id: 'indic',
    badgeLabel: 'INDIC',
    displayName: 'Indic Latin',
    description: 'Transliterate Devanagari and Gurmukhi scripts into Latin alphabet',
    icon: Icons.text_fields_rounded,
  );

  final String id;
  final String badgeLabel;
  final String displayName;
  final String description;
  final IconData icon;

  const TransliterationMode({
    required this.id,
    required this.badgeLabel,
    required this.displayName,
    required this.description,
    required this.icon,
  });

  /// Whether this mode keeps original text.
  bool get isOriginal => this == TransliterationMode.original;

  /// Whether this mode actively performs transliteration.
  bool get isRomanized => this != TransliterationMode.original;

  /// Serializes mode to persistent string key.
  String toKey() => id;

  /// Parses mode from key, with safe fallback and legacy boolean support.
  static TransliterationMode fromKey(String? key) {
    if (key == null || key.isEmpty) return TransliterationMode.original;
    final lower = key.trim().toLowerCase();
    if (lower == 'true') return TransliterationMode.romanized;
    if (lower == 'false') return TransliterationMode.original;

    for (final mode in TransliterationMode.values) {
      if (mode.id.toLowerCase() == lower || mode.badgeLabel.toLowerCase() == lower) {
        return mode;
      }
    }
    return TransliterationMode.original;
  }
}

/// Presentation format when transliteration is active.
enum TransliterationDisplayMode {
  /// Replaces the primary lyrics line directly with the transliterated text.
  replace('replace', 'Replace Original'),

  /// Displays the transliterated text as a phonetic ruby/subtext line alongside the original script.
  dualLine('dualLine', 'Dual Line (Ruby)');

  final String id;
  final String displayName;

  const TransliterationDisplayMode(this.id, this.displayName);

  static TransliterationDisplayMode fromKey(String? key) {
    if (key == null || key.isEmpty) return TransliterationDisplayMode.replace;
    final lower = key.trim().toLowerCase();
    for (final mode in TransliterationDisplayMode.values) {
      if (mode.id.toLowerCase() == lower) return mode;
    }
    return TransliterationDisplayMode.replace;
  }
}

/// Immutable state snapshot for lyrics transliteration.
@immutable
class TransliterationState {
  /// Active transliteration mode.
  final TransliterationMode mode;

  /// Last non-original mode selected (used when toggling on).
  final TransliterationMode lastActiveMode;

  /// Display presentation style (replace line vs dual-line ruby).
  final TransliterationDisplayMode displayMode;

  /// Dominant non-Latin script detected in currently playing lyrics (if any).
  final String? detectedScript;

  const TransliterationState({
    this.mode = TransliterationMode.original,
    this.lastActiveMode = TransliterationMode.romanized,
    this.displayMode = TransliterationDisplayMode.replace,
    this.detectedScript,
  });

  /// True if any transliteration mode is active.
  bool get isEnabled => mode != TransliterationMode.original;

  /// True if original script is kept.
  bool get isOriginal => mode == TransliterationMode.original;

  /// True if transliteration is active (alias for [isEnabled]).
  bool get isRomanized => isEnabled;

  /// Badge text representation of the current state.
  String get badgeLabel => mode.badgeLabel;

  TransliterationState copyWith({
    TransliterationMode? mode,
    TransliterationMode? lastActiveMode,
    TransliterationDisplayMode? displayMode,
    String? detectedScript,
    bool clearDetectedScript = false,
  }) {
    return TransliterationState(
      mode: mode ?? this.mode,
      lastActiveMode: lastActiveMode ?? this.lastActiveMode,
      displayMode: displayMode ?? this.displayMode,
      detectedScript:
          clearDetectedScript ? null : (detectedScript ?? this.detectedScript),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransliterationState &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          lastActiveMode == other.lastActiveMode &&
          displayMode == other.displayMode &&
          detectedScript == other.detectedScript;

  @override
  int get hashCode => Object.hash(mode, lastActiveMode, displayMode, detectedScript);

  @override
  String toString() =>
      'TransliterationState(mode: ${mode.id}, lastActiveMode: ${lastActiveMode.id}, displayMode: ${displayMode.id}, detectedScript: $detectedScript)';
}

// ============================================================================
// SharedPreferences Persistence Engine
// ============================================================================

const String kTransliterationModePrefKey = 'softify_lyrics_transliteration_mode';
const String kTransliterationDisplayModePrefKey =
    'softify_lyrics_transliteration_display_mode';
const String kTransliterationLegacyPrefKey = 'lyrics_romanize';

/// Self-contained, durable SharedPreferences engine matching the standard
/// `package:shared_preferences` API interface without requiring external native
/// compilation plugins.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronously accessible cached singleton instance if already resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock values for testing environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
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
      // In-memory fallback if file system access fails
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

  String? getString(String key) {
    final val = _store[key];
    if (val is String) return val;
    if (val != null) return val.toString();
    return null;
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
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

  Future<bool> remove(String key) async {
    _store.remove(key);
    await _persist();
    return true;
  }

  bool containsKey(String key) => _store.containsKey(key);
}

// ============================================================================
// Pure Dart Transliteration Engine & Analysis Helpers
// ============================================================================

/// Pure Dart transliteration engine providing deterministic conversion
/// across Japanese, Chinese, Korean, Cyrillic, and Indic scripts.
class TransliterationEngine {
  const TransliterationEngine._();

  /// Transliterates a given [text] string according to [mode].
  ///
  /// Preserves non-transliterable text (e.g., standard Latin English) untouched.
  static String transliterateText(String text, TransliterationMode mode) {
    if (text.isEmpty || mode == TransliterationMode.original) {
      return text;
    }

    switch (mode) {
      case TransliterationMode.original:
        return text;
      case TransliterationMode.romanized:
        return RomanizationService.romanize(text);
      case TransliterationMode.romaji:
        return RomanizationService.romanizeJapanese(text);
      case TransliterationMode.pinyin:
        return RomanizationService.romanizeChinese(text);
      case TransliterationMode.hangul:
        return RomanizationService.romanizeKorean(text);
      case TransliterationMode.cyrillic:
        return RomanizationService.romanizeCyrillic(text);
      case TransliterationMode.indic:
        return RomanizationService.romanize(text, language: 'Indic');
    }
  }

  /// Transliterates an individual [LyricLine], including word-level timings if present.
  static LyricLine transliterateLine(
    LyricLine line,
    TransliterationMode mode, {
    bool asMain = true,
  }) {
    if (mode == TransliterationMode.original) {
      return line;
    }

    final transliteratedText = transliterateText(line.text, mode);

    List<LyricWord>? transliteratedWords;
    if (line.words != null && line.words!.isNotEmpty) {
      transliteratedWords = line.words!.map((word) {
        return LyricWord(
          timestamp: word.timestamp,
          text: transliterateText(word.text, mode),
          duration: word.duration,
        );
      }).toList();
    }

    return LyricLine(
      timestamp: line.timestamp,
      text: asMain ? transliteratedText : line.text,
      words: asMain ? transliteratedWords : line.words,
      agent: line.agent,
    );
  }

  /// Transliterates an entire [SyncedLyrics] container according to [mode].
  static SyncedLyrics transliterateLyrics(
    SyncedLyrics lyrics,
    TransliterationMode mode, {
    bool asMain = true,
  }) {
    if (mode == TransliterationMode.original) {
      return lyrics;
    }

    final mappedLines = lyrics.lines.map((line) {
      return transliterateLine(line, mode, asMain: asMain);
    }).toList();

    final mappedPlain = lyrics.plainLyrics != null
        ? transliterateText(lyrics.plainLyrics!, mode)
        : null;

    final providerSuffix = mode == TransliterationMode.romanized
        ? '(Romanized)'
        : '(${mode.displayName})';

    return SyncedLyrics(
      trackId: lyrics.trackId,
      lines: mappedLines,
      plainLyrics: mappedPlain,
      rawLrc: lyrics.rawLrc,
      syncType: lyrics.syncType,
      providerName: lyrics.providerName != null
          ? '${lyrics.providerName} $providerSuffix'
          : providerSuffix,
      colors: lyrics.colors,
    );
  }

  /// Automatically identifies the predominant non-Latin script of [text].
  static String? detectScript(String text) {
    if (text.isEmpty) return null;
    return RomanizationService.detectLanguage(text);
  }

  /// Scans [lyrics] lines to detect the primary non-Latin language script.
  static String? detectLyricsScript(SyncedLyrics lyrics) {
    if (lyrics.lines.isEmpty) {
      if (lyrics.plainLyrics != null && lyrics.plainLyrics!.isNotEmpty) {
        return detectScript(lyrics.plainLyrics!);
      }
      return null;
    }

    final scriptCounts = <String, int>{};
    final sampleLimit = lyrics.lines.length < 30 ? lyrics.lines.length : 30;

    for (int i = 0; i < sampleLimit; i++) {
      final lineText = lyrics.lines[i].text.trim();
      if (lineText.isEmpty) continue;
      final script = RomanizationService.detectLanguage(lineText);
      if (script != null) {
        scriptCounts[script] = (scriptCounts[script] ?? 0) + 1;
      }
    }

    if (scriptCounts.isEmpty) return null;

    String? dominantScript;
    int maxCount = 0;
    for (final entry in scriptCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominantScript = entry.key;
      }
    }
    return dominantScript;
  }

  /// Returns recommended modes prioritizing detected script.
  static List<TransliterationMode> getRecommendedModes(String? script) {
    if (script == null) {
      return const [
        TransliterationMode.original,
        TransliterationMode.romanized,
        TransliterationMode.romaji,
        TransliterationMode.pinyin,
        TransliterationMode.hangul,
        TransliterationMode.cyrillic,
        TransliterationMode.indic,
      ];
    }

    switch (script.toLowerCase()) {
      case 'japanese':
        return const [
          TransliterationMode.original,
          TransliterationMode.romaji,
          TransliterationMode.romanized,
        ];
      case 'chinese':
        return const [
          TransliterationMode.original,
          TransliterationMode.pinyin,
          TransliterationMode.romanized,
        ];
      case 'korean':
        return const [
          TransliterationMode.original,
          TransliterationMode.hangul,
          TransliterationMode.romanized,
        ];
      case 'ukrainian':
      case 'russian':
        return const [
          TransliterationMode.original,
          TransliterationMode.cyrillic,
          TransliterationMode.romanized,
        ];
      case 'indic':
        return const [
          TransliterationMode.original,
          TransliterationMode.indic,
          TransliterationMode.romanized,
        ];
      default:
        return const [
          TransliterationMode.original,
          TransliterationMode.romanized,
        ];
    }
  }
}

// ============================================================================
// StateNotifier & Riverpod Providers
// ============================================================================

/// Manages transliteration state and handles persistence to SharedPreferences.
class TransliterationSwitcherNotifier
    extends StateNotifier<TransliterationState> {
  SharedPreferences? _prefs;

  TransliterationSwitcherNotifier({
    SharedPreferences? prefs,
    TransliterationState? initialState,
  })  : _prefs = prefs,
        super(initialState ?? const TransliterationState()) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final modeKey = _prefs?.getString(kTransliterationModePrefKey);
      final displayKey = _prefs?.getString(kTransliterationDisplayModePrefKey);
      final legacyBool = _prefs?.getBool(kTransliterationLegacyPrefKey);

      TransliterationMode loadedMode = state.mode;
      if (modeKey != null && modeKey.isNotEmpty) {
        loadedMode = TransliterationMode.fromKey(modeKey);
      } else if (legacyBool == true) {
        loadedMode = TransliterationMode.romanized;
      }

      final loadedDisplay = displayKey != null
          ? TransliterationDisplayMode.fromKey(displayKey)
          : state.displayMode;

      final lastActive = loadedMode != TransliterationMode.original
          ? loadedMode
          : state.lastActiveMode;

      if (mounted) {
        state = state.copyWith(
          mode: loadedMode,
          lastActiveMode: lastActive,
          displayMode: loadedDisplay,
        );
      }
    } catch (_) {}
  }

  /// Toggles between [TransliterationMode.original] and the user's preferred romanized mode.
  Future<void> toggle() async {
    if (state.mode.isOriginal) {
      // Toggle to last active mode, defaulting to romanized
      final targetMode = state.lastActiveMode.isOriginal
          ? TransliterationMode.romanized
          : state.lastActiveMode;
      await setMode(targetMode);
    } else {
      // Toggle back to original
      await setMode(TransliterationMode.original);
    }
  }

  /// Cycles sequentially through a provided or default list of modes.
  Future<void> cycleMode([List<TransliterationMode>? allowedModes]) async {
    final list = allowedModes ??
        const [
          TransliterationMode.original,
          TransliterationMode.romanized,
          TransliterationMode.romaji,
          TransliterationMode.pinyin,
        ];

    if (list.isEmpty) return;

    final currentIndex = list.indexOf(state.mode);
    final nextIndex = (currentIndex + 1) % list.length;
    await setMode(list[nextIndex]);
  }

  /// Explicitly sets the transliteration mode and persists it to SharedPreferences.
  Future<void> setMode(TransliterationMode mode) async {
    final lastActive =
        mode != TransliterationMode.original ? mode : state.lastActiveMode;

    state = state.copyWith(
      mode: mode,
      lastActiveMode: lastActive,
    );

    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(kTransliterationModePrefKey, mode.toKey());
      await _prefs?.setBool(
        kTransliterationLegacyPrefKey,
        mode != TransliterationMode.original,
      );
    } catch (_) {}
  }

  /// Sets the presentation style (single line replacement vs dual-line ruby).
  Future<void> setDisplayMode(TransliterationDisplayMode displayMode) async {
    state = state.copyWith(displayMode: displayMode);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(
        kTransliterationDisplayModePrefKey,
        displayMode.id,
      );
    } catch (_) {}
  }

  /// Sets detected dominant script for currently focused track/lyrics.
  void setDetectedScript(String? script) {
    state = state.copyWith(
      detectedScript: script,
      clearDetectedScript: script == null,
    );
  }

  /// Scans and analyzes the provided [lyrics] to update [detectedScript].
  void analyzeLyrics(SyncedLyrics lyrics) {
    final script = TransliterationEngine.detectLyricsScript(lyrics);
    setDetectedScript(script);
  }

  /// Resets configuration to default original state.
  Future<void> resetToDefault() async {
    await setMode(TransliterationMode.original);
    await setDisplayMode(TransliterationDisplayMode.replace);
  }
}

// ----------------------------------------------------------------------------
// Global Providers
// ----------------------------------------------------------------------------

/// Global Riverpod provider for lyrics transliteration switcher state.
final transliterationSwitcherProvider = StateNotifierProvider<
    TransliterationSwitcherNotifier, TransliterationState>((ref) {
  return TransliterationSwitcherNotifier();
});

/// Selects only the active [TransliterationMode].
final transliterationModeProvider = Provider<TransliterationMode>((ref) {
  return ref.watch(transliterationSwitcherProvider).mode;
});

/// Selects whether transliteration is actively enabled.
final isTransliterationEnabledProvider = Provider<bool>((ref) {
  return ref.watch(transliterationSwitcherProvider).isEnabled;
});

/// Selects the current display mode (replace vs dualLine).
final transliterationDisplayModeProvider =
    Provider<TransliterationDisplayMode>((ref) {
  return ref.watch(transliterationSwitcherProvider).displayMode;
});

/// Scoped family provider for per-view or per-track isolation if desired.
final scopedTransliterationSwitcherProvider = StateNotifierProvider.family<
    TransliterationSwitcherNotifier, TransliterationState, String>(
  (ref, scopeId) {
    return TransliterationSwitcherNotifier();
  },
);

// ============================================================================
// UI Component: TransliterationToggleChip Widget
// ============================================================================

/// An interactive Material 3 / AppTokens toggle chip widget for switching between
/// Original lyrics and Romanized / Pinyin / Romaji transliterations.
///
/// Features:
/// - Quick tap toggles between Original and Romanized modes.
/// - Long-press opens a selection sheet/dialog to pick specific phonetic systems
///   (Romaji, Pinyin, Hangul RR, Cyrillic, Indic).
/// - Dynamic badge ("ORIG", "ROM", "ROMAJI", "PINYIN", "HANGUL").
/// - Full Material 3 dark-glass and AMOLED styling with haptic feedback.
class TransliterationToggleChip extends ConsumerWidget {
  /// Explicit mode override if not reading directly from provider.
  final TransliterationMode? explicitMode;

  /// Optional tap callback. If null, invokes `toggle()` on notifier.
  final VoidCallback? onTap;

  /// Optional callback invoked when a mode is picked from the modal menu.
  final ValueChanged<TransliterationMode>? onModeSelected;

  /// Custom active accent color override.
  final Color? activeColor;

  /// Custom inactive text/border color.
  final Color? inactiveColor;

  /// Custom background color override.
  final Color? backgroundColor;

  /// Whether long-press opens mode selection menu. Defaults to true.
  final bool showMenuOnLongPress;

  /// Whether to display a compact down chevron next to the badge.
  final bool showDropdownIcon;

  /// Compact styling for tighter toolbars.
  final bool compact;

  /// Custom padding inside the chip.
  final EdgeInsetsGeometry? padding;

  /// Custom font size for the badge label.
  final double? fontSize;

  /// Optional subset of modes to offer in the picker menu.
  final List<TransliterationMode>? allowedModes;

  const TransliterationToggleChip({
    super.key,
    this.explicitMode,
    this.onTap,
    this.onModeSelected,
    this.activeColor,
    this.inactiveColor,
    this.backgroundColor,
    this.showMenuOnLongPress = true,
    this.showDropdownIcon = false,
    this.compact = false,
    this.padding,
    this.fontSize,
    this.allowedModes,
  });

  void _handleTap(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    if (onTap != null) {
      onTap!();
      return;
    }
    ref.read(transliterationSwitcherProvider.notifier).toggle();
  }

  void _showModePicker(BuildContext context, WidgetRef ref, TransliterationState state) {
    HapticFeedback.mediumImpact();
    final tokens = context.tokens;
    final modes = allowedModes ??
        TransliterationEngine.getRecommendedModes(state.detectedScript);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: tokens.surfaceElevated,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.radiusLg),
            ),
            border: Border.all(color: tokens.glassBorder, width: 1.0),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: tokens.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 20,
                        color: activeColor ?? tokens.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lyrics Transliteration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                          fontFamily: AppTheme.fontUi,
                        ),
                      ),
                      if (state.detectedScript != null) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceHighlight,
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                          ),
                          child: Text(
                            state.detectedScript!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: modes.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: tokens.divider),
                    itemBuilder: (_, index) {
                      final itemMode = modes[index];
                      final isSelected = (itemMode == state.mode);
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Icon(
                          itemMode.icon,
                          size: 20,
                          color: isSelected
                              ? (activeColor ?? tokens.accentCyan)
                              : tokens.textSecondary,
                        ),
                        title: Text(
                          itemMode.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (activeColor ?? tokens.accentCyan)
                                : tokens.textPrimary,
                            fontFamily: AppTheme.fontUi,
                          ),
                        ),
                        subtitle: Text(
                          itemMode.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: activeColor ?? tokens.accentCyan,
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceHighlight,
                                  borderRadius:
                                      BorderRadius.circular(tokens.radiusSm),
                                ),
                                child: Text(
                                  itemMode.badgeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(sheetContext);
                          if (onModeSelected != null) {
                            onModeSelected!(itemMode);
                          } else {
                            ref
                                .read(transliterationSwitcherProvider.notifier)
                                .setMode(itemMode);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(transliterationSwitcherProvider);
    final activeMode = explicitMode ?? state.mode;
    final isRomanized = activeMode.isRomanized;

    final effectiveAccent = activeColor ??
        (tokens.isGlass ? tokens.accentCyan : tokens.accent);
    final effectiveInactive = inactiveColor ?? tokens.textSecondary;

    final badgeText = activeMode.badgeLabel;
    final tooltipMessage = isRomanized
        ? '${activeMode.displayName} transliteration active\nTap to show original script, long-press for options'
        : 'Original script\nTap to romanize lyrics, long-press for options';

    return Tooltip(
      message: tooltipMessage,
      child: BouncingScaleButton(
        scaleFactor: 0.93,
        onTap: () => _handleTap(context, ref),
        onLongPress: showMenuOnLongPress
            ? () => _showModePicker(context, ref, state)
            : null,
        child: Semantics(
          button: true,
          label: 'Lyrics Transliteration: ${activeMode.displayName}',
          child: AnimatedContainer(
            duration: tokens.motionQuick,
            padding: padding ??
                EdgeInsets.symmetric(
                  horizontal: compact ? 6.0 : 8.0,
                  vertical: compact ? 2.0 : 3.5,
                ),
            decoration: BoxDecoration(
              color: isRomanized
                  ? effectiveAccent.withValues(alpha: 0.22)
                  : (backgroundColor ?? const Color(0xFF1E2025)),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: isRomanized
                    ? effectiveAccent.withValues(alpha: 0.9)
                    : const Color(0xFF2A2C34),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  Icon(
                    activeMode.icon,
                    size: 13,
                    color: isRomanized ? effectiveAccent : effectiveInactive,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: fontSize ?? (compact ? 11 : 12),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: isRomanized ? effectiveAccent : effectiveInactive,
                    fontFamily: AppTheme.fontUi,
                  ),
                ),
                if (showDropdownIcon) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 14,
                    color: isRomanized ? effectiveAccent : effectiveInactive,
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

// ============================================================================
// Lyrics View Integration Helpers & Builders
// ============================================================================

/// Builder widget that subscribes to [transliterationSwitcherProvider] and provides
/// automatically transliterated [SyncedLyrics] to its builder callback.
class TransliteratedLyricsBuilder extends ConsumerWidget {
  final SyncedLyrics? lyrics;
  final Widget Function(
    BuildContext context,
    SyncedLyrics? transliteratedLyrics,
    TransliterationState state,
  ) builder;

  const TransliteratedLyricsBuilder({
    super.key,
    required this.lyrics,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transliterationSwitcherProvider);
    final rawLyrics = lyrics;

    if (rawLyrics == null || state.isOriginal) {
      return builder(context, rawLyrics, state);
    }

    final transliterated = TransliterationEngine.transliterateLyrics(
      rawLyrics,
      state.mode,
      asMain: state.displayMode == TransliterationDisplayMode.replace,
    );

    return builder(context, transliterated, state);
  }
}

/// A flexible text widget that renders an individual lyric line with either
/// direct replacement or dual-line ruby layout based on [TransliterationDisplayMode].
class TransliteratedLyricLineWidget extends ConsumerWidget {
  final LyricLine line;
  final TextStyle baseStyle;
  final TextStyle? rubyStyle;
  final TextAlign textAlign;
  final bool isCurrent;
  final Color? accentColor;

  const TransliteratedLyricLineWidget({
    super.key,
    required this.line,
    required this.baseStyle,
    this.rubyStyle,
    this.textAlign = TextAlign.center,
    this.isCurrent = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transliterationSwitcherProvider);

    // If original, display standard text
    if (state.isOriginal) {
      return Text(
        line.text,
        style: baseStyle,
        textAlign: textAlign,
      );
    }

    final transliterated = TransliterationEngine.transliterateText(
      line.text,
      state.mode,
    );

    // If replace mode or transliteration is identical to original, render single line
    if (state.displayMode == TransliterationDisplayMode.replace ||
        transliterated == line.text) {
      return Text(
        transliterated,
        style: baseStyle,
        textAlign: textAlign,
      );
    }

    // Dual-line ruby presentation: transliteration above original
    final tokens = context.tokens;
    final effectiveRubyColor = accentColor ??
        (isCurrent ? tokens.accentCyan : tokens.textSecondary);

    final effectiveRubyStyle = (rubyStyle ??
            baseStyle.copyWith(
              fontSize: (baseStyle.fontSize ?? 16) * 0.72,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ))
        .copyWith(color: effectiveRubyColor);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: textAlign == TextAlign.left
          ? CrossAxisAlignment.start
          : textAlign == TextAlign.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.center,
      children: [
        Text(
          transliterated,
          style: effectiveRubyStyle,
          textAlign: textAlign,
        ),
        const SizedBox(height: 2),
        Text(
          line.text,
          style: baseStyle.copyWith(
            color: baseStyle.color?.withValues(alpha: 0.8),
          ),
          textAlign: textAlign,
        ),
      ],
    );
  }
}

// ============================================================================
// Extensions
// ============================================================================

extension TransliterationSyncedLyricsExtension on SyncedLyrics {
  /// Transliterates this [SyncedLyrics] instance using [mode].
  SyncedLyrics withTransliteration(
    TransliterationMode mode, {
    bool asMain = true,
  }) {
    return TransliterationEngine.transliterateLyrics(
      this,
      mode,
      asMain: asMain,
    );
  }
}

extension TransliterationLyricLineExtension on LyricLine {
  /// Transliterates this [LyricLine] instance using [mode].
  LyricLine withTransliteration(
    TransliterationMode mode, {
    bool asMain = true,
  }) {
    return TransliterationEngine.transliterateLine(
      this,
      mode,
      asMain: asMain,
    );
  }
}
