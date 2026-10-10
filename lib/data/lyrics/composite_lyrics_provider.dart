import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'kugou_lyrics_provider.dart';
import 'lrclib_lyrics_provider.dart';

/// Multi-source lyrics engine combining Spotify Color-Lyrics, LRCLIB, and Kugou catalogs.
/// Ensures maximum coverage and millisecond-accurate LRC synchronization.
class CompositeLyricsProvider implements ILyricsProvider {
  final ILyricsProvider? _spotify;
  final ILyricsProvider _primary;
  final ILyricsProvider _secondary;
  final Map<String, SyncedLyrics?> _cache = {};

  CompositeLyricsProvider({
    ILyricsProvider? spotify,
    ILyricsProvider? primary,
    ILyricsProvider? secondary,
    HttpClient? httpClient,
  })  : _spotify = spotify,
        _primary = primary ?? LrclibLyricsProvider(httpClient: httpClient),
        _secondary = secondary ?? KugouLyricsProvider(httpClient: httpClient);

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
    try {
      final primaryResult = await _primary.getLyrics(track);
      if (primaryResult != null && primaryResult.isSynced && primaryResult.lines.isNotEmpty) {
        _cache[track.id] = primaryResult;
        return primaryResult;
      }

      // 2. Query secondary provider (Kugou global synced database)
      final secondaryResult = await _secondary.getLyrics(track);
      if (secondaryResult != null && secondaryResult.isSynced && secondaryResult.lines.isNotEmpty) {
        _cache[track.id] = secondaryResult;
        return secondaryResult;
      }

      // 3. Fallback to any plain lyrics if available
      final plainFallback = primaryResult ?? secondaryResult;
      _cache[track.id] = plainFallback;
      return plainFallback;
    } catch (_) {
      try {
        final secondaryResult = await _secondary.getLyrics(track);
        _cache[track.id] = secondaryResult;
        return secondaryResult;
      } catch (_) {
        _cache[track.id] = null;
        return null;
      }
    }
  }
}
