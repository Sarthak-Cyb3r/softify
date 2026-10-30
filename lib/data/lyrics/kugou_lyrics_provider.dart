import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'lrclib_lyrics_provider.dart';
import 'spotify_lyrics_synchronizer.dart';

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
      final cleanTitle = SpotifyLyricsSynchronizer.cleanTrackTitle(track.title);
      final cleanArtist = SpotifyLyricsSynchronizer.cleanArtistName(track.artist);
      final primaryArtist = cleanArtist.split(RegExp(r'[,&/]')).first.trim();
      final query = '$cleanTitle $primaryArtist'.trim();

      // 1. Search song info & file hash
      final searchUri = Uri.parse(
        'https://songsearch.kugou.com/song_search_v2?keyword=${Uri.encodeComponent(query)}&page=1&pagesize=5',
      );
      final searchData = await _getJson(searchUri);
      if (searchData == null) return null;

      final infoList = (searchData['data']?['lists'] as List?)?.cast<Map<String, dynamic>>() ??
          (searchData['data']?['info'] as List?)?.cast<Map<String, dynamic>>() ??
          [];
      if (infoList.isEmpty) return null;

      // Filter candidates to strictly verify song title matches
      final matchingSongs = infoList.where((info) {
        final songName = (info['SongName'] ?? info['FileName'] ?? '').toString();
        return _isTitleMatch(cleanTitle, songName);
      }).toList();
      if (matchingSongs.isEmpty) return null;

      // Match candidate with closest duration among verified title matches
      Map<String, dynamic> bestSong = matchingSongs.first;
      if (track.duration.inSeconds > 0) {
        int bestDiff = 999999;
        for (final info in matchingSongs) {
          final dur = (info['Duration'] ?? info['duration'] as num?)?.toInt() ?? 0;
          final diff = (dur - track.duration.inSeconds).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestSong = info;
          }
        }
      }

      final hash = (bestSong['FileHash'] ?? bestSong['HQFileHash'] ?? bestSong['hash']) as String?;
      if (hash == null || hash.isEmpty) return null;

      // 2. Search lyric candidates using audio file hash
      final lyricSearchUri = Uri.parse(
        'https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=&duration=&hash=$hash',
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
        'https://krcs.kugou.com/download?ver=1&client=mobi&id=$candId&accesskey=$accessKey&fmt=lrc&charset=utf8',
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
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 4));
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  bool _isTitleMatch(String targetTitle, String candidateName) {
    final normTarget = _normalizeTitle(targetTitle);
    final normCand = _normalizeTitle(candidateName);
    if (normTarget.isEmpty || normCand.isEmpty) return false;
    if (normTarget == normCand) return true;
    if (normCand.contains(normTarget) || normTarget.contains(normCand)) return true;

    final targetTokens = normTarget.split(' ').where((w) => w.isNotEmpty).toSet();
    final candTokens = normCand.split(' ').where((w) => w.isNotEmpty).toSet();
    if (targetTokens.isEmpty || candTokens.isEmpty) return false;
    final common = targetTokens.intersection(candTokens);
    return (common.length / targetTokens.length) >= 0.5;
  }

  String _normalizeTitle(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
