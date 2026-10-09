import 'dart:async';
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
      final rawSourceId = track.sourceId.replaceFirst('yt_', '').trim();
      List<String> candidateIds = [];

      // If sourceId is already a valid 11-char YouTube ID, prioritize it
      if (rawSourceId.length == 11 && !rawSourceId.startsWith('itunes_')) {
        candidateIds.add(rawSourceId);
      } else {
        // Query YouTube and rank results by official production metrics
        final query = '${track.title} ${track.artist}'.trim();
        final searchResults =
            await _yt.search.search(query).timeout(const Duration(seconds: 5));
        if (searchResults.isEmpty) {
          throw Exception('No YouTube search results found for "$query"');
        }

        final scored = searchResults.take(10).toList();
        scored.sort((a, b) {
          final sA = _scoreCandidate(
            targetTitle: track.title,
            targetArtist: track.artist,
            targetDuration: track.duration,
            candidate: a,
          );
          final sB = _scoreCandidate(
            targetTitle: track.title,
            targetArtist: track.artist,
            targetDuration: track.duration,
            candidate: b,
          );
          return sB.compareTo(sA);
        });

        candidateIds = scored.map((v) => v.id.value).toList();
      }
 
      // Priority 0: Instant InnerTube direct audio resolution (bypasses watch-page scraping & IP rate limits)
      for (final candId in candidateIds) {
        try {
          final data = await _innertubeService.queryPlayer(candId);
          if (data != null) {
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
        final query = '${track.title} ${track.artist} official audio'.trim();
        final fallbackResults =
            await _yt.search.search(query).timeout(const Duration(seconds: 5));
        for (final alt in fallbackResults.take(3)) {
          if (candidateIds.contains(alt.id.value)) continue;
          try {
            manifest = await _yt.videos.streamsClient
                .getManifest(
                  alt.id.value,
                  requireWatchPage: false,
                )
                .timeout(const Duration(seconds: 5));
            resolvedVideoId = alt.id.value;
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
        // Filter M4A/AAC streams (container-native itag 140 / 139)
        final m4aStreams = audioStreams
            .where((s) => s.container.name.toLowerCase() == 'mp4')
            .toList();
        final candidates =
            m4aStreams.isNotEmpty ? m4aStreams : audioStreams.toList();

        // Target bitrate:
        // high: ~160 kbps (itag 140 / highest AAC)
        // standard: ~128-140 kbps (itag 140 is ~127 kbps)
        // low: ~48-64 kbps (itag 139 is ~49 kbps)
        final targetBitrate =
            quality == AudioQualityPreset.standard ? 130000 : 55000;

        candidates.sort((a, b) {
          final bitA = a.bitrate.bitsPerSecond;
          final bitB = b.bitrate.bitsPerSecond;
          return (bitA - targetBitrate)
              .abs()
              .compareTo((bitB - targetBitrate).abs());
        });
        selected = candidates.first;
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
        headers: null,
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

  int _scoreCandidate({
    required String targetTitle,
    required String targetArtist,
    required Duration targetDuration,
    required Video candidate,
  }) {
    int score = 0;
    final candTitle = candidate.title.toLowerCase();
    final candAuthor = candidate.author.toLowerCase();
    final candDuration = candidate.duration ?? Duration.zero;

    // 1. Topic channel (official distributor master audio)
    // ONLY award bonus if the channel author matches the target artist!
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
        // Heavy penalty if topic channel belongs to an unrelated artist
        // (e.g. "Khushboo Jain - Topic" when target is "Khushboo Grewal")
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
      'saregama',
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

    // 4. Negative junk keywords
    const negativeKeywords = [
      'reaction',
      'review',
      'teaser',
      'trailer',
      'cover',
      'karaoke',
      'instrumental',
      'slowed',
      'reverb',
      'bass boosted',
      'status',
      'short',
      'shorts',
      'ringtone',
      'tutorial',
      'behind the scenes',
      'making of',
      'interview',
      'full movie',
      'parody',
      'dance performance',
    ];
    final targetHasCover = targetTitle.toLowerCase().contains('cover');
    final targetHasRemix = targetTitle.toLowerCase().contains('remix');

    for (final neg in negativeKeywords) {
      if (candTitle.contains(neg)) {
        if (neg == 'cover' && targetHasCover) continue;
        score -= 100;
      }
    }

    if (!targetHasRemix && candTitle.contains('remix')) {
      score -= 60;
    }

    // 5. Heavy penalty for video versions that contain dialogue, film skits, or sound effects
    const videoDialogueKeywords = [
      'full video',
      'video song',
      'music video',
      'official video',
    ];
    for (final v in videoDialogueKeywords) {
      if (candTitle.contains(v)) {
        score -= 50;
        break;
      }
    }

    // 6. Heavy bonus for pure studio audio / album cuts (Spotify equivalents)
    const pureAudioKeywords = [
      'official audio',
      'audio song',
      'full audio',
      'original audio',
      'album version',
      'studio version',
      'audio',
      'lyric video',
      'lyrics',
    ];
    for (final a in pureAudioKeywords) {
      if (candTitle.contains(a)) {
        score += 50;
        break;
      }
    }

    // 7. Language mismatch: penalize alternate regional dubs
    // (e.g. telugu, tamil, bhojpuri, marathi, bengali) when target is Hindi / English
    const regionalLangs = [
      'tamil',
      'telugu',
      'bhojpuri',
      'marathi',
      'bengali',
      'kannada',
      'malayalam',
      'gujarati',
    ];
    final targetCombined =
        '${targetTitle.toLowerCase()} ${targetArtist.toLowerCase()}';
    for (final lang in regionalLangs) {
      if (candTitle.contains(lang) && !targetCombined.contains(lang)) {
        score -= 100;
      }
    }

    // 8. Title keywords
    final cleanTitle = targetTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
    if (cleanTitle.isNotEmpty && candTitle.contains(cleanTitle)) {
      score += 25;
    }

    // 9. Proximity to official track duration
    if (targetDuration > Duration.zero && candDuration > Duration.zero) {
      final diff = (targetDuration.inSeconds - candDuration.inSeconds).abs();
      if (diff <= 5) {
        score += 40;
      } else if (diff <= 15) {
        score += 20;
      } else if (diff <= 30) {
        score += 10;
      } else if (diff > 60) {
        score -= 60;
      }
    }

    return score;
  }

  void close() {
    _yt.close();
    _innertubeService.close();
  }
}
