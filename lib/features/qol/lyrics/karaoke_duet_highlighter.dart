// ============================================================================
// Feature 37: Karaoke Duet Multi-Color Highlighting
// Softify Linux Desktop Music Player - Quality of Life Subsystem
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/ports/i_lyrics_provider.dart';
import '../../../presentation/theme/app_theme.dart';

// ============================================================================
// SharedPreferences Persistence Engine (Self-Contained & Zero-Dependency)
// ============================================================================

const String kKaraokeDuetEnabledKey = 'karaoke_duet_highlighting_enabled';
const String kKaraokeDuetPresetKey = 'karaoke_duet_palette_preset';
const String kKaraokeDuetShowBadgesKey = 'karaoke_duet_show_singer_badges';
const String kKaraokeDuetAlignBySingerKey = 'karaoke_duet_align_by_singer';
const String kKaraokeDuetGlowEnabledKey = 'karaoke_duet_glow_effect_enabled';
const String kKaraokeDuetCustomColorsKey = 'karaoke_duet_custom_colors_json';

/// Lightweight, durable SharedPreferences engine matching the standard
/// `package:shared_preferences` interface without requiring external native binaries.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronously accessible instance if already resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock values for testing environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance for clean test suites.
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
      file = _resolveStorageFile();
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

  static File? _resolveStorageFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/shared_preferences.json');
      }
      return File('.softify_shared_preferences.json');
    } catch (_) {
      return null;
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
// Singer Role & Data Models
// ============================================================================

/// Identifies the vocalist role in a duet, ensemble, or backing arrangement.
enum SingerRole {
  /// Primary vocalist / Lead 1 / Male lead / Left-aligned default.
  lead1,

  /// Secondary duet vocalist / Lead 2 / Female lead / Right-aligned.
  lead2,

  /// Ensemble, collective chorus, both, or all singers together / Center-aligned.
  chorus,

  /// Background / backing harmony, ad-libs, or ambient echoes.
  background,

  /// Custom named singer or artist.
  custom;

  /// Default human-readable display label.
  String get defaultDisplayName {
    switch (this) {
      case SingerRole.lead1:
        return 'Lead 1';
      case SingerRole.lead2:
        return 'Lead 2';
      case SingerRole.chorus:
        return 'Chorus';
      case SingerRole.background:
        return 'Background';
      case SingerRole.custom:
        return 'Singer';
    }
  }

  /// Standard semantic icon.
  IconData get defaultIcon {
    switch (this) {
      case SingerRole.lead1:
        return Icons.mic_rounded;
      case SingerRole.lead2:
        return Icons.mic_external_on_rounded;
      case SingerRole.chorus:
        return Icons.groups_rounded;
      case SingerRole.background:
        return Icons.graphic_eq_rounded;
      case SingerRole.custom:
        return Icons.person_rounded;
    }
  }

  /// Default text alignment in duet layout.
  TextAlign get defaultAlignment {
    switch (this) {
      case SingerRole.lead1:
        return TextAlign.left;
      case SingerRole.lead2:
        return TextAlign.right;
      case SingerRole.chorus:
        return TextAlign.center;
      case SingerRole.background:
        return TextAlign.left;
      case SingerRole.custom:
        return TextAlign.left;
    }
  }

  /// Default cross-axis alignment in duet layout.
  CrossAxisAlignment get defaultCrossAxisAlignment {
    switch (this) {
      case SingerRole.lead1:
        return CrossAxisAlignment.start;
      case SingerRole.lead2:
        return CrossAxisAlignment.end;
      case SingerRole.chorus:
        return CrossAxisAlignment.center;
      case SingerRole.background:
        return CrossAxisAlignment.start;
      case SingerRole.custom:
        return CrossAxisAlignment.start;
    }
  }

  /// Default widget alignment in duet layout.
  Alignment get defaultWidgetAlignment {
    switch (this) {
      case SingerRole.lead1:
        return Alignment.centerLeft;
      case SingerRole.lead2:
        return Alignment.centerRight;
      case SingerRole.chorus:
        return Alignment.center;
      case SingerRole.background:
        return Alignment.centerLeft;
      case SingerRole.custom:
        return Alignment.centerLeft;
    }
  }
}

/// Represents a parsed singer entity with role and customized display tag.
@immutable
class DuetSinger {
  final SingerRole role;
  final String name;
  final String? tag;
  final bool isExplicitTag;

  const DuetSinger({
    required this.role,
    required this.name,
    this.tag,
    this.isExplicitTag = true,
  });

  bool get isLead1 => role == SingerRole.lead1;
  bool get isLead2 => role == SingerRole.lead2;
  bool get isChorus => role == SingerRole.chorus;
  bool get isBackground => role == SingerRole.background;
  bool get isCustom => role == SingerRole.custom;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DuetSinger &&
        other.role == role &&
        other.name.toLowerCase() == name.toLowerCase();
  }

  @override
  int get hashCode => Object.hash(role, name.toLowerCase());

  @override
  String toString() => 'DuetSinger(role: $role, name: "$name", tag: "$tag")';
}

/// Represents a parsed duet lyric line with singer assignment, cleaned text,
/// and timing metadata.
@immutable
class ParsedDuetLine {
  final String rawText;
  final String cleanLyrics;
  final DuetSinger singer;
  final Duration timestamp;
  final List<LyricWord>? words;
  final String? originalAgent;

  const ParsedDuetLine({
    required this.rawText,
    required this.cleanLyrics,
    required this.singer,
    this.timestamp = Duration.zero,
    this.words,
    this.originalAgent,
  });

  bool get hasSingerTag => singer.tag != null;
  bool get hasWords => words != null && words!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedDuetLine &&
        other.rawText == rawText &&
        other.cleanLyrics == cleanLyrics &&
        other.singer == singer &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode =>
      Object.hash(rawText, cleanLyrics, singer, timestamp);

  @override
  String toString() =>
      'ParsedDuetLine(singer: ${singer.name}, clean: "$cleanLyrics", time: $timestamp)';
}

/// Represents an individual singer segment within a multi-singer line.
@immutable
class ParsedDuetSegment {
  final DuetSinger singer;
  final String text;

  const ParsedDuetSegment({
    required this.singer,
    required this.text,
  });

  @override
  String toString() => 'ParsedDuetSegment(${singer.name}: "$text")';
}

