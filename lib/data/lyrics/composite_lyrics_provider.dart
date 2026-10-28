import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import '../../services/lyrics/paxsenix_lyrics_provider.dart';
import 'curated_lyrics_provider.dart';
import 'genius_lyrics_provider.dart';
import 'kugou_lyrics_provider.dart';
import 'lrclib_lyrics_provider.dart';
import 'netease_lyrics_provider.dart';
import 'saavn_lyrics_provider.dart';

/// Multi-source lyrics engine combining Softify Verified Studio Master (Tier 0),
/// Spotify Color-Lyrics v2 (Primary), LRCLIB, NetEase, Kugou, JioSaavn, and Genius catalogs.
/// Ensures maximum global coverage, millisecond-accurate LRC synchronization,
/// syllable karaoke progression, and extensive plain fallback.
class CompositeLyricsProvider implements ILyricsProvider {
  final ILyricsProvider _curated;
  final ILyricsProvider? _spotify;
  final ILyricsProvider? _betterLyrics;
  final ILyricsProvider? _paxsenix;
  final ILyricsProvider _lrclib;
  final ILyricsProvider _netease;
  final ILyricsProvider _kugou;
  final ILyricsProvider _saavn;
  final ILyricsProvider _fallback;
  final Map<String, SyncedLyrics?> _cache = {};

  static const int maxCacheEntries = 150;

