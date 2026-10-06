import 'dart:convert';
import 'dart:io';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';

class LrclibLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final Map<String, SyncedLyrics?> _memoryCache = {};

  LrclibLyricsProvider({HttpClient? httpClient})
      : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 45)
              ..maxConnectionsPerHost = 4);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_memoryCache.containsKey(track.id)) {
      return _memoryCache[track.id];
    }

    try {
      final queryParams = {
        'track_name': track.title,
        'artist_name': track.artist,
        'duration': track.duration.inSeconds.toString(),
      };

      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set('User-Agent', 'Softify/1.0 (https://github.com/softify/softify)');

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 404) {
        _memoryCache[track.id] = null;
        return null;
      }
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final syncedLrc = json['syncedLyrics'] as String?;
      final plainLyrics = json['plainLyrics'] as String?;

      final lines = syncedLrc != null ? parseLrc(syncedLrc) : <LyricLine>[];

      final result = SyncedLyrics(
        trackId: track.id,
        lines: lines,
        plainLyrics: plainLyrics,
        rawLrc: syncedLrc,
      );
      _memoryCache[track.id] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Parses an LRC timestamped string into a List of LyricLine items.
  static List<LyricLine> parseLrc(String syncedLrc) {
    final List<LyricLine> lines = [];
    final rawLines = syncedLrc.split('\n');
    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Parse LRC format: [mm:ss.xx] Lyrics
      final match = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(trimmed);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisRaw = match.group(3)!;
        final millis = millisRaw.length == 2
            ? int.parse(millisRaw) * 10
            : int.parse(millisRaw);
        final text = match.group(4)!.trim();

        lines.add(
          LyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: text,
          ),
        );
      }
    }
    return lines;
  }
}