// ============================================================================
// Color Palettes & Custom Color Configurations
// ============================================================================

/// Curated color themes for duet highlighting.
enum DuetColorPreset {
  /// Spotify Emerald Green (Lead 1) & Electric Rose (Lead 2).
  spotifyModern('Spotify Modern'),

  /// Cyberpunk Neon Cyan (Lead 1) & Hot Magenta (Lead 2).
  neonCyberpunk('Neon Cyberpunk'),

  /// Warm Amber Sunset (Lead 1) & Deep Dusk Rose (Lead 2).
  sunsetDuet('Sunset Duet'),

  /// Soft Mint (Lead 1) & Pastel Blush (Lead 2).
  pastelDream('Pastel Dream'),

  /// Pure Lime Green (Lead 1) & Vivid Crimson Red (Lead 2) for accessibility.
  highContrast('High Contrast');

  final String label;
  const DuetColorPreset(this.label);
}

/// Highly configurable multi-color assignment mapping singer roles and
/// individual custom singer names to dedicated colors, inactive opacities,
/// and glowing highlights.
@immutable
class DuetColorConfig {
  final Color lead1Color;
  final Color lead2Color;
  final Color chorusColor;
  final Color backgroundColor;
  final Map<String, Color> customSingerColors;
  final double inactiveOpacity;
  final double glowOpacity;
  final double glowBlurRadius;

  const DuetColorConfig({
    required this.lead1Color,
    required this.lead2Color,
    required this.chorusColor,
    required this.backgroundColor,
    this.customSingerColors = const {},
    this.inactiveOpacity = 0.38,
    this.glowOpacity = 0.55,
    this.glowBlurRadius = 12.0,
  });

  /// Factory constructor resolving predefined palette presets.
  factory DuetColorConfig.fromPreset(DuetColorPreset preset) {
    switch (preset) {
      case DuetColorPreset.spotifyModern:
        return const DuetColorConfig(
          lead1Color: Color(0xFF1DB954), // Spotify Emerald Green
          lead2Color: Color(0xFFFF4081), // Vibrant Rose Pink
          chorusColor: Color(0xFFFFD700), // Royal Gold
          backgroundColor: Color(0xFF00B0FF), // Sky Cyan
        );
      case DuetColorPreset.neonCyberpunk:
        return const DuetColorConfig(
          lead1Color: Color(0xFF00F0FF), // Electric Neon Cyan
          lead2Color: Color(0xFFFF007F), // Neon Magenta
          chorusColor: Color(0xFFFFE600), // Laser Yellow
          backgroundColor: Color(0xFF9D4EDD), // UV Violet
        );
      case DuetColorPreset.sunsetDuet:
        return const DuetColorConfig(
          lead1Color: Color(0xFFFF6D00), // Warm Solar Amber
          lead2Color: Color(0xFFE91E63), // Dusk Twilight Rose
          chorusColor: Color(0xFFFFB300), // Golden Sunset
          backgroundColor: Color(0xFF26A69A), // Ocean Teal
        );
      case DuetColorPreset.pastelDream:
        return const DuetColorConfig(
          lead1Color: Color(0xFF80CBC4), // Soft Spearmint
          lead2Color: Color(0xFFF48FB1), // Powder Blush Pink
          chorusColor: Color(0xFFFFE082), // Buttercup Cream
          backgroundColor: Color(0xFFB39DDB), // Misty Lavender
        );
      case DuetColorPreset.highContrast:
        return const DuetColorConfig(
          lead1Color: Color(0xFF00E676), // Vivid Emerald Green
          lead2Color: Color(0xFFFF1744), // High Contrast Crimson
          chorusColor: Color(0xFFFFFF00), // Pure Yellow
          backgroundColor: Color(0xFF00E5FF), // Pure Cyan
        );
    }
  }

