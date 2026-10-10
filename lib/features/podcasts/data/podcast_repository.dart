import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../domain/entities/stream_info.dart';
import '../../../domain/entities/track.dart';
import '../domain/podcast_episode.dart';
import '../domain/podcast_failure.dart';
import '../domain/podcast_show.dart';
import 'podcast_history_dao.dart';
import 'podcast_metadata_service.dart';
import 'podcast_rss_resolver.dart';

class PodcastException implements Exception {
  final PodcastFailure failure;
  const PodcastException(this.failure);

  @override
  String toString() => 'PodcastException: ${failure.userMessage}';
}

class PodcastRepository {
  final PodcastMetadataService _metadataService;
  final PodcastRssResolver _rssResolver;
  final PodcastHistoryDao? _historyDao;
  final HttpClient _client;

  PodcastRepository({
    PodcastMetadataService? metadataService,
    PodcastRssResolver? rssResolver,
    PodcastHistoryDao? historyDao,
    HttpClient? client,
  })  : _metadataService = metadataService ?? PodcastMetadataService(),
        _rssResolver = rssResolver ?? PodcastRssResolver(),
        _historyDao = historyDao,
        _client = client ?? HttpClient();

  PodcastRssResolver get rssResolver => _rssResolver;
  PodcastHistoryDao? get historyDao => _historyDao;

  /// Fetches episode metadata, resolves its direct playable audio stream,
  /// precaches it, and maps it to domain [PodcastEpisode] and [Track].
  Future<({PodcastEpisode episode, Track track})> fetchEpisode(String episodeId) async {
    try {
      var episode = await _metadataService.fetchEpisode(episodeId);

      // Pre-resolve direct stream so playback starts instantaneously
      StreamInfo? resolvedStream;
      if (episode.audioUrl != null && episode.audioUrl!.isNotEmpty) {
        final isEncrypted = episode.audioUrl!.contains('scdn.co') ||
            episode.audioUrl!.contains('spotifycdn.com');
        if (!isEncrypted) {
          final uri = Uri.tryParse(episode.audioUrl!);
          if (uri != null) {
            final isM4a = episode.audioUrl!.contains('.m4a');
            resolvedStream = StreamInfo(
              url: uri,
              container: isM4a ? 'm4a' : 'mp3',
              bitrate: 192000,
              codec: isM4a ? 'aac' : 'mp3',
              expiresAt: DateTime.now().add(const Duration(hours: 12)),
              providerName: 'podcast_direct',
              headers: null,
            );
          }
        }
      }

      final track = Track(
        id: 'podcast_${episode.id}',
        sourceId: 'podcast_${episode.id}',
        title: episode.title,
        artist: episode.showName,
        album: 'Podcast',
        duration: episode.duration,
        coverUrl: episode.coverUrl,
        matchConfidence: 1.0,
      );

      // Multi-tier fallback resolution (Apple Podcasts RSS -> YouTube Podcast -> Archive.org)
      resolvedStream ??= await _rssResolver.resolve(track);

      episode = episode.copyWith(audioUrl: resolvedStream.url.toString());
      _rssResolver.precacheStream(episode.id, resolvedStream);
      _rssResolver.precacheStream('podcast_${episode.id}', resolvedStream);

      return (episode: episode, track: track);
    } on PodcastFailure catch (f) {
      throw PodcastException(f);
    } catch (e) {
      throw PodcastException(EpisodeUnavailableFailure('Failed to load episode: $e'));
    }
  }

  /// Fetches a full show and its episodes via Spotify metadata and Apple Podcasts directory.
  Future<({PodcastShow show, List<PodcastEpisode> episodes})> fetchShow(String showId) async {
    try {
      final showMeta = await _metadataService.fetchShow(showId);
      return await _fetchShowEpisodesByName(
        showId: showId,
        title: showMeta.title,
        publisher: showMeta.publisher,
        description: showMeta.description,
        fallbackCover: showMeta.coverUrl,
      );
    } on PodcastFailure catch (f) {
      throw PodcastException(f);
    } catch (e) {
      throw PodcastException(EpisodeUnavailableFailure('Failed to load show: $e'));
    }
  }

  /// Searches for a podcast show by plain text name and returns its episodes.
  Future<({PodcastShow show, List<PodcastEpisode> episodes})> searchShow(String query) async {
    try {
      return await _fetchShowEpisodesByName(
        showId: 'search_${query.hashCode.abs()}',
        title: query,
        publisher: 'Podcast',
        description: '',
        fallbackCover: null,
      );
    } on PodcastFailure catch (f) {
      throw PodcastException(f);
    } catch (e) {
      throw PodcastException(EpisodeUnavailableFailure('Failed to search show: $e'));
    }
  }

