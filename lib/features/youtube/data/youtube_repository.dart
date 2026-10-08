import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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

  YoutubeRepository({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  /// Fetches video metadata and maps it to a [Track].
  Future<Track> fetchTrack(String videoId) async {
    try {
      final video = await _yt.videos.get(VideoId(videoId));

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
    if (msg.contains('unavailable') || msg.contains('not found')) {
      return const VideoUnavailableFailure();
    }
    return GenericYoutubeFailure(e.toString());
  }

  void close() {
    _yt.close();
  }
}