  /// Resolves the primary active highlight color for a given singer.
  Color getColor(DuetSinger singer) {
    final lowerName = singer.name.trim().toLowerCase();
    for (final entry in customSingerColors.entries) {
      if (entry.key.trim().toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return getColorForRole(singer.role);
  }

  /// Resolves the primary color mapped to a [SingerRole].
  Color getColorForRole(SingerRole role) {
    switch (role) {
      case SingerRole.lead1:
        return lead1Color;
      case SingerRole.lead2:
        return lead2Color;
      case SingerRole.chorus:
        return chorusColor;
      case SingerRole.background:
        return backgroundColor;
      case SingerRole.custom:
        return lead2Color;
    }
  }

  /// Resolves the dimmed inactive color for un-sung lines.
  Color getInactiveColor(DuetSinger singer, {Color? fallbackText}) {
    final primary = getColor(singer);
    return primary.withOpacity(inactiveOpacity);
  }

  /// Resolves the glowing text shadow for the active karaoke singer.
  List<Shadow> getGlowShadows(DuetSinger singer) {
    final primary = getColor(singer);
    return [
      Shadow(
        color: primary.withOpacity(glowOpacity),
        blurRadius: glowBlurRadius,
      ),
      Shadow(
        color: primary.withOpacity(glowOpacity * 0.5),
        blurRadius: glowBlurRadius * 1.8,
      ),
    ];
  }

  /// Resolves badge container background tint.
  Color getBadgeBackgroundColor(DuetSinger singer, {double opacity = 0.14}) {
    return getColor(singer).withOpacity(opacity);
  }

  /// Resolves badge border stroke color.
  Color getBadgeBorderColor(DuetSinger singer, {double opacity = 0.38}) {
    return getColor(singer).withOpacity(opacity);
  }

  /// Produces a copy with a specific role color modified.
  DuetColorConfig withRoleColor(SingerRole role, Color color) {
    switch (role) {
      case SingerRole.lead1:
        return copyWith(lead1Color: color);
      case SingerRole.lead2:
        return copyWith(lead2Color: color);
      case SingerRole.chorus:
        return copyWith(chorusColor: color);
      case SingerRole.background:
        return copyWith(backgroundColor: color);
      case SingerRole.custom:
        return copyWith(lead2Color: color);
    }
  }

  /// Produces a copy with a customized singer color assigned by artist name.
  DuetColorConfig withCustomSingerColor(String singerName, Color color) {
    final updated = Map<String, Color>.from(customSingerColors);
    updated[singerName.trim()] = color;
    return copyWith(customSingerColors: updated);
  }

  DuetColorConfig copyWith({
    Color? lead1Color,
    Color? lead2Color,
    Color? chorusColor,
    Color? backgroundColor,
    Map<String, Color>? customSingerColors,
    double? inactiveOpacity,
    double? glowOpacity,
    double? glowBlurRadius,
  }) {
    return DuetColorConfig(
      lead1Color: lead1Color ?? this.lead1Color,
      lead2Color: lead2Color ?? this.lead2Color,
      chorusColor: chorusColor ?? this.chorusColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      customSingerColors: customSingerColors ?? this.customSingerColors,
      inactiveOpacity: inactiveOpacity ?? this.inactiveOpacity,
      glowOpacity: glowOpacity ?? this.glowOpacity,
      glowBlurRadius: glowBlurRadius ?? this.glowBlurRadius,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lead1': lead1Color.value,
      'lead2': lead2Color.value,
      'chorus': chorusColor.value,
      'background': backgroundColor.value,
      'customSingers': customSingerColors.map(
        (key, value) => MapEntry(key, value.value),
      ),
      'inactiveOpacity': inactiveOpacity,
      'glowOpacity': glowOpacity,
      'glowBlurRadius': glowBlurRadius,
    };
  }

  DuetColorConfig applyCustomColorsJson(Map<String, dynamic> json) {
    Color? parseColor(dynamic val) =>
        val is int ? Color(val) : (val is num ? Color(val.toInt()) : null);

    final l1 = parseColor(json['lead1']);
    final l2 = parseColor(json['lead2']);
    final ch = parseColor(json['chorus']);
    final bg = parseColor(json['background']);

    final customMap = <String, Color>{};
    if (json['customSingers'] is Map) {
      (json['customSingers'] as Map).forEach((k, v) {
        final parsed = parseColor(v);
        if (parsed != null) {
          customMap[k.toString()] = parsed;
        }
      });
    }

    final inOp = (json['inactiveOpacity'] as num?)?.toDouble();
    final glOp = (json['glowOpacity'] as num?)?.toDouble();
    final glBr = (json['glowBlurRadius'] as num?)?.toDouble();

    return copyWith(
      lead1Color: l1,
      lead2Color: l2,
      chorusColor: ch,
      backgroundColor: bg,
      customSingerColors: customMap.isNotEmpty ? customMap : null,
      inactiveOpacity: inOp,
      glowOpacity: glOp,
      glowBlurRadius: glBr,
    );
  }
}

// ============================================================================
// Karaoke Duet Settings
// ============================================================================

/// Overall configuration state for Feature 37 Karaoke Duet Highlighting.
@immutable
class KaraokeDuetSettings {
  final bool enabled;
  final DuetColorPreset preset;
  final DuetColorConfig colors;
  final bool showSingerBadges;
  final bool alignBySinger;
  final bool enableGlowEffect;
  final double activeScale;

  const KaraokeDuetSettings({
    this.enabled = true,
    this.preset = DuetColorPreset.spotifyModern,
    required this.colors,
    this.showSingerBadges = true,
    this.alignBySinger = true,
    this.enableGlowEffect = true,
    this.activeScale = 1.05,
  });

  factory KaraokeDuetSettings.defaultSettings() {
    return KaraokeDuetSettings(
      enabled: true,
      preset: DuetColorPreset.spotifyModern,
      colors: DuetColorConfig.fromPreset(DuetColorPreset.spotifyModern),
      showSingerBadges: true,
      alignBySinger: true,
      enableGlowEffect: true,
      activeScale: 1.05,
    );
  }

  KaraokeDuetSettings copyWith({
    bool? enabled,
    DuetColorPreset? preset,
    DuetColorConfig? colors,
    bool? showSingerBadges,
    bool? alignBySinger,
    bool? enableGlowEffect,
    double? activeScale,
  }) {
    return KaraokeDuetSettings(
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
      colors: colors ?? this.colors,
      showSingerBadges: showSingerBadges ?? this.showSingerBadges,
      alignBySinger: alignBySinger ?? this.alignBySinger,
      enableGlowEffect: enableGlowEffect ?? this.enableGlowEffect,
      activeScale: activeScale ?? this.activeScale,
    );
  }
}

// ============================================================================
// Karaoke Duet Parser
// ============================================================================

/// Robust, pure Dart parser detecting singer tag prefixes in synchronized LRC,
/// plain lyrics, and [LyricLine] structures.
class KaraokeDuetParser {
  const KaraokeDuetParser();

  // Pattern matching LRC timestamps at the beginning of a line: [01:23.45]
  static final RegExp _lrcTimestampPattern = RegExp(
    r'^\s*\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*',
  );

  // Pattern matching bracket prefixes: [Lead 1], [Chorus], [Singer 2], [Taylor Swift]
  static final RegExp _bracketPattern = RegExp(
    r'^\s*\[([a-zA-Z0-9_\s\.\-:]+)\]\s*',
  );

  // Pattern matching curly brace tags: {Lead 1}, {agent:v1}, {v2}
  static final RegExp _curlyPattern = RegExp(
    r'^\s*\{([a-zA-Z0-9_\s\.\-:]+)\}\s*',
  );

  // Pattern matching parentheses prefixes: (Lead 1), (Chorus), (Background)
  static final RegExp _parenPattern = RegExp(
    r'^\s*\(([a-zA-Z0-9_\s\.\-:]+)\)\s*',
  );

  // Pattern matching colon prefixes: Lead 1: lyrics, Singer 2: lyrics, Chorus: lyrics
  static final RegExp _colonPattern = RegExp(
    r'^\s*([A-Za-z][A-Za-z0-9_\s]{1,24})\s*:\s+',
  );

  /// Parses a generic line representation (either [LyricLine] or [String]).
  ParsedDuetLine parseLine(
    dynamic lineOrText, {
    Duration? timestamp,
    List<LyricWord>? words,
    String? agent,
  }) {
    if (lineOrText is ParsedDuetLine) {
      return lineOrText;
    }
    if (lineOrText is LyricLine) {
      return parseLyricLine(lineOrText);
    }
    return parseText(
      lineOrText?.toString() ?? '',
      timestamp: timestamp,
      words: words,
      agent: agent,
    );
  }

  /// Parses an official Softify [LyricLine] entity.
  ParsedDuetLine parseLyricLine(LyricLine line) {
    return parseText(
      line.text,
      timestamp: line.timestamp,
      words: line.words,
      agent: line.agent,
    );
  }

  /// Parses raw lyrics text, extracting singer tags and sanitizing lyrics.
  ParsedDuetLine parseText(
    String rawText, {
    Duration? timestamp,
    List<LyricWord>? words,
    String? agent,
  }) {
    var workingText = rawText;
    var parsedTimestamp = timestamp ?? Duration.zero;

    // 1. Detect and consume any leading LRC timestamp [mm:ss.xx]
    final timeMatch = _lrcTimestampPattern.firstMatch(workingText);
    if (timeMatch != null) {
      if (timestamp == null) {
        final minutes = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        final millis = int.tryParse(timeMatch.group(3) ?? '0') ?? 0;
        parsedTimestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
      }
      workingText = workingText.substring(timeMatch.end);
    }

    // 2. Check for tag prefixes in text
    String? detectedTag;
    String? tagContent;
    String? cleanLyrics;

    // Check [Bracket Tag]
    final bracketMatch = _bracketPattern.firstMatch(workingText);
    if (bracketMatch != null) {
      detectedTag = bracketMatch.group(0);
      tagContent = bracketMatch.group(1);
      cleanLyrics = workingText.substring(bracketMatch.end).trim();
    }

    // Check {Curly Tag}
    if (detectedTag == null) {
      final curlyMatch = _curlyPattern.firstMatch(workingText);
      if (curlyMatch != null) {
        detectedTag = curlyMatch.group(0);
        tagContent = curlyMatch.group(1);
        cleanLyrics = workingText.substring(curlyMatch.end).trim();
      }
    }

    // Check (Parentheses Tag)
    if (detectedTag == null) {
      final parenMatch = _parenPattern.firstMatch(workingText);
      if (parenMatch != null) {
        final content = parenMatch.group(1)?.trim() ?? '';
        // Only classify as singer tag if matching known role or name-like
        if (_isLikelySingerContent(content)) {
          detectedTag = parenMatch.group(0);
          tagContent = content;
          cleanLyrics = workingText.substring(parenMatch.end).trim();
        }
      }
    }

    // Check Colon Prefix: "Lead 1: ..."
    if (detectedTag == null) {
      final colonMatch = _colonPattern.firstMatch(workingText);
      if (colonMatch != null) {
        final prefix = colonMatch.group(1)?.trim() ?? '';
        if (_isLikelySingerContent(prefix)) {
          detectedTag = colonMatch.group(0);
          tagContent = prefix;
          cleanLyrics = workingText.substring(colonMatch.end).trim();
        }
      }
    }

    // 3. Resolve DuetSinger from tag or fallback to agent metadata
    DuetSinger resolvedSinger;

    if (tagContent != null && tagContent.isNotEmpty) {
      final role = _roleFromTagString(tagContent);
      final displayName = _formatDisplayName(role, tagContent);
      resolvedSinger = DuetSinger(
        role: role,
        name: displayName,
        tag: detectedTag?.trim(),
        isExplicitTag: true,
      );
    } else if (agent != null && agent.trim().isNotEmpty) {
      final role = _roleFromAgentMetadata(agent);
      final displayName = _formatDisplayName(role, agent);
      resolvedSinger = DuetSinger(
        role: role,
        name: displayName,
        tag: null,
        isExplicitTag: true,
      );
      cleanLyrics = workingText.trim();
    } else {
      // Default fallback for plain lyrics
      resolvedSinger = const DuetSinger(
        role: SingerRole.lead1,
        name: 'Lead 1',
        tag: null,
        isExplicitTag: false,
      );
      cleanLyrics = workingText.trim();
    }

    // 4. Sanitize syllable words if tag prefix was stripped
    final sanitizedWords = (detectedTag != null && words != null)
        ? _sanitizeWords(words, detectedTag)
        : words;

    return ParsedDuetLine(
      rawText: rawText,
      cleanLyrics: cleanLyrics ?? workingText.trim(),
      singer: resolvedSinger,
      timestamp: parsedTimestamp,
      words: sanitizedWords,
      originalAgent: agent,
    );
  }

  /// Parses a batch of lines from lyrics or LRC file content.
  List<ParsedDuetLine> parseLyrics(List<LyricLine> lines) {
    return lines.map(parseLyricLine).toList();
  }

  /// Parses plain string lyrics line-by-line.
  List<ParsedDuetLine> parseTextLines(String text) {
    final lines = text.split('\n');
    return lines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => parseText(l))
        .toList();
  }

  /// Parses inline singer switches within a single line.
  /// E.g. "[Lead 1] I want it that way [Lead 2] Tell me why [Chorus] Ain't nothin'"
  List<ParsedDuetSegment> parseSegments(String text) {
    final regex = RegExp(r'\[([a-zA-Z0-9_\s\.\-:]+)\]');
    final matches = regex.allMatches(text).toList();
    if (matches.isEmpty) {
      final parsed = parseText(text);
      return [ParsedDuetSegment(singer: parsed.singer, text: parsed.cleanLyrics)];
    }

    final segments = <ParsedDuetSegment>[];
    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];
      final tagContent = m.group(1) ?? '';
      final role = _roleFromTagString(tagContent);
      final singer = DuetSinger(
        role: role,
        name: _formatDisplayName(role, tagContent),
        tag: m.group(0),
        isExplicitTag: true,
      );

      final startIndex = m.end;
      final endIndex =
          (i + 1 < matches.length) ? matches[i + 1].start : text.length;
      final segmentText = text.substring(startIndex, endIndex).trim();

      if (segmentText.isNotEmpty) {
        segments.add(ParsedDuetSegment(singer: singer, text: segmentText));
      }
    }
    return segments;
  }

  // --------------------------------------------------------------------------
  // Tag Role Resolution Helpers
  // --------------------------------------------------------------------------

  static bool _isLikelySingerContent(String content) {
    final lower = content.trim().toLowerCase();
    // Exclude URLs and common LRC metadata tags
    if (lower.startsWith('http') ||
        lower.startsWith('ar:') ||
        lower.startsWith('ti:') ||
        lower.startsWith('al:') ||
        lower.startsWith('by:') ||
        lower.startsWith('offset:')) {
      return false;
    }
    // Match known roles or any reasonable name string (2-25 characters)
    return lower.length >= 2 && lower.length <= 25;
  }

  static SingerRole _roleFromTagString(String rawTag) {
    var tag = rawTag.trim().toLowerCase();
    if (tag.startsWith('agent:')) {
      tag = tag.substring(6).trim();
    }

    // Lead 1 Detection
    if (tag == 'lead 1' ||
        tag == 'lead1' ||
        tag == 'singer 1' ||
        tag == 'singer1' ||
        tag == 'vocal 1' ||
        tag == 'vocals 1' ||
        tag == 'v1' ||
        tag == 'male' ||
        tag == 'boy' ||
        tag == 'part 1' ||
        tag == 'left') {
      return SingerRole.lead1;
    }

    // Lead 2 Detection
    if (tag == 'lead 2' ||
        tag == 'lead2' ||
        tag == 'singer 2' ||
        tag == 'singer2' ||
        tag == 'vocal 2' ||
        tag == 'vocals 2' ||
        tag == 'v2' ||
        tag == 'female' ||
        tag == 'girl' ||
        tag == 'part 2' ||
        tag == 'right') {
      return SingerRole.lead2;
    }

    // Chorus / Ensemble / Both Detection
    if (tag == 'chorus' ||
        tag == 'all' ||
        tag == 'both' ||
        tag == 'together' ||
        tag == 'duet' ||
        tag == 'ensemble' ||
        tag == 'group' ||
        tag == 'v1000' ||
        tag == 'everyone') {
      return SingerRole.chorus;
    }

    // Background / Backing / Ad-Lib Detection
    if (tag == 'background' ||
        tag == 'backing' ||
        tag == 'bg' ||
        tag == 'ad-lib' ||
        tag == 'adlib' ||
        tag == 'ad lib' ||
        tag == 'harmony' ||
        tag == 'echo' ||
        tag == 'whisper') {
      return SingerRole.background;
    }

    return SingerRole.custom;
  }

  static SingerRole _roleFromAgentMetadata(String agent) {
    final lower = agent.trim().toLowerCase();
    if (lower == 'v1' || lower == 'lead1' || lower == 'lead 1') {
      return SingerRole.lead1;
    }
    if (lower == 'v2' || lower == 'lead2' || lower == 'lead 2') {
      return SingerRole.lead2;
    }
    if (lower == 'v1000' ||
        lower == 'chorus' ||
        lower == 'all' ||
        lower == 'both' ||
        lower == 'together') {
      return SingerRole.chorus;
    }
    if (lower == 'bg' || lower == 'background' || lower == 'backing') {
      return SingerRole.background;
    }
    return SingerRole.custom;
  }

  static String _formatDisplayName(SingerRole role, String rawTag) {
    var clean = rawTag.trim();
    if (clean.toLowerCase().startsWith('agent:')) {
      clean = clean.substring(6).trim();
    }
    switch (role) {
      case SingerRole.lead1:
        if (clean.toLowerCase().contains('male')) return 'Male';
        if (clean.toLowerCase().contains('singer 1')) return 'Singer 1';
        return 'Lead 1';
      case SingerRole.lead2:
        if (clean.toLowerCase().contains('female')) return 'Female';
        if (clean.toLowerCase().contains('singer 2')) return 'Singer 2';
        return 'Lead 2';
      case SingerRole.chorus:
        if (clean.toLowerCase() == 'both') return 'Both';
        if (clean.toLowerCase() == 'all') return 'All';
        if (clean.toLowerCase() == 'together') return 'Together';
        return 'Chorus';
      case SingerRole.background:
        if (clean.toLowerCase().contains('backing')) return 'Backing';
        if (clean.toLowerCase().contains('ad-lib') ||
            clean.toLowerCase().contains('adlib')) {
          return 'Ad-lib';
        }
        return 'Background';
      case SingerRole.custom:
        // Capitalize words for artist names
        return clean
            .split(' ')
            .map((w) => w.isNotEmpty
                ? '${w[0].toUpperCase()}${w.substring(1)}'
                : '')
            .join(' ');
    }
  }

  static List<LyricWord>? _sanitizeWords(
    List<LyricWord> words,
    String rawTag,
  ) {
    if (words.isEmpty) return words;
    final cleaned = <LyricWord>[];
    var remainingPrefix = rawTag.trim();

    for (final word in words) {
      if (remainingPrefix.isEmpty) {
        cleaned.add(word);
        continue;
      }
      final wordText = word.text.trim();
      if (remainingPrefix.startsWith(wordText)) {
        remainingPrefix = remainingPrefix.substring(wordText.length).trim();
        continue;
      }
      if (word.text.startsWith(remainingPrefix)) {
        final newText = word.text.substring(remainingPrefix.length).trim();
        remainingPrefix = '';
        if (newText.isNotEmpty) {
          cleaned.add(LyricWord(
            timestamp: word.timestamp,
            text: newText,
            duration: word.duration,
          ));
        }
        continue;
      }
      // Strip any residual bracket tags
      final stripped = word.text
          .replaceAll(RegExp(r'^[\[\{\(].*?[\]\}\)]\s*'), '')
          .trim();
      if (stripped.isNotEmpty) {
        cleaned.add(LyricWord(
          timestamp: word.timestamp,
          text: stripped,
          duration: word.duration,
        ));
      }
      remainingPrefix = '';
    }
    return cleaned.isEmpty ? words : cleaned;
  }
}

