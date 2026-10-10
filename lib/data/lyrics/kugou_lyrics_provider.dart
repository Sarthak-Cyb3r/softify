import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'lrclib_lyrics_provider.dart';

/// Fallback / secondary lyrics provider backed by Kugou's public music catalog.
/// Kugou provides millisecond-accurate synchronized LRC lyrics for global tracks.
class KugouLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final Map<String, SyncedLyrics?> _cache = {};

  KugouLyricsProvider({HttpClient? httpClient})
      : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 30)
              ..maxConnectionsPerHost = 4);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    try {
      final cleanTitle = _cleanTitle(track.title);
      final query = '$cleanTitle ${track.artist}'.trim();

      // 1. Search song info & file hash
      final searchUri = Uri.parse(
        'http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=${Uri.encodeComponent(query)}&page=1&pagesize=5',
      );
      final searchData = await _getJson(searchUri);
      if (searchData == null) return null;

      final infoList = (searchData['data']?['info'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (infoList.isEmpty) return null;

      // Match candidate with closest duration
      Map<String, dynamic> bestSong = infoList.first;
      if (track.duration.inSeconds > 0) {
        int bestDiff = 999999;
        for (final info in infoList) {
          final dur = (info['duration'] as num?)?.toInt() ?? 0;
          final diff = (dur - track.duration.inSeconds).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestSong = info;
          }
        }
      }

      final hash = bestSong['hash'] as String?;
      if (hash == null || hash.isEmpty) return null;

      // 2. Search lyric candidates using audio file hash
      final lyricSearchUri = Uri.parse(
        'http://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=&duration=&hash=$hash',
      );
      final lyricSearchData = await _getJson(lyricSearchUri);
      if (lyricSearchData == null) return null;

      final candidates = (lyricSearchData['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (candidates.isEmpty) return null;

      final bestCandidate = candidates.first;
      final candId = bestCandidate['id'];
      final accessKey = bestCandidate['accesskey'];
      if (candId == null || accessKey == null) return null;

      // 3. Download lyric text in LRC format
      final downloadUri = Uri.parse(
        'http://krcs.kugou.com/download?ver=1&client=mobi&id=$candId&accesskey=$accessKey&fmt=lrc&charset=utf8',
      );
      final downloadData = await _getJson(downloadUri);
      if (downloadData == null) return null;

      final base64Content = downloadData['content'] as String?;
      if (base64Content == null || base64Content.isEmpty) return null;

      final lrcString = utf8.decode(base64.decode(base64Content), allowMalformed: true);
      final lines = LrclibLyricsProvider.parseLrc(lrcString);
      if (lines.isEmpty) return null;

      final result = SyncedLyrics(
        trackId: track.id,
        lines: lines,
        rawLrc: lrcString,
      );
      _cache[track.id] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final req = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
      req.headers.set('User-Agent', 'Mozilla/5.0 (X11; Linux x86_64)');
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\s+feat\..*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+ft\..*$', caseSensitive: false), '')
        .trim();
  }
}
