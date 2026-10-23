import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'spotify_lyrics_synchronizer.dart';

class LrclibLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final Map<String, SyncedLyrics?> _memoryCache = {};

  LrclibLyricsProvider({HttpClient? httpClient})
      : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 45)
              ..maxConnectionsPerHost = 4);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_memoryCache.containsKey(track.id)) {
      return _memoryCache[track.id];
    }

    try {
      final cleanTitle = SpotifyLyricsSynchronizer.cleanTrackTitle(track.title);
      final cleanArtist = SpotifyLyricsSynchronizer.cleanArtistName(track.artist);
      final primaryArtist = cleanArtist
          .split(RegExp(r',|\s+feat\.?|\s+ft\.?', caseSensitive: false))
          .first
          .trim();

      // 1. Try exact match with cleaned title & primary artist
      var result = await _tryExactGet(cleanTitle, primaryArtist, track.duration, track.id);
      if (result != null) {
        _memoryCache[track.id] = result;
        return result;
      }

      // 2. Try exact match with cleaned title & full cleaned artist
      if (cleanArtist.isNotEmpty && cleanArtist != primaryArtist) {
        result = await _tryExactGet(cleanTitle, cleanArtist, track.duration, track.id);
        if (result != null) {
          _memoryCache[track.id] = result;
          return result;
        }
      }

      // 3. Fallback to smart search with duration-proximity ranking
      final searchResult = await _searchFallback(track, cleanTitle, primaryArtist);
      if (searchResult != null) {
        _memoryCache[track.id] = searchResult;
        return searchResult;
      }

      _memoryCache[track.id] = null;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SyncedLyrics?> _tryExactGet(
    String title,
    String artist,
    Duration duration,
    String trackId,
  ) async {
    try {
      final queryParams = {
        'track_name': title,
        'artist_name': artist,
        if (duration.inSeconds > 0) 'duration': duration.inSeconds.toString(),
      };

      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 4));
      request.headers.set('User-Agent', 'Softify/1.0 (https://github.com/softify/softify)');

      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final syncedLrc = json['syncedLyrics'] as String?;
        final plainLyrics = json['plainLyrics'] as String?;

        if (json['instrumental'] == true) {
          return SyncedLyrics(
            trackId: trackId,
            lines: const [
              LyricLine(
                timestamp: Duration.zero,
                text: '[instrumental]',
              ),
            ],
            plainLyrics: '[instrumental]',
            syncType: 'LINE_SYNCED',
            providerName: 'LRCLIB (Instrumental)',
          );
        }

        if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
          final lines = parseLrc(syncedLrc);
          if (lines.isNotEmpty) {
            return SyncedLyrics(
              trackId: trackId,
              lines: lines,
              plainLyrics: plainLyrics,
              rawLrc: syncedLrc,
              syncType: 'LINE_SYNCED',
              providerName: 'LRCLIB',
            );
          }
        }

        if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
          return SyncedLyrics(
            trackId: trackId,
            lines: const [],
            plainLyrics: plainLyrics.trim(),
            syncType: 'UNSYNCED',
            providerName: 'LRCLIB (Plain)',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<SyncedLyrics?> _searchFallback(
    Track track,
    String cleanTitle,
    String primaryArtist,
  ) async {
    try {
      final query = '$cleanTitle $primaryArtist'.trim();

      final uri = Uri.https('lrclib.net', '/api/search', {'q': query});
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 4));
      request.headers.set('User-Agent', 'Softify/1.0 (https://github.com/softify/softify)');

      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final list = jsonDecode(body) as List<dynamic>;
      var candidates = list.cast<Map<String, dynamic>>().where((item) {
        final synced = item['syncedLyrics'] as String?;
        final candName = (item['trackName'] ?? item['name'] ?? '').toString();
        return (synced != null && synced.trim().isNotEmpty) && _isTitleMatch(cleanTitle, candName);
      }).toList();

      // If no candidates matched with artist included, retry search with clean title alone
      if (candidates.isEmpty && cleanTitle.length > 2) {
        try {
          final titleUri = Uri.https('lrclib.net', '/api/search', {'q': cleanTitle});
          final titleReq = await _httpClient.getUrl(titleUri).timeout(const Duration(seconds: 4));
          titleReq.headers.set('User-Agent', 'Softify/1.0 (https://github.com/softify/softify)');
          final titleRes = await titleReq.close().timeout(const Duration(seconds: 4));
          if (titleRes.statusCode == 200) {
            final titleBody = await titleRes.transform(utf8.decoder).join();
            final titleList = jsonDecode(titleBody) as List<dynamic>;
            candidates = titleList.cast<Map<String, dynamic>>().where((item) {
              final synced = item['syncedLyrics'] as String?;
              final candName = (item['trackName'] ?? item['name'] ?? '').toString();
              return (synced != null && synced.trim().isNotEmpty) && _isTitleMatch(cleanTitle, candName);
            }).toList();
          }
        } catch (_) {}
      }

      final target = track.duration.inSeconds.toDouble();

      if (candidates.isNotEmpty) {
        // Filter out tracks with massive duration mismatch (> 25s) when duration is known
        final viableCandidates = target > 30
            ? candidates.where((c) {
                final dur = (c['duration'] as num?)?.toDouble() ?? 0.0;
                return dur > 0 && (dur - target).abs() <= 25;
              }).toList()
            : candidates;

        final candidateList =
            viableCandidates.isNotEmpty ? viableCandidates : candidates;

        candidateList.sort((a, b) {
          final durA = (a['duration'] as num?)?.toDouble() ?? 0.0;
          final durB = (b['duration'] as num?)?.toDouble() ?? 0.0;
          return (durA - target).abs().compareTo((durB - target).abs());
        });

        final best = candidateList.first;
        final syncedLrc = best['syncedLyrics'] as String?;
        final plainLyrics = best['plainLyrics'] as String?;
        if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
          final lines = parseLrc(syncedLrc);
          if (lines.isNotEmpty) {
            return SyncedLyrics(
              trackId: track.id,
              lines: lines,
              plainLyrics: plainLyrics,
              rawLrc: syncedLrc,
              syncType: 'LINE_SYNCED',
              providerName: 'LRCLIB (Search)',
            );
          }
        }
      }

      // Check for plain lyrics or instrumental flag among search results
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        if (item['instrumental'] == true) {
          return SyncedLyrics(
            trackId: track.id,
            lines: const [
              LyricLine(
                timestamp: Duration.zero,
                text: '[instrumental]',
              ),
            ],
            plainLyrics: '[instrumental]',
            syncType: 'LINE_SYNCED',
            providerName: 'LRCLIB (Instrumental)',
          );
        }
        final plain = item['plainLyrics'] as String?;
        if (plain != null && plain.trim().isNotEmpty) {
          return SyncedLyrics(
            trackId: track.id,
            lines: const [],
            plainLyrics: plain.trim(),
            syncType: 'UNSYNCED',
            providerName: 'LRCLIB (Plain)',
          );
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parses an LRC timestamped string into a List of LyricLine items.
  static List<LyricLine> parseLrc(String syncedLrc) {
    final List<LyricLine> lines = [];
    final rawLines = syncedLrc.split('\n');
    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Parse LRC format: [mm:ss.xx] Lyrics
      final match = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(trimmed);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisRaw = match.group(3)!;
        final millis = millisRaw.length == 2
            ? int.parse(millisRaw) * 10
            : int.parse(millisRaw);
        final rawText = match.group(4)!.trim();

        // Check for enhanced word-level LRC tags: <mm:ss.xx>word
        final wordRegex = RegExp(r'<(\d{2}):(\d{2})\.(\d{2,3})>([^<]*)');
        final wordMatches = wordRegex.allMatches(rawText).toList();
        List<LyricWord>? words;
        String cleanText = rawText;

        if (wordMatches.isNotEmpty) {
          words = [];
          final buffer = StringBuffer();
          for (final wm in wordMatches) {
            final wMin = int.parse(wm.group(1)!);
            final wSec = int.parse(wm.group(2)!);
            final wMilliRaw = wm.group(3)!;
            final wMillis = wMilliRaw.length == 2
                ? int.parse(wMilliRaw) * 10
                : int.parse(wMilliRaw);
            final wText = wm.group(4) ?? '';
            words.add(
              LyricWord(
                timestamp: Duration(
                  minutes: wMin,
                  seconds: wSec,
                  milliseconds: wMillis,
                ),
                text: wText.trim(),
              ),
            );
            buffer.write(wText);
          }
          cleanText = buffer.toString().trim();
        }

        final lineDuration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );

        // Filter out duplicate-timestamp translation/sub-caption lines (e.g. "(English translation)")
        if (lines.isNotEmpty &&
            (lines.last.timestamp == lineDuration ||
                (lineDuration - lines.last.timestamp).inMilliseconds.abs() < 50)) {
          final isEnclosedTranslation =
              (cleanText.startsWith('(') && cleanText.endsWith(')')) ||
              (cleanText.startsWith('[') && cleanText.endsWith(']')) ||
              (cleanText.startsWith('（') && cleanText.endsWith('）'));
          if (isEnclosedTranslation) {
            // Drop duplicate translation line to preserve original primary vocals
            continue;
          }
        }

        lines.add(
          LyricLine(
            timestamp: lineDuration,
            text: cleanText,
            words: words,
          ),
        );
      }
    }
    return lines;
  }

  static bool _isTitleMatch(String targetTitle, String candidateName) {
    final normTarget = _normalizeTitle(targetTitle);
    final normCand = _normalizeTitle(candidateName);
    if (normTarget.isEmpty || normCand.isEmpty) return false;
    if (normTarget == normCand) return true;
    if (normCand.contains(normTarget) || normTarget.contains(normCand)) return true;

    final targetTokens = normTarget.split(' ').where((w) => w.isNotEmpty).toSet();
    final candTokens = normCand.split(' ').where((w) => w.isNotEmpty).toSet();
    if (targetTokens.isEmpty || candTokens.isEmpty) return false;
    final common = targetTokens.intersection(candTokens);
    return (common.length / targetTokens.length) >= 0.5;
  }

  static String _normalizeTitle(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