// ============================================================================
// Riverpod State Management & Notifiers
// ============================================================================

/// Manages reactive configuration for Feature 37 Karaoke Duet Highlighting.
class KaraokeDuetSettingsNotifier extends StateNotifier<KaraokeDuetSettings> {
  SharedPreferences? _prefs;

  KaraokeDuetSettingsNotifier({
    SharedPreferences? prefs,
    KaraokeDuetSettings? initialSettings,
  })  : _prefs = prefs,
        super(initialSettings ?? KaraokeDuetSettings.defaultSettings()) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final p = _prefs!;

      var current = state;

      if (p.containsKey(kKaraokeDuetEnabledKey)) {
        final enabled = p.getBool(kKaraokeDuetEnabledKey);
        if (enabled != null) {
          current = current.copyWith(enabled: enabled);
        }
      }

      if (p.containsKey(kKaraokeDuetPresetKey)) {
        final presetStr = p.getString(kKaraokeDuetPresetKey);
        final preset = DuetColorPreset.values.firstWhere(
          (e) => e.name == presetStr,
          orElse: () => DuetColorPreset.spotifyModern,
        );
        current = current.copyWith(
          preset: preset,
          colors: DuetColorConfig.fromPreset(preset),
        );
      }

      if (p.containsKey(kKaraokeDuetShowBadgesKey)) {
        final badges = p.getBool(kKaraokeDuetShowBadgesKey);
        if (badges != null) {
          current = current.copyWith(showSingerBadges: badges);
        }
      }

