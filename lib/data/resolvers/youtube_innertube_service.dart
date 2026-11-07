import 'dart:convert';
import 'dart:io';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/track.dart';
import '../../features/youtube/domain/youtube_failure.dart';

class YtmTrackCandidate {
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;
  final String? coverUrl;
  final String? backgroundUrl;

  const YtmTrackCandidate({
    required this.videoId,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    this.coverUrl,
    this.backgroundUrl,
  });

  Track toTrack() {
    return Track(
      id: 'ytm_$videoId',
      sourceId: 'ytm_$videoId',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      coverUrl: (coverUrl != null && coverUrl!.isNotEmpty)
          ? coverUrl
          : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      matchConfidence: 1.0,
    );
  }
}

class InnertubeMetadata {
  final String videoId;
  final String title;
  final String author;
  final Duration duration;
  final String coverUrl;
  final String? backgroundUrl;
  final bool isLive;

  const InnertubeMetadata({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
    required this.coverUrl,
    this.backgroundUrl,
    required this.isLive,
  });
}

class YoutubeInnertubeService {
  final HttpClient _client;

  YoutubeInnertubeService({HttpClient? client}) : _client = client ?? HttpClient();

  static const String _playerEndpoint =
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

  static const String androidUserAgent =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
  static const String iosUserAgent =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
  static const String visionosUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15';

  static String? _cachedVisitorData =
      'CgtkUVZ6SFNGWXhmUSigy6HWBjIKCgJJThIEGgAgW2K1AgqyAkN1SUJDQVVTbEFFQjhRWnVadFctTkEwRENMcjNQYVlOZXlta3JqbGNHMmxiNTFJTVFVYzc5akp2NThZcnZPejBJd0JDelpKNVppYXEtTW5QcThXWHNNY1FYVUk0dEtkNXM2a0g1d2lkbVd1U0w1N2xJWWZCQkhMNHJoR3hlTU5IWVN5TGRDMmZWV2NiVU5nS056NTMzcnlnSEZTRHZ2MHZRZE9XVDFKNVFRZnVJclg5YTdRbF83TkQ1alpRNURnZGtOaGFvLVpzMlk0TmxvbG9LQVV5UlFIZXFaMVBUZUpRRE0wbFZrdE00enlsMVNtZGFWQi1aTTNwdHFtT0hEVnA2U1lTUDVobTBtMTJZRDhEVUQydEs0S1o1MlNKNV91Y3VpSUlyN3BUcjVIdVNOem9Ddw%3D%3D';

