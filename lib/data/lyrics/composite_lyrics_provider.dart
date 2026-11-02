import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
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
  final Map<String, Future<SyncedLyrics?>> _inFlight = {};

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
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    final inFlight = _inFlight[track.id];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _resolveLyricsWithTimeout(track);
    _inFlight[track.id] = future;

    try {
      final result = await future;
      _addToCache(track.id, result);
      return result;
    } finally {
      _inFlight.remove(track.id);
    }
  }

  Future<SyncedLyrics?> _resolveLyricsWithTimeout(Track track) async {
    try {
      return await _resolveLyrics(track).timeout(
        const Duration(seconds: 14),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SyncedLyrics?> _resolveLyrics(Track track) async {
    // Tier 0 (Gold Standard): Query Softify verified studio master catalog (0ms)
    try {
      final curatedResult = await _curated.getLyrics(track);
      if (curatedResult != null &&
          curatedResult.isSynced &&
          curatedResult.lines.isNotEmpty) {
        return curatedResult;
      }
    } catch (_) {}

    // Tier 1 (Fast Concurrent Query): LRCLIB, NetEase, Kugou, and JioSaavn in parallel
    final fastTierFuture = Future.wait([
      _lrclib
          .getLyrics(track)
          .timeout(const Duration(milliseconds: 3500), onTimeout: () => null)
          .catchError((_) => null),
      _netease
          .getLyrics(track)
          .timeout(const Duration(milliseconds: 3000), onTimeout: () => null)
          .catchError((_) => null),
      _kugou
          .getLyrics(track)
          .timeout(const Duration(milliseconds: 3200), onTimeout: () => null)
          .catchError((_) => null),
      _saavn
          .getLyrics(track)
          .timeout(const Duration(milliseconds: 3500), onTimeout: () => null)
          .catchError((_) => null),
      if (_paxsenix != null)
        _paxsenix!
            .getLyrics(track)
            .timeout(const Duration(milliseconds: 800), onTimeout: () => null)
            .catchError((_) => null)
      else
        Future<SyncedLyrics?>.value(null),
      if (_betterLyrics != null)
        _betterLyrics!
            .getLyrics(track)
            .timeout(const Duration(milliseconds: 800), onTimeout: () => null)
            .catchError((_) => null)
      else
        Future<SyncedLyrics?>.value(null),
    ]);

    SyncedLyrics? lrclibResult;
    SyncedLyrics? neteaseResult;
    SyncedLyrics? kugouResult;
    SyncedLyrics? saavnResult;
    SyncedLyrics? paxResult;
    SyncedLyrics? betterResult;

    try {
      final fastResults = await fastTierFuture;
      lrclibResult = fastResults[0];
      neteaseResult = fastResults[1];
      kugouResult = fastResults[2];
      saavnResult = fastResults[3];
      paxResult = fastResults[4];
      betterResult = fastResults[5];

      // 1. Syllable/Karaoke sync preference (Paxsenix Apple Music or BetterLyrics)
      if (paxResult != null &&
          paxResult.isSynced &&
          paxResult.lines.isNotEmpty &&
          paxResult.isSyllableSynced) {
        return paxResult;
      }

      if (betterResult != null &&
          betterResult.isSynced &&
          betterResult.lines.isNotEmpty &&
          betterResult.isSyllableSynced) {
        return betterResult;
      }

      // 2. Line-synced preference (LRCLIB, NetEase, Kugou, JioSaavn)
      if (lrclibResult != null &&
          lrclibResult.isSynced &&
          lrclibResult.lines.isNotEmpty) {
        return lrclibResult;
      }

      if (neteaseResult != null &&
          neteaseResult.isSynced &&
          neteaseResult.lines.isNotEmpty) {
        return neteaseResult;
      }

      if (kugouResult != null &&
          kugouResult.isSynced &&
          kugouResult.lines.isNotEmpty) {
        return kugouResult;
      }

      if (saavnResult != null &&
          saavnResult.isSynced &&
          saavnResult.lines.isNotEmpty) {
        return saavnResult;
      }

      if (paxResult != null &&
          paxResult.isSynced &&
          paxResult.lines.isNotEmpty) {
        return paxResult;
      }

      if (betterResult != null &&
          betterResult.isSynced &&
          betterResult.lines.isNotEmpty) {
        return betterResult;
      }
    } catch (_) {}

    // Tier 2: Query Spotify official color-lyrics v2
    SyncedLyrics? spotifyResult;
    if (_spotify != null) {
      try {
        spotifyResult = await _spotify!.getLyrics(track).timeout(
              const Duration(milliseconds: 1800),
              onTimeout: () => null,
            );
        if (spotifyResult != null &&
            spotifyResult.isSynced &&
            spotifyResult.lines.isNotEmpty) {
          return spotifyResult;
        }
      } catch (_) {}
    }

    // Tier 4: Fallback to verified plain lyrics across sources
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
      return plainFallback;
    }

    // Tier 5: Query Genius for verified song lyrics
    try {
      final geniusResult = await _fallback.getLyrics(track).timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
      if (geniusResult != null &&
          geniusResult.plainLyrics != null &&
          geniusResult.plainLyrics!.trim().isNotEmpty) {
        return geniusResult;
      }
    } catch (_) {}

    // Tier 6: Strict Instrumental Detection
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
      return instrumentalResult;
    }

    return null;
  }

  void _addToCache(String key, SyncedLyrics? value) {
    if (_cache.length >= maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}