      if (p.containsKey(kKaraokeDuetAlignBySingerKey)) {
        final align = p.getBool(kKaraokeDuetAlignBySingerKey);
        if (align != null) {
          current = current.copyWith(alignBySinger: align);
        }
      }

      if (p.containsKey(kKaraokeDuetGlowEnabledKey)) {
        final glow = p.getBool(kKaraokeDuetGlowEnabledKey);
        if (glow != null) {
          current = current.copyWith(enableGlowEffect: glow);
        }
      }

      if (p.containsKey(kKaraokeDuetCustomColorsKey)) {
        final rawJson = p.getString(kKaraokeDuetCustomColorsKey);
        if (rawJson != null && rawJson.trim().isNotEmpty) {
          final decoded = jsonDecode(rawJson);
          if (decoded is Map<String, dynamic>) {
            current = current.copyWith(
              colors: current.colors.applyCustomColorsJson(decoded),
            );
          }
        }
      }

      state = current;
    } catch (_) {
      // In-memory fallback
    }
  }

  Future<void> _persistSettings() async {
    try {
      final p = _prefs ?? await SharedPreferences.getInstance();
      _prefs = p;
      await p.setBool(kKaraokeDuetEnabledKey, state.enabled);
      await p.setString(kKaraokeDuetPresetKey, state.preset.name);
      await p.setBool(kKaraokeDuetShowBadgesKey, state.showSingerBadges);
      await p.setBool(kKaraokeDuetAlignBySingerKey, state.alignBySinger);
      await p.setBool(kKaraokeDuetGlowEnabledKey, state.enableGlowEffect);
      await p.setString(
        kKaraokeDuetCustomColorsKey,
        jsonEncode(state.colors.toJson()),
      );
    } catch (_) {}
  }

  Future<void> toggleEnabled() async {
    state = state.copyWith(enabled: !state.enabled);
    await _persistSettings();
  }

  Future<void> setEnabled(bool enabled) async {
    if (state.enabled == enabled) return;
    state = state.copyWith(enabled: enabled);
    await _persistSettings();
  }

  Future<void> setPreset(DuetColorPreset preset) async {
    final baseConfig = DuetColorConfig.fromPreset(preset);
    final updatedColors = baseConfig.copyWith(
      customSingerColors: state.colors.customSingerColors,
    );
    state = state.copyWith(preset: preset, colors: updatedColors);
    await _persistSettings();
  }

  Future<void> setSingerColor(SingerRole role, Color color) async {
    final updatedColors = state.colors.withRoleColor(role, color);
    state = state.copyWith(colors: updatedColors);
    await _persistSettings();
  }

  Future<void> setCustomSingerColor(String singerName, Color color) async {
    final updatedColors = state.colors.withCustomSingerColor(singerName, color);
    state = state.copyWith(colors: updatedColors);
    await _persistSettings();
  }

  Future<void> setShowSingerBadges(bool show) async {
    if (state.showSingerBadges == show) return;
    state = state.copyWith(showSingerBadges: show);
    await _persistSettings();
  }

  Future<void> toggleSingerBadges() async {
    state = state.copyWith(showSingerBadges: !state.showSingerBadges);
    await _persistSettings();
  }

  Future<void> setAlignBySinger(bool align) async {
    if (state.alignBySinger == align) return;
    state = state.copyWith(alignBySinger: align);
    await _persistSettings();
  }

  Future<void> toggleAlignBySinger() async {
    state = state.copyWith(alignBySinger: !state.alignBySinger);
    await _persistSettings();
  }

  Future<void> setGlowEffect(bool enable) async {
    if (state.enableGlowEffect == enable) return;
    state = state.copyWith(enableGlowEffect: enable);
    await _persistSettings();
  }

  Future<void> toggleGlowEffect() async {
    state = state.copyWith(enableGlowEffect: !state.enableGlowEffect);
    await _persistSettings();
  }

  Future<void> setActiveScale(double scale) async {
    state = state.copyWith(activeScale: scale);
    await _persistSettings();
  }

  Future<void> resetToDefaults() async {
    state = KaraokeDuetSettings.defaultSettings();
    await _persistSettings();
  }
}

