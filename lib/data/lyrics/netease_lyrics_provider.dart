import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'lrclib_lyrics_provider.dart';

/// Synchronized lyrics provider backed by NetEase Cloud Music's global catalog.
/// NetEase has one of the world's most extensive databases of timestamped LRC lyrics
/// with millisecond synchronization across international and regional languages.
class NeteaseLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final Map<String, SyncedLyrics?> _cache = {};

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  NeteaseLyricsProvider({HttpClient? httpClient})
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

      // 1. Search song catalog
      final searchUri = Uri.parse(
        'https://music.163.com/api/search/get/web?csrf_token=&hlpretag=&hlposttag=&s=${Uri.encodeComponent(query)}&type=1&offset=0&total=true&limit=5',
      );

      final searchData = await _getJson(searchUri);
      if (searchData == null) return null;

      final songsList = (searchData['result']?['songs'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (songsList.isEmpty) return null;

      // Filter candidates to strictly verify song title matches
      final matchingSongs = songsList.where((song) {
        final songName = (song['name'] ?? '').toString();
        return _isTitleMatch(cleanTitle, songName);
      }).toList();
      if (matchingSongs.isEmpty) return null;

      // Match candidate with closest duration when duration is known
      Map<String, dynamic> bestSong = matchingSongs.first;
      if (track.duration.inMilliseconds > 0) {
        int bestDiff = 99999999;
        for (final song in matchingSongs) {
          final durMs = (song['dt'] ?? song['duration'] as num?)?.toInt() ?? 0;
          if (durMs > 0) {
            final diff = (durMs - track.duration.inMilliseconds).abs();
            if (diff < bestDiff) {
              bestDiff = diff;
              bestSong = song;
            }
          }
        }
      }

      final songId = bestSong['id'];
      if (songId == null) return null;

      // 2. Fetch lyrics by song ID
      final lyricUri = Uri.parse(
        'https://music.163.com/api/song/lyric?os=pc&id=$songId&lv=-1&kv=-1&tv=-1',
      );

      final lyricData = await _getJson(lyricUri);
      if (lyricData == null) return null;

      final lrcString = lyricData['lrc']?['lyric'] as String?;
      if (lrcString == null || lrcString.trim().isEmpty) return null;

      // 3. Parse synchronized LRC lines
      final lines = LrclibLyricsProvider.parseLrc(lrcString);
      if (lines.isEmpty) return null;

      final plainLyrics = lines.map((l) => l.text).join('\n');
      final result = SyncedLyrics(
        trackId: track.id,
        lines: lines,
        plainLyrics: plainLyrics,
        rawLrc: lrcString,
      );

      _cache[track.id] = result;
      return result;
    } catch (_) {
      _cache[track.id] = null;
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 4));
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Referer', 'https://music.163.com/');

      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
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

  bool _isTitleMatch(String targetTitle, String candidateName) {
    final normTarget = _normalizeTitle(targetTitle);
    final normCand = _normalizeTitle(candidateName);
    if (normTarget.isEmpty || normCand.isEmpty) return false;
    if (normTarget == normCand) return true;
    if (normCand.contains(normTarget) || normTarget.contains(normCand)) return true;

    final targetTokens = normTarget.split(' ').where((w) => w.length > 2).toSet();
    final candTokens = normCand.split(' ').where((w) => w.length > 2).toSet();
    if (targetTokens.isEmpty || candTokens.isEmpty) return false;
    final common = targetTokens.intersection(candTokens);
    return (common.length / targetTokens.length) >= 0.6;
  }

  String _normalizeTitle(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
