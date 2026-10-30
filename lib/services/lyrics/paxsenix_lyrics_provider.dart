import 'dart:convert';
import 'dart:io';

import '../../data/lyrics/lrclib_lyrics_provider.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'ttml_parser.dart';

/// Search candidate result from Apple Music catalog API.
class PaxsenixSearchResult {
  final String id;
  final String trackName;
  final String artistName;
  final String? albumName;
  final int? durationSec;

  const PaxsenixSearchResult({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.durationSec,
  });

  String get displayName => trackName;
  String get displayArtist => artistName;
}

/// Token manager that acquires and caches anonymous Apple Music web bearer tokens.
class AppleTokenManager {
  final HttpClient? _httpClient;
  String? _cachedToken;

  AppleTokenManager({
    HttpClient? httpClient,
    String? presetToken,
  })  : _httpClient = httpClient,
        _cachedToken = presetToken;

  String? get cachedToken => _cachedToken;

  void clearToken() {
    _cachedToken = null;
  }

  Future<String> getToken([HttpClient? fallbackClient]) async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken!;
    }
    final client = _httpClient ?? fallbackClient ?? HttpClient();
    try {
      // 1. Fetch beta.music.apple.com to locate index~*.js
      final req1 = await client
          .getUrl(Uri.parse('https://beta.music.apple.com'))
          .timeout(const Duration(seconds: 4));
      req1.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Softify/1.0',
      );
      final res1 = await req1.close().timeout(const Duration(seconds: 4));
      final body1 = await res1.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));

      final indexJsRegex = RegExp(r'/assets/index~[^/]+\.js');
      final indexJsMatch = indexJsRegex.firstMatch(body1);
      if (indexJsMatch == null) {
        throw StateError('Could not find index JS URL in Apple Music web page');
      }

      final indexJsUri = indexJsMatch.group(0)!;
      final req2 = await client
          .getUrl(Uri.parse('https://beta.music.apple.com$indexJsUri'))
          .timeout(const Duration(seconds: 4));
      req2.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Softify/1.0',
      );
      final res2 = await req2.close().timeout(const Duration(seconds: 4));
      final body2 = await res2.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));

      final tokenRegex = RegExp(
        r'eyJ[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+',
      );
      final tokenMatch = tokenRegex.firstMatch(body2);
      if (tokenMatch == null) {
        throw StateError('Could not extract bearer token from Apple Music JS bundle');
      }

      _cachedToken = tokenMatch.group(0)!;
      return _cachedToken!;
    } catch (e) {
      throw StateError('Error fetching Apple Music token: $e');
    }
  }
}