/// Provider for Feature 37 Karaoke Duet Settings.
final karaokeDuetSettingsProvider =
    StateNotifierProvider<KaraokeDuetSettingsNotifier, KaraokeDuetSettings>(
  (ref) => KaraokeDuetSettingsNotifier(),
);

/// Provider exposing the singleton parser instance.
final karaokeDuetParserProvider = Provider<KaraokeDuetParser>((ref) {
  return const KaraokeDuetParser();
});

/// High-level helper bundle combining active settings and parser.
class KaraokeDuetHighlighter {
  final KaraokeDuetSettings settings;
  final KaraokeDuetParser parser;

  const KaraokeDuetHighlighter({
    required this.settings,
    required this.parser,
  });

  Color getColor(DuetSinger singer) => settings.colors.getColor(singer);

  Color getInactiveColor(DuetSinger singer) =>
      settings.colors.getInactiveColor(singer);

  List<Shadow>? getGlowShadows(DuetSinger singer) =>
      settings.enableGlowEffect ? settings.colors.getGlowShadows(singer) : null;
}

final karaokeDuetHighlighterProvider = Provider<KaraokeDuetHighlighter>((ref) {
  final settings = ref.watch(karaokeDuetSettingsProvider);
  final parser = ref.watch(karaokeDuetParserProvider);
  return KaraokeDuetHighlighter(settings: settings, parser: parser);
});

// ============================================================================
// Karaoke Duet UI Components
// ============================================================================

/// Custom clipper for continuous horizontal karaoke progress wipe.
class _HorizontalProgressClipper extends CustomClipper<Rect> {
  final double progress;
  final bool isRtl;

  const _HorizontalProgressClipper(this.progress, {this.isRtl = false});

