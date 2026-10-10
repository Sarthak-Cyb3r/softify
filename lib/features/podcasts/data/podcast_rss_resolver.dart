import 'dart:convert';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide StreamInfo;

import '../../../data/resolvers/youtube_innertube_service.dart';
import '../../../data/resolvers/youtube_stream_resolver.dart';
import '../../../domain/entities/audio_quality_preset.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../domain/entities/track.dart';
import '../../../domain/ports/i_stream_resolver.dart';
import '../domain/podcast_failure.dart';
import 'podcast_metadata_service.dart';

class PodcastRssResolver implements IStreamResolver {
  final HttpClient _client;
  final YoutubeStreamResolver? _ytResolver;
  final PodcastMetadataService? _metadataService;
  final YoutubeExplode _yt;
  final YoutubeInnertubeService _innertubeService;
  final Map<String, StreamInfo> _cache = {};

  YoutubeStreamResolver? get ytResolver => _ytResolver;

  PodcastRssResolver({
    HttpClient? client,
    YoutubeStreamResolver? ytResolver,
    PodcastMetadataService? metadataService,
    YoutubeExplode? yt,
    YoutubeInnertubeService? innertubeService,
  })  : _client = client ?? HttpClient(),
        _ytResolver = ytResolver ?? YoutubeStreamResolver(),
        _metadataService = metadataService,
        _yt = yt ?? ytResolver?.yt ?? YoutubeExplode(),
        _innertubeService =
            innertubeService ?? ytResolver?.innertubeService ?? YoutubeInnertubeService();

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    final primaryKey = track.id;
    final secondaryKey = track.sourceId;
    if (!forceFresh) {
      if (_cache.containsKey(primaryKey) && !_cache[primaryKey]!.isExpired) {
        return _cache[primaryKey]!;
      }
      if (_cache.containsKey(secondaryKey) && !_cache[secondaryKey]!.isExpired) {
        return _cache[secondaryKey]!;
      }
    }

    // Tier 1: Search Apple / iTunes Podcast Directory for RSS Feed & Episodes
    try {
      final stream = await resolveEpisodeStream(
        showName: track.artist,
        episodeTitle: track.title,
        targetDuration: track.duration,
      );
      if (stream != null) {
        precacheStream(primaryKey, stream);
        return stream;
      }
    } catch (_) {}

    // Tier 1.5: Direct Spotify episode embed resolver (for shows with unencrypted passthrough URLs)
    final epId = track.sourceId.startsWith('podcast_')
        ? track.sourceId.replaceFirst('podcast_', '')
        : (track.id.startsWith('podcast_') ? track.id.replaceFirst('podcast_', '') : null);
    if (epId != null && epId.length == 22 && _metadataService != null) {
      try {
        final ep = await _metadataService.fetchEpisode(epId);
        if (ep.audioUrl != null && ep.audioUrl!.isNotEmpty) {
          final isEncrypted = ep.audioUrl!.contains('scdn.co') ||
              ep.audioUrl!.contains('spotifycdn.com');
          if (!isEncrypted) {
            final uri = Uri.tryParse(ep.audioUrl!);
            if (uri != null) {
              final isM4a = ep.audioUrl!.contains('.m4a');
              final stream = StreamInfo(
                url: uri,
                container: isM4a ? 'm4a' : 'mp3',
                bitrate: 192000,
                codec: isM4a ? 'aac' : 'mp3',
                expiresAt: DateTime.now().add(const Duration(hours: 12)),
                providerName: 'spotify_passthrough_direct',
                headers: null,
              );
              precacheStream(primaryKey, stream);
              return stream;
            }
          }
        }
      } catch (_) {}
    }

    // Tier 2: Fallback to podcast-optimized YouTube Audio Stream
    try {
      final stream = await _resolveViaYouTube(
        showName: track.artist,
        episodeTitle: track.title,
        duration: track.duration,
        quality: quality,
      );
      if (stream != null) {
        precacheStream(primaryKey, stream);
        return stream;
      }
    } catch (_) {}

    // Tier 3: Fallback to Archive.org audio & podcast archives
    try {
      final stream = await _resolveViaArchiveOrg(
        showName: track.artist,
        episodeTitle: track.title,
        duration: track.duration,
      );
      if (stream != null) {
        precacheStream(primaryKey, stream);
        return stream;
      }
    } catch (_) {}

