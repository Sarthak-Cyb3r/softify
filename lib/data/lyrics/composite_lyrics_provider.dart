import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'genius_lyrics_provider.dart';
import 'kugou_lyrics_provider.dart';
import 'lrclib_lyrics_provider.dart';
import 'netease_lyrics_provider.dart';
import 'saavn_lyrics_provider.dart';

/// Multi-source lyrics engine combining Spotify Color-Lyrics v2 (Primary),
/// LRCLIB, NetEase, Kugou, JioSaavn, and Genius catalogs.
/// Ensures maximum global coverage, millisecond-accurate LRC synchronization,
/// syllable karaoke progression, and extensive plain fallback.
class CompositeLyricsProvider implements ILyricsProvider {
  final ILyricsProvider? _spotify;
  final ILyricsProvider _lrclib;
  final ILyricsProvider _netease;
  final ILyricsProvider _kugou;
  final ILyricsProvider _saavn;
  final ILyricsProvider _fallback;
  final Map<String, SyncedLyrics?> _cache = {};

  static const int maxCacheEntries = 150;

  CompositeLyricsProvider({
    ILyricsProvider? spotify,
    ILyricsProvider? primary,
    ILyricsProvider? netease,
    ILyricsProvider? secondary,
    ILyricsProvider? saavn,
    ILyricsProvider? fallback,
    HttpClient? httpClient,
  })  : _spotify = spotify,
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

    // Tier 0 (Primary): Query Spotify official color-lyrics v2
    if (_spotify != null) {
      try {
        final spotifyResult = await _spotify.getLyrics(track);
        if (spotifyResult != null &&
            spotifyResult.isSynced &&
            spotifyResult.lines.isNotEmpty) {
          _addToCache(track.id, spotifyResult);
          return spotifyResult;
        }
      } catch (_) {}
    }

    // Tier 1: Query LRCLIB with exact + search fallback
    SyncedLyrics? lrclibResult;
    try {
      lrclibResult = await _lrclib.getLyrics(track);
      if (lrclibResult != null &&
          lrclibResult.isSynced &&
          lrclibResult.lines.isNotEmpty) {
        _addToCache(track.id, lrclibResult);
        return lrclibResult;
      }
    } catch (_) {}

    // Tier 2: Query NetEase Cloud Music global synced database
    SyncedLyrics? neteaseResult;
    try {
      neteaseResult = await _netease.getLyrics(track);
      if (neteaseResult != null &&
          neteaseResult.isSynced &&
          neteaseResult.lines.isNotEmpty) {
        _addToCache(track.id, neteaseResult);
        return neteaseResult;
      }
    } catch (_) {}

    // Tier 3: Query Kugou global synced database
    SyncedLyrics? kugouResult;
    try {
      kugouResult = await _kugou.getLyrics(track);
      if (kugouResult != null &&
          kugouResult.isSynced &&
          kugouResult.lines.isNotEmpty) {
        _addToCache(track.id, kugouResult);
        return kugouResult;
      }
    } catch (_) {}

    // Tier 4: Fallback to any plain lyrics found across providers
    final plainFallback = lrclibResult ?? neteaseResult ?? kugouResult;
    if (plainFallback != null &&
        ((plainFallback.plainLyrics != null &&
                plainFallback.plainLyrics!.trim().isNotEmpty) ||
            plainFallback.lines.isNotEmpty)) {
      _addToCache(track.id, plainFallback);
      return plainFallback;
    }

    // Tier 5: Query JioSaavn official verified lyrics database
    try {
      final saavnResult = await _saavn.getLyrics(track);
      if (saavnResult != null &&
          ((saavnResult.plainLyrics != null &&
                  saavnResult.plainLyrics!.trim().isNotEmpty) ||
              saavnResult.lines.isNotEmpty)) {
        _addToCache(track.id, saavnResult);
        return saavnResult;
      }
    } catch (_) {}

    // Tier 6: Ultimate fallback: Query Genius for verified song lyrics
    try {
      final geniusResult = await _fallback.getLyrics(track);
      if (geniusResult != null) {
        _addToCache(track.id, geniusResult);
        return geniusResult;
      }
    } catch (_) {}

    _addToCache(track.id, plainFallback);
    return plainFallback;
  }

  void _addToCache(String key, SyncedLyrics? value) {
    if (_cache.length >= maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}
