import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'spotify_lyrics_synchronizer.dart';

/// Official JioSaavn verified lyrics provider.
/// Supplies verified studio lyrics for tens of millions of Indian, Bollywood, Punjabi,
/// Asian, and international tracks directly from JioSaavn's official catalog.
class SaavnLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final Map<String, SyncedLyrics?> _cache = {};

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  SaavnLyricsProvider({HttpClient? httpClient})
      : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 30)
              ..maxConnectionsPerHost = 6);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    try {
      String? pid;
      if (track.sourceId.startsWith('saavn_')) {
        pid = track.sourceId.replaceFirst('saavn_', '').trim();
      } else {
        pid = await _resolvePid(track);
      }

      if (pid == null || pid.isEmpty) {
        _cache[track.id] = null;
        return null;
      }

      final uri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$pid&ctx=web6dot0&api_version=4&_format=json',
      );

      final req = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 6));
      req.headers.set('User-Agent', _userAgent);
      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        _cache[track.id] = null;
        return null;
      }

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final rawLyrics = json['lyrics'] as String?;

      if (rawLyrics == null || rawLyrics.trim().isEmpty) {
        _cache[track.id] = null;
        return null;
      }

      final cleanLyrics = _sanitizeLyrics(rawLyrics);
      if (cleanLyrics.isEmpty) {
        _cache[track.id] = null;
        return null;
      }

      final result = SyncedLyrics(
        trackId: track.id,
        lines: const [],
        plainLyrics: cleanLyrics,
      );

      _cache[track.id] = result;
      return result;
    } catch (_) {
      _cache[track.id] = null;
      return null;
    }
  }

  Future<String?> _resolvePid(Track track) async {
    try {
      final cleanTitle = SpotifyLyricsSynchronizer.cleanTrackTitle(track.title);
      final cleanArtist = SpotifyLyricsSynchronizer.cleanArtistName(track.artist);
      final primaryArtist = cleanArtist.split(RegExp(r'[,&/]')).first.trim();
      final query = '$cleanTitle $primaryArtist'.trim();

      final searchUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=${Uri.encodeComponent(query)}&_format=json&_marker=0&ctx=web6dot0',
      );

      final req = await _httpClient.getUrl(searchUri).timeout(const Duration(seconds: 5));
      req.headers.set('User-Agent', _userAgent);
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final songsObj = json['songs'];
      if (songsObj is! Map<String, dynamic>) return null;

      final songList = (songsObj['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      if (songList.isEmpty) return null;

      // Find best match by title
      for (final song in songList) {
        final candTitle = _normalize((song['title'] ?? '').toString());
        if (candTitle == cleanTitle || candTitle.contains(cleanTitle) || cleanTitle.contains(candTitle)) {
          final pid = song['id']?.toString();
          if (pid != null && pid.isNotEmpty) {
            return pid;
          }
        }
      }

      // Fallback to top song result
      return songList.first['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  String _sanitizeLyrics(String raw) {
    return raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
  }
}