  CompositeLyricsProvider({
    ILyricsProvider? curated,
    ILyricsProvider? spotify,
    ILyricsProvider? betterLyrics,
    ILyricsProvider? paxsenix,
    ILyricsProvider? primary,
    ILyricsProvider? netease,
    ILyricsProvider? secondary,
    ILyricsProvider? saavn,
    ILyricsProvider? fallback,
    HttpClient? httpClient,
  })  : _curated = curated ?? CuratedLyricsProvider(),
        _spotify = spotify,
        _betterLyrics = betterLyrics,
        _paxsenix = paxsenix,
        _lrclib = primary ?? LrclibLyricsProvider(httpClient: httpClient),
        _netease = netease ?? NeteaseLyricsProvider(httpClient: httpClient),
        _kugou = secondary ?? KugouLyricsProvider(httpClient: httpClient),
        _saavn = saavn ?? SaavnLyricsProvider(httpClient: httpClient),
        _fallback = fallback ?? GeniusLyricsProvider(httpClient: httpClient);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_cache.containsKey(track.id) && _cache[track.id] != null) {
      return _cache[track.id];
    }

    // Tier 0 (Gold Standard): Query Softify verified studio master catalog
    try {
      final curatedResult = await _curated.getLyrics(track);
      if (curatedResult != null &&
          curatedResult.isSynced &&
          curatedResult.lines.isNotEmpty) {
        _addToCache(track.id, curatedResult);
        return curatedResult;
      }
    } catch (_) {}

    // Tier 1 (Primary - Syllable/Word-by-Word Karaoke): Query BetterLyrics (BeautifulLyrics Apple Music TTML)
    if (_betterLyrics != null) {
      try {
        final betterResult = await _betterLyrics.getLyrics(track);
        if (betterResult != null &&
            betterResult.isSynced &&
            betterResult.lines.isNotEmpty) {
          _addToCache(track.id, betterResult);
          return betterResult;
        }
      } catch (_) {}
    }

    // Tier 1.2: Query Paxsenix for Musixmatch / Apple Music rich syllable / word-by-word sync
    if (_paxsenix != null) {
      try {
        final paxResult = await _paxsenix.getLyrics(track);
        if (paxResult != null &&
            paxResult.isSynced &&
            paxResult.lines.isNotEmpty &&
            paxResult.isSyllableSynced) {
          _addToCache(track.id, paxResult);
          return paxResult;
        }
      } catch (_) {}
    }

    // Tier 1.5: Query Spotify official color-lyrics v2
    SyncedLyrics? spotifyResult;
    if (_spotify != null) {
      try {
        spotifyResult = await _spotify.getLyrics(track);
        if (spotifyResult != null &&
            spotifyResult.isSynced &&
            spotifyResult.lines.isNotEmpty) {
          _addToCache(track.id, spotifyResult);
          return spotifyResult;
        }
      } catch (_) {}
    }

    // Tier 2: Query LRCLIB and JioSaavn concurrently
    SyncedLyrics? lrclibResult;
    SyncedLyrics? saavnResult;
    try {
      final tier2Results = await Future.wait([
        _lrclib.getLyrics(track).catchError((_) => null),
        _saavn.getLyrics(track).catchError((_) => null),
      ]);
      lrclibResult = tier2Results[0];
      saavnResult = tier2Results[1];

      // If LRCLIB returned valid synced lyrics, immediately return
      if (lrclibResult != null &&
          lrclibResult.isSynced &&
          lrclibResult.lines.isNotEmpty) {
        _addToCache(track.id, lrclibResult);
        return lrclibResult;
      }

      // If JioSaavn returned synced lyrics, return
      if (saavnResult != null &&
          saavnResult.isSynced &&
          saavnResult.lines.isNotEmpty) {
        _addToCache(track.id, saavnResult);
        return saavnResult;
      }
    } catch (_) {}

    // Tier 3: Query NetEase Cloud Music and Kugou concurrently
    SyncedLyrics? neteaseResult;
    SyncedLyrics? kugouResult;
    try {
      final tier3Results = await Future.wait([
        _netease.getLyrics(track).catchError((_) => null),
        _kugou.getLyrics(track).catchError((_) => null),
      ]);
      neteaseResult = tier3Results[0];
      kugouResult = tier3Results[1];

      if (neteaseResult != null &&
          neteaseResult.isSynced &&
          neteaseResult.lines.isNotEmpty) {
        _addToCache(track.id, neteaseResult);
        return neteaseResult;
      }

      if (kugouResult != null &&
          kugouResult.isSynced &&
          kugouResult.lines.isNotEmpty) {
        _addToCache(track.id, kugouResult);
        return kugouResult;
      }
    } catch (_) {}

    // Tier 4: Fallback to verified plain lyrics across sources
    // (JioSaavn verified studio lyrics first, then LRCLIB plain, NetEase, Kugou, Spotify)
    final plainCandidates = [
      saavnResult,
      lrclibResult,
      neteaseResult,
      kugouResult,
      spotifyResult,
    ];

    final plainFallback = plainCandidates.firstWhere(
      (c) =>
          c != null &&
          ((c.plainLyrics != null && c.plainLyrics!.trim().isNotEmpty) ||
              c.lines.isNotEmpty),
      orElse: () => null,
    );

    if (plainFallback != null) {
      _addToCache(track.id, plainFallback);
      return plainFallback;
    }

    // Tier 5: Query Genius for verified song lyrics
    try {
      final geniusResult = await _fallback.getLyrics(track);
      if (geniusResult != null &&
          geniusResult.plainLyrics != null &&
          geniusResult.plainLyrics!.trim().isNotEmpty) {
        _addToCache(track.id, geniusResult);
        return geniusResult;
      }
    } catch (_) {}

    // Tier 6: Strict Instrumental Detection
    // Note: Do NOT match "soundtrack", "score", or "album" as those are vocal movie songs!
    final isExplicitInstrumental = RegExp(
      r'\b(?:instrumental|karaoke|backing track|minus one|white noise|relaxing sound|nature sounds|ambient rain)\b',
      caseSensitive: false,
    ).hasMatch(track.title);

    if (isExplicitInstrumental) {
      final instrumentalResult = SyncedLyrics(
        trackId: track.id,
        lines: const [
          LyricLine(timestamp: Duration.zero, text: '♪ Instrumental ♪'),
        ],
        plainLyrics: '♪ Instrumental ♪',
        syncType: 'LINE_SYNCED',
        providerName: 'Instrumental',
      );
      _addToCache(track.id, instrumentalResult);
      return instrumentalResult;
    }

    return null;
  }

  void _addToCache(String key, SyncedLyrics? value) {
    if (value == null) return;
    if (_cache.length >= maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}
