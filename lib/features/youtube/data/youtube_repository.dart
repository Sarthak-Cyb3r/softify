import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../data/resolvers/youtube_innertube_service.dart';
import '../../../data/resolvers/youtube_stream_resolver.dart';
import '../../../domain/entities/track.dart';
import '../domain/youtube_failure.dart';

class YoutubeException implements Exception {
  final YoutubeFailure failure;
  const YoutubeException(this.failure);

  @override
  String toString() => 'YoutubeException: ${failure.userMessage}';
}

class YoutubeRepository {
  final YoutubeExplode _yt;
  final YoutubeInnertubeService _innertubeService;

  YoutubeRepository({
    YoutubeExplode? yt,
    YoutubeInnertubeService? innertubeService,
  })  : _yt = yt ?? YoutubeExplode(),
        _innertubeService = innertubeService ?? YoutubeInnertubeService();

  /// Fetches video metadata and maps it to a [Track].
  Future<Track> fetchTrack(String videoId) async {
    // Tier 1: Query YouTube InnerTube API directly (bypasses watch-page web scraping & IP bot-checks)
    try {
      final innerTubeData = await _innertubeService.queryPlayer(videoId);
      if (innerTubeData != null) {
        final meta = _innertubeService.parseMetadata(videoId, innerTubeData);
        final stream = _innertubeService.extractStream(videoId, innerTubeData);
        if (stream != null) {
          YoutubeStreamResolver.precacheStream('yt_${meta.videoId}', stream);
        }
        return Track(
          id: 'yt_${meta.videoId}',
          sourceId: 'yt_${meta.videoId}',
          title: meta.title,
          artist: meta.author,
          album: 'YouTube',
          duration: meta.duration,
          coverUrl: meta.coverUrl,
          matchConfidence: 1.0,
        );
      }
    } on YoutubeFailure catch (fail) {
      throw YoutubeException(fail);
    } catch (_) {
      // Proceed to fallback tiers
    }

    // Tier 2: YoutubeExplode client
    try {
      final video = await _yt.videos
          .get(VideoId(videoId))
          .timeout(const Duration(seconds: 5));

      if (video.isLive) {
        throw const YoutubeException(LiveStreamFailure());
      }

      final coverUrl = video.thumbnails.maxResUrl.isNotEmpty
          ? video.thumbnails.maxResUrl
          : video.thumbnails.highResUrl;

      return Track(
        id: 'yt_${video.id.value}',
        sourceId: 'yt_${video.id.value}',
        title: video.title.trim(),
        artist:
            video.author.trim().isNotEmpty ? video.author.trim() : 'YouTube',
        album: 'YouTube',
        duration: video.duration ?? Duration.zero,
        coverUrl: coverUrl,
        matchConfidence: 1.0,
      );
    } on YoutubeException {
      rethrow;
    } on VideoUnavailableException catch (e) {
      throw YoutubeException(_mapUnavailableException(e));
    } on VideoUnplayableException catch (e) {
      throw YoutubeException(_mapUnplayableException(e));
    } on SocketException catch (_) {
      throw const YoutubeException(NetworkErrorFailure());
    } on TimeoutException catch (_) {
      throw const YoutubeException(NetworkErrorFailure());
    } catch (e) {
      // Tier 3: If rate-limited or error, try oEmbed fallback for metadata
      try {
        final oembed = await _innertubeService.fetchOembed(videoId);
        if (oembed != null) {
          return Track(
            id: 'yt_${oembed.videoId}',
            sourceId: 'yt_${oembed.videoId}',
            title: oembed.title,
            artist: oembed.author,
            album: 'YouTube',
            duration: oembed.duration,
            coverUrl: oembed.coverUrl,
            matchConfidence: 1.0,
          );
        }
      } catch (oembedError) {
        if (oembedError is YoutubeFailure) {
          throw YoutubeException(oembedError);
        }
      }
      throw YoutubeException(_mapGenericException(e));
    }
  }

  /// Fetches playlist metadata and maps its videos to a list of [Track]s.
  Future<List<Track>> fetchPlaylistTracks(
    String playlistId, {
    int limit = 200,
  }) async {
    try {
      final stream = _yt.playlists.getVideos(PlaylistId(playlistId));
      final List<Track> tracks = [];

      await for (final video in stream.take(limit)) {
        if (video.isLive) continue; // Skip live streams in playlists

        final coverUrl = video.thumbnails.maxResUrl.isNotEmpty
            ? video.thumbnails.maxResUrl
            : video.thumbnails.highResUrl;

        tracks.add(
          Track(
            id: 'yt_${video.id.value}',
            sourceId: 'yt_${video.id.value}',
            title: video.title.trim(),
            artist: video.author.trim().isNotEmpty
                ? video.author.trim()
                : 'YouTube',
            album: 'YouTube',
            duration: video.duration ?? Duration.zero,
            coverUrl: coverUrl,
            matchConfidence: 1.0,
          ),
        );
      }

      if (tracks.isEmpty) {
        throw const YoutubeException(
          VideoUnavailableFailure(
            'Playlist is empty or contains no playable videos.',
          ),
        );
      }

      return tracks;
    } on YoutubeException {
      rethrow;
    } on SocketException catch (_) {
      throw const YoutubeException(NetworkErrorFailure());
    } on TimeoutException catch (_) {
      throw const YoutubeException(NetworkErrorFailure());
    } catch (e) {
      throw YoutubeException(_mapGenericException(e));
    }
  }

  YoutubeFailure _mapUnplayableException(VideoUnplayableException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('live')) {
      return const LiveStreamFailure();
    }
    if (msg.contains('private')) {
      return const PrivateVideoFailure();
    }
    if (msg.contains('age') || msg.contains('sign in')) {
      return const AgeRestrictedFailure();
    }
    if (msg.contains('region') ||
        msg.contains('country') ||
        msg.contains('blocked')) {
      return const RegionBlockedFailure();
    }
    return const VideoUnavailableFailure();
  }

  YoutubeFailure _mapUnavailableException(VideoUnavailableException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('private')) {
      return const PrivateVideoFailure();
    }
    return const VideoUnavailableFailure();
  }

  YoutubeFailure _mapGenericException(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('clientexception')) {
      return const NetworkErrorFailure();
    }
    if (msg.contains('live')) {
      return const LiveStreamFailure();
    }
    if (msg.contains('private')) {
      return const PrivateVideoFailure();
    }
    if (msg.contains('age') || msg.contains('sign in')) {
      return const AgeRestrictedFailure();
    }
    if (msg.contains('region') ||
        msg.contains('country') ||
        msg.contains('blocked')) {
      return const RegionBlockedFailure();
    }
    if (msg.contains('requestlimit') ||
        msg.contains('rate limit') ||
        msg.contains('ratelimit') ||
        msg.contains('too many requests')) {
      return const VideoUnavailableFailure(
        'YouTube rate-limited this request. Please try again in a few moments.',
      );
    }
    if (msg.contains('unavailable') || msg.contains('not found')) {
      return const VideoUnavailableFailure();
    }
    return const GenericYoutubeFailure();
  }

  YoutubeFailure mapException(Object e) => _mapGenericException(e);

  void close() {
    _yt.close();
    _innertubeService.close();
  }
}
