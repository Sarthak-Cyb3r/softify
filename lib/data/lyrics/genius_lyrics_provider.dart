import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'spotify_lyrics_synchronizer.dart';

/// Unofficial Genius lyrics provider for extensive global song coverage.
/// Acts as the ultimate fallback for indie, rap, and obscure tracks when LRC catalogs have no entry.
class GeniusLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;

  GeniusLyricsProvider({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    try {
      final cleanTitle = SpotifyLyricsSynchronizer.cleanTrackTitle(track.title);
      final cleanArtist = SpotifyLyricsSynchronizer.cleanArtistName(track.artist);
      final primaryArtist = cleanArtist.split(RegExp(r'[,&/]')).first.trim();
      final query = '$cleanTitle $primaryArtist'.trim();
      final songPath = await _searchSongPath(query);
      if (songPath == null) return null;

      final lyrics = await _scrapeLyrics(songPath);
      if (lyrics == null || lyrics.trim().isEmpty) return null;

      return SyncedLyrics(
        trackId: track.id,
        lines: const [],
        plainLyrics: lyrics.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _searchSongPath(String query) async {
    try {
      final uri = Uri.parse(
        'https://genius.com/api/search/multi?q=${Uri.encodeComponent(query)}',
      );
      final request =
          await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set('User-Agent',
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
      final json = jsonDecode(body) as Map<String, dynamic>;
      final responseMap = json['response'] as Map<String, dynamic>?;
      final sections = responseMap?['sections'] as List<dynamic>?;
      if (sections == null) return null;

      for (final sec in sections) {
        if (sec is! Map<String, dynamic>) continue;
        if (sec['type'] == 'song') {
          final hits = sec['hits'] as List<dynamic>?;
          if (hits != null && hits.isNotEmpty) {
            final firstHit = hits.first as Map<String, dynamic>?;
            final result = firstHit?['result'] as Map<String, dynamic>?;
            final path = result?['path'] as String?;
            if (path != null && path.isNotEmpty) {
              return path;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _scrapeLyrics(String path) async {
    try {
      final uri = Uri.parse('https://genius.com$path');
      final request =
          await _httpClient.getUrl(uri).timeout(const Duration(seconds: 6));
      request.headers.set('User-Agent',
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      final response =
          await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final html = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
      final buffer = StringBuffer();

      // Find all divs matching data-lyrics-container="true"
      final containerPattern = RegExp(
        r'<div[^>]*data-lyrics-container="true"[^>]*>(.*?)<\/div>',
        dotAll: true,
      );

      final matches = containerPattern.allMatches(html);
      for (final match in matches) {
        var chunk = match.group(1) ?? '';
        // Replace <br/> and <br> with newlines
        chunk = chunk.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');
        // Remove all HTML tags
        chunk = chunk.replaceAll(RegExp(r'<[^>]+>'), '');
        // Decode HTML entities
        chunk = _decodeHtmlEntities(chunk);
        buffer.writeln(chunk);
      }

      final result = buffer.toString().trim();
      return result.isNotEmpty ? result : null;
    } catch (_) {}
    return null;
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
