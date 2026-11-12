import 'dart:async';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide StreamInfo;

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_stream_resolver.dart';
import 'piped_stream_resolver.dart';
import 'youtube_innertube_service.dart';

class YoutubeStreamResolver implements IStreamResolver {
  final YoutubeExplode _yt;
  final YoutubeInnertubeService _innertubeService;
  final PipedStreamResolver? _fallbackResolver;
  final Map<String, StreamInfo> _cache = {};
  static final Map<String, StreamInfo> _staticCache = {};

  static const String youtubeUserAgent =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11)';

  /// Pre-caches a freshly resolved stream so subsequent playback requires 0 extra network calls.
  static void precacheStream(String sourceId, StreamInfo stream) {
    for (final q in AudioQualityPreset.values) {
      _staticCache['${sourceId}_${q.name}'] = stream;
    }
  }

  YoutubeStreamResolver({
    YoutubeExplode? yt,
    YoutubeInnertubeService? innertubeService,
    PipedStreamResolver? fallbackResolver,
  })  : _yt = yt ?? YoutubeExplode(),
        _innertubeService = innertubeService ?? YoutubeInnertubeService(),
        _fallbackResolver = fallbackResolver ?? PipedStreamResolver();

  YoutubeExplode get yt => _yt;
  YoutubeInnertubeService get innertubeService => _innertubeService;

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    final cacheKey = '${track.sourceId}_${quality.name}';
    if (!forceFresh) {
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey]!;
        if (!cached.isExpired) return cached;
      }
      if (_staticCache.containsKey(cacheKey)) {
        final cached = _staticCache[cacheKey]!;
        if (!cached.isExpired) return cached;
      }
    }

    try {
      final rawSourceId = (track.sourceId.isNotEmpty ? track.sourceId : track.id)
          .replaceFirst('ytm_', '')
          .replaceFirst('yt_', '')
          .trim();
      List<String> candidateIds = [];

      // If sourceId is already a valid 11-char YouTube ID, prioritize it
      if (rawSourceId.length == 11 &&
          RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(rawSourceId) &&
          !rawSourceId.startsWith('itunes_')) {
        candidateIds.add(rawSourceId);
      } else {
        final cleanTitle = cleanSongTitle(track.title);
        final primaryArtist = track.artist.split(RegExp(r'[,/&]')).first.trim();

        final searchQueries = <String>[
          '$cleanTitle $primaryArtist'.trim(),
          if (track.artist != primaryArtist) '$cleanTitle ${track.artist}'.trim(),
          if (cleanTitle != track.title) '${track.title} $primaryArtist'.trim(),
          if (track.album != null && track.album!.isNotEmpty && track.album != track.title)
            '$cleanTitle ${track.album}'.trim(),
        ];

        // Priority 0: YouTube Music (WEB_REMIX) official tracks & Topic releases.
        for (final q in searchQueries) {
          try {
            final ytmTracks = await _innertubeService.searchMusic(q);
            if (ytmTracks.isNotEmpty) {
              final scored = ytmTracks
                  .map((c) => (candidate: c, score: _scoreYtmCandidate(targetTrack: track, candidate: c)))
                  .where((pair) => pair.score >= 70)
                  .toList();
              scored.sort((a, b) => b.score.compareTo(a.score));
              for (final pair in scored) {
                if (!candidateIds.contains(pair.candidate.videoId)) {
                  candidateIds.add(pair.candidate.videoId);
                }
              }
            }
          } catch (_) {}
          if (candidateIds.isNotEmpty) break;
        }

        // Fallback 1: YouTube video catalog fallback only if YouTube Music yielded zero verified candidates
        if (candidateIds.isEmpty) {
          for (final q in searchQueries.take(2)) {
            try {
              final searchResults =
                  await _yt.search.search(q).timeout(const Duration(seconds: 5));
              if (searchResults.isNotEmpty) {
                final scored = searchResults
                    .take(10)
                    .map((v) => (
                          video: v,
                          score: _scoreCandidate(
                            targetTitle: track.title,
                            targetArtist: track.artist,
                            targetDuration: track.duration,
                            candidate: v,
                          ),
                        ))
                    .where((pair) => pair.score >= 70)
                    .toList();
                scored.sort((a, b) => b.score.compareTo(a.score));

                for (final pair in scored) {
                  if (!candidateIds.contains(pair.video.id.value)) {
                    candidateIds.add(pair.video.id.value);
                  }
                }
              }
            } catch (_) {}
            if (candidateIds.isNotEmpty) break;
          }
        }

        if (candidateIds.isEmpty) {
          throw Exception('No verified audio candidates found for "${track.title}" by ${track.artist}');
        }
      }
 
      // Priority 0: Desktop Native Stream Resolver (yt-dlp bypasses YouTube throttling and PO-tokens on Linux/macOS/Windows)
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        for (final candId in candidateIds) {
          final stream = await _resolveViaDesktopYtDlp(candId);
          if (stream != null) {
            _cache[cacheKey] = stream;
            return stream;
          }
        }
      }

      // Priority 1: Instant InnerTube direct audio resolution (universal fallback on desktop, primary on mobile)
      for (final candId in candidateIds) {
          try {
            final data = await _innertubeService.queryPlayer(candId);
            if (data != null) {
              // Guard against wrong track mismatch when candidate was resolved from search
              if (candId != rawSourceId) {
                final videoDetails = data['videoDetails'] as Map<String, dynamic>?;
                if (videoDetails != null) {
                  if (videoDetails['isLiveContent'] == true) {
                    continue;
                  }

                  final candTitle = (videoDetails['title'] as String? ?? '').toLowerCase();
                  final candLengthSec = int.tryParse(videoDetails['lengthSeconds']?.toString() ?? '0') ?? 0;
                  final candDuration = Duration(seconds: candLengthSec);

                  // Reject if candidate duration deviates widely from target (e.g. > 120s discrepancy or > 2.5x ratio, or < 30s teaser)
                  if (track.duration > const Duration(seconds: 30) && candDuration > Duration.zero) {
                    final diff = (candDuration.inSeconds - track.duration.inSeconds).abs();
                    final maxSec = candDuration.inSeconds > track.duration.inSeconds ? candDuration.inSeconds : track.duration.inSeconds;
                    final minSec = candDuration.inSeconds < track.duration.inSeconds ? candDuration.inSeconds : track.duration.inSeconds;
                    if (diff > 120 || (minSec > 0 && maxSec / minSec > 2.5) || candDuration.inSeconds < 30) {
                      continue;
                    }
                  }

                  // Reject if promotional ads, trailers, movie scenes, or reaction videos
                  const junkKeywords = [
                    'carvaan', 'teaser', 'trailer', 'reaction', 'review',
                    'interview', 'full movie', 'making of', 'behind the scenes',
                  ];
                  if (junkKeywords.any((k) => candTitle.contains(k))) {
                    continue;
                  }

                  // Reject unwanted remixes, covers, unplugged, lofi, or instrumental versions when target is original
                  final targetLower = track.title.toLowerCase();
                  final targetHasRemix = targetLower.contains('remix') || targetLower.contains('mashup');
                  final targetHasCover = targetLower.contains('cover');
                  final targetHasUnplugged = targetLower.contains('unplugged') || targetLower.contains('acoustic');
                  final targetHasLofi = targetLower.contains('lofi') || targetLower.contains('lo-fi');
                  final targetHasSlowed = targetLower.contains('slowed');
                  final targetHasInstrumental = targetLower.contains('instrumental') || targetLower.contains('karaoke');

                  if (!targetHasRemix && (candTitle.contains('remix') || candTitle.contains('mashup') || candTitle.contains('dj ') || candTitle.contains('club mix') || candTitle.contains('dance mix'))) {
                    continue;
                  }
                  if (!targetHasCover && candTitle.contains('cover')) {
                    continue;
                  }
                  if (!targetHasUnplugged && (candTitle.contains('unplugged') || candTitle.contains('acoustic'))) {
                    continue;
                  }
                  if (!targetHasLofi && (candTitle.contains('lofi') || candTitle.contains('lo-fi'))) {
                    continue;
                  }
                  if (!targetHasSlowed && (candTitle.contains('slowed') || candTitle.contains('reverb') || candTitle.contains('sped up') || candTitle.contains('speed up'))) {
                    continue;
                  }
                  if (!targetHasInstrumental && (candTitle.contains('instrumental') || candTitle.contains('karaoke'))) {
                    continue;
                  }

                  // Reject if candidate title shares NO significant words (length >= 3) with target title
                  final targetWords = track.title
                      .toLowerCase()
                      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '')
                      .split(' ')
                      .where((w) => w.length >= 3)
                      .toList();
                  if (targetWords.isNotEmpty && !targetWords.any((w) => candTitle.contains(w))) {
                    continue;
                  }
                }
              }

              final stream = _innertubeService.extractStream(
                candId,
                data,
                quality: quality,
              );
              if (stream != null) {
                _cache[cacheKey] = stream;
                return stream;
              }
            }
          } catch (_) {}
        }

      StreamManifest? manifest;
      String? resolvedVideoId;
      for (final candId in candidateIds) {
        try {
          manifest = await _yt.videos.streamsClient
              .getManifest(
                candId,
                requireWatchPage: false,
              )
              .timeout(const Duration(seconds: 5));
          resolvedVideoId = candId;
          break;
        } catch (_) {
          continue;
        }
      }

      // If all initial candidates failed manifest (e.g. geo/age restrictions), try fallback search
      if (manifest == null) {
        final query = '${track.title} ${track.artist}'.trim();
        final fallbackYtm = await _innertubeService.searchMusic(query);
        for (final alt in fallbackYtm) {
          if (candidateIds.contains(alt.videoId)) continue;
          if (_scoreYtmCandidate(targetTrack: track, candidate: alt) < 70) continue;
          try {
            manifest = await _yt.videos.streamsClient
                .getManifest(
                  alt.videoId,
                  requireWatchPage: false,
                )
                .timeout(const Duration(seconds: 5));
            resolvedVideoId = alt.videoId;
            break;
          } catch (_) {
            continue;
          }
        }
      }

      if (manifest == null || resolvedVideoId == null) {
        throw Exception(
          'Could not retrieve playable audio stream manifest for "${track.title}" (${track.artist})',
        );
      }

      // Select best candidate stream:
      // Priority 1: Pure audio streams (M4A AAC itag 140/139 or Opus itag 251).
      // Audio-only streams guarantee pure studio track audio without video multiplexing overhead or movie dialogue clips.
      final audioStreams = manifest.audioOnly;
      final dynamic selected;

      if (audioStreams.isNotEmpty) {
        // Exclude auto-dubbed language tracks to preserve original video audio
        final nonDubbedStreams = audioStreams.where((s) {
          final urlStr = s.url.toString();
          return !urlStr.contains('dubbed-auto') &&
              !urlStr.contains('acont%3Ddubbed') &&
              !urlStr.contains('acont=dubbed');
        }).toList();

        final effectiveStreams =
            nonDubbedStreams.isNotEmpty ? nonDubbedStreams : audioStreams.toList();

        // Priority 0: Check for studio master stream twins (Opus 774 256k or AAC 141 256k)
        final itag774 = effectiveStreams.where((s) => s.tag == 774).firstOrNull;
        final itag141 = effectiveStreams.where((s) => s.tag == 141).firstOrNull;
        if (quality == AudioQualityPreset.high && (itag774 != null || itag141 != null)) {
          selected = itag774 ?? itag141;
        } else {
          // Filter M4A/AAC streams (container-native itag 140 / 139)
          final m4aStreams = effectiveStreams
              .where((s) => s.container.name.toLowerCase() == 'mp4')
              .toList();
          final candidates =
              m4aStreams.isNotEmpty ? m4aStreams : effectiveStreams;

          // Target bitrate:
          // high: ~256 kbps (itag 774 / itag 141 / highest AAC)
          // standard: ~128-140 kbps (itag 140 is ~127 kbps)
          // low: ~48-64 kbps (itag 139 is ~49 kbps)
          final targetBitrate = quality == AudioQualityPreset.high
              ? 256000
              : (quality == AudioQualityPreset.standard ? 130000 : 55000);

          candidates.sort((a, b) {
            final bitA = a.bitrate.bitsPerSecond;
            final bitB = b.bitrate.bitsPerSecond;
            return (bitA - targetBitrate)
                .abs()
                .compareTo((bitB - targetBitrate).abs());
          });
          selected = candidates.first;
        }
      } else {
        // Fallback to progressive muxed stream if audio-only stream is absent
        final tag18Candidates = manifest.muxed.where((s) => s.tag == 18).toList();
        if (tag18Candidates.isNotEmpty) {
          selected = tag18Candidates.first;
        } else if (manifest.muxed.isNotEmpty) {
          selected = manifest.muxed.first;
        } else {
          throw Exception('No audio streams available for video "$resolvedVideoId"');
        }
      }

      final streamInfo = StreamInfo(
        url: selected.url,
        container:
            selected.container.name == 'mp4' ? 'm4a' : selected.container.name,
        bitrate: selected.bitrate.bitsPerSecond,
        codec: selected is AudioStreamInfo ? selected.audioCodec : 'aac',
        expiresAt: DateTime.now().add(const Duration(minutes: 45)),
        providerName: 'youtube_explode (itag ${selected.tag})',
        headers: const {'User-Agent': youtubeUserAgent},
        sizeBytes: selected.size.totalBytes,
      );

      _cache[cacheKey] = streamInfo;
      return streamInfo;
    } catch (primaryError) {
      if (_fallbackResolver != null) {
        try {
          final fallbackStream = await _fallbackResolver.resolve(
            track,
            quality: quality,
            forceFresh: forceFresh,
          );
          _cache[cacheKey] = fallbackStream;
          return fallbackStream;
        } catch (_) {
          // If fallback also fails, rethrow primary
        }
      }
      throw Exception(
        'Failed to resolve audio stream for "${track.title}" (${track.sourceId}): $primaryError',
      );
    }
  }

  @override
  Future<void> prefetch(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
  }) async {
    try {
      await resolve(track, quality: quality, forceFresh: false);
    } catch (_) {
      // Best-effort prefetch
    }
  }

  static final List<RegExp> _disqualifyPatterns = [
    RegExp(r'\bremix\b', caseSensitive: false),
    RegExp(r'\bre-mix\b', caseSensitive: false),
    RegExp(r'\bmix\b', caseSensitive: false),
    RegExp(r'\bclub mix\b', caseSensitive: false),
    RegExp(r'\bdance mix\b', caseSensitive: false),
    RegExp(r'\bdhol mix\b', caseSensitive: false),
    RegExp(r'\bdholak mix\b', caseSensitive: false),
    RegExp(r'\bdj\b', caseSensitive: false),
    RegExp(r'\bdj\s+[a-z0-9]+', caseSensitive: false),
    RegExp(r'\bmashup\b', caseSensitive: false),
    RegExp(r'\bmash-up\b', caseSensitive: false),
    RegExp(r'\bmedley\b', caseSensitive: false),
    RegExp(r'\blofi\b', caseSensitive: false),
    RegExp(r'\blo-fi\b', caseSensitive: false),
    RegExp(r'\bslowed\b', caseSensitive: false),
    RegExp(r'\breverb\b', caseSensitive: false),
    RegExp(r'\bsped up\b', caseSensitive: false),
    RegExp(r'\bspeed up\b', caseSensitive: false),
    RegExp(r'\b8d\b', caseSensitive: false),
    RegExp(r'\b16d\b', caseSensitive: false),
    RegExp(r'\bbass boosted\b', caseSensitive: false),
    RegExp(r'\bboosted\b', caseSensitive: false),
    RegExp(r'\bcover\b', caseSensitive: false),
    RegExp(r'\btribute\b', caseSensitive: false),
    RegExp(r'\brendition\b', caseSensitive: false),
    RegExp(r'\bunplugged\b', caseSensitive: false),
    RegExp(r'\bacoustic\b', caseSensitive: false),
    RegExp(r'\bkaraoke\b', caseSensitive: false),
    RegExp(r'\binstrumental\b', caseSensitive: false),
    RegExp(r'\bringtone\b', caseSensitive: false),
    RegExp(r'\bstatus\b', caseSensitive: false),
  ];

  static String cleanSongTitle(String title) {
    var t = title.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '');
    t = t.replaceAll(
      RegExp(
        r'\s*-\s*(coke studio|live|remastered|mono|stereo|from\s.*).*$',
        caseSensitive: false,
      ),
      '',
    );
    return t.trim();
  }

  static bool isDisqualifiedVariant(String rawTargetTitle, String candTitle) {
    final tClean = cleanSongTitle(rawTargetTitle).toLowerCase();
    final cLower = candTitle.toLowerCase();
    for (final pat in _disqualifyPatterns) {
      if (pat.hasMatch(cLower) && !pat.hasMatch(tClean)) {
        return true;
      }
    }
    return false;
  }

  static bool hasTitleMatch(String targetTitle, String candTitle) {
    final tClean = cleanSongTitle(targetTitle).toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
    final cClean = cleanSongTitle(candTitle).toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
    if (tClean.isEmpty || cClean.isEmpty) return false;
    if (tClean == cClean) return true;

    // Word boundary containment for subtitles, artist prefixes, or title extensions
    final tPadded = ' $tClean ';
    final cPadded = ' $cClean ';
    final tWordsList = tClean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (cPadded.contains(tPadded)) {
      if (tWordsList.length > 1 || tClean.length >= 8 || (tClean.length / cClean.length >= 0.70)) {
        return true;
      }
    }
    if (tPadded.contains(cPadded)) {
      if (cClean.length / tClean.length >= 0.85) return true;
    }

    const titleStopWords = {'the', 'a', 'an', 'in', 'on', 'of', 'and', 'to', 'for', 'with', 'from', 'by', 'is', 'it', 'me', 'you'};
    final tTokens = tClean.split(RegExp(r'\s+')).where((w) => w.length >= 3 && !titleStopWords.contains(w)).toSet();
    final cTokens = cClean.split(RegExp(r'\s+')).where((w) => w.length >= 3 && !titleStopWords.contains(w)).toSet();
    if (tTokens.isNotEmpty && cTokens.isNotEmpty) {
      final overlap = tTokens.intersection(cTokens);
      if (tTokens.length == 1) {
        final tWordsAll = tClean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        final cWordsAll = cClean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        if ((tWordsAll - cWordsAll).abs() > 0) return false;
      }
      return (overlap.length / tTokens.length) >= 0.60;
    }
    return false;
  }

  static bool hasArtistMatch(String targetArtist, String candArtist) {
    final tNorm = targetArtist.toLowerCase().replaceAll('\u00A0', ' ');
    final cNorm = candArtist.toLowerCase().replaceAll('\u00A0', ' ');
    final targetArtists = tNorm.split(RegExp(r'[,/&]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final candArtists = cNorm.split(RegExp(r'[,/&•]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    for (final ta in targetArtists) {
      if (ta.length >= 3 && cNorm.contains(ta)) return true;
      for (final ca in candArtists) {
        if (ca == ta) return true;
        if (ca.length >= 3 && ta.length >= 3) {
          if (ca.contains(ta) || ta.contains(ca)) return true;
        }
      }
    }
    const artistStopWords = {
      'the', 'and', 'feat', 'ft', 'featuring', 'with', 'presents', 'prod', 'by',
      'music', 'band', 'records', 'official', 'original', 'soundtrack', 'all',
      'star', 'stars', 'dj', 'vj', 'mr', 'ms', 'mrs', 'dr', 'to', 'in', 'on', 'of',
    };
    final tTokens = tNorm.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 3 && !artistStopWords.contains(w)).toSet();
    final cTokens = cNorm.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 3 && !artistStopWords.contains(w)).toSet();
    if (tTokens.isNotEmpty && cTokens.isNotEmpty) {
      if (tTokens.intersection(cTokens).isNotEmpty) return true;
    }
    return false;
  }

  int _scoreYtmCandidate({
    required Track targetTrack,
    required YtmTrackCandidate candidate,
  }) {
    // 0. Hard disqualification: title match check
    if (!hasTitleMatch(targetTrack.title, candidate.title)) {
      return -9999;
    }

    // 1. Hard disqualification: variant check (remix, mashup, dj, cover, lofi, etc.)
    if (isDisqualifiedVariant(targetTrack.title, candidate.title)) {
      return -9999;
    }

    // 2. Hard disqualification: artist match check
    if (!hasArtistMatch(targetTrack.artist, candidate.artist)) {
      return -9999;
    }

    // 3. Hard disqualification: duration discrepancy (>90s and >35%)
    if (targetTrack.duration > const Duration(seconds: 30) && candidate.duration > Duration.zero) {
      final diff = (targetTrack.duration.inSeconds - candidate.duration.inSeconds).abs();
      if (diff > 90 && diff > (targetTrack.duration.inSeconds * 0.35)) {
        return -9999;
      }
    }

    int score = 100; // Base bonus for being an official YouTube Music track
    final candTitle = candidate.title.toLowerCase();
    final candArtist = candidate.artist.toLowerCase();
    final candAlbum = candidate.album?.toLowerCase();

    // 4. Exact / close title bonus
    final cleanTargetTitle = cleanSongTitle(targetTrack.title).toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    final cleanCandTitle = cleanSongTitle(candTitle).replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    if (cleanCandTitle == cleanTargetTitle) {
      score += 60;
    } else if (cleanCandTitle.contains(cleanTargetTitle) || cleanTargetTitle.contains(cleanCandTitle)) {
      score += 35;
    }

    // 4.5 Artist match bonus
    final cleanTargetArtist = targetTrack.artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    final cleanCandArtist = candArtist.replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    if (cleanCandArtist.isNotEmpty && cleanTargetArtist.isNotEmpty) {
      if (cleanCandArtist == cleanTargetArtist || cleanCandArtist.contains(cleanTargetArtist)) {
        score += 35;
      }
    }

    // 5. Album match bonus
    if (targetTrack.album != null && candAlbum != null) {
      final cleanTargetAlbum = targetTrack.album!.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
      final cleanCandAlbum = candAlbum.replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
      if (cleanTargetAlbum.isNotEmpty && (cleanCandAlbum.contains(cleanTargetAlbum) || cleanTargetAlbum.contains(cleanCandAlbum))) {
        score += 40;
      }
    }

    // 6. Duration proximity bonus
    if (targetTrack.duration > Duration.zero && candidate.duration > Duration.zero) {
      final diff = (targetTrack.duration.inSeconds - candidate.duration.inSeconds).abs();
      if (diff <= 6) {
        score += 40;
      } else if (diff <= 15) {
        score += 25;
      } else if (diff <= 45) {
        score += 10;
      }
    }

    return score;
  }

  int _scoreCandidate({
    required String targetTitle,
    required String targetArtist,
    required Duration targetDuration,
    required Video candidate,
  }) {
    // 0. Hard disqualifications
    if (!hasTitleMatch(targetTitle, candidate.title)) {
      return -9999;
    }
    if (isDisqualifiedVariant(targetTitle, candidate.title)) {
      return -9999;
    }
    if (!hasArtistMatch(targetArtist, candidate.author)) {
      return -9999;
    }
    final candDuration = candidate.duration ?? Duration.zero;
    if (targetDuration > const Duration(seconds: 30) && candDuration > Duration.zero) {
      final diff = (targetDuration.inSeconds - candDuration.inSeconds).abs();
      if (diff > 90 && diff > (targetDuration.inSeconds * 0.35)) {
        return -9999;
      }
    }

    int score = 0;
    final candTitle = candidate.title.toLowerCase();
    final candAuthor = candidate.author.toLowerCase();

    // 1. Topic channel (official distributor master audio)
    final cleanArtistWords = targetArtist
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();

    if (candAuthor.endsWith('- topic')) {
      final topicAuthor = candAuthor.replaceFirst('- topic', '').trim();
      final authorMatchesTarget =
          cleanArtistWords.any((w) => topicAuthor.contains(w));
      if (authorMatchesTarget) {
        score += 80;
      } else {
        score -= 100;
      }
    }

    // 2. Official Record Label / VEVO
    const officialLabels = [
      'vevo',
      't-series',
      'tseries',
      'sony music',
      'zee music',
      'yrf',
      'tips official',
      'speed records',
      'white hill',
      'universal music',
      'warner music',
      'atlantic records',
      'def jam',
      'interscope',
      'columbia records',
      'geet mp3',
      'yash raj films',
      'aditya music',
      'lahari music',
      'eros',
      'eros now',
      'eros music',
      'think music',
    ];
    if (officialLabels.any((label) => candAuthor.contains(label))) {
      score += 50;
    }

    // 3. Artist channel match
    for (final word in cleanArtistWords) {
      if (candAuthor.contains(word)) {
        score += 15;
      }
    }

    // 4. Heavy penalty for promotional ads / Carvaan voiceovers
    if (candTitle.contains('carvaan') || candAuthor.contains('carvaan')) {
      score -= 500;
    }

    // 5. Heavy bonus for pure studio audio / album cuts
    const pureAudioKeywords = [
      'official audio',
      'audio song',
      'full audio',
      'original audio',
      'album version',
      'studio version',
      'audio',
    ];
    for (final a in pureAudioKeywords) {
      if (candTitle.contains(a)) {
        score += 50;
        break;
      }
    }

    // 6. Proximity to official track duration
    if (targetDuration > Duration.zero && candDuration > Duration.zero) {
      final diff = (targetDuration.inSeconds - candDuration.inSeconds).abs();
      if (diff <= 6) {
        score += 40;
      } else if (diff <= 15) {
        score += 25;
      } else if (diff <= 45) {
        score += 10;
      }
    }

    return score;
  }

  Future<StreamInfo?> _resolveViaDesktopYtDlp(String videoId) async {
    try {
      final res = await Process.run(
        'yt-dlp',
        ['-g', '-f', 'ba/b', 'https://www.youtube.com/watch?v=$videoId'],
      ).timeout(const Duration(seconds: 6));
      if (res.exitCode == 0) {
        final urlStr = (res.stdout as String).trim();
        if (urlStr.startsWith('http')) {
          final uri = Uri.parse(urlStr);
          return StreamInfo(
            url: uri,
            container: urlStr.contains('.webm') ? 'webm' : 'm4a',
            bitrate: 160000,
            codec: urlStr.contains('.webm') ? 'opus' : 'aac',
            expiresAt: DateTime.now().add(const Duration(hours: 4)),
            providerName: 'yt_dlp (desktop)',
            headers: const {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          );
        }
      }
    } catch (_) {}
    return null;
  }

  void close() {
    _yt.close();
    _innertubeService.close();
  }
}
