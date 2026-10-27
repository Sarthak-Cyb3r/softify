import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'ttml_parser.dart';

/// Provider for Apple Music word-by-word karaoke lyrics backed by the BetterLyrics service.
/// Fetches XML TTML data and parses it into syllable-synchronized [SyncedLyrics].
class BetterLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final String _baseUrl;
  final Map<String, SyncedLyrics?> _cache = {};

  static const String defaultEndpoint = 'https://lyrics-api.boidu.dev';

  BetterLyricsProvider({
    HttpClient? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 30)
              ..maxConnectionsPerHost = 4),
        _baseUrl = baseUrl ?? defaultEndpoint;

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    try {
      final queryParams = <String, String>{
        's': track.title,
        'a': track.artist,
      };

      if (track.duration.inSeconds > 0) {
        queryParams['d'] = track.duration.inSeconds.toString();
      }
      final albumName = track.album;
      if (albumName != null && albumName.isNotEmpty) {
        queryParams['al'] = albumName;
      }

      final uri = Uri.parse('$_baseUrl/getLyrics').replace(queryParameters: queryParams);
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 6));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Softify/1.0');
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        _cache[track.id] = null;
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final ttml = json['ttml'] as String?;

      if (ttml == null || ttml.trim().isEmpty) {
        _cache[track.id] = null;
        return null;
      }

      final parsedLines = TTMLParser.parseTTML(ttml);
      if (parsedLines.isEmpty) {
        _cache[track.id] = null;
        return null;
      }

      final syncedLyrics = TTMLParser.toSyncedLyrics(
        track.id,
        parsedLines,
        providerName: 'BetterLyrics',
      );

      _cache[track.id] = syncedLyrics;
      return syncedLyrics;
    } catch (_) {
      _cache[track.id] = null;
      return null;
    }
  }

  void clearCache() => _cache.clear();
}
