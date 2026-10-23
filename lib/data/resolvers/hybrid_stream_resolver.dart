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
  final Map<String, Future<StreamInfo>> _inFlight = {};

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
    final idKey = '${track.id}_${quality.name}';

    if (!forceFresh) {
      if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
        return _cache[cacheKey]!;
      }
      if (_cache.containsKey(idKey) && !_cache[idKey]!.isExpired) {
        return _cache[idKey]!;
      }
      if (_inFlight.containsKey(cacheKey)) {
        return await _inFlight[cacheKey]!;
      }
      if (_inFlight.containsKey(idKey)) {
        return await _inFlight[idKey]!;
      }
    }

    final future = _resolveInternal(track, quality: quality, forceFresh: forceFresh);
    _inFlight[cacheKey] = future;
    _inFlight[idKey] = future;

    try {
      final info = await future;
      _cache[cacheKey] = info;
      _cache[idKey] = info;
      return info;
    } finally {
      _inFlight.remove(cacheKey);
      _inFlight.remove(idKey);
    }
  }

  Future<StreamInfo> _resolveInternal(
    Track track, {
    required AudioQualityPreset quality,
    required bool forceFresh,
  }) async {
    // Direct YouTube link tracks bypass Saavn
    if (track.sourceId.startsWith('yt_')) {
      return await _ytResolver.resolve(
        track,
        quality: quality,
        forceFresh: forceFresh,
      );
    }

    // Podcast tracks route to PodcastRssResolver
    if (track.sourceId.startsWith('podcast_')) {
      return await _podcastResolver.resolve(
        track,
        quality: quality,
        forceFresh: forceFresh,
      );
    }

    // Phase 8 Architecture:
    // Primary: JioSaavn Studio Audio Master (320kbps / 160kbps CD-quality AAC).
    // Provides pure studio recordings with zero dialogue and instantaneous CDNs.
    try {
      return await _saavnResolver.resolve(
        track,
        quality: quality,
        forceFresh: forceFresh,
      );
    } catch (_) {
      // Secondary fallback: YouTube Explode with enhanced studio scoring
      return await _ytResolver.resolve(
        track,
        quality: quality,
        forceFresh: forceFresh,
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
    } catch (_) {}
  }

  void close() {
    _ytResolver.close();
    _podcastResolver.close();
  }
}
