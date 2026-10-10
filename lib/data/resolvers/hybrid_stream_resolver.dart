import 'dart:async';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_stream_resolver.dart';
import '../../features/podcasts/data/podcast_rss_resolver.dart';
import 'saavn_stream_resolver.dart';
import 'youtube_stream_resolver.dart';

class HybridStreamResolver implements IStreamResolver {
  final SaavnStreamResolver _saavnResolver;
  final YoutubeStreamResolver _ytResolver;
  final PodcastRssResolver _podcastResolver;
  final Map<String, StreamInfo> _cache = {};

  HybridStreamResolver({
    SaavnStreamResolver? saavnResolver,
    YoutubeStreamResolver? ytResolver,
    PodcastRssResolver? podcastResolver,
  })  : _saavnResolver = saavnResolver ?? SaavnStreamResolver(),
        _ytResolver = ytResolver ?? YoutubeStreamResolver(),
        _podcastResolver = podcastResolver ??
            PodcastRssResolver(ytResolver: ytResolver ?? YoutubeStreamResolver());

  PodcastRssResolver get podcastResolver => _podcastResolver;

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    final cacheKey = '${track.id}_${track.sourceId}_${quality.name}';
    if (!forceFresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (!cached.isExpired) {
        return cached;
      }
    }

    StreamInfo info;

    // Direct YouTube link tracks bypass Saavn
    if (track.sourceId.startsWith('yt_')) {
      info = await _ytResolver.resolve(
        track,
        quality: quality,
        forceFresh: forceFresh,
      );
      _cache[cacheKey] = info;
      return info;
    }

    // Podcast tracks route to PodcastRssResolver
    if (track.sourceId.startsWith('podcast_')) {
      info = await _podcastResolver.resolve(
        track,
        quality: quality,
        forceFresh: forceFresh,
      );
      _cache[cacheKey] = info;
      return info;
    }

    // Phase 8 Architecture:
    // Primary: JioSaavn Studio Audio Master (320kbps / 160kbps CD-quality AAC).
    // Provides pure studio recordings with zero dialogue and instantaneous CDNs.
    try {
      info = await _saavnResolver.resolve(
        track,
        quality: quality,
        forceFresh: forceFresh,
      );
    } catch (_) {
      // Secondary fallback: YouTube Explode with enhanced studio scoring
      info = await _ytResolver.resolve(
        track,
        quality: quality,
        forceFresh: forceFresh,
      );
    }

    _cache[cacheKey] = info;
    return info;
  }

  @override
  Future<void> prefetch(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
  }) async {
    try {
      await resolve(track, quality: quality);
    } catch (_) {}
  }

  void close() {
    _ytResolver.close();
    _podcastResolver.close();
  }
}
