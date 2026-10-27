import 'dart:convert';
import 'dart:io';

import '../../data/lyrics/lrclib_lyrics_provider.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';

/// Zemer: verified lyrics provider for Jewish, Hebrew, and Yiddish music.
/// Queries `https://search.zemer.io` by YouTube videoId or track metadata,
/// resolving and fetching pointers across jkaraoke, lrclib, jyrics, shironet,
/// zingmusic, tab4u, and zemirotdb.
class ZemerLyricsProvider implements ILyricsProvider {
  final HttpClient _httpClient;
  final String _baseUrl;
  final Map<String, SyncedLyrics?> _cache = {};

  static const String defaultEndpoint = 'https://search.zemer.io';

  ZemerLyricsProvider({
    HttpClient? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 30)
              ..maxConnectionsPerHost = 4),
        _baseUrl = baseUrl ?? defaultEndpoint;

  static final RegExp _numericEntity = RegExp(r'&#(\d+);');
  static final RegExp _hexEntity = RegExp(r'&#x([0-9a-fA-F]+);');
  static final RegExp _tag = RegExp(r'<[^>]+>');
  static final RegExp _br = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final RegExp _spaces = RegExp(r'[ \t ]+');
  static final RegExp _jyricsCut = RegExp(
    r'<ul[^>]*class="[^"]*related-list|<h\d[^>]*>\s*Other Songs from',
    caseSensitive: false,
  );
  static final RegExp _jyricsScript = RegExp(
    r'<script[\s\S]*?</script>|<style[\s\S]*?</style>|<!--[\s\S]*?-->',
  );
  static final RegExp _jyricsNav = RegExp(
    r'^(Print|SHARE|Added by|admin)$',
    caseSensitive: false,
  );
  static final RegExp _label = RegExp(
    r'^\(?\s*(verse|chorus|bridge|intro|outro|pre-?chorus|hook|refrain|interlude|פזמון|בית|גשר|מעבר|סיום|פתיחה)\s*[\d\w]*\s*:?\s*\)?$',
    caseSensitive: false,
  );
  static final RegExp _credit = RegExp(
    r'^\(?\s*(composed|arranged|written|lyrics|words|music|produced|recorded|later recorded|originally|from the album|album)\b[^\n]*\bby\b|^\(?\s*(composed|arranged|recorded)\b|^(מילים|לחן|עיבוד|הפקה)\s*:',
    caseSensitive: false,
  );

  /// Unescapes HTML entities commonly found in Hebrew & Jewish music lyrics portals.
  static String unescape(String s) {
    return s
        .replaceAll('&#8217;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&#8211;', '–')
        .replaceAll('&ndash;', '–')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(_numericEntity, (m) {
          final code = int.tryParse(m.group(1)!);
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        })
        .replaceAllMapped(_hexEntity, (m) {
          final code = int.tryParse(m.group(1)!, radix: 16);
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        });
  }

