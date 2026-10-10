import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';

/// Unofficial Spotify Color-Lyrics v2 provider.
/// Reverse-engineered from Spotify's internal spclient.wg.spotify.com/color-lyrics endpoint.
class SpotifyLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final String? Function()? _tokenGetter;
  final String? Function()? _customEndpointGetter;
  final Map<String, SyncedLyrics?> _cache = {};

  static const String defaultSpClientUrl = 'https://spclient.wg.spotify.com/color-lyrics/v2/track';

  SpotifyLyricsProvider({
    HttpClient? httpClient,
    String? Function()? tokenGetter,
    String? Function()? customEndpointGetter,
  })  : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 30)
              ..maxConnectionsPerHost = 4),
        _tokenGetter = tokenGetter,
        _customEndpointGetter = customEndpointGetter;

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    final spotifyId = _extractSpotifyId(track);
    if (spotifyId == null) return null;

    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    final token = _tokenGetter?.call()?.trim();
    final customEndpoint = _customEndpointGetter?.call()?.trim();

    // If neither a token nor a custom endpoint is configured, skip to next provider
    if ((token == null || token.isEmpty) &&
        (customEndpoint == null || customEndpoint.isEmpty)) {
      return null;
    }

    try {
      final SyncedLyrics? result;
      if (customEndpoint != null && customEndpoint.isNotEmpty) {
        result = await _fetchFromCustomEndpoint(customEndpoint, spotifyId, track);
      } else if (token != null && token.isNotEmpty) {
        result = await _fetchFromSpClient(token, spotifyId, track);
      } else {
        result = null;
      }

      _cache[track.id] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<SyncedLyrics?> _fetchFromSpClient(
    String token,
    String spotifyId,
    Track track,
  ) async {
    final cleanToken = token.startsWith('Bearer ') ? token.substring(7).trim() : token;
    final uri = Uri.parse(
      '$defaultSpClientUrl/$spotifyId?format=json&vocalRemoval=false&market=from_token',
    );

    final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
    request.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
    request.headers.set('app-platform', 'WebPlayer');
    request.headers.set('Authorization', 'Bearer $cleanToken');
    request.headers.set('Accept', 'application/json');

    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;

    final body = await response.transform(utf8.decoder).join();
    return parseSpotifyLyricsJson(body, track.id);
  }

  Future<SyncedLyrics?> _fetchFromCustomEndpoint(
    String endpoint,
    String spotifyId,
    Track track,
  ) async {
    final base = endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;
    final uri = Uri.parse('$base/?trackid=$spotifyId&format=raw');

    final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
    request.headers.set('User-Agent', 'Softify/1.0 (https://github.com/softify/softify)');
    request.headers.set('Accept', 'application/json');

    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;

    final body = await response.transform(utf8.decoder).join();
    return parseSpotifyLyricsJson(body, track.id);
  }

  /// Parses Spotify color-lyrics v2 JSON response into domain SyncedLyrics model.
  static SyncedLyrics? parseSpotifyLyricsJson(String jsonStr, String trackId) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final lyricsMap = json['lyrics'] as Map<String, dynamic>? ?? json;
      final rawLines = lyricsMap['lines'] as List<dynamic>?;
      if (rawLines == null || rawLines.isEmpty) return null;

      final List<LyricLine> lines = [];
      final buffer = StringBuffer();

      for (final l in rawLines) {
        if (l is! Map<String, dynamic>) continue;
        final startMsStr = l['startTimeMs']?.toString() ?? '0';
        final startMs = int.tryParse(startMsStr) ?? 0;
        final words = (l['words'] ?? '').toString().trim();
        if (words.isEmpty) continue;

        final lineTimestamp = Duration(milliseconds: startMs);

        // Syllable/word-level timestamps if available
        List<LyricWord>? lyricWords;
        final rawSyllables = l['syllables'] as List<dynamic>?;
        if (rawSyllables != null && rawSyllables.isNotEmpty) {
          lyricWords = [];
          for (final syl in rawSyllables) {
            if (syl is Map<String, dynamic>) {
              final sylStartMs = int.tryParse(syl['startTimeMs']?.toString() ?? '') ?? startMs;
              final sylText = (syl['text'] ?? '').toString();
              if (sylText.isNotEmpty) {
                lyricWords.add(LyricWord(
                  timestamp: Duration(milliseconds: sylStartMs),
                  text: sylText,
                ));
              }
            }
          }
        }

        final m = lineTimestamp.inMinutes.toString().padLeft(2, '0');
        final s = (lineTimestamp.inSeconds % 60).toString().padLeft(2, '0');
        final cs = ((lineTimestamp.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
        buffer.writeln('[$m:$s.$cs] $words');

        lines.add(LyricLine(
          timestamp: lineTimestamp,
          text: words,
          words: lyricWords,
        ));
      }

      if (lines.isEmpty) return null;

      return SyncedLyrics(
        trackId: trackId,
        lines: lines,
        plainLyrics: lines.map((l) => l.text).join('\n'),
        rawLrc: buffer.toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractSpotifyId(Track track) {
    if (track.sourceId.startsWith('spotify_')) {
      return track.sourceId.replaceFirst('spotify_', '').trim();
    }
    if (track.id.startsWith('spotify_')) {
      return track.id.replaceFirst('spotify_', '').trim();
    }
    // Check if it's already a standard 22-character base62 Spotify ID
    final candidate = track.sourceId.trim();
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(candidate)) {
      return candidate;
    }
    return null;
  }
}
