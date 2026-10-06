// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:just_audio/just_audio.dart';

/// Custom StreamAudioSource that proxies progressive media requests into
/// chunked byte-range requests bounded to <= 256 KB, ensuring GoogleVideo
/// audio streams never receive HTTP 403 Forbidden.
class ChunkedStreamAudioSource extends StreamAudioSource {
  final Uri uri;
  final int totalBytes;
  final String contentType;
  final HttpClient _client = HttpClient();

  static const String _userAgent =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
  static const int _maxChunkSize = 256 * 1024; // 256 KB max accepted by YouTube

  ChunkedStreamAudioSource({
    required this.uri,
    required this.totalBytes,
    this.contentType = 'audio/mp4',
    super.tag,
  });

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final targetEnd = end ?? (effectiveStart + _maxChunkSize);
    final effectiveEnd =
        min(targetEnd, min(totalBytes, effectiveStart + _maxChunkSize));

    final request = await _client.getUrl(uri);
    request.headers.set('User-Agent', _userAgent);
    request.headers.set('Range', 'bytes=$effectiveStart-${effectiveEnd - 1}');

    final response = await request.close();
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }

    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: totalBytes,
      contentLength: effectiveEnd - effectiveStart,
      offset: effectiveStart,
      stream: response,
      contentType: contentType,
    );
  }
}
