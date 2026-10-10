import '../entities/track.dart';

class LyricWord {
  final Duration timestamp;
  final String text;

  const LyricWord({
    required this.timestamp,
    required this.text,
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

class SyncedLyrics {
  final String trackId;
  final List<LyricLine> lines;
  final String? plainLyrics;
  final String? rawLrc;

  const SyncedLyrics({
    required this.trackId,
    required this.lines,
    this.plainLyrics,
    this.rawLrc,
  });

  bool get isSynced => lines.isNotEmpty;
}

abstract class ILyricsProvider {
  /// Fetches synchronized lyrics for a track (e.g. via LRCLIB).
  /// Returns null if not found.
  Future<SyncedLyrics?> getLyrics(Track track);
}
