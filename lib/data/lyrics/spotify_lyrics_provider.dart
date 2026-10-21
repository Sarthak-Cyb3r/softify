import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'spotify_lyrics_synchronizer.dart';

/// Unofficial Spotify Color-Lyrics v2 provider.
/// Reverse-engineered from Spotify's internal spclient.wg.spotify.com/color-lyrics endpoint.
/// Enforces bounded caching, SSRF endpoint sanitization, and syllable/color parsing.
class SpotifyLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final String? Function()? _tokenGetter;
  final String? Function()? _customEndpointGetter;
  final Map<String, SyncedLyrics?> _cache = {};

  static const int maxCacheEntries = 100;
  static const String defaultSpClientUrl =
      'https://spclient.wg.spotify.com/color-lyrics/v2/track';

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

    // If neither a token nor a custom endpoint is configured, return null gracefully
    if ((token == null || token.isEmpty) &&
        (customEndpoint == null || customEndpoint.isEmpty)) {
      return null;
    }

    try {
      final SyncedLyrics? result;
      if (customEndpoint != null && customEndpoint.isNotEmpty) {
        result =
            await _fetchFromCustomEndpoint(customEndpoint, spotifyId, track);
      } else if (token != null && token.isNotEmpty) {
        result = await _fetchFromSpClient(token, spotifyId, track);
      } else {
        result = null;
      }

      _addToCache(track.id, result);
      return result;
    } catch (_) {
      return null;
    }
  }

  void _addToCache(String key, SyncedLyrics? value) {
    if (_cache.length >= maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  Future<SyncedLyrics?> _fetchFromSpClient(
    String token,
    String spotifyId,
    Track track,
  ) async {
    final cleanToken =
        token.startsWith('Bearer ') ? token.substring(7).trim() : token;
    final isSpDcCookie =
        cleanToken.startsWith('sp_dc=') || cleanToken.length > 120;

    final uri = Uri.parse(
      '$defaultSpClientUrl/$spotifyId?format=json&vocalRemoval=false&market=from_token',
    );

    final request =
        await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
    request.headers.set(
      'User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    );
    request.headers.set('app-platform', 'WebPlayer');
    request.headers.set('Accept', 'application/json');

    if (isSpDcCookie) {
      final cookieVal = cleanToken.startsWith('sp_dc=')
          ? cleanToken
          : 'sp_dc=$cleanToken';
      request.headers.set('Cookie', cookieVal);
    } else {
      request.headers.set('Authorization', 'Bearer $cleanToken');
    }

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
    // AppSec: Sanitize endpoint against SSRF and invalid schemes
    final sanitizedUri = SpotifyLyricsSynchronizer.sanitizeEndpoint(endpoint);
    if (sanitizedUri == null) return null;

    final baseStr = sanitizedUri.toString();
    final cleanBase =
        baseStr.endsWith('/') ? baseStr.substring(0, baseStr.length - 1) : baseStr;
    final uri = Uri.parse('$cleanBase/?trackid=$spotifyId&format=raw');

    final request =
        await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
    request.headers.set(
      'User-Agent',
      'Softify/1.0 (https://github.com/softify/softify)',
    );
    request.headers.set('Accept', 'application/json');

    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;

    final body = await response.transform(utf8.decoder).join();
    return parseSpotifyLyricsJson(body, track.id);
  }

  /// Parses Spotify color-lyrics v2 JSON response into domain SyncedLyrics model.
  /// Extracts syncType, syllable-level word timings, and album complementary colors.
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
          final tempWords = <LyricWord>[];
          for (final syl in rawSyllables) {
            if (syl is Map<String, dynamic>) {
              final sylStartMs =
                  int.tryParse(syl['startTimeMs']?.toString() ?? '') ?? startMs;
              final sylText = (syl['text'] ?? '').toString();
              if (sylText.isNotEmpty) {
                tempWords.add(LyricWord(
                  timestamp: Duration(milliseconds: sylStartMs),
                  text: sylText,
                ));
              }
            }
          }

          if (tempWords.isNotEmpty) {
            lyricWords = [];
            for (int i = 0; i < tempWords.length; i++) {
              final nextStart = (i + 1 < tempWords.length)
                  ? tempWords[i + 1].timestamp
                  : null;
              final duration = nextStart != null
                  ? (nextStart - tempWords[i].timestamp)
                  : null;
              lyricWords.add(LyricWord(
                timestamp: tempWords[i].timestamp,
                text: tempWords[i].text,
                duration: duration,
              ));
            }
          }
        }

        final m = lineTimestamp.inMinutes.toString().padLeft(2, '0');
        final s = (lineTimestamp.inSeconds % 60).toString().padLeft(2, '0');
        final cs =
            ((lineTimestamp.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
        buffer.writeln('[$m:$s.$cs] $words');

        lines.add(LyricLine(
          timestamp: lineTimestamp,
          text: words,
          words: lyricWords,
        ));
      }

      if (lines.isEmpty) return null;

      // Extract colors from root or lyrics level
      LyricColors? lyricColors;
      final colorsMap = (json['colors'] ?? lyricsMap['colors']) as Map<String, dynamic>?;
      if (colorsMap != null) {
        lyricColors = LyricColors(
          background: (colorsMap['background'] as num?)?.toInt(),
          text: (colorsMap['text'] as num?)?.toInt(),
          highlightText: (colorsMap['highlightText'] as num?)?.toInt(),
        );
      }

      final syncType = lyricsMap['syncType']?.toString() ??
          (lines.any((l) => l.words != null && l.words!.isNotEmpty)
              ? 'SYLLABLE_SYNCED'
              : 'LINE_SYNCED');

      final providerName = lyricsMap['provider']?.toString() ??
          lyricsMap['providerDisplayName']?.toString() ??
          'Musixmatch';

      return SyncedLyrics(
        trackId: trackId,
        lines: lines,
        plainLyrics: lines.map((l) => l.text).join('\n'),
        rawLrc: buffer.toString().trim(),
        syncType: syncType,
        providerName: providerName,
        colors: lyricColors,
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractSpotifyId(Track track) {
    for (final raw in [track.sourceId, track.id]) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('spotify:track:')) {
        return trimmed.replaceFirst('spotify:track:', '').trim();
      }
      if (trimmed.startsWith('spotify_')) {
        final candidate = trimmed.replaceFirst('spotify_', '').trim();
        if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(candidate)) {
          return candidate;
        }
      }
      if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(trimmed)) {
        return trimmed;
      }
    }
    return null;
  }
}