  @override
  Rect getClip(Size size) {
    final width = size.width * progress.clamp(0.0, 1.0);
    if (isRtl) {
      return Rect.fromLTRB(size.width - width, 0, size.width, size.height);
    }
    return Rect.fromLTWH(0, 0, width, size.height);
  }

  @override
  bool shouldReclip(_HorizontalProgressClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.isRtl != isRtl;
}

/// Elegant badge pill displaying the vocalist name, icon, and role color.
class KaraokeDuetBadge extends StatelessWidget {
  final DuetSinger singer;
  final Color? color;
  final bool isCompact;
  final VoidCallback? onTap;

  const KaraokeDuetBadge({
    super.key,
    required this.singer,
    this.color,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (singer.role == SingerRole.lead2
            ? const Color(0xFFFF4081)
            : const Color(0xFF1DB954));

    final badgeWidget = Container(
      key: Key('karaoke_duet_badge_${singer.name}'),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8.0 : 12.0,
        vertical: isCompact ? 2.5 : 4.5,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: effectiveColor.withOpacity(0.38),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            singer.role.defaultIcon,
            size: isCompact ? 12.0 : 15.0,
            color: effectiveColor,
          ),
          const SizedBox(width: 4.5),
          Text(
            singer.name,
            style: TextStyle(
              color: effectiveColor,
              fontSize: isCompact ? 11.0 : 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: badgeWidget,
      );
    }

    return badgeWidget;
  }
}

/// Primary Material 3 widget rendering a duet karaoke lyric line with
/// vocalist-specific color highlights, badge, dynamic alignment, and
/// smooth continuous or syllable-synced wipe animations.
class KaraokeDuetLineView extends ConsumerWidget {
  /// Lyric source: accepts [ParsedDuetLine], [LyricLine], or raw [String].
  final dynamic line;

  /// Whether this lyric line is the currently active playing line.
  final bool isActive;

  /// Karaoke wipe progress (0.0 to 1.0) for the active line.
  final double progress;

  /// Current audio position for syllable-level word highlighting.
  final Duration? currentPosition;

  /// Callback when user taps the line (e.g. seek to line timestamp).
  final VoidCallback? onTap;

  /// Callback on line long press.
  final VoidCallback? onLongPress;

  /// Base font size for lyric text.
  final double fontSize;

  /// Line height multiplier.
  final double lineHeight;

  /// Text font weight override.
  final FontWeight? fontWeight;

  /// Text alignment override. If null, automatically resolves from duet role.
  final TextAlign? textAlign;

  /// Override to force singer badge visibility.
  final bool? showBadge;

  /// Override to enable or disable singer alignment.
  final bool? alignBySinger;

  /// Override for glowing text shadow.
  final bool? enableGlow;

  /// Padding around the line item.
  final EdgeInsetsGeometry padding;

  /// Optional custom color config override for localized previewing.
  final DuetColorConfig? colorConfigOverride;

  const KaraokeDuetLineView({
    super.key,
    required this.line,
    this.isActive = false,
    this.progress = 0.0,
    this.currentPosition,
    this.onTap,
    this.onLongPress,
    this.fontSize = 22.0,
    this.lineHeight = 1.35,
    this.fontWeight,
    this.textAlign,
    this.showBadge,
    this.alignBySinger,
    this.enableGlow,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    this.colorConfigOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(karaokeDuetSettingsProvider);
    final parser = ref.watch(karaokeDuetParserProvider);

    // Resolve ParsedDuetLine
    final ParsedDuetLine parsed;
    if (line is ParsedDuetLine) {
      parsed = line as ParsedDuetLine;
    } else if (line is LyricLine) {
      parsed = parser.parseLyricLine(line as LyricLine);
    } else if (line is String) {
      parsed = parser.parseText(line as String);
    } else {
      parsed = parser.parseText(line?.toString() ?? '');
    }

    final effectiveColorConfig =
        colorConfigOverride ?? settings.colors;

    // Duet coloring enabled check
    final isDuetActive = settings.enabled;
    final singer = parsed.singer;

    final Color activeColor = isDuetActive
        ? effectiveColorConfig.getColor(singer)
        : (Theme.of(context).colorScheme.primary);

    final Color inactiveColor = isDuetActive
        ? effectiveColorConfig.getInactiveColor(singer)
        : (Theme.of(context).colorScheme.onSurface.withOpacity(0.38));

    final bool effectiveGlow = enableGlow ??
        (settings.enabled && settings.enableGlowEffect && isActive);

    final List<Shadow>? glowShadows = effectiveGlow
        ? effectiveColorConfig.getGlowShadows(singer)
        : null;

    final bool effectiveAlignBySinger = alignBySinger ??
        (settings.enabled && settings.alignBySinger);

    final TextAlign effectiveTextAlign = textAlign ??
        (effectiveAlignBySinger
            ? singer.role.defaultAlignment
            : TextAlign.left);

    final CrossAxisAlignment effectiveCrossAxis = effectiveAlignBySinger
        ? singer.role.defaultCrossAxisAlignment
        : CrossAxisAlignment.start;

    final Alignment effectiveAlignment = effectiveAlignBySinger
        ? singer.role.defaultWidgetAlignment
        : Alignment.centerLeft;

    final bool effectiveShowBadge = showBadge ??
        (settings.enabled &&
            settings.showSingerBadges &&
            parsed.singer.isExplicitTag);

    final effectiveFontWeight = fontWeight ??
        (isActive ? FontWeight.w700 : FontWeight.w600);

    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: effectiveFontWeight,
      fontFamily: 'Manrope',
    );

    // Build the lyric text widget (Syllable words / Continuous Wipe / Static)
    final Widget lyricsTextWidget = _buildLyricsContent(
      context: context,
      parsed: parsed,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      glowShadows: glowShadows,
      baseStyle: baseStyle,
      textAlign: effectiveTextAlign,
    );

    final contentColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: effectiveCrossAxis,
      children: [
        if (effectiveShowBadge) ...[
          KaraokeDuetBadge(
            singer: singer,
            color: activeColor,
            isCompact: true,
          ),
          const SizedBox(height: 5.0),
        ],
        lyricsTextWidget,
      ],
    );

    final scaledContent = AnimatedScale(
      scale: isActive ? settings.activeScale : 1.0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: effectiveAlignment,
      child: contentColumn,
    );

