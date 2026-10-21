import '../entities/track.dart';

class LyricWord {
  final Duration timestamp;
  final String text;
  final Duration? duration;

  const LyricWord({
    required this.timestamp,
    required this.text,
    this.duration,
  });
}

class LyricLine {
  final Duration timestamp;
  final String text;
  final List<LyricWord>? words;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.words,
  });
}

class LyricColors {
  final int? background;
  final int? text;
  final int? highlightText;

  const LyricColors({
    this.background,
    this.text,
    this.highlightText,
  });
}

class SyncedLyrics {
  final String trackId;
  final List<LyricLine> lines;
  final String? plainLyrics;
  final String? rawLrc;
  final String? syncType; // 'LINE_SYNCED', 'SYLLABLE_SYNCED', 'UNSYNCED'
  final String? providerName;
  final LyricColors? colors;

  const SyncedLyrics({
    required this.trackId,
    required this.lines,
    this.plainLyrics,
    this.rawLrc,
    this.syncType,
    this.providerName,
    this.colors,
  });

  bool get isSynced => lines.isNotEmpty;
  bool get isSyllableSynced =>
      syncType == 'SYLLABLE_SYNCED' ||
      lines.any((l) => l.words != null && l.words!.isNotEmpty);
}

abstract class ILyricsProvider {
  /// Fetches synchronized lyrics for a track.
  /// Returns null if not found.
  Future<SyncedLyrics?> getLyrics(Track track);
}