  Future<({PodcastShow show, List<PodcastEpisode> episodes})> _fetchShowEpisodesByName({
    required String showId,
    required String title,
    required String publisher,
    required String description,
    String? fallbackCover,
  }) async {
    // 1. Search Apple Podcasts API for the show
    final term = Uri.encodeComponent(title);
    final searchUri = Uri.parse(
      'https://itunes.apple.com/search?term=$term&media=podcast&entity=podcast&limit=1',
    );

    final req = await _client.getUrl(searchUri).timeout(const Duration(seconds: 6));
    req.headers.set(
      'User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    );
    final res = await req.close().timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) {
      throw const EpisodeUnavailableFailure('Show directory temporarily unavailable.');
    }

    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? [];

    if (results.isEmpty) {
      // Fallback for Spotify Exclusive Shows (not listed in Apple Podcasts directory)
      if (!showId.startsWith('search_')) {
        final spotifyEpisodes = await _metadataService.fetchShowEpisodesViaSpotifyApi(
          showId: showId,
          showTitle: title,
          coverUrl: fallbackCover,
        );

        if (spotifyEpisodes.isNotEmpty) {
          final show = PodcastShow(
            id: showId,
            title: title,
            publisher: publisher,
            description: description,
            coverUrl: fallbackCover,
            episodes: spotifyEpisodes,
          );
          return (show: show, episodes: spotifyEpisodes);
        }
      }

      throw EpisodeUnavailableFailure('Could not find podcast show "$title".');
    }

    final showData = results.first as Map<String, dynamic>;
    final collectionId = showData['collectionId'] as num?;
    final canonicalTitle = (showData['collectionName'] as String?) ?? title;
    final canonicalPublisher = (showData['artistName'] as String?) ?? publisher;
    final cover = (showData['artworkUrl600'] ?? showData['artworkUrl100'] ?? fallbackCover) as String?;
    final feedUrl = showData['feedUrl'] as String?;

    final List<PodcastEpisode> episodes = [];

    // 2. Fast Path: Lookup episodes via Apple API (up to 200 items in JSON)
    if (collectionId != null) {
      try {
        final lookupUri = Uri.parse(
          'https://itunes.apple.com/lookup?id=$collectionId&entity=podcastEpisode&limit=200',
        );
        final lReq = await _client.getUrl(lookupUri).timeout(const Duration(seconds: 7));
        lReq.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        );
        final lRes = await lReq.close().timeout(const Duration(seconds: 7));

        if (lRes.statusCode == 200) {
          final lBody = await lRes.transform(utf8.decoder).join();
          final lJson = jsonDecode(lBody) as Map<String, dynamic>;
          final epList = lJson['results'] as List<dynamic>? ?? [];

          for (var i = 1; i < epList.length; i++) {
            final ep = epList[i] as Map<String, dynamic>;
            final epTitle = ep['trackName'] as String? ?? 'Episode $i';
            final audioUrl = ep['episodeUrl'] as String? ?? '';
            if (audioUrl.isEmpty) continue;

            final epId = 'apple_${ep['trackId'] ?? audioUrl.hashCode.abs()}';
            final durMs = (ep['trackTimeMillis'] as num?)?.toInt() ?? 0;
            final desc = (ep['description'] as String?) ?? '';
            final epCover = (ep['artworkUrl600'] ?? ep['artworkUrl160'] ?? cover) as String?;

            DateTime? relDate;
            if (ep['releaseDate'] != null) {
              relDate = DateTime.tryParse(ep['releaseDate'] as String);
            }

            final episode = PodcastEpisode(
              id: epId,
              showId: showId,
              showName: canonicalTitle,
              title: epTitle,
              description: desc,
              duration: Duration(milliseconds: durMs),
              coverUrl: epCover,
              releaseDate: relDate,
              audioUrl: audioUrl,
            );

            // Precache audio stream immediately
            final isM4a = audioUrl.contains('.m4a');
            _rssResolver.precacheStream(
              episode.id,
              StreamInfo(
                url: Uri.parse(audioUrl),
                container: isM4a ? 'm4a' : 'mp3',
                bitrate: 192000,
                codec: isM4a ? 'aac' : 'mp3',
                expiresAt: DateTime.now().add(const Duration(hours: 12)),
                providerName: 'podcast_show',
                headers: null,
              ),
            );

            episodes.add(episode);
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: Parse direct RSS feed if Apple lookup didn't yield episodes
    if (episodes.isEmpty && feedUrl != null && feedUrl.isNotEmpty) {
      final feedUri = Uri.tryParse(feedUrl);
      if (feedUri != null) {
        final rssResult = await fetchFromDirectRss(feedUri);
        episodes.addAll(rssResult.map((e) => e.episode));
      }
    }

    if (episodes.isEmpty) {
      throw const EpisodeUnavailableFailure('No playable episodes found for this show.');
    }

    final podcastShow = PodcastShow(
      id: showId,
      title: canonicalTitle,
      publisher: canonicalPublisher,
      description: description,
      coverUrl: cover,
      episodes: episodes,
    );

    return (show: podcastShow, episodes: episodes);
  }

  /// Parses a direct RSS feed and returns the latest episodes as [PodcastEpisode].
  Future<List<({PodcastEpisode episode, Track track})>> fetchFromDirectRss(Uri feedUri) async {
    try {
      final req = await _client.getUrl(feedUri).timeout(const Duration(seconds: 12));
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      );
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw EpisodeUnavailableFailure('Failed to load RSS feed (HTTP ${res.statusCode}).');
      }

      final xml = await res.transform(utf8.decoder).join();
      final showTitle = _extractTag(xml, 'title') ?? 'Podcast';
      final showImage = _extractShowImage(xml);

      final items = <({PodcastEpisode episode, Track track})>[];
      final itemPattern = RegExp(r'<item[^>]*>(.*?)</item>', dotAll: true);
      final enclosurePattern = RegExp(r'<enclosure[^>]+url=["\x27]([^"\x27]+)["\x27]', dotAll: true);
      final durationPattern = RegExp(r'<(?:itunes:)?duration>(.*?)</(?:itunes:)?duration>', dotAll: true);
      final descPattern = RegExp(r'<(?:description|itunes:summary)>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</(?:description|itunes:summary)>', dotAll: true);

      for (final match in itemPattern.allMatches(xml)) {
        final chunk = match.group(1) ?? '';
        final title = _extractTag(chunk, 'title') ?? 'Episode';
        final eMatch = enclosurePattern.firstMatch(chunk);
        final audioUrl = eMatch != null ? (eMatch.group(1) ?? '').trim() : '';
        if (audioUrl.isEmpty) continue;

        final durMatch = durationPattern.firstMatch(chunk);
        final duration = _parseDuration(durMatch?.group(1)?.trim());

        final descMatch = descPattern.firstMatch(chunk);
        final desc = descMatch != null ? _cleanXml(descMatch.group(1) ?? '') : '';

        final episodeId = 'rss_${audioUrl.hashCode.abs()}';

        final episode = PodcastEpisode(
          id: episodeId,
          showId: 'rss_${feedUri.toString().hashCode.abs()}',
          showName: showTitle,
          title: title,
          description: desc,
          duration: duration,
          coverUrl: showImage,
          audioUrl: audioUrl,
        );

        final track = Track(
          id: 'podcast_${episode.id}',
          sourceId: 'podcast_${episode.id}',
          title: episode.title,
          artist: episode.showName,
          album: 'Podcast',
          duration: episode.duration,
          coverUrl: episode.coverUrl,
          matchConfidence: 1.0,
        );

        // Precache audio stream
        final isM4a = audioUrl.contains('.m4a');
        _rssResolver.precacheStream(
          track.id,
          StreamInfo(
            url: Uri.parse(audioUrl),
            container: isM4a ? 'm4a' : 'mp3',
            bitrate: 192000,
            codec: isM4a ? 'aac' : 'mp3',
            expiresAt: DateTime.now().add(const Duration(hours: 12)),
            providerName: 'podcast_rss',
            headers: null,
          ),
        );

        items.add((episode: episode, track: track));
        if (items.length >= 200) break;
      }

      if (items.isEmpty) {
        throw const EpisodeUnavailableFailure('No playable audio episodes found in this RSS feed.');
      }

      return items;
    } on PodcastFailure catch (f) {
      throw PodcastException(f);
    } on SocketException {
      throw const PodcastException(NetworkPodcastFailure());
    } catch (e) {
      throw PodcastException(EpisodeUnavailableFailure('Failed to parse RSS feed: $e'));
    }
  }

  String? _extractTag(String xml, String tag) {
    final pattern = RegExp('<$tag>(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?</$tag>', dotAll: true);
    final match = pattern.firstMatch(xml);
    return match != null ? _cleanXml(match.group(1) ?? '') : null;
  }

  String? _extractShowImage(String xml) {
    final itunesImage = RegExp(r'<itunes:image[^>]+href=["\x27]([^"\x27]+)["\x27]').firstMatch(xml);
    if (itunesImage != null) return itunesImage.group(1);

    final imgUrl = RegExp(r'<image>.*?<url>(.*?)</url>.*?</image>', dotAll: true).firstMatch(xml);
    if (imgUrl != null) return imgUrl.group(1)?.trim();

    return null;
  }

  Duration _parseDuration(String? str) {
    if (str == null || str.isEmpty) return Duration.zero;
    if (int.tryParse(str) != null) {
      return Duration(seconds: int.parse(str));
    }
    final parts = str.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    }
    return Duration.zero;
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

  void close() {
    _metadataService.close();
    _rssResolver.close();
    _client.close(force: true);
  }
}