  /// Collapses spaces and removes superfluous leading/trailing blank lines.
  static String tidy(List<String> lines) {
    final out = <String>[];
    for (final raw in lines) {
      final l = raw.replaceAll(_spaces, ' ').trim();
      if (l.isNotEmpty || (out.isNotEmpty && out.last.isNotEmpty)) {
        out.add(l);
      }
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    while (out.isNotEmpty && out.first.isEmpty) {
      out.removeAt(0);
    }
    return out.join('\n');
  }

  /// Formats seconds into standard LRC timestamp `mm:ss.xx`.
  static String lrcTime(double s) {
    final m = (s / 60).toInt();
    final rem = s - m * 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = rem.toStringAsFixed(2).padLeft(5, '0');
    return '$mStr:$sStr';
  }

  /// Verifies body has at least 4 non-blank lyric lines.
  static bool hasBody(String text) {
    return text.split('\n').where((l) => l.trim().isNotEmpty).length >= 4;
  }

  /// Returns numeric rank for source types (lower rank is preferred).
  static int rank(String type) {
    switch (type) {
      case 'jkaraoke':
        return 0;
      case 'lrclib':
      case 'jyrics':
      case 'shironet':
      case 'zingmusic':
      case 'tab4u':
      case 'zemirotdb':
        return 1;
      case 'booklet':
      case 'manual':
        return 2;
      case 'canonical':
      case 'community':
        return 3;
      default:
        return 9;
    }
  }

  /// Extracts the YouTube video ID from [Track] sourceId or id.
  static String extractVideoId(Track track) {
    if (track.sourceId.startsWith('yt_')) {
      return track.sourceId.substring(3);
    }
    if (track.id.startsWith('yt_')) {
      return track.id.substring(3);
    }
    final ytIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (ytIdRegex.hasMatch(track.sourceId)) {
      return track.sourceId;
    }
    if (ytIdRegex.hasMatch(track.id)) {
      return track.id;
    }
    return track.sourceId.isNotEmpty ? track.sourceId : track.id;
  }

  /// Resolves track video ID or query on Zemer search service.
  Future<Map<String, dynamic>?> resolve(
    String videoId, [
    Track? track,
  ]) async {
    try {
      if (videoId.isNotEmpty) {
        final uri = Uri.parse('$_baseUrl/lyrics/resolve').replace(
          queryParameters: {'videoId': videoId},
        );
        final body = await _fetchText(uri.toString());
        if (body != null) {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic> &&
              decoded['sources'] is List &&
              (decoded['sources'] as List).isNotEmpty) {
            return decoded;
          }
        }
      }

      // Metadata query fallback
      if (track != null) {
        final q = '${track.title} ${track.artist}'.trim();
        if (q.isNotEmpty) {
          final searchUri = Uri.parse('$_baseUrl/lyrics/resolve').replace(
            queryParameters: {'q': q},
          );
          final body = await _fetchText(searchUri.toString());
          if (body != null) {
            final decoded = jsonDecode(body);
            if (decoded is Map<String, dynamic> &&
                decoded['sources'] is List &&
                (decoded['sources'] as List).isNotEmpty) {
              return decoded;
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches and parses lyrics body for a specific pointer source.
  Future<String?> fetchBody(Map<String, dynamic> source) async {
    final type = source['type'] as String? ?? '';
    switch (type) {
      case 'jkaraoke':
        final feedUrl = source['feedUrl'] as String?;
        final songId = (source['songId'] as num?)?.toInt();
        if (feedUrl != null && songId != null) {
          final page = await _fetchText(feedUrl);
          if (page != null) {
            return jkaraokeLrc(page, songId);
          }
        }
        return null;

      case 'lrclib':
        final trackId = source['trackId'];
        if (trackId != null) {
          final body = await _fetchText('https://lrclib.net/api/get/$trackId');
          if (body != null) {
            return lrclibBody(body);
          }
        }
        return null;

      case 'jyrics':
        final url = source['url'] as String?;
        if (url != null) {
          final html = await _fetchText(url);
          if (html != null) {
            return parseJyrics(html);
          }
        }
        return null;

      case 'shironet':
        final url = source['url'] as String?;
        if (url != null) {
          final html = await _fetchText(url);
          if (html != null) {
            return parseShironet(html);
          }
        }
        return null;

      case 'zingmusic':
        final trackId = source['trackId'];
        if (trackId != null) {
          final html = await _zingLyricsHtml(trackId);
          if (html != null) {
            return zingToPlain(html);
          }
        }
        return null;

      case 'tab4u':
        final url = source['url'] as String?;
        if (url != null) {
          final html = await _fetchText(url);
          if (html != null) {
            return parseTab4u(html);
          }
        }
        return null;

      case 'zemirotdb':
        final url = source['url'] as String?;
        if (url != null) {
          final html = await _fetchText(url);
          if (html != null) {
            return parseZemirotDb(html);
          }
        }
        return null;

      case 'booklet':
      case 'manual':
      case 'canonical':
      case 'community':
        final syncedLrc = source['syncedLrc'] as String?;
        if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
          return syncedLrc;
        }
        final plain = source['plain'] as String?;
        if (plain != null && plain.trim().isNotEmpty) {
          return plain;
        }
        return null;

      default:
        return null;
    }
  }

  /// Parses JKaraoke JSON feed into synchronized LRC text.
  static String? jkaraokeLrc(String pageJson, int songId) {
    try {
      final map = jsonDecode(pageJson) as Map<String, dynamic>;
      final data =
          (map['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final song = data.firstWhere(
        (s) => s['id'] == songId || (s['id'] as num?)?.toInt() == songId,
        orElse: () => <String, dynamic>{},
      );
      if (song.isEmpty) return null;

      final rawLyrics =
          (song['lyrics'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final ls = rawLyrics.where((it) {
        final start = it['start'];
        final text = it['text'] as String?;
        return start != null && text != null && text.trim().isNotEmpty;
      }).toList();

      if (ls.length < 4) return null;

      for (int k = 1; k < ls.length; k++) {
        final curr = (ls[k]['start'] as num).toDouble();
        final prev = (ls[k - 1]['start'] as num).toDouble();
        if (curr + 0.01 < prev) return null;
      }

      final firstStart = (ls.first['start'] as num).toDouble();
      if (firstStart < 0) return null;

      final dur = (song['duration'] as num?)?.toInt();
      final lastStart = (ls.last['start'] as num).toDouble();
      if (dur != null && dur > 0 && lastStart > dur + 2) return null;

      return ls.map((it) {
        final sec = (it['start'] as num).toDouble();
        final text = (it['text'] as String).trim();
        return '[${lrcTime(sec)}]$text';
      }).join('\n');
    } catch (_) {
      return null;
    }
  }

  /// Extracts synced or plain lyrics from LRCLIB JSON payload.
  static String? lrclibBody(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      if (map['instrumental'] == true) return null;
      final synced = map['syncedLyrics'] as String?;
      if (synced != null && synced.trim().isNotEmpty) {
        return synced;
      }
      final plain = map['plainLyrics'] as String?;
      if (plain != null && plain.trim().isNotEmpty) {
        return plain;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parses JYrics HTML structure, cleaning boilerplate and metadata.
  static String? parseJyrics(String html) {
    try {
      final artMatch = RegExp(r'<article[\s\S]*?</article>').firstMatch(html);
      var art = artMatch?.group(0) ?? html;
      final cutMatch = _jyricsCut.firstMatch(art);
      if (cutMatch != null) {
        art = art.substring(0, cutMatch.start);
      }
      final text = unescape(
        art
            .replaceAll(_jyricsScript, '')
            .replaceAll(_br, '\n')
            .replaceAll(RegExp(r'</p>\s*', caseSensitive: false), '\n\n')
            .replaceAll(RegExp(r'</(div|h\d|li)>\s*', caseSensitive: false), '\n')
            .replaceAll(_tag, ''),
      );
      final lines = text
          .split('\n')
          .map((l) => l.replaceAll(_spaces, ' ').trim())
          .toList();
      final i = lines.indexWhere((l) => l.toLowerCase() == 'lyric');
      final body = (i >= 0 ? lines.sublist(i + 1) : lines)
          .where((l) => !_jyricsNav.hasMatch(l))
          .toList();
      while (body.isNotEmpty && body.first.isEmpty) {
        body.removeAt(0);
      }
      if (body.isNotEmpty) {
        body.removeAt(0);
      }
      final filtered = body
          .where((l) => !_label.hasMatch(l) && !_credit.hasMatch(l))
          .toList();
      final res = tidy(filtered);
      return res.isEmpty ? null : res;
    } catch (_) {
      return null;
    }
  }

  /// Parses Shironet lyric HTML.
  static String? parseShironet(String html) {
    try {
      final spanMatch = RegExp(
        r'<span[^>]*class="artist_lyrics_text"[^>]*>([\s\S]*?)</span>',
      ).firstMatch(html);
      if (spanMatch == null) return null;
      final span = spanMatch.group(1)!;
      final text = unescape(span.replaceAll(_br, '\n').replaceAll(_tag, ''));
      final lines =
          text.split('\n').where((l) => !_label.hasMatch(l.trim())).toList();
      final res = tidy(lines);
      return res.isEmpty ? null : res;
    } catch (_) {
      return null;
    }
  }

  /// Strips formatting tags and bracket labels from ZingMusic HTML.
  static String? zingToPlain(String html) {
    try {
      final text = unescape(
        html
            .replaceAll(_br, '\n')
            .replaceAll(
              RegExp(r'</(p|div|pre|li|h\d)>', caseSensitive: false),
              '\n',
            )
            .replaceAll(_tag, '')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>'),
      );
      final bracketLabel = RegExp(r'^\[[^\]]*\]$');
      final parenLabel = RegExp(
        r'^\((?:verse|chorus|bridge|intro|outro|פזמון|בית|מעבר|גשר)\b[^)]*\)$',
        caseSensitive: false,
      );
      final lines = text.split('\n').where((it) {
        final l = it.trim();
        return !bracketLabel.hasMatch(l) && !parenLabel.hasMatch(l);
      }).toList();
      final res = tidy(lines);
      return res.isEmpty ? null : res;
    } catch (_) {
      return null;
    }
  }

  /// Parses Tab4u Hebrew lyrics tab cells.
  static String? parseTab4u(String html) {
    try {
      final lines = <String>[];
      final hebrewRegex = RegExp(r'[א-ת]');
      for (final m in RegExp(
        r'<td class="song[^"]*"[^>]*>([\s\S]*?)</td>',
      ).allMatches(html)) {
        final t = unescape(
          m.group(1)!.replaceAll(_tag, ''),
        ).replaceAll(_spaces, ' ').trim();
        if (t.isEmpty || !hebrewRegex.hasMatch(t)) continue;
        lines.add(t);
      }
      final res = tidy(lines);
      return res.isEmpty ? null : res;
    } catch (_) {
      return null;
    }
  }

  /// Parses ZemirotDB Hebrew lyrics section.
  static String? parseZemirotDb(String html) {
    try {
      final divMatch = RegExp(
        r'''<div id=['"]hebrew['"][^>]*>([\s\S]*?)</div>''',
      ).firstMatch(html);
      if (divMatch == null) return null;
      final div = divMatch.group(1)!;
      final text = unescape(
        div
            .replaceAll(_br, '\n')
            .replaceAll(RegExp(r'</p>\s*', caseSensitive: false), '\n\n')
            .replaceAll(_tag, ''),
      );
      final res = tidy(text.split('\n'));
      return res.isEmpty ? null : res;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    try {
      final videoId = extractVideoId(track);
      final resolved = await resolve(videoId, track);
      if (resolved == null) {
        _cache[track.id] = null;
        return null;
      }

      final rawSources = (resolved['sources'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (rawSources.isEmpty) {
        _cache[track.id] = null;
        return null;
      }

      final sortedSources = List<Map<String, dynamic>>.from(rawSources)
        ..sort((a, b) {
          final aSynced = a['synced'] == true;
          final bSynced = b['synced'] == true;
          if (aSynced != bSynced) {
            return aSynced ? -1 : 1; // Synced sources take precedence
          }
          final rankA = rank((a['type'] as String?) ?? '');
          final rankB = rank((b['type'] as String?) ?? '');
          return rankA.compareTo(rankB);
        });

      for (final source in sortedSources) {
        try {
          final body = await fetchBody(source);
          if (body != null && hasBody(body)) {
            final sourceType = source['type'] as String? ?? 'zemer';
            // Check if returned body contains LRC timestamps
            if (RegExp(r'\[\d{1,2}:\d{2}').hasMatch(body)) {
              final lines = LrclibLyricsProvider.parseLrc(body);
              if (lines.isNotEmpty) {
                final isWordSynced =
                    lines.any((l) => l.words != null && l.words!.isNotEmpty);
                final synced = SyncedLyrics(
                  trackId: track.id,
                  lines: lines,
                  rawLrc: body,
                  plainLyrics: lines.map((l) => l.text).join('\n'),
                  syncType: isWordSynced ? 'SYLLABLE_SYNCED' : 'LINE_SYNCED',
                  providerName: 'Zemer ($sourceType)',
                );
                _cache[track.id] = synced;
                return synced;
              }
            }

            // Fallback to plain lyrics
            final plainLyrics = SyncedLyrics(
              trackId: track.id,
              lines: const [],
              plainLyrics: body.trim(),
              syncType: 'UNSYNCED',
              providerName: 'Zemer ($sourceType)',
            );
            _cache[track.id] = plainLyrics;
            return plainLyrics;
          }
        } catch (_) {
          continue;
        }
      }

      _cache[track.id] = null;
      return null;
    } catch (_) {
      _cache[track.id] = null;
      return null;
    }
  }

  Future<String?> _fetchText(String url) async {
    try {
      final req = await _httpClient
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      req.headers.set('Accept', 'text/html,application/json');
      req.headers.set(
        'User-Agent',
        'Softify/1.0 (https://github.com/softify/softify)',
      );
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return await res.transform(utf8.decoder).join();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _zingLyricsHtml(dynamic trackId) async {
    try {
      final req = await _httpClient
          .postUrl(Uri.parse('https://jewishmusic.fm:8443/graphql'))
          .timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(
        'User-Agent',
        'Softify/1.0 (https://github.com/softify/softify)',
      );
      req.write(
        jsonEncode({
          'query': '{ track(where:{id:$trackId}){ heLyrics enLyrics } }',
        }),
      );
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final map = jsonDecode(body) as Map<String, dynamic>;
      final track = map['data']?['track'] as Map<String, dynamic>?;
      if (track == null) return null;
      final he = track['heLyrics'] as String?;
      if (he != null && he.trim().isNotEmpty) return he;
      return track['enLyrics'] as String?;
    } catch (_) {
      return null;
    }
  }

  void clearCache() => _cache.clear();
}