    throw const EpisodeUnavailableFailure(
      'This episode is protected by Spotify DRM (CBCS) and has no public audio feed.',
    );
  }

  /// Searches YouTube specifically for a podcast episode, matching by title and duration.
  Future<StreamInfo?> _resolveViaYouTube({
    required String showName,
    required String episodeTitle,
    required Duration duration,
    AudioQualityPreset quality = AudioQualityPreset.standard,
  }) async {
    // 1. Sanitize title: remove emojis, leading episode numbers/tags, outer parens
    var cleanTitle = episodeTitle
        .replaceAll(
          RegExp(
            r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}]',
            unicode: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'^\s*(Episode|Ep\.?|#)\s*\d+[\s\:\-\.\(]*', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'[\(\)]'), ' ')
        .trim();

    final firstSegment = cleanTitle.split('|').first.trim();
    final showClean = showName
        .replaceAll(RegExp(r'\b(podcast|show|audio series)\b', caseSensitive: false), '')
        .trim();

    final epNumMatch =
        RegExp(r'\b(?:episode|ep\.?|#)\s*(\d+)\b', caseSensitive: false).firstMatch(episodeTitle);
    final epNum = epNumMatch?.group(1);

    final queries = <String>[
      if (showClean.isNotEmpty && firstSegment.isNotEmpty) '$showClean $firstSegment',
      if (firstSegment.isNotEmpty) '$showName $firstSegment',
      if (firstSegment.isNotEmpty) firstSegment,
      if (epNum != null && showClean.isNotEmpty) '$showClean episode $epNum',
      if (epNum != null) '$showName $epNum',
    ];

    Video? bestVideo;
    int bestScore = -999;

    for (final q in queries) {
      try {
        final searchResults = await _yt.search.search(q).timeout(const Duration(seconds: 5));
        for (final v in searchResults) {
          final candDur = v.duration ?? Duration.zero;
          // Skip if candidate is less than 2 mins when expected episode is > 5 mins
          if (duration > const Duration(minutes: 5) && candDur < const Duration(minutes: 2)) {
            continue;
          }

          final tLower = v.title.toLowerCase();
          final sLower = showClean.toLowerCase();
          final fLower = firstSegment.toLowerCase();

          var score = 0;
          if (duration > Duration.zero && candDur > Duration.zero) {
            final diff = (candDur.inSeconds - duration.inSeconds).abs();
            if (diff <= 15) {
              score += 300;
            } else if (diff <= 60) {
              score += 250;
            } else if (diff <= 180) {
              score += 150;
            } else if (diff <= (duration.inSeconds * 0.15)) {
              score += 80;
            } else {
              score -= 60;
            }
          }

          // Title correlation
          if (fLower.isNotEmpty) {
            final words = fLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
            if (words.isNotEmpty) {
              final matches = words.where((w) => tLower.contains(w)).length;
              score += ((matches / words.length) * 100).toInt();
            }
          }

          if (sLower.isNotEmpty && tLower.contains(sLower)) {
            score += 40;
          }

          if (epNum != null &&
              (tLower.contains(epNum) ||
                  tLower.contains('ep $epNum') ||
                  tLower.contains('episode $epNum'))) {
            score += 50;
          }

          if (tLower.contains('teaser') ||
              tLower.contains('review') ||
              tLower.contains('reaction')) {
            score -= 100;
          }

          if (score > bestScore) {
            bestScore = score;
            bestVideo = v;
          }
        }
        if (bestScore >= 200) break;
      } catch (_) {}
    }

    if (bestVideo != null && bestScore >= 80) {
      final candId = bestVideo.id.value;
      // Priority 1: InnerTube direct audio resolution
      try {
        final data = await _innertubeService.queryPlayer(candId);
        if (data != null) {
          final stream = _innertubeService.extractStream(candId, data, quality: quality);
          if (stream != null) return stream;
        }
      } catch (_) {}

      // Priority 2: YoutubeExplode stream manifest
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(candId);
        final audioOnly = manifest.audioOnly;
        if (audioOnly.isNotEmpty) {
          final stream = audioOnly.withHighestBitrate();
          return StreamInfo(
            url: stream.url,
            container: stream.container.name,
            bitrate: stream.bitrate.bitsPerSecond,
            codec: stream.audioCodec,
            expiresAt: DateTime.now().add(const Duration(hours: 6)),
            providerName: 'podcast_youtube',
          );
        }
      } catch (_) {}
    }

    return null;
  }

  /// Searches Archive.org for mirrored podcast episodes and audio programs.
  Future<StreamInfo?> _resolveViaArchiveOrg({
    required String showName,
    required String episodeTitle,
    required Duration duration,
  }) async {
    final cleanTitle = episodeTitle
        .replaceFirst(
          RegExp(r'^\s*(\d+|ep\s*\d+|episode\s*\d+|#\s*\d+)[\.\:\-\s]+', caseSensitive: false),
          '',
        )
        .trim();

    try {
      final searchUri = Uri.parse(
        'https://archive.org/advancedsearch.php'
        '?q=${Uri.encodeComponent('("$showName" OR "$cleanTitle") AND mediatype:audio')}'
        '&fl[]=identifier,title,mediatype'
        '&rows=5&output=json',
      );
      final req = await _client.getUrl(searchUri).timeout(const Duration(seconds: 6));
      req.headers.set('User-Agent', _userAgent);
      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final docs = data['response']?['docs'] as List<dynamic>? ?? [];

      for (final doc in docs) {
        if (doc is! Map) continue;
        final id = doc['identifier'] as String?;
        if (id == null) continue;

        final metaUri = Uri.parse('https://archive.org/metadata/$id');
        final mReq = await _client.getUrl(metaUri).timeout(const Duration(seconds: 6));
        mReq.headers.set('User-Agent', _userAgent);
        final mRes = await mReq.close().timeout(const Duration(seconds: 6));
        if (mRes.statusCode != 200) continue;

        final mBody = await mRes.transform(utf8.decoder).join();
        final meta = jsonDecode(mBody) as Map<String, dynamic>;
        final files = meta['files'] as List<dynamic>? ?? [];

        for (final f in files) {
          if (f is! Map) continue;
          final name = f['name'] as String? ?? '';
          if (name.endsWith('.mp3') || name.endsWith('.m4a')) {
            final isM4a = name.endsWith('.m4a');
            final downloadUrl = Uri.parse(
              'https://archive.org/download/$id/${Uri.encodeComponent(name)}',
            );
            return StreamInfo(
              url: downloadUrl,
              container: isM4a ? 'm4a' : 'mp3',
              bitrate: 128000,
              codec: isM4a ? 'aac' : 'mp3',
              expiresAt: DateTime.now().add(const Duration(hours: 12)),
              providerName: 'podcast_archive',
            );
          }
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> prefetch(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
  }) async {
    try {
      await resolve(track, quality: quality);
    } catch (_) {}
  }

  /// Resolves direct audio stream URL for a given show name and episode title.
  Future<StreamInfo?> resolveEpisodeStream({
    required String showName,
    required String episodeTitle,
    Duration targetDuration = Duration.zero,
  }) async {
    // 1. Query iTunes Podcast API
    final query = Uri.encodeComponent(showName);
    final searchUri = Uri.parse(
      'https://itunes.apple.com/search?term=$query&media=podcast&entity=podcast&limit=3',
    );

    final req = await _client.getUrl(searchUri).timeout(const Duration(seconds: 5));
    req.headers.set('User-Agent', _userAgent);
    final res = await req.close().timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;

    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return null;

    for (final show in results) {
      final colName = show['collectionName'] as String? ?? '';
      final showSim = _calculateSimilarity(_normalize(colName), _normalize(showName));
      if (showSim < 0.35 &&
          !_normalize(colName).contains(_normalize(showName)) &&
          !_normalize(showName).contains(_normalize(colName))) {
        // Show name does not match at all! Skip this unrelated collection!
        continue;
      }

      final collectionId = show['collectionId'] as num?;
      final feedUrl = show['feedUrl'] as String?;

      // Fast Path: Check Apple Podcast Episodes Lookup (instant JSON)
      if (collectionId != null) {
        try {
          final stream = await _findAudioInAppleLookup(
            collectionId.toInt(),
            episodeTitle,
            targetDuration: targetDuration,
          );
          if (stream != null) return stream;
        } catch (_) {}
      }

      // Secondary Path: Download and parse RSS feed XML
      if (feedUrl != null && feedUrl.isNotEmpty) {
        try {
          final stream = await _findAudioInFeed(
            feedUrl,
            episodeTitle,
            targetDuration: targetDuration,
          );
          if (stream != null) return stream;
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  /// Queries Apple podcast episodes lookup endpoint for fast JSON-based matching.
  Future<StreamInfo?> _findAudioInAppleLookup(
    int collectionId,
    String targetTitle, {
    Duration targetDuration = Duration.zero,
  }) async {
    final lookupUri = Uri.parse(
      'https://itunes.apple.com/lookup?id=$collectionId&entity=podcastEpisode&limit=100',
    );
    final req = await _client.getUrl(lookupUri).timeout(const Duration(seconds: 6));
    req.headers.set('User-Agent', _userAgent);
    final res = await req.close().timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;

    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = json['results'] as List<dynamic>? ?? [];
    if (items.length <= 1) return null;

    // First item is collection metadata, remaining items are episodes
    final normalizedTarget = _normalize(targetTitle);
    Map<String, dynamic>? bestItem;
    double bestScore = 0.0;

    for (var i = 1; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final trackName = item['trackName'] as String? ?? '';
      final score = _calculateSimilarity(normalizedTarget, _normalize(trackName));
      if (score > bestScore) {
        bestScore = score;
        bestItem = item;
      }
    }

    // Strict threshold: never fall back to unrelated items[1]
    final selected = (bestScore >= 0.35) ? bestItem : null;
    if (selected == null) return null;

    // Validate duration tolerance if targetDuration is provided
    if (targetDuration > Duration.zero) {
      final timeMillis = selected['trackTimeMillis'] as num?;
      if (timeMillis != null && timeMillis > 0) {
        final candDur = Duration(milliseconds: timeMillis.toInt());
        final diff = (candDur.inSeconds - targetDuration.inSeconds).abs();
        if (diff > (targetDuration.inSeconds * 0.35)) {
          return null; // Duration mismatch
        }
      }
    }

    final audioUrlStr = selected['episodeUrl'] as String?;
    if (audioUrlStr == null || audioUrlStr.isEmpty) return null;

    final audioUri = Uri.tryParse(audioUrlStr);
    if (audioUri == null) return null;

    final isM4a = audioUrlStr.contains('.m4a');
    return StreamInfo(
      url: audioUri,
      container: isM4a ? 'm4a' : 'mp3',
      bitrate: 192000,
      codec: isM4a ? 'aac' : 'mp3',
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
      providerName: 'podcast_apple_lookup',
      headers: null,
    );
  }

  /// Fetches RSS feed XML and finds audio enclosure for the matching episode.
  Future<StreamInfo?> _findAudioInFeed(
    String feedUrl,
    String targetTitle, {
    Duration targetDuration = Duration.zero,
  }) async {
    final req = await _client.getUrl(Uri.parse(feedUrl)).timeout(const Duration(seconds: 12));
    req.headers.set('User-Agent', _userAgent);
    final res = await req.close().timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;

    final xml = await res.transform(utf8.decoder).join();
    final items = _parseRssItems(xml);
    if (items.isEmpty) return null;

    final normalizedTarget = _normalize(targetTitle);

    // Score candidates by title similarity
    Map<String, String>? bestItem;
    double bestScore = 0.0;

    for (final item in items) {
      final itemTitle = item['title'] ?? '';
      final score = _calculateSimilarity(normalizedTarget, _normalize(itemTitle));
      if (score > bestScore) {
        bestScore = score;
        bestItem = item;
      }
    }

    // Strict threshold: never fall back to unrelated items.first
    final selected = (bestScore >= 0.35) ? bestItem : null;
    if (selected == null) return null;

    final audioUrlStr = selected['audioUrl'];
    if (audioUrlStr == null || audioUrlStr.isEmpty) return null;

    final audioUri = Uri.tryParse(audioUrlStr);
    if (audioUri == null) return null;

    final container = audioUrlStr.contains('.m4a') ? 'm4a' : 'mp3';
    final codec = container == 'm4a' ? 'aac' : 'mp3';

    return StreamInfo(
      url: audioUri,
      container: container,
      bitrate: 192000,
      codec: codec,
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
      providerName: 'podcast_rss',
      headers: null,
    );
  }

  List<Map<String, String>> _parseRssItems(String xml) {
    final items = <Map<String, String>>[];
    final itemPattern = RegExp(r'<item[^>]*>(.*?)</item>', dotAll: true);
    final titlePattern = RegExp(r'<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', dotAll: true);
    final enclosurePattern = RegExp(r'<enclosure[^>]+url=["\x27]([^"\x27]+)["\x27]', dotAll: true);

    for (final match in itemPattern.allMatches(xml)) {
      final chunk = match.group(1) ?? '';
      final tMatch = titlePattern.firstMatch(chunk);
      final eMatch = enclosurePattern.firstMatch(chunk);

      final title = tMatch != null ? _cleanXml(tMatch.group(1) ?? '') : '';
      final audioUrl = eMatch != null ? (eMatch.group(1) ?? '').trim() : '';

      if (audioUrl.isNotEmpty) {
        items.add({
          'title': title,
          'audioUrl': audioUrl,
        });
      }
    }
    return items;
  }

  String _cleanXml(String str) {
    return str
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _normalize(String str) {
    return str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
  }

  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    if (a.contains(b) || b.contains(a)) return 0.8;

    final wordsA = a.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    final wordsB = b.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    final intersection = wordsA.intersection(wordsB).length;
    return (2.0 * intersection) / (wordsA.length + wordsB.length);
  }

  void precacheStream(String key, StreamInfo stream) {
    _cache[key] = stream;
    final clean = key.replaceFirst('podcast_', '');
    _cache[clean] = stream;
    _cache['podcast_$clean'] = stream;
  }

  StreamInfo? getCachedStream(String key) => _cache[key];

  void close() {
    _client.close(force: true);
  }
}
