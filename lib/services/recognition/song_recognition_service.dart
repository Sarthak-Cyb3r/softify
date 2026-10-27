import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../domain/entities/track.dart';
import 'shazam_signature_generator.dart';

/// Exception thrown when song recognition fails.
class RecognitionException implements Exception {
  final String message;
  final int? statusCode;

  const RecognitionException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'RecognitionException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Structured recognition result resolved from Apple Shazam API.
class RecognitionResult {
  final String trackId;
  final String title;
  final String artist;
  final String? album;
  final String? coverArtUrl;
  final String? coverArtHqUrl;
  final String? genre;
  final String? releaseDate;
  final String? label;
  final List<String>? lyrics;
  final String? shazamUrl;
  final String? appleMusicUrl;
  final String? spotifyUrl;
  final String? isrc;
  final String? youtubeVideoId;
  final double? offsetSeconds;

  const RecognitionResult({
    required this.trackId,
    required this.title,
    required this.artist,
    this.album,
    this.coverArtUrl,
    this.coverArtHqUrl,
    this.genre,
    this.releaseDate,
    this.label,
    this.lyrics,
    this.shazamUrl,
    this.appleMusicUrl,
    this.spotifyUrl,
    this.isrc,
    this.youtubeVideoId,
    this.offsetSeconds,
  });

  /// Converts this recognized song into Softify's core [Track] domain entity.
  Track toTrack({Duration duration = Duration.zero}) {
    return Track(
      id: trackId,
      sourceId: youtubeVideoId ?? 'shazam_$trackId',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      coverUrl: coverArtHqUrl ?? coverArtUrl,
      matchConfidence: 1.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'track_id': trackId,
      'title': title,
      'artist': artist,
      'album': album,
      'cover_art_url': coverArtUrl,
      'cover_art_hq_url': coverArtHqUrl,
      'genre': genre,
      'release_date': releaseDate,
      'label': label,
      'lyrics': lyrics,
      'shazam_url': shazamUrl,
      'apple_music_url': appleMusicUrl,
      'spotify_url': spotifyUrl,
      'isrc': isrc,
      'youtube_video_id': youtubeVideoId,
      'offset_seconds': offsetSeconds,
    };
  }