/// Reverse-engineered Paxsenix & Apple Music lyrics provider.
/// Hits `https://lyrics.paxsenix.org` and Apple Music Catalog API.
class PaxsenixLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final String _baseUrl;
  final String _appleApiBase;
  final AppleTokenManager _tokenManager;
  final Map<String, SyncedLyrics?> _cache = {};

  static const String defaultEndpoint = 'https://lyrics.paxsenix.org';
  static const String defaultAppleApiBase =
      'https://amp-api.music.apple.com/v1/catalog/us';

  PaxsenixLyricsProvider({
    HttpClient? httpClient,
    String? baseUrl,
    String? appleApiBase,
    String? appleToken,
  })  : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 30)
              ..maxConnectionsPerHost = 4),
        _baseUrl = baseUrl ?? defaultEndpoint,
        _appleApiBase = appleApiBase ?? defaultAppleApiBase,
        _tokenManager = AppleTokenManager(
          httpClient: httpClient,
          presetToken: appleToken,
        );

  static final List<RegExp> titleCleanupPatterns = [
    RegExp(
      r'\s*\(.*?(official|video|audio|lyrics|lyric|visualizer|hd|hq|4k|remaster|remix|live|acoustic|version|edit|extended|radio|clean|explicit).*?\)',
      caseSensitive: false,
    ),
    RegExp(
      r'\s*\[.*?(official|video|audio|lyrics|lyric|visualizer|hd|hq|4k|remaster|remix|live|acoustic|version|edit|extended|radio|clean|explicit).*?\]',
      caseSensitive: false,
    ),
    RegExp(r'\s*【.*?】'),
    RegExp(r'\s*\|.*$'),
    RegExp(
      r'\s*-\s*(official|video|audio|lyrics|lyric|visualizer).*$',
      caseSensitive: false,
    ),
    RegExp(r'\s*\(feat\..*?\)', caseSensitive: false),
    RegExp(r'\s*\(ft\..*?\)', caseSensitive: false),
    RegExp(r'\s*feat\..*$', caseSensitive: false),
    RegExp(r'\s*ft\..*$', caseSensitive: false),
    RegExp(r'\s*\([^)]*\d{4}[^)]*\)', caseSensitive: false),
  ];

  static const List<String> artistSeparators = [
    ' & ',
    ' and ',
    ', ',
    ' x ',
    ' X ',
    ' feat. ',
    ' feat ',
    ' ft. ',
    ' ft ',
    ' featuring ',
    ' with ',
  ];

  /// Sanitizes title string according to Metrolist's regex filters.
  static String cleanTitle(String title) {
    var cleaned = title.trim();
    for (final pattern in titleCleanupPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    return cleaned.trim();
  }

  /// Sanitizes artist string according to Metrolist's separator rules.
  static String cleanArtist(String artist) {
    var cleaned = artist.trim();
    for (final separator in artistSeparators) {
      final idx = cleaned.toLowerCase().indexOf(separator.toLowerCase());
      if (idx != -1) {
        cleaned = cleaned.substring(0, idx);
        break;
      }
    }
    return cleaned.trim();
  }

  /// Queries Apple Music catalog API for songs matching [query].
  Future<List<PaxsenixSearchResult>> search(String query) async {
    try {
      final token = await _tokenManager.getToken(_httpClient);
      return await _searchWithToken(token, query);
    } catch (_) {
      _tokenManager.clearToken();
      try {
        final newToken = await _tokenManager.getToken(_httpClient);
        return await _searchWithToken(newToken, query);
      } catch (_) {
        return const [];
      }
    }
  }

  Future<List<PaxsenixSearchResult>> _searchWithToken(
    String token,
    String query,
  ) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final searchUri = Uri.parse(
        '$_appleApiBase/search?term=$encodedQuery&types=songs&limit=25&l=en-US&platform=web&format[resources]=map&include[songs]=artists&extend=artistUrl',
      );
      final req =
          await _httpClient.getUrl(searchUri).timeout(const Duration(seconds: 4));
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.set('Origin', 'https://music.apple.com');
      req.headers.set('Referer', 'https://music.apple.com/');
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:95.0) Gecko/20100101 Firefox/95.0',
      );
      req.headers.set('Accept', 'application/json');
      req.headers.set('Accept-Language', 'en-US,en;q=0.5');
      req.headers.set('x-apple-renewal', 'true');

      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode == 401) {
        throw const HttpException('Unauthorized (401)');
      }
      if (res.statusCode != 200) {
        return const [];
      }

      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
      final map = jsonDecode(body) as Map<String, dynamic>;
      final results = map['results'] as Map<String, dynamic>?;
      final songsObj = results?['songs'] as Map<String, dynamic>?;
      final songDataList =
          (songsObj?['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      final resources = map['resources'] as Map<String, dynamic>?;
      final songMap = resources?['songs'] as Map<String, dynamic>?;

      final searchResults = <PaxsenixSearchResult>[];
      for (final songData in songDataList) {
        final id = songData['id']?.toString() ?? '';
        final detail = songMap?[id] as Map<String, dynamic>?;
        if (detail == null) continue;
        final attr = detail['attributes'] as Map<String, dynamic>?;
        if (attr == null) continue;

        final durMs = (attr['durationInMillis'] as num?)?.toInt();
        searchResults.add(
          PaxsenixSearchResult(
            id: id,
            trackName: (attr['name'] as String?) ?? '',
            artistName: (attr['artistName'] as String?) ?? '',
            albumName: attr['albumName'] as String?,
            durationSec: durMs != null ? durMs ~/ 1000 : null,
          ),
        );
      }
      return searchResults;
    } catch (e) {
      if (e is HttpException) rethrow;
      return const [];
    }
  }

  /// Scores and filters Apple Music search results against target track metadata.
  static List<MapEntry<PaxsenixSearchResult, double>> scoreAndFilterResults(
    List<PaxsenixSearchResult> results,
    String title,
    String artist,
    int durationSec,
  ) {
    final durationMs = durationSec * 1000;
    final cleanupRegex = RegExp(r'\s*\(.*?\)|\s*\[.*?\]');
    final cleanedTitle =
        title.replaceAll(cleanupRegex, '').toLowerCase().trim();
    final cleanedArtist = cleanArtist(artist).toLowerCase();

    final targetIsMixed = title.toLowerCase().contains('mixed');
    final targetIsRemix = title.toLowerCase().contains('remix');

    final scored = <MapEntry<PaxsenixSearchResult, double>>[];

    for (final result in results) {
      double score = 0.0;
      final resultTitle = result.displayName;
      final resultArtist = result.displayArtist;

      if (result.durationSec != null && durationMs > 0) {
        final resultDurMs = result.durationSec! * 1000;
        final diff = (resultDurMs - durationMs).abs();
        if (diff <= 2000) {
          score += 100;
        } else if (diff <= 5000) {
          score += 50;
        } else if (diff <= 10000) {
          score += 10;
        } else {
          score -= 50;
        }
      }

      final resultTitleCleaned =
          resultTitle.replaceAll(cleanupRegex, '').toLowerCase().trim();
      if (resultTitleCleaned == cleanedTitle) {
        score += 80;
      } else if (resultTitleCleaned.contains(cleanedTitle) ||
          cleanedTitle.contains(resultTitleCleaned)) {
        score += 40;
      }

      // Version mismatch penalties
      final resultIsMixed = resultTitle.toLowerCase().contains('mixed');
      final resultIsRemix = resultTitle.toLowerCase().contains('remix');

      if (resultIsMixed && !targetIsMixed) score -= 60;
      if (resultIsRemix && !targetIsRemix) score -= 40;

      final resultArtistLower = resultArtist.toLowerCase();
      if (resultArtistLower.contains(cleanedArtist)) {
        score += 50;
      } else {
        final artistWords =
            cleanedArtist.split(RegExp(r'\s+')).where((w) => w.length > 2);
        if (artistWords.any((w) => resultArtistLower.contains(w))) {
          score += 25;
        }
      }

      if (score > 0) {
        scored.add(MapEntry(result, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(10).toList();
  }

  /// Calculates quality score: 3 = syllable/word, 2 = line, 1 = plain, 0 = empty.
  static int getQuality(SyncedLyrics lyrics) {
    if (lyrics.isSyllableSynced) return 3;
    if (lyrics.isSynced) return 2;
    if (lyrics.plainLyrics != null && lyrics.plainLyrics!.trim().isNotEmpty) {
      return 1;
    }
    return 0;
  }

  /// Fetches and parses lyrics for a specific Apple Music track ID from Paxsenix.
  Future<SyncedLyrics?> fetchLyricsForTrack(
    String appleTrackId,
    String originalTrackId,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/apple-music/lyrics?id=$appleTrackId');
      final req =
          await _httpClient.getUrl(uri).timeout(const Duration(seconds: 3));
      req.headers.set(
        'User-Agent',
        'Softify/1.0 (https://github.com/softify/softify)',
      );
      req.headers.set('Accept', 'application/json');

      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;

      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 3));
      final map = jsonDecode(body) as Map<String, dynamic>;

      // 1. TTML content has highest fidelity
      final ttml = map['ttmlContent'] as String?;
      if (ttml != null && ttml.trim().isNotEmpty) {
        final parsed = TTMLParser.parseTTML(ttml);
        if (parsed.isNotEmpty) {
          return TTMLParser.toSyncedLyrics(
            originalTrackId,
            parsed,
            providerName: 'Paxsenix (TTML)',
          );
        }
      }

      // 2. ELRC multi-person or standard ELRC
      final elrcMulti = map['elrcMultiPerson'] as String?;
      if (elrcMulti != null && elrcMulti.trim().isNotEmpty) {
        final lines = LrclibLyricsProvider.parseLrc(elrcMulti);
        if (lines.isNotEmpty) {
          final isWordSynced =
              lines.any((l) => l.words != null && l.words!.isNotEmpty);
          return SyncedLyrics(
            trackId: originalTrackId,
            lines: lines,
            rawLrc: elrcMulti,
            plainLyrics: lines.map((l) => l.text).join('\n'),
            syncType: isWordSynced ? 'SYLLABLE_SYNCED' : 'LINE_SYNCED',
            providerName: 'Paxsenix (ELRC MultiPerson)',
          );
        }
      }

      final elrc = map['elrc'] as String?;
      if (elrc != null && elrc.trim().isNotEmpty) {
        final lines = LrclibLyricsProvider.parseLrc(elrc);
        if (lines.isNotEmpty) {
          final isWordSynced =
              lines.any((l) => l.words != null && l.words!.isNotEmpty);
          return SyncedLyrics(
            trackId: originalTrackId,
            lines: lines,
            rawLrc: elrc,
            plainLyrics: lines.map((l) => l.text).join('\n'),
            syncType: isWordSynced ? 'SYLLABLE_SYNCED' : 'LINE_SYNCED',
            providerName: 'Paxsenix (ELRC)',
          );
        }
      }

      // 3. Plain lyrics
      final plain = map['plain'] as String?;
      if (plain != null && plain.trim().isNotEmpty) {
        return SyncedLyrics(
          trackId: originalTrackId,
          lines: const [],
          plainLyrics: plain.trim(),
          syncType: 'UNSYNCED',
          providerName: 'Paxsenix (Plain)',
        );
      }

      // 4. Content array
      final content = map['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        final type = map['type'] as String?;
        final isSyllable = type == 'Syllable';

        if (!isSyllable) {
          final plainLines = content
              .map((line) {
                final wordsRaw = line['text'] as List<dynamic>?;
                return wordsRaw
                        ?.map((w) => (w['text'] as String?) ?? '')
                        .join(' ') ??
                    '';
              })
              .where((l) => l.trim().isNotEmpty)
              .join('\n');

          if (plainLines.isNotEmpty) {
            return SyncedLyrics(
              trackId: originalTrackId,
              lines: const [],
              plainLyrics: plainLines,
              syncType: 'UNSYNCED',
              providerName: 'Paxsenix',
            );
          }
        } else {
          final lines = <LyricLine>[];
          for (final line in content) {
            final timeMs = (line['timestamp'] as num?)?.toInt() ?? 0;
            final wordsRaw = line['text'] as List<dynamic>?;
            List<LyricWord>? words;
            String lineText = '';
            if (wordsRaw != null && wordsRaw.isNotEmpty) {
              final wordsList = <LyricWord>[];
              final parts = <String>[];
              for (final w in wordsRaw) {
                final wText = (w['text'] as String?) ?? '';
                final wStart = (w['timestamp'] as num?)?.toInt() ?? 0;
                final wEnd = (w['endtime'] as num?)?.toInt() ?? wStart;
                final dur = wEnd > wStart
                    ? Duration(milliseconds: wEnd - wStart)
                    : null;
                wordsList.add(
                  LyricWord(
                    timestamp: Duration(milliseconds: wStart),
                    text: wText,
                    duration: dur,
                  ),
                );
                parts.add(wText);
              }
              words = wordsList;
              lineText = parts.join(' ');
            }
            if (lineText.trim().isNotEmpty) {
              lines.add(
                LyricLine(
                  timestamp: Duration(milliseconds: timeMs),
                  text: lineText.trim(),
                  words: words,
                ),
              );
            }
          }
          if (lines.isNotEmpty) {
            return SyncedLyrics(
              trackId: originalTrackId,
              lines: lines,
              plainLyrics: lines.map((l) => l.text).join('\n'),
              syncType: 'SYLLABLE_SYNCED',
              providerName: 'Paxsenix (Content)',
            );
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    try {
      // 1. Direct fetch if sourceId is numeric Apple Music ID
      if (track.sourceId.isNotEmpty &&
          RegExp(r'^\d+$').hasMatch(track.sourceId)) {
        final direct = await fetchLyricsForTrack(track.sourceId, track.id);
        if (direct != null) {
          _cache[track.id] = direct;
          return direct;
        }
      }

      final cleanedTitle = cleanTitle(track.title);
      final cleanedArtist = cleanArtist(track.artist);

      final searchQueries = <String>[
        if (cleanedArtist.isNotEmpty) '$cleanedTitle $cleanedArtist'.trim(),
        cleanedTitle,
        if (track.album != null && track.album!.trim().isNotEmpty)
          '$cleanedTitle $cleanedArtist ${track.album!.trim()}'.trim(),
      ];

      List<MapEntry<PaxsenixSearchResult, double>> scoredCandidates = [];
      for (final query in searchQueries) {
        if (scoredCandidates.isEmpty && query.isNotEmpty) {
          final results = await search(query);
          if (results.isNotEmpty) {
            scoredCandidates = scoreAndFilterResults(
              results,
              track.title,
              track.artist,
              track.duration.inSeconds,
            );
          }
        }
      }

      if (scoredCandidates.isEmpty) {
        _cache[track.id] = null;
        return null;
      }

      SyncedLyrics? bestLyrics;
      int bestQuality = 0;

      for (final candidate in scoredCandidates.take(2)) {
        final lyrics = await fetchLyricsForTrack(candidate.key.id, track.id);
        if (lyrics == null) break;

        final quality = getQuality(lyrics);
        if (quality > bestQuality) {
          bestQuality = quality;
          bestLyrics = lyrics;
        }

        if (bestQuality == 3) break; // Word-synced is best
      }

      _cache[track.id] = bestLyrics;
      return bestLyrics;
    } catch (_) {
      _cache[track.id] = null;
      return null;
    }
  }

  void clearCache() => _cache.clear();
}
