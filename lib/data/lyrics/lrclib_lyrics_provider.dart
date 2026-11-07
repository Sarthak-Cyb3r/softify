import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'spotify_lyrics_synchronizer.dart';

class LrclibLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final Map<String, SyncedLyrics?> _memoryCache = {};

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  LrclibLyricsProvider({HttpClient? httpClient})
      : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 45)
              ..maxConnectionsPerHost = 4);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_memoryCache.containsKey(track.id) &&
        _memoryCache[track.id] != null &&
        _memoryCache[track.id]!.isSynced) {
      return _memoryCache[track.id];
    }

    try {
      final cleanTitle = SpotifyLyricsSynchronizer.cleanTrackTitle(track.title);
      final cleanArtist = SpotifyLyricsSynchronizer.cleanArtistName(track.artist);

      // Extract title candidates: cleaned title, bare title without brackets/parentheses, dash split
      final candidateTitles = <String>{
        cleanTitle,
        if (cleanTitle.contains(RegExp(r'[\(\[]')))
          cleanTitle.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '').trim(),
        if (track.title.contains(' - '))
          track.title.split(' - ').first.trim(),
        track.title.trim(),
      }.where((t) => t.isNotEmpty).toList();

      final bareTitle = candidateTitles.length > 1 ? candidateTitles[1] : cleanTitle;

      // Extract artist candidates: primary artist, full string, and split individuals
      final candidateArtists = <String>{
        cleanArtist.split(RegExp(r'[,/;&]|\s+feat\.?|\s+ft\.?|\s+with\b', caseSensitive: false)).first.trim(),
        cleanArtist,
        ...cleanArtist
            .split(RegExp(r'[,/;&]|\s+feat\.?|\s+ft\.?|\s+with\b', caseSensitive: false))
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty),
      }.where((a) => a.isNotEmpty).toList();

      final primaryArtist = candidateArtists.isNotEmpty ? candidateArtists.first : cleanArtist;

      // Build targeted search queries prioritized for fast synced resolution
      final searchQueries = <String>{
        if (primaryArtist.isNotEmpty) '$cleanTitle $primaryArtist'.trim(),
        if (bareTitle.isNotEmpty && bareTitle != cleanTitle && primaryArtist.isNotEmpty)
          '$bareTitle $primaryArtist'.trim(),
        if (candidateArtists.length > 2 && candidateArtists[2].isNotEmpty)
          '$cleanTitle ${candidateArtists[2]}'.trim(),
        cleanTitle,
        if (bareTitle.isNotEmpty && bareTitle != cleanTitle) bareTitle,
      }.toList();

      // 1. High-speed multi-query search with full payload retrieval
      final searchResult = await _searchLyrics(track, searchQueries, candidateTitles);
      if (searchResult != null && searchResult.isSynced && searchResult.lines.isNotEmpty) {
        _memoryCache[track.id] = searchResult;
        return searchResult;
      }

      // 2. Exact match fallback with cleanTitle and primaryArtist
      final exactResult = await _tryExactGet(cleanTitle, primaryArtist, track.duration, track.id);
      if (exactResult != null && exactResult.isSynced && exactResult.lines.isNotEmpty) {
        _memoryCache[track.id] = exactResult;
        return exactResult;
      }

      // 3. Fallback to plain lyrics candidate if no synced lyrics could be found
      final plainResult = (searchResult != null && !searchResult.isSynced)
          ? searchResult
          : (exactResult != null && !exactResult.isSynced ? exactResult : null);

      if (plainResult != null) {
        _memoryCache[track.id] = plainResult;
        return plainResult;
      }

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
    final targetSec = duration.inSeconds.toDouble();
    // 1. Try with duration parameter first
    if (duration.inSeconds > 0) {
      final withDur = await _executeExactGet(
        {
          'track_name': title,
          'artist_name': artist,
          'duration': duration.inSeconds.toString(),
        },
        trackId,
        targetSec,
      );
      if (withDur != null) return withDur;
    }

    // 2. Retry without duration parameter (handles slight duration deviations across platforms)
    return _executeExactGet(
      {
        'track_name': title,
        'artist_name': artist,
      },
      trackId,
      targetSec,
    );
  }

  Future<SyncedLyrics?> _executeExactGet(
    Map<String, String> queryParams,
    String trackId,
    double targetSec,
  ) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 3));
      request.headers.set('User-Agent', _userAgent);

      var response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode == 503) {
        // Handle transient Cloudflare / LRCLIB ServerOverloaded rate limits
        await Future.delayed(const Duration(milliseconds: 600));
        final retryReq = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 2));
        retryReq.headers.set('User-Agent', _userAgent);
        response = await retryReq.close().timeout(const Duration(seconds: 2));
      }

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
        final json = jsonDecode(body) as Map<String, dynamic>;
        final syncedLrc = json['syncedLyrics'] as String?;
        final plainLyrics = json['plainLyrics'] as String?;
        final candDur = (json['duration'] as num?)?.toDouble() ?? 0.0;

        if (json['instrumental'] == true) {
          final trackName = queryParams['track_name'] ?? (json['trackName'] as String? ?? '');
          final isExplicitInstrumental = RegExp(
            r'\b(?:instrumental|karaoke|backing track|minus one)\b',
            caseSensitive: false,
          ).hasMatch(trackName);
          if (isExplicitInstrumental) {
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
          // Do not mask vocal tracks as instrumental; allow fallbacks to resolve lyrics
          return null;
        }

        final durationMismatch =
            targetSec > 30 && candDur > 0 && !isDurationAcceptable(candDur, targetSec);

        if (syncedLrc != null && syncedLrc.trim().isNotEmpty && !durationMismatch) {
          final lines = parseLrc(syncedLrc);
          if (lines.isNotEmpty && isLrcCoverageValid(lines, targetSec)) {
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

  Future<SyncedLyrics?> _searchLyrics(
    Track track,
    List<String> queries,
    List<String> candidateTitles,
  ) async {
    try {
      SyncedLyrics? plainCandidate;

      for (final query in queries) {
        final uri = Uri.https('lrclib.net', '/api/search', {'q': query});
        final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 4));
        request.headers.set('User-Agent', _userAgent);

        var response = await request.close().timeout(const Duration(seconds: 4));
        if (response.statusCode == 503) {
          await Future.delayed(const Duration(milliseconds: 600));
          final retryReq = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 3));
          retryReq.headers.set('User-Agent', _userAgent);
          response = await retryReq.close().timeout(const Duration(seconds: 3));
        }
        if (response.statusCode != 200) continue;

        final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
        final list = jsonDecode(body) as List<dynamic>;
        if (list.isEmpty) continue;

        final matchingItems = list.cast<Map<String, dynamic>>().where((item) {
          final candName = (item['trackName'] ?? item['name'] ?? '').toString();
          return candidateTitles.any((t) => _isTitleMatch(t, candName));
        }).toList();

        if (matchingItems.isEmpty) continue;

        final targetSec = track.duration.inSeconds.toDouble();

        // 1. Prioritize line-synced lyrics with acceptable duration and coverage
        final syncedCandidates = matchingItems.where((item) {
          final synced = item['syncedLyrics'] as String?;
          return synced != null && synced.trim().isNotEmpty;
        }).toList();

        if (syncedCandidates.isNotEmpty) {
          final viable = targetSec > 30
              ? syncedCandidates.where((c) {
                  final dur = (c['duration'] as num?)?.toDouble() ?? 0.0;
                  return dur > 0 && isDurationAcceptable(dur, targetSec);
                }).toList()
              : syncedCandidates;

          if (targetSec > 30 && viable.isNotEmpty) {
            viable.sort((a, b) {
              final durA = (a['duration'] as num?)?.toDouble() ?? 0.0;
              final durB = (b['duration'] as num?)?.toDouble() ?? 0.0;
              return (durA - targetSec).abs().compareTo((durB - targetSec).abs());
            });
          }

          for (final cand in viable) {
            final syncedLrc = cand['syncedLyrics'] as String?;
            final plainLyrics = cand['plainLyrics'] as String?;
            if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
              final lines = parseLrc(syncedLrc);
              if (lines.isNotEmpty && isLrcCoverageValid(lines, targetSec)) {
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
        }

        // 2. Keep plain lyrics candidate, but continue evaluating remaining search queries
        for (final item in matchingItems) {
          final plain = item['plainLyrics'] as String?;
          if (plain != null && plain.trim().isNotEmpty) {
            plainCandidate ??= SyncedLyrics(
              trackId: track.id,
              lines: const [],
              plainLyrics: plain.trim(),
              syncType: 'UNSYNCED',
              providerName: 'LRCLIB (Plain)',
            );
            break;
          }
        }
      }

      return plainCandidate;
    } catch (_) {
      return null;
    }
  }

  /// Parses an LRC timestamped string into a List of LyricLine items.
  static List<LyricLine> parseLrc(String syncedLrc) {
    final List<LyricLine> lines = [];
    final rawLines = syncedLrc.split('\n');

    // Parse standard LRC header offset tag [offset:+/-ms] if present
    int globalOffsetMs = 0;
    for (final line in rawLines) {
      final trimmed = line.trim();
      final offsetMatch = RegExp(r'^\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false).firstMatch(trimmed);
      if (offsetMatch != null) {
        globalOffsetMs = int.tryParse(offsetMatch.group(1)!) ?? 0;
        break;
      }
    }

    final tagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Extract all timestamp tags on this line (supports repeated chorus tags e.g. [00:10.00][01:20.00]Lyric)
      final tagMatches = tagRegex.allMatches(trimmed).toList();
      if (tagMatches.isEmpty) continue;

      final lastTagEnd = tagMatches.last.end;
      String rawText = trimmed.substring(lastTagEnd).trim();

      // Check for duet vocalist agent tags: {agent:v1}, [agent:v2], {v1}, etc.
      String? agent;
      final agentMatch = RegExp(r'[\{\[]agent:?\s*([a-zA-Z0-9_-]+)[\}\]]', caseSensitive: false).firstMatch(rawText);
      if (agentMatch != null) {
        agent = agentMatch.group(1);
        rawText = rawText.replaceFirst(agentMatch.group(0)!, '').trim();
      }

      // Check for enhanced word-level LRC tags: <mm:ss.xx>word
      final wordRegex = RegExp(r'<(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?>([^<]*)');
      final wordMatches = wordRegex.allMatches(rawText).toList();
      List<LyricWord>? words;
      String cleanText = rawText;

      if (wordMatches.isNotEmpty) {
        final tempWords = <LyricWord>[];
        final buffer = StringBuffer();
        for (final wm in wordMatches) {
          final wMin = int.parse(wm.group(1)!);
          final wSec = int.parse(wm.group(2)!);
          final wMilliRaw = wm.group(3);
          int wMillis = 0;
          if (wMilliRaw != null) {
            if (wMilliRaw.length == 1) {
              wMillis = int.parse(wMilliRaw) * 100;
            } else if (wMilliRaw.length == 2) {
              wMillis = int.parse(wMilliRaw) * 10;
            } else {
              wMillis = int.parse(wMilliRaw.substring(0, 3));
            }
          }
          final wText = wm.group(4) ?? '';
          final totalMs = wMin * 60000 + wSec * 1000 + wMillis + globalOffsetMs;
          tempWords.add(
            LyricWord(
              timestamp: Duration(milliseconds: totalMs < 0 ? 0 : totalMs),
              text: wText.trim(),
            ),
          );
          buffer.write(wText);
        }
        if (tempWords.isNotEmpty) {
          words = [];
          for (int w = 0; w < tempWords.length; w++) {
            final nextStart = (w + 1 < tempWords.length) ? tempWords[w + 1].timestamp : null;
            final duration = nextStart != null ? (nextStart - tempWords[w].timestamp) : null;
            words.add(LyricWord(
              timestamp: tempWords[w].timestamp,
              text: tempWords[w].text,
              duration: duration,
            ));
          }
        }
        cleanText = buffer.toString().trim();
      }

      for (final tm in tagMatches) {
        final minutes = int.parse(tm.group(1)!);
        final seconds = int.parse(tm.group(2)!);
        final millisRaw = tm.group(3);
        int millis = 0;
        if (millisRaw != null) {
          if (millisRaw.length == 1) {
            millis = int.parse(millisRaw) * 100;
          } else if (millisRaw.length == 2) {
            millis = int.parse(millisRaw) * 10;
          } else {
            millis = int.parse(millisRaw.substring(0, 3));
          }
        }

        final totalMs = minutes * 60000 + seconds * 1000 + millis + globalOffsetMs;
        final lineDuration = Duration(milliseconds: totalMs < 0 ? 0 : totalMs);

        lines.add(
          LyricLine(
            timestamp: lineDuration,
            text: cleanText,
            words: words,
            agent: agent,
          ),
        );
      }
    }

    // Sort chronologically in case of out-of-order or multi-timestamp lines
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Filter out duplicate-timestamp translation/sub-caption lines (e.g. "(English translation)")
    final List<LyricLine> deduped = [];
    for (final l in lines) {
      if (deduped.isNotEmpty &&
          (l.timestamp - deduped.last.timestamp).inMilliseconds.abs() < 50) {
        final isEnclosedTranslation =
            (l.text.startsWith('(') && l.text.endsWith(')')) ||
            (l.text.startsWith('[') && l.text.endsWith(']')) ||
            (l.text.startsWith('（') && l.text.endsWith('）'));
        if (isEnclosedTranslation) {
          continue;
        }
      }
      deduped.add(l);
    }
    return deduped;
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

  static bool isDurationAcceptable(double candidateSec, double targetSec) {
    if (targetSec <= 30) return true;
    final diff = (candidateSec - targetSec).abs();
    if (targetSec <= 300) {
      return diff <= 25; // 25s tolerance for normal songs <= 5 min
    } else if (targetSec <= 600) {
      return diff <= 45; // 45s tolerance for 5-10 min songs
    } else {
      // For long tracks (>10 min), max 15% tolerance or 90s
      final maxDiff = math.max(60.0, targetSec * 0.15);
      return diff <= maxDiff;
    }
  }

  static bool isLrcCoverageValid(List<LyricLine> lines, double targetSec) {
    if (lines.isEmpty) return false;
    if (targetSec <= 60) return true;
    final lastTs = lines.last.timestamp.inSeconds;
    // Last line must occur within at least 55% of track duration (or if track is huge, not end >60s early)
    if (lastTs < targetSec * 0.55 && (targetSec - lastTs) > 60) {
      return false;
    }
    return true;
  }
}
