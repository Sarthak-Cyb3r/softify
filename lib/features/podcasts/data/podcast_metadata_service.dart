import 'dart:convert';
import 'dart:io';

import '../domain/podcast_episode.dart';
import '../domain/podcast_failure.dart';

class PodcastShowMetadata {
  final String title;
  final String publisher;
  final String description;
  final String? coverUrl;

  const PodcastShowMetadata({
    required this.title,
    required this.publisher,
    required this.description,
    this.coverUrl,
  });
}

class PodcastMetadataService {
  final HttpClient _client;

  PodcastMetadataService({HttpClient? client}) : _client = client ?? HttpClient();

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static const String _crawlerUserAgent =
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.html)';

  static String? _cachedAnonymousToken;
  static DateTime? _tokenExpiry;

  /// Retrieves a working anonymous Spotify bearer access token.
  Future<String?> getAnonymousToken({String? fallbackId}) async {
    if (_cachedAnonymousToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedAnonymousToken;
    }

    final id = fallbackId ?? '3pUWoZ6fC2qA02D3X0CeMb';
    final uri = Uri.parse('https://open.spotify.com/embed/show/$id');
    try {
      final req = await _client.getUrl(uri).timeout(const Duration(seconds: 5));
      req.headers.set('User-Agent', _defaultUserAgent);
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final tokenMatch = RegExp(r'"accessToken":"([^"]+)"').firstMatch(body);
        if (tokenMatch != null) {
          _cachedAnonymousToken = tokenMatch.group(1);
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
          return _cachedAnonymousToken;
        }
      }
    } catch (_) {}
    return _cachedAnonymousToken;
  }

  /// Fetches show metadata for a Spotify podcast show ID.
  Future<PodcastShowMetadata> fetchShow(String showId) async {
    // 1. Try Spotify embed Next.js metadata
    try {
      final embedUri = Uri.parse('https://open.spotify.com/embed/show/$showId');
      final req = await _client.getUrl(embedUri).timeout(const Duration(seconds: 5));
      req.headers.set('User-Agent', _defaultUserAgent);
      req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');

      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final tokenMatch = RegExp(r'"accessToken":"([^"]+)"').firstMatch(body);
        if (tokenMatch != null) {
          _cachedAnonymousToken = tokenMatch.group(1);
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
        }

        final nextDataMatch =
            RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>')
                .firstMatch(body);

        if (nextDataMatch != null) {
          final jsonStr = nextDataMatch.group(1)!;
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          final entity =
              parsed['props']?['pageProps']?['state']?['data']?['entity'] as Map<String, dynamic>?;

          if (entity != null) {
            final title = (entity['subtitle'] ?? entity['title'] ?? entity['name'] ?? 'Podcast') as String;
            final publisher = (entity['subtitle'] ?? 'Podcast') as String;
            final desc = (entity['description'] as String?) ?? '';

            String? coverUrl;
            final visual = entity['visualIdentity'];
            if (visual is Map && visual['image'] is List) {
              final images = visual['image'] as List<dynamic>;
              if (images.isNotEmpty && images.last is Map) {
                coverUrl = (images.last as Map)['url'] as String?;
              }
            } else if (entity['relatedEntityCoverArt'] is Map) {
              final sources = entity['relatedEntityCoverArt']['sources'] as List<dynamic>?;
              if (sources != null && sources.isNotEmpty && sources.first is Map) {
                coverUrl = (sources.first as Map)['url'] as String?;
              }
            }

            if (title.isNotEmpty && title != 'Page not available') {
              return PodcastShowMetadata(
                title: title,
                publisher: publisher,
                description: desc,
                coverUrl: coverUrl,
              );
            }
          }
        }
      }
    } catch (_) {}

    // 2. OpenGraph SSR crawler fallback
    try {
      final showUri = Uri.parse('https://open.spotify.com/show/$showId');
      final req = await _client.getUrl(showUri).timeout(const Duration(seconds: 5));
      req.headers.set('User-Agent', _crawlerUserAgent);

      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final html = await res.transform(utf8.decoder).join();
        final ogTitleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html);
        final ogDescMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(html);
        final ogImageMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(html);

        final title = ogTitleMatch?.group(1)?.trim();
        final rawDesc = ogDescMatch?.group(1)?.trim() ?? '';
        final coverUrl = ogImageMatch?.group(1)?.trim();

        if (title != null && title.isNotEmpty && title != 'Spotify – Web Player') {
          // Description format: "Podcast · Publisher · Description"
          final parts = rawDesc.split(' · ');
          final publisher = parts.length >= 2 ? parts[1].trim() : 'Podcast';
          final desc = parts.length >= 3 ? parts.sublist(2).join(' · ').trim() : rawDesc;

          return PodcastShowMetadata(
            title: title,
            publisher: publisher,
            description: desc,
            coverUrl: coverUrl,
          );
        }
      }
    } catch (_) {}

    throw const EpisodeUnavailableFailure('Show not found or unavailable on Spotify.');
  }

  /// Fetches metadata for a single Spotify podcast episode.
  Future<PodcastEpisode> fetchEpisode(String episodeId) async {
    final uri = Uri.parse('https://open.spotify.com/embed/episode/$episodeId');
    try {
      final req = await _client.getUrl(uri).timeout(const Duration(seconds: 6));
      req.headers.set('User-Agent', _defaultUserAgent);
      req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');

      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode == 404) {
        throw const EpisodeUnavailableFailure('Episode not found on Spotify.');
      }
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final tokenMatch = RegExp(r'"accessToken":"([^"]+)"').firstMatch(body);
        if (tokenMatch != null) {
          _cachedAnonymousToken = tokenMatch.group(1);
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
        }

        final nextDataMatch =
            RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>')
                .firstMatch(body);

        if (nextDataMatch != null) {
          final jsonStr = nextDataMatch.group(1)!;
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          final entity =
              parsed['props']?['pageProps']?['state']?['data']?['entity'] as Map<String, dynamic>?;

          if (entity != null) {
            final title = (entity['title'] ?? entity['name'] ?? 'Podcast Episode') as String;
            final showName = (entity['subtitle'] ?? 'Podcast') as String;
            final durationMs = (entity['duration'] as num?)?.toInt() ?? 0;

            String? coverUrl;
            final visual = entity['visualIdentity'];
            if (visual is Map && visual['image'] is List) {
              final images = visual['image'] as List<dynamic>;
              if (images.isNotEmpty && images.last is Map) {
                coverUrl = (images.last as Map)['url'] as String?;
              }
            } else if (visual is List && visual.isNotEmpty) {
              coverUrl = visual.first['url'] as String?;
            }

            DateTime? releaseDate;
            final relDate = entity['releaseDate'];
            if (relDate is Map && relDate['isoString'] != null) {
              releaseDate = DateTime.tryParse(relDate['isoString'] as String);
            } else if (relDate is String) {
              releaseDate = DateTime.tryParse(relDate);
            }

            // Check for direct unencrypted passthrough audio URL
            String? audioUrl;
            final defaultAudio = parsed['props']?['pageProps']?['state']?['data']?['defaultAudioFileObject'] as Map<String, dynamic>?;
            if (defaultAudio != null) {
              final passthroughUrl = defaultAudio['passthroughUrl'] as String?;
              final format = defaultAudio['format'] as String? ?? '';
              final isEncryptedCbcs = format.contains('CBCS');

              if (passthroughUrl != null && passthroughUrl.isNotEmpty) {
                audioUrl = passthroughUrl;
              } else if (!isEncryptedCbcs && defaultAudio['url'] is List) {
                final urls = (defaultAudio['url'] as List).whereType<String>().toList();
                if (urls.isNotEmpty && !urls.first.contains('scdn.co') && !urls.first.contains('spotifycdn.com')) {
                  audioUrl = urls.first;
                }
              }
            }

            final desc = (entity['description'] as String?) ?? '';

            return PodcastEpisode(
              id: episodeId,
              showId: (entity['relatedEntityUri'] as String? ?? '').replaceFirst('spotify:show:', ''),
              showName: showName,
              title: title,
              description: desc,
              duration: Duration(milliseconds: durationMs),
              coverUrl: coverUrl,
              releaseDate: releaseDate,
              audioUrl: audioUrl,
            );
          }
        }
      }
    } catch (_) {}

    // Fallback 1: OpenGraph crawler
    try {
      final epUri = Uri.parse('https://open.spotify.com/episode/$episodeId');
      final req = await _client.getUrl(epUri).timeout(const Duration(seconds: 5));
      req.headers.set('User-Agent', _crawlerUserAgent);

      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final html = await res.transform(utf8.decoder).join();
        final ogTitle = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html)?.group(1)?.trim();
        final ogDesc = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(html)?.group(1)?.trim();
        final ogImage = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(html)?.group(1)?.trim();

        if (ogTitle != null && ogTitle.isNotEmpty && ogTitle != 'Spotify – Web Player') {
          // Format of ogDesc is usually: "Show Name · Episode"
          final showName = ogDesc != null && ogDesc.contains(' · ')
              ? ogDesc.split(' · ').first.trim()
              : 'Podcast';

          return PodcastEpisode(
            id: episodeId,
            showId: '',
            showName: showName,
            title: ogTitle,
            description: '',
            duration: Duration.zero,
            coverUrl: ogImage,
          );
        }
      }
    } catch (_) {}

    // Fallback 2: oEmbed
    return await _fetchEpisodeViaOEmbed(episodeId);
  }

  Future<PodcastEpisode> _fetchEpisodeViaOEmbed(String episodeId) async {
    final oembedUri = Uri.parse(
      'https://open.spotify.com/oembed?url=https://open.spotify.com/episode/$episodeId',
    );
    final req = await _client.getUrl(oembedUri).timeout(const Duration(seconds: 5));
    req.headers.set('User-Agent', _defaultUserAgent);
    final res = await req.close().timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) {
      throw const EpisodeUnavailableFailure('Episode not available.');
    }

    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final title = (json['title'] as String? ?? 'Podcast Episode').trim();
    final thumbnail = json['thumbnail_url'] as String?;

    return PodcastEpisode(
      id: episodeId,
      showId: '',
      showName: 'Podcast',
      title: title,
      description: '',
      duration: Duration.zero,
      coverUrl: thumbnail,
    );
  }

  /// Fetches episodes of a Spotify show directly via Spotify's internal Pathfinder GraphQL API.
  /// Used for Spotify Exclusive and Original shows that are not in public RSS/Apple directories.
  Future<List<PodcastEpisode>> fetchShowEpisodesViaSpotifyApi({
    required String showId,
    required String showTitle,
    String? coverUrl,
  }) async {
    final token = await getAnonymousToken(fallbackId: showId);
    if (token == null) return const [];

    try {
      final variables = jsonEncode({
        'uri': 'spotify:show:$showId',
        'offset': 0,
        'limit': 100,
        'includeEpisodeContentRatingsV2': false,
      });
      final extensions = jsonEncode({
        'persistedQuery': {
          'version': 1,
          'sha256Hash': '3539d746cf882f3909660de40b4ef472b3f5893a0761d617c282541de5d412c5',
        },
      });

      final queryUri = Uri.parse(
        'https://api-partner.spotify.com/pathfinder/v1/query'
        '?operationName=queryPodcastEpisodes'
        '&variables=${Uri.encodeComponent(variables)}'
        '&extensions=${Uri.encodeComponent(extensions)}',
      );

      final req = await _client.getUrl(queryUri).timeout(const Duration(seconds: 8));
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.set('User-Agent', _defaultUserAgent);
      req.headers.set('Accept', 'application/json');

      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final items = json['data']?['podcastUnionV2']?['episodesV2']?['items'] as List<dynamic>?;
        if (items == null || items.isEmpty) return const [];

        final List<PodcastEpisode> episodes = [];
        for (final item in items) {
          if (item is! Map) continue;
          final entity = item['entity'] as Map<String, dynamic>?;
          if (entity == null) continue;

          final uriStr = entity['_uri'] as String? ?? '';
          final epId = uriStr.replaceFirst('spotify:episode:', '');
          final epData = entity['data'] as Map<String, dynamic>? ?? {};

          final name = epData['name'] as String? ?? 'Episode';
          final desc = epData['description'] as String? ?? '';
          final durationMs = (epData['duration']?['totalMilliseconds'] as num?)?.toInt() ?? 0;

          String? epCover = coverUrl;
          final coverArt = epData['coverArt'];
          if (coverArt is Map && coverArt['sources'] is List) {
            final sources = coverArt['sources'] as List<dynamic>;
            if (sources.isNotEmpty && sources.first is Map) {
              epCover = sources.first['url'] as String?;
            }
          }

          DateTime? relDate;
          final dateStr = epData['releaseDate']?['isoString'] as String?;
          if (dateStr != null) {
            relDate = DateTime.tryParse(dateStr);
          }

          episodes.add(
            PodcastEpisode(
              id: epId,
              showId: showId,
              showName: showTitle,
              title: name,
              description: desc,
              duration: Duration(milliseconds: durationMs),
              coverUrl: epCover,
              releaseDate: relDate,
              audioUrl: null,
            ),
          );
        }

        return episodes;
      }
    } catch (_) {}

    return const [];
  }

  void close() {
    _client.close(force: true);
  }
}