  Future<String?> _getVisitorData() async {
    if (_cachedVisitorData != null) return _cachedVisitorData;
    try {
      final req = await _client
          .getUrl(Uri.parse('https://www.youtube.com/'))
          .timeout(const Duration(seconds: 4));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final html = await res.transform(utf8.decoder).join();
        final match = RegExp(r'"visitorData":"([^"]+)"').firstMatch(html);
        if (match != null) {
          _cachedVisitorData = match.group(1);
          return _cachedVisitorData;
        }
      }
    } catch (_) {}
    return _cachedVisitorData;
  }

  bool _isPlayable(Map<String, dynamic>? data) {
    if (data == null) return false;
    final playability = data['playabilityStatus'] as Map<String, dynamic>? ?? {};
    final status = (playability['status'] as String? ?? '').toUpperCase();
    if (status != 'OK') return false;
    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return false;
    final adaptive = streamingData['adaptiveFormats'] as List<dynamic>? ?? [];
    final formats = streamingData['formats'] as List<dynamic>? ?? [];
    return adaptive.any((f) => f is Map<String, dynamic> && (f['url'] as String? ?? '').isNotEmpty) ||
        formats.any((f) => f is Map<String, dynamic> && (f['url'] as String? ?? '').isNotEmpty);
  }

  /// Fetches video metadata and direct stream info via YouTube's InnerTube API.
  /// Completely bypasses web watch-page HTML scraping and bot-detection rate limits.
  Future<Map<String, dynamic>?> queryPlayer(String videoId) async {
    // 1. Priority 0: iOS Client (supports unthrottled direct playback with User-Agent header)
    final iosData = await _postPlayer(
      videoId: videoId,
      userAgent: iosUserAgent,
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

    if (iosData != null && _isPlayable(iosData)) {
      iosData['_clientUserAgent'] = iosUserAgent;
      iosData['_clientName'] = 'IOS';
      return iosData;
    }

    // 2. Fallback to Android Client
    final androidData = await _postPlayer(
      videoId: videoId,
      userAgent: androidUserAgent,
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

    if (androidData != null && _isPlayable(androidData)) {
      androidData['_clientUserAgent'] = androidUserAgent;
      androidData['_clientName'] = 'ANDROID';
      return androidData;
    }

    // 3. Fallback to Apple VisionOS Client with visitorData
    try {
      final visitor = await _getVisitorData();
      final visionosData = await _postPlayer(
        videoId: videoId,
        userAgent: visionosUserAgent,
        clientContext: {
          'clientName': 'VISIONOS',
          'clientVersion': '1.02',
          'deviceMake': 'Apple',
          'deviceModel': 'RealityDevice17,1',
          'osName': 'visionOS',
          'osVersion': '26.5.23O471',
          'hl': 'en',
          'gl': 'US',
          if (visitor != null) 'visitorData': visitor,
        },
      );

      if (visionosData != null && _isPlayable(visionosData)) {
        visionosData['_clientUserAgent'] = visionosUserAgent;
        visionosData['_clientName'] = 'VISIONOS';
        return visionosData;
      }
    } catch (_) {}

    return iosData ?? androidData;
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

      final body = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 6));
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

    // Extract high-resolution landscape background artwork
    String? backgroundUrl;
    final microformat = data['microformat']?['microformatDataRenderer'] as Map<String, dynamic>?;
    final microThumbs = microformat?['thumbnail']?['thumbnails'] as List<dynamic>?;
    if (microThumbs != null && microThumbs.isNotEmpty) {
      final lastThumb = microThumbs.last as Map<String, dynamic>?;
      final raw = lastThumb?['url'] as String?;
      if (raw != null && raw.isNotEmpty) {
        backgroundUrl = raw.startsWith('http://') ? 'https://${raw.substring(7)}' : raw;
      }
    }
    backgroundUrl ??= 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';

    return InnertubeMetadata(
      videoId: videoId,
      title: title.isNotEmpty ? title : 'YouTube Track',
      author: author.isNotEmpty ? author : 'YouTube',
      duration: Duration(seconds: lengthSecs),
      coverUrl: coverUrl,
      backgroundUrl: backgroundUrl,
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

    Map<String, dynamic>? selected;
    String streamContainer = 'm4a';
    String streamCodec = 'aac';

    // Filter out auto-dubbed audio formats to preserve the original video audio track
    final nonDubbedAudio = audioFormats.where((f) {
      final audioTrack = f['audioTrack'] as Map<String, dynamic>?;
      if (audioTrack != null) {
        if (audioTrack['isAutoDubbed'] == true) return false;
        if (audioTrack['audioIsDefault'] == true) return true;
        final name = (audioTrack['displayName'] as String? ?? '').toLowerCase();
        if (name.contains('original')) return true;
      }
      final url = (f['url'] as String? ?? '');
      if (url.contains('dubbed-auto') ||
          url.contains('acont%3Ddubbed') ||
          url.contains('acont=dubbed')) {
        return false;
      }
      return true;
    }).toList();

    final effectiveAudio = nonDubbedAudio.isNotEmpty ? nonDubbedAudio : audioFormats;

    if (effectiveAudio.isNotEmpty) {
      // Prioritize M4A (AAC itag 140 / 139) for container consistency
      final m4aFormats = effectiveAudio
          .where((f) => (f['mimeType'] as String? ?? '').contains('mp4'))
          .toList();
      final candidates = m4aFormats.isNotEmpty ? m4aFormats : effectiveAudio;

      final targetBitrate = quality == AudioQualityPreset.high
          ? 160000
          : (quality == AudioQualityPreset.standard ? 130000 : 55000);

      candidates.sort((a, b) {
        final bitA = (a['bitrate'] as num?)?.toInt() ?? 0;
        final bitB = (b['bitrate'] as num?)?.toInt() ?? 0;
        return (bitA - targetBitrate)
            .abs()
            .compareTo((bitB - targetBitrate).abs());
      });

      selected = candidates.first;
      final mime = (selected['mimeType'] as String? ?? '');
      streamContainer = mime.contains('mp4') ? 'm4a' : 'webm';
      streamCodec = mime.contains('mp4') ? 'aac' : 'opus';
    } else {
      // Fallback: Check progressive muxed formats with audio (itag 18, 22)
      final formats = streamingData['formats'] as List<dynamic>? ?? [];
      final muxedWithUrl = formats
          .whereType<Map<String, dynamic>>()
          .where((f) => (f['url'] as String? ?? '').isNotEmpty)
          .toList();

      if (muxedWithUrl.isNotEmpty) {
        // Tag 18 is 360p MP4 with AAC audio, lightweight and universally playable
        final tag18 = muxedWithUrl.where((f) => f['itag'] == 18).toList();
        selected = tag18.isNotEmpty ? tag18.first : muxedWithUrl.first;
        streamContainer = 'm4a';
        streamCodec = 'aac';
      }
    }

    if (selected == null) return null;

    final streamUrl = Uri.parse(selected['url'] as String);
    final bitrate = (selected['bitrate'] as num?)?.toInt() ?? 128000;
    final itag = selected['itag'];
    final clientUa = data['_clientUserAgent'] as String? ?? iosUserAgent;
    final clientName = data['_clientName'] as String? ?? 'IOS';

    return StreamInfo(
      url: streamUrl,
      container: streamContainer,
      bitrate: bitrate,
      codec: streamCodec,
      expiresAt: DateTime.now().add(const Duration(hours: 4)),
      providerName: 'innertube_${clientName.toLowerCase()} (itag $itag)',
      headers: {
        'User-Agent': clientUa,
        'Referer': 'https://www.youtube.com/',
      },
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

      final body = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5));
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

  /// Searches YouTube Music (WEB_REMIX) for pure studio master audio recordings.
  /// Parses structured song metadata (title, artist, album, duration, album art).
  Future<List<YtmTrackCandidate>> searchMusic(
    String query, {
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false');
      final req = await _client.postUrl(uri).timeout(const Duration(seconds: 5));
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      );
      req.headers.set('Referer', 'https://music.youtube.com/');
      req.headers.set('Content-Type', 'application/json');

      final payload = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240422.01.00',
            'hl': 'en',
            'gl': 'IN',
          }
        },
        'query': query,
        'params': 'EgWKAQIIAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D', // Filter for Songs
      };

      req.add(utf8.encode(jsonEncode(payload)));
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      final contents = json['contents'];
      if (contents == null) return [];

      final candidates = <YtmTrackCandidate>[];
      final seen = <String>{};

      void walk(dynamic node) {
        if (candidates.length >= limit) return;
        if (node is Map<String, dynamic>) {
          if (node.containsKey('musicResponsiveListItemRenderer')) {
            final item = node['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
            if (item != null) {
              String? vid;
              final plData = item['playlistItemData'] as Map<String, dynamic>?;
              if (plData != null && plData['videoId'] is String) {
                vid = plData['videoId'] as String;
              }
              if (vid == null || vid.isEmpty) {
                final overlay = item['overlay'] as Map<String, dynamic>?;
                final thumbOverlay = overlay?['musicItemThumbnailOverlayRenderer'] as Map<String, dynamic>?;
                final playBtn = thumbOverlay?['content']?['musicPlayButtonRenderer'] as Map<String, dynamic>?;
                final watchEp = playBtn?['playNavigationEndpoint']?['watchEndpoint'] as Map<String, dynamic>?;
                if (watchEp != null && watchEp['videoId'] is String) {
                  vid = watchEp['videoId'] as String;
                }
              }
              if (vid == null || vid.isEmpty) {
                final flexCols = item['flexColumns'] as List<dynamic>? ?? [];
                for (final col in flexCols) {
                  if (col is Map<String, dynamic>) {
                    final runs = col['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List<dynamic>? ?? [];
                    for (final r in runs) {
                      if (r is Map<String, dynamic>) {
                        final epVid = r['navigationEndpoint']?['watchEndpoint']?['videoId'] as String?;
                        if (epVid != null && epVid.isNotEmpty) {
                          vid = epVid;
                          break;
                        }
                      }
                    }
                  }
                  if (vid != null) break;
                }
              }

              if (vid != null && vid.isNotEmpty && seen.add(vid)) {
                final flexCols = item['flexColumns'] as List<dynamic>? ?? [];
                String title = '';
                if (flexCols.isNotEmpty && flexCols[0] is Map<String, dynamic>) {
                  final runs = flexCols[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List<dynamic>? ?? [];
                  title = runs.map((r) => r is Map<String, dynamic> ? (r['text'] as String? ?? '') : '').join().trim();
                }

                String artist = '';
                String? album;
                var durationSec = 0;

                if (flexCols.length > 1 && flexCols[1] is Map<String, dynamic>) {
                  final runs = flexCols[1]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List<dynamic>? ?? [];
                  final texts = runs
                      .map((r) => r is Map<String, dynamic> ? (r['text'] as String? ?? '').trim() : '')
                      .where((t) => t.isNotEmpty)
                      .toList();

                  final parts = <String>[];
                  final curr = <String>[];
                  for (final t in texts) {
                    if (t == '•') {
                      if (curr.isNotEmpty) {
                        parts.add(curr.join(' '));
                        curr.clear();
                      }
                    } else {
                      curr.add(t);
                    }
                  }
                  if (curr.isNotEmpty) parts.add(curr.join(' '));

                  if (parts.isNotEmpty) artist = parts[0];
                  for (var i = 1; i < parts.length; i++) {
                    final p = parts[i];
                    final durMatch = RegExp(r'^(\d+):(\d+)$').firstMatch(p);
                    if (durMatch != null) {
                      durationSec = int.parse(durMatch.group(1)!) * 60 + int.parse(durMatch.group(2)!);
                    } else if (album == null && !RegExp(r'(plays|views)$', caseSensitive: false).hasMatch(p)) {
                      album = p;
                    }
                  }
                }

                String? cover;
                final thumbObj = item['thumbnail'] as Map<String, dynamic>?;
                final thumbRenderer = thumbObj?['musicThumbnailRenderer'] as Map<String, dynamic>?;
                final thumbList = thumbRenderer?['thumbnail']?['thumbnails'] as List<dynamic>? ?? [];
                if (thumbList.isNotEmpty) {
                  final last = thumbList.last as Map<String, dynamic>?;
                  final rawUrl = last?['url'] as String? ?? '';
                  if (rawUrl.isNotEmpty) {
                    cover = rawUrl.replaceAll(RegExp(r'=w\d+-h\d+-'), '=w544-h544-');
                  }
                }

                candidates.add(
                  YtmTrackCandidate(
                    videoId: vid,
                    title: title.isNotEmpty ? title : 'YouTube Music Track',
                    artist: artist.isNotEmpty ? artist : 'Unknown Artist',
                    album: album,
                    duration: Duration(seconds: durationSec),
                    coverUrl: cover,
                    backgroundUrl: 'https://i.ytimg.com/vi/$vid/maxresdefault.jpg',
                  ),
                );
              }
            }
          } else {
            for (final v in node.values) {
              walk(v);
            }
          }
        } else if (node is List) {
          for (final it in node) {
            walk(it);
          }
        }
      }

      walk(contents);
      return candidates;
    } catch (_) {
      return [];
    }
  }

  /// Searches YouTube Music (WEB_REMIX) and returns matching video IDs.
  Future<List<String>> searchMusicTracks(String query) async {
    final cands = await searchMusic(query);
    return cands.map((c) => c.videoId).toList();
  }

  /// Searches YouTube Music and maps results directly into [Track] domain entities.
  Future<List<Track>> searchMusicTrackEntities(String query, {int limit = 20}) async {
    final cands = await searchMusic(query, limit: limit);
    return cands.map((c) => c.toTrack()).toList();
  }

  /// Retrieves music search auto-complete suggestions from YouTube Music.
  Future<List<String>> getMusicSearchSuggestions(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    try {
      final uri = Uri.parse(
        'https://music.youtube.com/youtubei/v1/music/get_search_suggestions?prettyPrint=false',
      );
      final req = await _client.postUrl(uri).timeout(const Duration(seconds: 4));
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      );
      req.headers.set('Referer', 'https://music.youtube.com/');
      req.headers.set('Content-Type', 'application/json');

      final payload = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240422.01.00',
            'hl': 'en',
            'gl': 'IN',
          }
        },
        'input': clean,
      };

      req.add(utf8.encode(jsonEncode(payload)));
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return [];

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      final suggestions = <String>[];
      final seen = <String>{};

      void walk(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node.containsKey('searchSuggestionRenderer')) {
            final rend = node['searchSuggestionRenderer'] as Map<String, dynamic>?;
            final epQuery = rend?['navigationEndpoint']?['searchEndpoint']?['query'] as String?;
            if (epQuery != null && epQuery.isNotEmpty && seen.add(epQuery.toLowerCase())) {
              suggestions.add(epQuery);
            }
          } else {
            for (final v in node.values) {
              walk(v);
            }
          }
        } else if (node is List) {
          for (final it in node) {
            walk(it);
          }
        }
      }

      walk(json['contents']);
      return suggestions;
    } catch (_) {
      return [];
    }
  }

  /// Resolves high-resolution 16:9 / 1080p background artwork from YouTube Music.
  Future<String?> resolveBackgroundArtwork(String videoIdOrQuery) async {
    String? vid;
    final clean = videoIdOrQuery
        .replaceFirst('ytm_', '')
        .replaceFirst('yt_', '')
        .trim();
    if (clean.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) {
      vid = clean;
    } else {
      final cands = await searchMusic(clean);
      if (cands.isNotEmpty) {
        vid = cands.first.videoId;
      }
    }

    if (vid == null) return null;

    try {
      final data = await queryPlayer(vid);
      if (data != null) {
        // 1. Try microformat 1280x720 / 1920x1080 backdrop
        final microThumb = data['microformat']?['microformatDataRenderer']?['thumbnail']?['thumbnails'] as List<dynamic>?;
        if (microThumb != null && microThumb.isNotEmpty) {
          final url = microThumb.last['url'] as String?;
          if (url != null && url.isNotEmpty) {
            return url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
          }
        }

        // 2. Try videoDetails landscape thumbnail
        final vidThumb = data['videoDetails']?['thumbnail']?['thumbnails'] as List<dynamic>?;
        if (vidThumb != null && vidThumb.isNotEmpty) {
          final url = vidThumb.last['url'] as String?;
          if (url != null && url.isNotEmpty) {
            return url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
          }
        }
      }
    } catch (_) {}

    return 'https://i.ytimg.com/vi/$vid/maxresdefault.jpg';
  }

  void close() {
    _client.close();
  }
}