    return Semantics(
      label: '${singer.name}: ${parsed.cleanLyrics}',
      selected: isActive,
      button: onTap != null,
      child: InkWell(
        key: Key('karaoke_duet_line_${singer.role.name}'),
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: activeColor.withOpacity(0.12),
        highlightColor: activeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: padding,
          child: Align(
            alignment: effectiveAlignment,
            child: scaledContent,
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsContent({
    required BuildContext context,
    required ParsedDuetLine parsed,
    required Color activeColor,
    required Color inactiveColor,
    required List<Shadow>? glowShadows,
    required TextStyle baseStyle,
    required TextAlign textAlign,
  }) {
    // 1. Syllable-level word highlighting
    if (parsed.hasWords && currentPosition != null) {
      return _buildSyllableWords(
        words: parsed.words!,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        glowShadows: glowShadows,
        baseStyle: baseStyle,
        textAlign: textAlign,
      );
    }

    // 2. Continuous horizontal progress sweep wipe for active line
    if (isActive && progress > 0.0 && progress < 1.0) {
      return _buildContinuousKaraokeWipe(
        cleanLyrics: parsed.cleanLyrics,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        glowShadows: glowShadows,
        baseStyle: baseStyle,
        textAlign: textAlign,
      );
    }

    // 3. Standard active vs inactive text
    final currentColor = isActive ? activeColor : inactiveColor;
    return Text(
      parsed.cleanLyrics,
      textAlign: textAlign,
      style: baseStyle.copyWith(
        color: currentColor,
        shadows: glowShadows,
      ),
    );
  }

  Widget _buildSyllableWords({
    required List<LyricWord> words,
    required Color activeColor,
    required Color inactiveColor,
    required List<Shadow>? glowShadows,
    required TextStyle baseStyle,
    required TextAlign textAlign,
  }) {
    final spans = <InlineSpan>[];
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isSung = word.timestamp <= currentPosition!;
      final wordColor = isSung ? activeColor : inactiveColor;
      final wordShadows = isSung ? glowShadows : null;

      spans.add(
        TextSpan(
          text: word.text + (i < words.length - 1 ? ' ' : ''),
          style: baseStyle.copyWith(
            color: wordColor,
            shadows: wordShadows,
            fontWeight: isSung ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
    );
  }

  Widget _buildContinuousKaraokeWipe({
    required String cleanLyrics,
    required Color activeColor,
    required Color inactiveColor,
    required List<Shadow>? glowShadows,
    required TextStyle baseStyle,
    required TextAlign textAlign,
  }) {
    return Stack(
      children: [
        // Inactive background layer
        Text(
          cleanLyrics,
          textAlign: textAlign,
          style: baseStyle.copyWith(color: inactiveColor),
        ),
        // Active sung layer clipped to sweep progress
        ClipRect(
          clipper: _HorizontalProgressClipper(progress),
          child: Text(
            cleanLyrics,
            textAlign: textAlign,
            style: baseStyle.copyWith(
              color: activeColor,
              shadows: glowShadows,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact horizontal legend displaying active singers in a duet track.
class KaraokeDuetLegend extends StatelessWidget {
  final List<DuetSinger> singers;
  final DuetColorConfig? colorConfig;

  const KaraokeDuetLegend({
    super.key,
    required this.singers,
    this.colorConfig,
  });

  @override
  Widget build(BuildContext context) {
    if (singers.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: singers.map((s) {
          final color = colorConfig?.getColor(s) ??
              (s.role == SingerRole.lead2
                  ? const Color(0xFFFF4081)
                  : const Color(0xFF1DB954));
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: KaraokeDuetBadge(
              singer: s,
              color: color,
              isCompact: true,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Modal bottom sheet permitting live customization of duet palette presets,
/// singer alignments, badges, and color fine-tuning.
class KaraokeDuetSettingsSheet extends ConsumerWidget {
  const KaraokeDuetSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const KaraokeDuetSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(karaokeDuetSettingsProvider);
    final notifier = ref.read(karaokeDuetSettingsProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16171B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40.0,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.duo_rounded, color: Color(0xFFED5564)),
                  SizedBox(width: 8.0),
                  Text(
                    'Karaoke Duet Settings',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => notifier.resetToDefaults(),
                child: const Text('Reset'),
              ),
            ],
          ),
          const Divider(color: Colors.white12),

          // Toggles
          SwitchListTile(
            title: const Text('Multi-Color Duet Highlighting'),
            subtitle: const Text('Assign distinctive colors per singer'),
            value: settings.enabled,
            onChanged: (val) => notifier.setEnabled(val),
          ),
          SwitchListTile(
            title: const Text('Align by Singer'),
            subtitle: const Text('Lead 1 on left, Lead 2 on right, Chorus center'),
            value: settings.alignBySinger,
            onChanged: settings.enabled
                ? (val) => notifier.setAlignBySinger(val)
                : null,
          ),
          SwitchListTile(
            title: const Text('Show Singer Badges'),
            subtitle: const Text('Display vocalist identifier pill on lines'),
            value: settings.showSingerBadges,
            onChanged: settings.enabled
                ? (val) => notifier.setShowSingerBadges(val)
                : null,
          ),
          SwitchListTile(
            title: const Text('Vocal Glow Effect'),
            subtitle: const Text('Vibrant glowing aura on active vocal line'),
            value: settings.enableGlowEffect,
            onChanged: settings.enabled
                ? (val) => notifier.setGlowEffect(val)
                : null,
          ),

          const SizedBox(height: 12.0),
          const Text(
            'Color Palette Preset',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8.0),

          // Preset Chips
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: DuetColorPreset.values.map((preset) {
              final isSelected = settings.preset == preset;
              return ChoiceChip(
                label: Text(preset.label),
                selected: isSelected,
                onSelected: settings.enabled
                    ? (_) => notifier.setPreset(preset)
                    : null,
              );
            }).toList(),
          ),

          const SizedBox(height: 20.0),

          // Live Preview Card
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0C0E),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Duet Preview',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 12.0),
                KaraokeDuetLineView(
                  line: '[Lead 1] I found a love for me',
                  isActive: true,
                  fontSize: 18.0,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8.0),
                KaraokeDuetLineView(
                  line: '[Lead 2] Darling, just dive right in',
                  isActive: false,
                  fontSize: 18.0,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8.0),
                KaraokeDuetLineView(
                  line: '[Chorus] Baby, I\'m dancing in the dark',
                  isActive: false,
                  fontSize: 18.0,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
