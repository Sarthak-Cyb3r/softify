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
    if (_cache.containsKey(track.id) && _cache[track.id] != null) {
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
        return null;
      }

      final uri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$pid&ctx=web6dot0&api_version=4&_format=json',
      );

      final req = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 6));
      req.headers.set('User-Agent', _userAgent);
      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        return null;
      }

      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
      final json = jsonDecode(body) as Map<String, dynamic>;
      final rawLyrics = json['lyrics'] as String?;

      if (rawLyrics == null || rawLyrics.trim().isEmpty) {
        return null;
      }

      final cleanLyrics = _sanitizeLyrics(rawLyrics);
      if (cleanLyrics.isEmpty) {
        return null;
      }

      final result = SyncedLyrics(
        trackId: track.id,
        lines: const [],
        plainLyrics: cleanLyrics,
        syncType: 'UNSYNCED',
        providerName: 'JioSaavn',
      );

      _cache[track.id] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolvePid(Track track) async {
    try {
      final cleanTitle = SpotifyLyricsSynchronizer.cleanTrackTitle(track.title);
      final cleanArtist = SpotifyLyricsSynchronizer.cleanArtistName(track.artist);
      final primaryArtist = cleanArtist.split(RegExp(r'[,&/]')).first.trim();
      final normTarget = _normalize(cleanTitle);

      final queries = [
        if (primaryArtist.isNotEmpty) '$cleanTitle $primaryArtist'.trim(),
        cleanTitle,
      ];

      for (final q in queries) {
        final searchUri = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=8&p=1&q=${Uri.encodeComponent(q)}',
        );

        final req = await _httpClient.getUrl(searchUri).timeout(const Duration(seconds: 5));
        req.headers.set('User-Agent', _userAgent);
        final res = await req.close().timeout(const Duration(seconds: 5));
        if (res.statusCode != 200) continue;

        final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
        final json = jsonDecode(body) as Map<String, dynamic>;
        final results = (json['results'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        final simpleTarget = _phoneticSimplify(normTarget);

        // 1. First pass: Exact, substring, or phonetic title match that has verified lyrics
        for (final song in results) {
          final candTitle = _normalize((song['title'] ?? song['song'] ?? '').toString());
          final simpleCand = _phoneticSimplify(candTitle);
          final moreInfo = song['more_info'] as Map<String, dynamic>? ?? {};
          final hasLyrics = moreInfo['has_lyrics'] == 'true' ||
              moreInfo['has_lyrics'] == true ||
              song['has_lyrics'] == 'true' ||
              song['has_lyrics'] == true;

          final matches = candTitle == normTarget ||
              candTitle.contains(normTarget) ||
              normTarget.contains(candTitle) ||
              (simpleTarget.isNotEmpty &&
                  (simpleCand == simpleTarget ||
                      simpleCand.contains(simpleTarget) ||
                      simpleTarget.contains(simpleCand)));

          if (hasLyrics && matches) {
            final lid = moreInfo['lyrics_id']?.toString().trim();
            final pid = (lid != null && lid.isNotEmpty && lid != 'null')
                ? lid
                : song['id']?.toString();
            if (pid != null && pid.isNotEmpty) {
              return pid;
            }
          }
        }

        // 2. Second pass: Try any matching title in search results
        for (final song in results) {
          final candTitle = _normalize((song['title'] ?? song['song'] ?? '').toString());
          final simpleCand = _phoneticSimplify(candTitle);
          final matches = candTitle == normTarget ||
              candTitle.contains(normTarget) ||
              normTarget.contains(candTitle) ||
              (simpleTarget.isNotEmpty &&
                  (simpleCand == simpleTarget ||
                      simpleCand.contains(simpleTarget) ||
                      simpleTarget.contains(simpleCand)));

          if (matches) {
            final moreInfo = song['more_info'] as Map<String, dynamic>? ?? {};
            final lid = moreInfo['lyrics_id']?.toString().trim();
            final pid = (lid != null && lid.isNotEmpty && lid != 'null')
                ? lid
                : song['id']?.toString();
            if (pid != null && pid.isNotEmpty) {
              return pid;
            }
          }
        }
      }

      // Fallback: autocomplete endpoint
      final acUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=${Uri.encodeComponent(cleanTitle)}&_format=json&_marker=0&ctx=web6dot0',
      );
      final acReq = await _httpClient.getUrl(acUri).timeout(const Duration(seconds: 4));
      acReq.headers.set('User-Agent', _userAgent);
      final acRes = await acReq.close().timeout(const Duration(seconds: 4));
      if (acRes.statusCode == 200) {
        final acBody = await acRes.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
        final acJson = jsonDecode(acBody) as Map<String, dynamic>;
        final songsObj = acJson['songs'];
        if (songsObj is Map<String, dynamic>) {
          final songList = (songsObj['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          for (final song in songList) {
            final candTitle = _normalize((song['title'] ?? '').toString());
            if (candTitle == normTarget ||
                candTitle.contains(normTarget) ||
                normTarget.contains(candTitle)) {
              final pid = song['id']?.toString();
              if (pid != null && pid.isNotEmpty) {
                return pid;
              }
            }
          }
          if (songList.isNotEmpty) {
            return songList.first['id']?.toString();
          }
        }
      }

      return null;
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

  static String _phoneticSimplify(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'([aeiou])\1+'), r'$1')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
