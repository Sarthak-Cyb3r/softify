import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'genius_lyrics_provider.dart';
import 'kugou_lyrics_provider.dart';
import 'lrclib_lyrics_provider.dart';
import 'netease_lyrics_provider.dart';

/// Multi-source lyrics engine combining Spotify Color-Lyrics, LRCLIB, NetEase, Kugou, and Genius catalogs.
/// Ensures maximum global coverage and millisecond-accurate LRC synchronization with extensive plain fallback.
class CompositeLyricsProvider implements ILyricsProvider {
  final ILyricsProvider? _spotify;
  final ILyricsProvider _primary;
  final ILyricsProvider _netease;
  final ILyricsProvider _secondary;
  final ILyricsProvider _fallback;
  final Map<String, SyncedLyrics?> _cache = {};

  CompositeLyricsProvider({
    ILyricsProvider? spotify,
    ILyricsProvider? primary,
    ILyricsProvider? netease,
    ILyricsProvider? secondary,
    ILyricsProvider? fallback,
    HttpClient? httpClient,
  })  : _spotify = spotify,
        _primary = primary ?? LrclibLyricsProvider(httpClient: httpClient),
        _netease = netease ?? NeteaseLyricsProvider(httpClient: httpClient),
        _secondary = secondary ?? KugouLyricsProvider(httpClient: httpClient),
        _fallback = fallback ?? GeniusLyricsProvider(httpClient: httpClient);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    // 0. Query Spotify official color-lyrics if available
    if (_spotify != null) {
      try {
        final spotifyResult = await _spotify.getLyrics(track);
        if (spotifyResult != null && spotifyResult.isSynced && spotifyResult.lines.isNotEmpty) {
          _cache[track.id] = spotifyResult;
          return spotifyResult;
        }
      } catch (_) {}
    }

    // 1. Query primary provider (LRCLIB with exact + search fallback)
    SyncedLyrics? primaryResult;
    try {
      primaryResult = await _primary.getLyrics(track);
      if (primaryResult != null && primaryResult.isSynced && primaryResult.lines.isNotEmpty) {
        _cache[track.id] = primaryResult;
        return primaryResult;
      }
    } catch (_) {}

    // 2. Query NetEase Cloud Music global synced database
    SyncedLyrics? neteaseResult;
    try {
      neteaseResult = await _netease.getLyrics(track);
      if (neteaseResult != null && neteaseResult.isSynced && neteaseResult.lines.isNotEmpty) {
        _cache[track.id] = neteaseResult;
        return neteaseResult;
      }
    } catch (_) {}

    // 3. Query Kugou global synced database
    SyncedLyrics? secondaryResult;
    try {
      secondaryResult = await _secondary.getLyrics(track);
      if (secondaryResult != null && secondaryResult.isSynced && secondaryResult.lines.isNotEmpty) {
        _cache[track.id] = secondaryResult;
        return secondaryResult;
      }
    } catch (_) {}

    // 4. Fallback to any plain lyrics found across providers
    final plainFallback = primaryResult ?? neteaseResult ?? secondaryResult;
    if (plainFallback != null &&
        ((plainFallback.plainLyrics != null &&
                plainFallback.plainLyrics!.trim().isNotEmpty) ||
            plainFallback.lines.isNotEmpty)) {
      _cache[track.id] = plainFallback;
      return plainFallback;
    }

    // 5. Ultimate fallback: Query Genius for verified song lyrics
    try {
      final geniusResult = await _fallback.getLyrics(track);
      if (geniusResult != null) {
        _cache[track.id] = geniusResult;
        return geniusResult;
      }
    } catch (_) {}

    _cache[track.id] = plainFallback;
    return plainFallback;
  }
}
