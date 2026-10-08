import 'dart:convert';
import 'dart:io';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/stream_info.dart';
import '../../features/youtube/domain/youtube_failure.dart';

class InnertubeMetadata {
  final String videoId;
  final String title;
  final String author;
  final Duration duration;
  final String coverUrl;
  final bool isLive;

  const InnertubeMetadata({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
    required this.coverUrl,
    required this.isLive,
  });
}

class YoutubeInnertubeService {
  final HttpClient _client;

  YoutubeInnertubeService({HttpClient? client}) : _client = client ?? HttpClient();

  static const String _playerEndpoint =
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

  /// Fetches video metadata and direct stream info via YouTube's InnerTube API.
  /// Completely bypasses web watch-page HTML scraping and bot-detection rate limits.
  Future<Map<String, dynamic>?> queryPlayer(String videoId) async {
    // 1. Try Android Client
    final androidData = await _postPlayer(
      videoId: videoId,
      userAgent: 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
      clientContext: {
        'clientName': 'ANDROID',
        'clientVersion': '20.10.38',
        'osName': 'Android',
        'osVersion': '11',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    );

    if (androidData != null) return androidData;

    // 2. Fallback to iOS Client
    return _postPlayer(
      videoId: videoId,
      userAgent:
          'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
      clientContext: {
        'clientName': 'IOS',
        'clientVersion': '20.10.4',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'osName': 'IOS',
        'osVersion': '18.1.0.22B83',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    );
  }

  Future<Map<String, dynamic>?> _postPlayer({
    required String videoId,
    required String userAgent,
    required Map<String, dynamic> clientContext,
  }) async {
    try {
      final uri = Uri.parse(_playerEndpoint);
      final req = await _client.postUrl(uri).timeout(const Duration(seconds: 6));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('User-Agent', userAgent);

      final payload = {
        'context': {'client': clientContext},
        'videoId': videoId,
      };

      req.add(utf8.encode(jsonEncode(payload)));
      final res = await req.close().timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) {
        return null;
      }

      final body = await res.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Parses metadata from InnerTube or throws typed [YoutubeFailure].
  InnertubeMetadata parseMetadata(String videoId, Map<String, dynamic> data) {
    final playability = data['playabilityStatus'] as Map<String, dynamic>? ?? {};
    final status = (playability['status'] as String? ?? '').toUpperCase();
    final reason = (playability['reason'] as String? ?? '').trim();

    if (status != 'OK') {
      final reasonLower = reason.toLowerCase();
      if (reasonLower.contains('live')) {
        throw const LiveStreamFailure();
      }
      if (reasonLower.contains('private')) {
        throw const PrivateVideoFailure();
      }
      if (reasonLower.contains('age') ||
          reasonLower.contains('sign in') ||
          status == 'LOGIN_REQUIRED') {
        throw const AgeRestrictedFailure();
      }
      if (reasonLower.contains('country') ||
          reasonLower.contains('region') ||
          reasonLower.contains('blocked')) {
        throw const RegionBlockedFailure();
      }
      if (reason.isNotEmpty) {
        throw VideoUnavailableFailure(reason);
      }
      throw const VideoUnavailableFailure();
    }

    final videoDetails = data['videoDetails'] as Map<String, dynamic>? ?? {};
    final isLive = videoDetails['isLiveContent'] == true;
    if (isLive) {
      throw const LiveStreamFailure();
    }

    final title = (videoDetails['title'] as String? ?? '').trim();
    final author = (videoDetails['author'] as String? ?? '').trim();
    final lengthStr = videoDetails['lengthSeconds'] as String? ?? '0';
    final lengthSecs = int.tryParse(lengthStr) ?? 0;

    // Pick highest resolution thumbnail available
    String coverUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    final thumbnailObj = videoDetails['thumbnail'] as Map<String, dynamic>?;
    if (thumbnailObj != null) {
      final thumbnails = thumbnailObj['thumbnails'] as List<dynamic>? ?? [];
      if (thumbnails.isNotEmpty) {
        final sorted = List<Map<String, dynamic>>.from(
          thumbnails.whereType<Map<String, dynamic>>(),
        )..sort((a, b) {
            final wA = (a['width'] as num?)?.toInt() ?? 0;
            final wB = (b['width'] as num?)?.toInt() ?? 0;
            return wB.compareTo(wA);
          });
        if (sorted.isNotEmpty) {
          final url = sorted.first['url'] as String? ?? '';
          if (url.isNotEmpty) coverUrl = url;
        }
      }
    }

    return InnertubeMetadata(
      videoId: videoId,
      title: title.isNotEmpty ? title : 'YouTube Track',
      author: author.isNotEmpty ? author : 'YouTube',
      duration: Duration(seconds: lengthSecs),
      coverUrl: coverUrl,
      isLive: isLive,
    );
  }

  /// Extracts audio-only stream from InnerTube response.
  StreamInfo? extractStream(
    String videoId,
    Map<String, dynamic> data, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
  }) {
    final streamingData = data['streamingData'] as Map<String, dynamic>? ?? {};
    final adaptive = streamingData['adaptiveFormats'] as List<dynamic>? ?? [];

    final audioFormats = adaptive
        .whereType<Map<String, dynamic>>()
        .where((f) {
          final mime = (f['mimeType'] as String? ?? '').toLowerCase();
          final hasUrl = (f['url'] as String? ?? '').isNotEmpty;
          return mime.contains('audio') && hasUrl;
        })
        .toList();

    if (audioFormats.isEmpty) return null;

    // Prioritize M4A (AAC itag 140 / 139) for container consistency
    final m4aFormats = audioFormats
        .where((f) => (f['mimeType'] as String? ?? '').contains('mp4'))
        .toList();
    final candidates = m4aFormats.isNotEmpty ? m4aFormats : audioFormats;

    final targetBitrate =
        quality == AudioQualityPreset.standard ? 130000 : 55000;

    candidates.sort((a, b) {
      final bitA = (a['bitrate'] as num?)?.toInt() ?? 0;
      final bitB = (b['bitrate'] as num?)?.toInt() ?? 0;
      return (bitA - targetBitrate)
          .abs()
          .compareTo((bitB - targetBitrate).abs());
    });

    final selected = candidates.first;
    final streamUrl = Uri.parse(selected['url'] as String);
    final bitrate = (selected['bitrate'] as num?)?.toInt() ?? 128000;
    final mime = (selected['mimeType'] as String? ?? '');
    final itag = selected['itag'];

    return StreamInfo(
      url: streamUrl,
      container: mime.contains('mp4') ? 'm4a' : 'webm',
      bitrate: bitrate,
      codec: mime.contains('mp4') ? 'aac' : 'opus',
      expiresAt: DateTime.now().add(const Duration(hours: 4)),
      providerName: 'innertube_android (itag $itag)',
      sizeBytes: (selected['contentLength'] as String?) != null
          ? int.tryParse(selected['contentLength'] as String)
          : null,
    );
  }

  /// YouTube oEmbed fallback for basic metadata (title, author, thumbnail)
  Future<InnertubeMetadata?> fetchOembed(String videoId) async {
    try {
      final uri = Uri.parse(
        'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json',
      );
      final req = await _client.getUrl(uri).timeout(const Duration(seconds: 5));
      final res = await req.close().timeout(const Duration(seconds: 5));

      if (res.statusCode == 404) {
        throw const VideoUnavailableFailure();
      }
      if (res.statusCode != 200) return null;

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      return InnertubeMetadata(
        videoId: videoId,
        title: (json['title'] as String? ?? '').trim(),
        author: (json['author_name'] as String? ?? '').trim(),
        duration: Duration.zero,
        coverUrl: (json['thumbnail_url'] as String? ??
            'https://i.ytimg.com/vi/$videoId/hqdefault.jpg'),
        isLive: false,
      );
    } on YoutubeFailure {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  void close() {
    _client.close();
  }
}
