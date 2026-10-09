import 'dart:convert';
import 'dart:io';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_stream_resolver.dart';

class PipedStreamResolver implements IStreamResolver {
  final List<String> _instances;
  final HttpClient _httpClient;
  int _currentInstanceIndex = 0;

  // In-memory short-lived stream cache (45 min TTL)
  final Map<String, StreamInfo> _cache = {};

  PipedStreamResolver({
    List<String>? instances,
    HttpClient? httpClient,
  })  : _instances = instances ??
            [
              'https://pipedapi.kavin.rocks',
              'https://api.piped.privacydev.net',
              'https://piped-api.lunar.icu',
            ],
        _httpClient = httpClient ?? HttpClient();

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    final cacheKey = '${track.sourceId}_${quality.name}';
    if (!forceFresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (!cached.isExpired) {
        return cached;
      }
    }

    Exception? lastError;
    final totalInstances = _instances.length;

    for (int attempt = 0; attempt < totalInstances; attempt++) {
      final instanceIndex = (_currentInstanceIndex + attempt) % totalInstances;
      final instanceUrl = _instances[instanceIndex];

      try {
        final rawVideoId = track.sourceId.replaceFirst('yt_', '').trim();
        final streamInfo = await _fetchFromInstance(
          instanceUrl,
          rawVideoId,
          quality,
        );

        // Mark this instance as the current working primary
        _currentInstanceIndex = instanceIndex;
        _cache[cacheKey] = streamInfo;
        return streamInfo;
      } catch (e) {
        lastError = Exception('Failed on $instanceUrl: $e');
      }
    }

    throw Exception(
      'PipedStreamResolver exhausted all $totalInstances instances for track "${track.title}" (${track.sourceId}). Last error: $lastError',
    );
  }

  Future<StreamInfo> _fetchFromInstance(
    String instanceUrl,
    String videoId,
    AudioQualityPreset quality,
  ) async {
    final uri = Uri.parse('$instanceUrl/streams/$videoId');
    final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 7));
    request.headers.set('User-Agent', 'Softify/1.0 (Mobile Android)');

    final response = await request.close().timeout(const Duration(seconds: 7));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    final audioStreams = (json['audioStreams'] as List<dynamic>?) ?? [];
    if (audioStreams.isEmpty) {
      throw Exception('No audio streams returned from $instanceUrl for $videoId');
    }

    // Filter for M4A/AAC streams
    final m4aStreams = audioStreams.where((stream) {
      final mime = (stream['mimeType'] as String? ?? '').toLowerCase();
      final format = (stream['format'] as String? ?? '').toLowerCase();
      return mime.contains('audio/mp4') || format == 'm4a';
    }).toList();

    final candidateList = m4aStreams.isNotEmpty ? m4aStreams : audioStreams;

    // Pick stream closest to target bitrate
    // standard: ~128-140 kbps (130000 bps)
    // low: ~48-64 kbps (55000 bps)
    final targetBitrate = quality == AudioQualityPreset.standard ? 130000 : 55000;

    candidateList.sort((a, b) {
      final bitA = (a['bitrate'] as num?)?.toInt() ?? 0;
      final bitB = (b['bitrate'] as num?)?.toInt() ?? 0;
      return (bitA - targetBitrate).abs().compareTo((bitB - targetBitrate).abs());
    });

    final selected = candidateList.first;
    final streamUrl = Uri.parse(selected['url'] as String);
    final bitrate = (selected['bitrate'] as num?)?.toInt() ?? 128000;
    final codec = (selected['codec'] as String?) ?? 'mp4a.40.2';

    return StreamInfo(
      url: streamUrl,
      container: 'm4a',
      bitrate: bitrate,
      codec: codec,
      expiresAt: DateTime.now().add(const Duration(minutes: 45)),
      providerName: 'piped ($instanceUrl)',
    );
  }

  @override
  Future<void> prefetch(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
  }) async {
    try {
      await resolve(track, quality: quality, forceFresh: false);
    } catch (_) {
      // Prefetch is best-effort and silent
    }
  }
}