  factory RecognitionResult.fromMap(Map<String, dynamic> map) {
    return RecognitionResult(
      trackId: map['track_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String?,
      coverArtUrl: map['cover_art_url'] as String?,
      coverArtHqUrl: map['cover_art_hq_url'] as String?,
      genre: map['genre'] as String?,
      releaseDate: map['release_date'] as String?,
      label: map['label'] as String?,
      lyrics: (map['lyrics'] as List<dynamic>?)?.cast<String>(),
      shazamUrl: map['shazam_url'] as String?,
      appleMusicUrl: map['apple_music_url'] as String?,
      spotifyUrl: map['spotify_url'] as String?,
      isrc: map['isrc'] as String?,
      youtubeVideoId: map['youtube_video_id'] as String?,
      offsetSeconds: (map['offset_seconds'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'RecognitionResult(trackId: $trackId, title: "$title", artist: "$artist", album: "$album")';
}

/// Cached recognition result with timestamp.
class _CachedResult {
  final int timestamp;
  final RecognitionResult? result;

  const _CachedResult(this.result, this.timestamp);
}

/// Audio recognition discovery service querying Apple's Shazam discovery gateway.
class SongRecognitionService {
  static const int minRequestIntervalMs = 1000;
  static const int maxRetries = 3;
  static const int initialRetryDelayMs = 1500;
  static const int cacheDurationMs = 300000; // 5 minutes

  final http.Client _client;
  final math.Random _random;

  int _lastRequestTime = 0;
  final Map<String, _CachedResult> _cache = {};

  static const List<String> _userAgents = [
    'Dalvik/2.1.0 (Linux; U; Android 5.0.2; VS980 4G Build/LRX22G)',
    'Dalvik/1.6.0 (Linux; U; Android 4.4.2; SM-T210 Build/KOT49H)',
    'Dalvik/2.1.0 (Linux; U; Android 5.1.1; SM-P905V Build/LMY47X)',
    'Dalvik/2.1.0 (Linux; U; Android 6.0.1; SM-G920F Build/MMB29K)',
    'Dalvik/2.1.0 (Linux; U; Android 5.0; SM-G900F Build/LRX21T)',
  ];

  static const List<String> _timezones = [
    'Europe/Paris',
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
    'Asia/Tokyo',
    'Asia/Dubai',
  ];

  SongRecognitionService({http.Client? client, math.Random? random})
      : _client = client ?? http.Client(),
        _random = random ?? math.Random();

  /// Clears in-memory recognition result cache.
  void clearCache() => _cache.clear();

  /// Recognizes audio from 16kHz 16-bit mono PCM bytes.
  Future<RecognitionResult?> recognizePcm(
    Uint8List pcmBytes, {
    int? sampleDurationMs,
    int magicHeader = ShazamSignatureGenerator.kDefaultMagicHeader,
  }) async {
    final signature = ShazamSignatureGenerator.fromI16(
      pcmBytes,
      magicHeader: magicHeader,
    );
    final durationMs = sampleDurationMs ?? (pcmBytes.length ~/ 32);
    return recognizeSignature(signature, sampleDurationMs: durationMs);
  }

  /// Queries the Apple Shazam API using the generated base64 Data URI signature.
  Future<RecognitionResult?> recognizeSignature(
    String signatureUri, {
    int sampleDurationMs = 3000,
  }) async {
    final cacheKey = signatureUri.hashCode.toString();
    final cached = _getCachedResult(cacheKey);
    if (cached != null) return cached.result;

    await _enforceRateLimit();

    RecognitionResult? result;
    Exception? lastException;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        result = await _executeRequest(signatureUri, sampleDurationMs);
        _cacheResult(cacheKey, result);
        return result;
      } on RecognitionException catch (e) {
        lastException = e;
        if (e.statusCode == 429) {
          if (attempt < maxRetries - 1) {
            final delayMs = initialRetryDelayMs * (1 << attempt);
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
        }
        rethrow;
      } catch (e) {
        lastException = RecognitionException('Network error: $e');
        if (attempt < maxRetries - 1) {
          final delayMs = initialRetryDelayMs * (1 << attempt);
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
      }
    }

    if (lastException != null) throw lastException;
    return null;
  }

  Future<RecognitionResult?> _executeRequest(
    String signatureUri,
    int sampleDurationMs,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uuid1 = _generateUuid().toUpperCase();
    final uuid2 = _generateUuid();

    final url = Uri.parse(
      'https://amp.shazam.com/discovery/v5/en/US/android/-/tag/$uuid1/$uuid2?'
      'sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true&video=v3',
    );

    final userAgent = _userAgents[_random.nextInt(_userAgents.length)];
    final timezone = _timezones[_random.nextInt(_timezones.length)];

    final requestBody = {
      'geolocation': {
        'altitude': _random.nextDouble() * 400 + 100,
        'latitude': _random.nextDouble() * 180 - 90,
        'longitude': _random.nextDouble() * 360 - 180,
      },
      'signature': {
        'samplems': sampleDurationMs,
        'timestamp': timestamp,
        'uri': signatureUri,
      },
      'timestamp': timestamp,
      'timezone': timezone,
    };

    final response = await _client.post(
      url,
      headers: {
        'User-Agent': userAgent,
        'Content-Language': 'en_US',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 429) {
      throw const RecognitionException('Too many requests', 429);
    }
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode >= 500) {
      throw RecognitionException(
        'Shazam service temporarily unavailable',
        response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecognitionException(
        'Recognition failed with HTTP ${response.statusCode}',
        response.statusCode,
      );
    }

    final Map<String, dynamic> jsonResponse;
    try {
      jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw RecognitionException('Failed to parse Shazam JSON: $e');
    }

    return _parseShazamResponse(jsonResponse);
  }

  RecognitionResult? _parseShazamResponse(Map<String, dynamic> json) {
    final track = json['track'] as Map<String, dynamic>?;
    if (track == null) return null;

    final tagId = json['tagid'] as String?;
    final trackId = (track['key'] as String?) ?? tagId ?? '';
    final title = (track['title'] as String?) ?? '';
    final artist = (track['subtitle'] as String?) ?? '';

    // Parse sections
    String? album;
    String? label;
    String? releaseDate;
    List<String>? lyrics;

    final sections = track['sections'] as List<dynamic>?;
    if (sections != null) {
      for (final s in sections) {
        if (s is! Map<String, dynamic>) continue;
        final type = s['type'] as String?;

        if (type == 'SONG') {
          final metadata = s['metadata'] as List<dynamic>?;
          if (metadata != null) {
            for (final m in metadata) {
              if (m is! Map<String, dynamic>) continue;
              final metaTitle = m['title'] as String?;
              final text = m['text'] as String?;
              if (metaTitle == 'Album') {
                album = text;
              } else if (metaTitle == 'Label') {
                label = text;
              } else if (metaTitle == 'Released') {
                releaseDate = text;
              }
            }
          }
        } else if (type == 'LYRICS') {
          final textList = s['text'] as List<dynamic>?;
          if (textList != null) {
            lyrics = textList.cast<String>();
          }
        }
      }
    }

    // Images
    final images = track['images'] as Map<String, dynamic>?;
    final coverArt = images?['coverart'] as String?;
    final coverArtHq = images?['coverarthq'] as String?;

    // Genres
    final genres = track['genres'] as Map<String, dynamic>?;
    final primaryGenre = genres?['primary'] as String?;

    // Hub options & actions
    String? appleMusicUrl;
    String? spotifyUrl;
    String? youtubeVideoId;

    final hub = track['hub'] as Map<String, dynamic>?;
    if (hub != null) {
      // Apple Music
      final options = hub['options'] as List<dynamic>?;
      if (options != null) {
        for (final opt in options) {
          if (opt is! Map<String, dynamic>) continue;
          final providerName = opt['providername'] as String?;
          final optType = opt['type'] as String?;
          final actions = opt['actions'] as List<dynamic>?;
          final firstAction = actions?.firstOrNull as Map<String, dynamic>?;
          final uri = firstAction?['uri'] as String?;

          if (providerName != null &&
              providerName.toLowerCase().contains('apple')) {
            appleMusicUrl ??= uri;
          }

          if (optType != null &&
              optType.toLowerCase().contains('video') &&
              uri != null) {
            if (uri.contains('v=')) {
              youtubeVideoId = uri.split('v=').last.split('&').first;
            } else {
              final lastSeg = uri.split('/').last;
              if (lastSeg.length == 11) {
                youtubeVideoId = lastSeg;
              }
            }
          }
        }
      }

      // Spotify Provider
      final providers = hub['providers'] as List<dynamic>?;
      if (providers != null) {
        for (final prov in providers) {
          if (prov is! Map<String, dynamic>) continue;
          final caption = prov['caption'] as String?;
          if (caption != null && caption.toLowerCase().contains('spotify')) {
            final actions = prov['actions'] as List<dynamic>?;
            final firstAction = actions?.firstOrNull as Map<String, dynamic>?;
            spotifyUrl = firstAction?['uri'] as String?;
          }
        }
      }
    }

    // Match offset
    double? offsetSeconds;
    final matches = json['matches'] as List<dynamic>?;
    if (matches != null && matches.isNotEmpty) {
      final firstMatch = matches.first as Map<String, dynamic>?;
      offsetSeconds = (firstMatch?['offset'] as num?)?.toDouble();
    }

    return RecognitionResult(
      trackId: trackId,
      title: title,
      artist: artist,
      album: album,
      coverArtUrl: coverArt,
      coverArtHqUrl: coverArtHq,
      genre: primaryGenre,
      releaseDate: releaseDate,
      label: label,
      lyrics: lyrics,
      shazamUrl: track['url'] as String?,
      appleMusicUrl: appleMusicUrl,
      spotifyUrl: spotifyUrl,
      isrc: track['isrc'] as String?,
      youtubeVideoId: youtubeVideoId,
      offsetSeconds: offsetSeconds,
    );
  }

  Future<void> _enforceRateLimit() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - _lastRequestTime;
    if (diff < minRequestIntervalMs) {
      await Future.delayed(Duration(milliseconds: minRequestIntervalMs - diff));
    }
    _lastRequestTime = DateTime.now().millisecondsSinceEpoch;
  }

  _CachedResult? _getCachedResult(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - cached.timestamp > cacheDurationMs) {
      _cache.remove(key);
      return null;
    }
    return cached;
  }

  void _cacheResult(String key, RecognitionResult? result) {
    _cache[key] = _CachedResult(result, DateTime.now().millisecondsSinceEpoch);
    if (_cache.length > 200) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _cache.removeWhere((_, v) => now - v.timestamp > cacheDurationMs);
    }
  }

  String _generateUuid() {
    String hex4() => _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return '${hex4()}${hex4()}-${hex4()}-4${hex4().substring(1)}-${(8 + _random.nextInt(4)).toRadixString(16)}${hex4().substring(1)}-${hex4()}${hex4()}${hex4()}';
  }
}
